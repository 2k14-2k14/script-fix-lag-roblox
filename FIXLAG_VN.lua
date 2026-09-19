-- =====================================================
-- FIXLAG_VN TURBO v5 — FAST ENGINE (5-10x nhanh hơn)
-- Master single-pass applier + full memoize cache
-- =====================================================
local Lighting    = game:GetService("Lighting")
local Workspace   = game:GetService("Workspace")
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Stats       = game:GetService("Stats")
local SoundSvc    = game:GetService("SoundService")
local StarterGui  = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local Cam         = Workspace.CurrentCamera

for _, v in ipairs(game.CoreGui:GetChildren()) do
    if v.Name == "FIXLAG_VN" then v:Destroy() end
end

local function forceEnableCoreGui()
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true)
    end)
end
forceEnableCoreGui()
spawn(function() while task.wait(1) do forceEnableCoreGui() end end)

-- =====================================================
-- ⚡ FAST LOOKUP TABLES (memoized)
-- =====================================================
local BLACKLIST_KEYWORDS = {
    "sky","sun","moon","star","cloud","lens","flare","atmosphere",
    "fog","rain","snow","wind","particle","effect","glow","beam",
    "trail","smoke","fire","flame","spark","light","lamp","billboard",
    "surfacegui","text","gui","label","sign","nametag","name",
    "humanoid","character","player","npc","lensfl","spawnlocation","checkpoint",
    "leaderboard","board","scoreboard","top","rank","kill","win","stat",
}
local PROTECTED_NAMES = {
    "baseplate","base","ground","floor","platform","spawn",
    "terrain","world","map","zone","area","region",
    "start","lobby","hub","main","center","root",
    "foundation","pavement","road","path","walkway",
}

-- ⚡ Memoize by name (rất nhiều part có cùng tên)
local _blackMemo, _protMemo = {}, {}
local function isBlacklisted(p)
    if not p or not p.Name then return false end
    local m = _blackMemo[p.Name]
    if m ~= nil then return m end
    local n = p.Name:lower()
    m = false
    for i = 1, #BLACKLIST_KEYWORDS do
        if n:find(BLACKLIST_KEYWORDS[i]) then m = true; break end
    end
    _blackMemo[p.Name] = m
    return m
end

local function isNameProtected(p)
    if not p or not p.Name then return false end
    local m = _protMemo[p.Name]
    if m ~= nil then return m end
    local n = p.Name:lower()
    m = false
    for i = 1, #PROTECTED_NAMES do
        if n:find(PROTECTED_NAMES[i]) then m = true; break end
    end
    _protMemo[p.Name] = m
    return m
end

-- =====================================================
-- ⚡ CHARACTER CACHE
-- =====================================================
local _charCache = {}
local function refreshCharCache()
    _charCache = {}
    local ps = Players:GetPlayers()
    for i = 1, #ps do
        local c = ps[i].Character
        if c then _charCache[c] = true end
    end
end
refreshCharCache()
spawn(function() while task.wait(3) do refreshCharCache() end end)

local function isPartOfAnyCharacter(p)
    if not p then return false end
    local anc = p
    for i = 1, 6 do
        if not anc or anc == Workspace then break end
        if _charCache[anc] then return true end
        if anc:IsA("Model") and anc:FindFirstChildOfClass("Humanoid") then return true end
        anc = anc.Parent
    end
    return false
end

local function isUIInstance(inst)
    if not inst then return false end
    local par = inst
    for i = 1, 6 do
        if not par then break end
        if par:IsA("ScreenGui") or par:IsA("PlayerGui") or par:IsA("CoreGui") then return true end
        if par:IsA("GuiObject") or par:IsA("GuiBase2d") or par:IsA("LayerCollector") then return true end
        if par:IsA("SurfaceGui") or par:IsA("BillboardGui") then return true end
        if par == Workspace then break end
        par = par.Parent
    end
    return false
end

local function isProtected(p)
    if not p then return false end
    if isNameProtected(p) then return true end
    if p:IsA("BasePart") then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root and p.Position.Y < root.Position.Y - 3 then return true end
        local s = p.Size
        if s.X > 100 or s.Z > 100 then return true end
    end
    return false
end

-- ⚡ Cache ghost check
local _ghostCache = setmetatable({}, {__mode = "k"})
local function isSafeToGhost(p)
    if not p or not p:IsA("BasePart") then return false end
    local c = _ghostCache[p]
    if c ~= nil then return c end
    local r = true
    if isUIInstance(p) or isBlacklisted(p) or isProtected(p) or isPartOfAnyCharacter(p) then
        r = false
    elseif p.Material == Enum.Material.Neon or p.Material == Enum.Material.Glass
       or p.Material == Enum.Material.ForceField or p.Material == Enum.Material.Foil then
        r = false
    elseif p.Transparency >= 0.95 then
        r = false
    else
        local s = p.Size
        if s.X < 1 and s.Y < 1 and s.Z < 1 then r = false
        elseif s.Y < 0.1 and (s.X > 10 or s.Z > 10) then r = false
        else
            local kids = p:GetChildren()
            for i = 1, #kids do
                local d = kids[i]
                local dc = d.ClassName
                if dc == "SurfaceGui" or dc == "BillboardGui" or dc == "ParticleEmitter"
                   or dc == "Beam" or dc == "Trail" or dc == "PointLight"
                   or dc == "SpotLight" or dc == "SurfaceLight" then
                    r = false; break
                end
            end
            if r and p:IsA("Part") then
                if p.Shape == Enum.PartType.Ball or p.Shape == Enum.PartType.Cylinder then r = false end
            end
        end
    end
    _ghostCache[p] = r
    return r
end
spawn(function() while task.wait(5) do _ghostCache = setmetatable({}, {__mode = "k"}) end end)

-- =====================================================
-- STATE
-- =====================================================
local state = {
    ghostMap=false, ghostLevel=0.3,
    playerBlack=false, npcBlack=false,
    lighting=false, effects=false, hideFar=false,
    lowQuality=false, atmosphere=false, physics=false,
    skybox=false, terrain=false, killLights=false,
    killFire=false, debrisClean=false, soundKill=false,
    killAllSound=false, killAllBeam=false,
    blockSpawn=false, stopAnims=false, killDecor2=false,
    aggressiveGC=false, instantGC=false,
    forceMinGraphics=false, forceShadow=false,
    purgeEffectsOnly=false, purgeParticleModels=false,
    killInvisible=false, killTiny=false, forcePlastic=false,
    killDecalTexture=false, stopAllAnim=false, sleepHumanoids=false,
    anchorFar=false, cameraOptimize=false, purgeLighting=false,
    throttleRender=false, memoryPurge=false, turboFix=false,
    autoClean=false, cullDist=80, fpsTarget=60,
}

local saved = {
    parts={}, lighting={}, atmo={}, physics={}, sky={},
    lights={}, fires={}, sounds={}, allSounds={},
    allBeams={}, materials={}, connections={},
    playerColors={}, npcColors={},
    ghostParts={}, plasticParts={}, decalParts={}, anchoredFar={},
    camSaved={},
}

local turboLoading, allLoading = false, false
local applying = false

-- FPS counter
local fpsFrames, fpsStart, fpsLast, fpsFallback = 0, os.clock(), 0, 0
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    if now - fpsLast < 0.001 then return end
    fpsLast = now
    fpsFrames = fpsFrames + 1
    if now - fpsStart >= 1 then
        fpsFallback = math.floor(fpsFrames / (now - fpsStart) + 0.5)
        fpsFrames, fpsStart = 0, now
    end
end)

local function getFPS()
    local ok, v = pcall(function() return Stats.RenderFPS:GetValue() end)
    if ok and type(v) == "number" and v > 0 and v < 1000 then return math.floor(v + 0.5) end
    return fpsFallback
end

local function getPing()
    local ok, p = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    if ok and type(p) == "number" then return math.floor(p) end
    return 0
end

local function getOrigin()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        return char.HumanoidRootPart.Position, char
    end
    return nil, nil
end

local function isFireColor(c)
    if not c then return false end
    local r, g, b = c.R, c.G, c.B
    return (r > 0.55 and g < 0.6 and b < 0.4) or (r > 0.7 and g > 0.25 and g < 0.85 and b < 0.35)
end

local function isFireTexture(t)
    if not t then return false end
    t = t:lower()
    return t:find("fire") or t:find("flame") or t:find("ember") or t:find("spark") or t:find("burn")
end

-- =====================================================
-- QUICK MODULES (không cần GetDescendants)
-- =====================================================
local function toggleLighting(on)
    if on then
        saved.lighting = {GS = Lighting.GlobalShadows, B = Lighting.Brightness, OA = Lighting.OutdoorAmbient}
        Lighting.GlobalShadows = false; Lighting.Brightness = 1
        Lighting.OutdoorAmbient = Color3.fromRGB(80,80,80)
    elseif saved.lighting.GS ~= nil then
        Lighting.GlobalShadows = saved.lighting.GS
        Lighting.Brightness = saved.lighting.B
        Lighting.OutdoorAmbient = saved.lighting.OA
    end
end

local function togglePurgeLighting(on)
    if on then
        for _, v in ipairs(Lighting:GetChildren()) do
            pcall(function()
                if v:IsA("SunRaysEffect") or v:IsA("BloomEffect")
                   or v:IsA("DepthOfFieldEffect") or v:IsA("BlurEffect") then
                    v.Enabled = false
                end
            end)
        end
        Lighting.GlobalShadows = false
    end
end

local function toggleLowQuality(on)
    local ok, cur = pcall(function() return settings().Rendering.QualityLevel end)
    if on then
        saved.quality = ok and cur or Enum.QualityLevel.Automatic
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level03 end)
    else
        pcall(function() settings().Rendering.QualityLevel = saved.quality or Enum.QualityLevel.Automatic end)
    end
end

local function toggleThrottleRender(on)
    if on then pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level03 end) end
end

local function toggleCameraOptimize(on)
    if on then
        saved.camSaved.FOV = Cam.FieldOfView
        pcall(function() Cam.FieldOfView = 70 end)
        for _, v in ipairs(Cam:GetChildren()) do
            pcall(function()
                if v:IsA("PostEffect") then
                    table.insert(saved.camSaved, {obj=v, e=v.Enabled}); v.Enabled = false
                end
            end)
        end
    else
        pcall(function() Cam.FieldOfView = saved.camSaved.FOV or 70 end)
        for _, s in ipairs(saved.camSaved) do
            pcall(function() if s.obj and s.obj.Parent then s.obj.Enabled = s.e end end)
        end
        saved.camSaved = {}
    end
end

local function toggleAtmosphere(on)
    if on then
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Atmosphere") or v:IsA("Clouds") then
                pcall(function() table.insert(saved.atmo, {obj=v}); v.Parent = nil end)
            end
        end
    else
        for _, a in ipairs(saved.atmo) do
            pcall(function() if a.obj then a.obj.Parent = Lighting end end)
        end
        saved.atmo = {}
    end
end

local function toggleSkybox(on)
    if on then
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Sky") then table.insert(saved.sky, {obj=v}); v.Parent = nil end
        end
    else
        for _, s in ipairs(saved.sky) do
            pcall(function() if s.obj then s.obj.Parent = Lighting end end)
        end
        saved.sky = {}
    end
end

local function toggleTerrain(on)
    local t = Workspace:FindFirstChildOfClass("Terrain"); if not t then return end
    pcall(function()
        if on then t.Decoration = false; t.WaterWaveSize = 0; t.WaterWaveSpeed = 0
        else t.Decoration = true; t.WaterWaveSize = 0.15; t.WaterWaveSpeed = 10 end
    end)
end
local toggleKillDecor2 = toggleTerrain

local function toggleKillAllSound(on)
    if on then pcall(function() SoundSvc.AmbientReverb = Enum.ReverbType.NoReverb end) end
end

local function toggleDebrisClean(on)
    if on then
        if saved.connections.debris then saved.connections.debris:Disconnect() end
        saved.connections.debris = Workspace.DescendantAdded:Connect(function(v)
            pcall(function()
                local c = v.ClassName
                if c == "Explosion" then v:Destroy()
                elseif c == "Fire" then v.Enabled = false; v.Size = 0
                elseif c == "Smoke" then v.Enabled = false
                elseif c == "ParticleEmitter" or c == "Trail" or c == "Beam" then v.Enabled = false
                end
            end)
        end)
    else
        if saved.connections.debris then saved.connections.debris:Disconnect(); saved.connections.debris = nil end
    end
end

local function toggleBlockSpawn(on)
    if on then
        if saved.connections.block then saved.connections.block:Disconnect() end
        saved.connections.block = Workspace.DescendantAdded:Connect(function(v)
            pcall(function()
                local c = v.ClassName
                if c == "Explosion" then v:Destroy()
                elseif c == "Sound" then v.Volume = 0
                elseif c == "PointLight" or c == "SpotLight" or c == "SurfaceLight" then v.Enabled = false
                elseif c == "ParticleEmitter" or c == "Trail" or c == "Beam" or c == "Fire" or c == "Smoke" or c == "Sparkles" then v.Enabled = false
                end
            end)
        end)
    else
        if saved.connections.block then saved.connections.block:Disconnect(); saved.connections.block = nil end
    end
end

local function toggleInstantGC(on)
    if on then
        if saved.connections.instantGC then saved.connections.instantGC:Disconnect() end
        saved.connections.instantGC = RunService.Heartbeat:Connect(function()
            pcall(function() collectgarbage("collect") end)
        end)
    else
        if saved.connections.instantGC then saved.connections.instantGC:Disconnect(); saved.connections.instantGC = nil end
    end
end

local function toggleMemoryPurge(on)
    if on then
        pcall(function() collectgarbage("setpause", 100) end)
        pcall(function() collectgarbage("setstepmul", 200) end)
        if saved.connections.memPurge then saved.connections.memPurge:Disconnect() end
        saved.connections.memPurge = task.spawn(function()
            while state.memoryPurge do
                pcall(function() collectgarbage("collect") end)
                task.wait(1)
            end
        end)
    end
end

local function toggleAggressiveGC(on)
    if on then
        if saved.connections.gc then saved.connections.gc:Disconnect() end
        saved.connections.gc = task.spawn(function()
            while state.aggressiveGC do
                pcall(function() collectgarbage("collect") end)
                task.wait(0.5)
            end
        end)
    end
end

local function toggleForceMinGraphics(on)
    if on then
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level03 end)
    else
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
    end
end

-- =====================================================
-- ⚡⚡⚡ MASTER SINGLE-PASS APPLIER (SIÊU NHANH)
-- =====================================================
-- Nhận 1 table cfg với các flag, chạy 1 pass DUY NHẤT
-- Cực nhanh vì chỉ GetDescendants 1 lần
-- =====================================================
local function masterApply(cfg, progressLabel)
    if applying then return end
    applying = true

    spawn(function()
        local all = Workspace:GetDescendants()
        local total = #all
        local char = LocalPlayer.Character
        local origin = char and char:FindFirstChild("HumanoidRootPart")
        local originPos = origin and origin.Position
        local cullD = state.cullDist
        local ghostLv = state.ghostLevel

        -- Refresh char cache trước khi loop
        refreshCharCache()

        -- Accumulator
        local nGhost, nPlastic, nDecal, nFar, nShadow = 0, 0, 0, 0, 0

        -- ═══ LOOP CHÍNH — 1 PASS ═══
        for i = 1, total do
            local v = all[i]
            pcall(function()
                local cls = v.ClassName
                local isChar = false
                local isProt = false
                local isUI = false

                -- BASE PART
                if cls == "Part" or cls == "MeshPart" or cls == "UnionOperation"
                   or cls == "WedgePart" or cls == "TrussPart" or cls == "CornerWedgePart"
                   or cls == "NegateOperation" or cls == "IntersectOperation" then

                    isChar = isPartOfAnyCharacter(v)
                    isProt = isProtected(v)
                    isUI = isUIInstance(v)

                    -- ═══ BLACK MODE (xử lý TRƯỚC khi skip) ═══
                    if cfg.black and not isUI then
                        if isChar then
                            -- Character của player khác?
                            local parentModel = v:FindFirstAncestorOfClass("Model")
                            if parentModel and parentModel ~= char then
                                if not Players:GetPlayerFromCharacter(parentModel)
                                   or cfg.npcBlackOnly == nil then
                                    -- NPC hoặc player other
                                    if v.Material ~= Enum.Material.Neon and v.Material ~= Enum.Material.Glass
                                       and v.Transparency <= 0.5 then
                                        if not v:GetAttribute("BlackOrig") then
                                            v:SetAttribute("BlackOrig", v.Color)
                                            table.insert(saved.playerColors, {obj=v, c=v.Color, m=v.Material, t=v.Transparency})
                                        end
                                        v.Color = Color3.fromRGB(0,0,0)
                                        v.Material = Enum.Material.SmoothPlastic
                                        v.Transparency = 0
                                        v.Reflectance = 0
                                        v.CastShadow = false
                                    end
                                end
                            end
                        end
                    end

                    if not isChar and not isProt and not isUI then
                        -- ═══ KILL INVISIBLE ═══
                        if cfg.killInvisible and v.Transparency >= 0.95 then
                            v:Destroy()
                            return
                        end

                        -- ═══ KILL TINY ═══
                        if cfg.killTiny then
                            local s = v.Size
                            if s.X < 0.5 and s.Y < 0.5 and s.Z < 0.5 then
                                v:Destroy()
                                return
                            end
                        end

                        -- ═══ FORCE PLASTIC ═══
                        if cfg.forcePlastic then
                            local m = v.Material
                            if m ~= Enum.Material.Plastic and m ~= Enum.Material.SmoothPlastic
                               and m ~= Enum.Material.Neon and m ~= Enum.Material.ForceField then
                                table.insert(saved.plasticParts, {obj=v, m=m})
                                v.Material = Enum.Material.Plastic
                                nPlastic = nPlastic + 1
                            end
                        end

                        -- ═══ GHOST ═══
                        if cfg.ghost and isSafeToGhost(v) then
                            if not v:GetAttribute("GhostOrig") then
                                v:SetAttribute("GhostOrig", v.Transparency)
                                table.insert(saved.ghostParts, {obj=v, t=v.Transparency})
                            end
                            v.Transparency = math.max(v.Transparency, ghostLv)
                            nGhost = nGhost + 1
                        end

                        -- ═══ HIDE FAR ═══
                        if cfg.hideFar and originPos then
                            if (v.Position - originPos).Magnitude > cullD and v.Transparency < 0.95 then
                                table.insert(saved.parts, {obj=v, trans=v.Transparency})
                                v.Transparency = 1
                                nFar = nFar + 1
                            end
                        end

                        -- ═══ PHYSICS ═══
                        if cfg.physics and originPos then
                            if (v.Position - originPos).Magnitude > cullD then
                                table.insert(saved.parts, {obj=v, canTouch=v.CanTouch, canQuery=v.CanQuery, noPhysics=true})
                                v.CanTouch = false; v.CanQuery = false
                            end
                        end

                        -- ═══ ANCHOR FAR ═══
                        if cfg.anchorFar and originPos then
                            if not v.Anchored and (v.Position - originPos).Magnitude > cullD then
                                table.insert(saved.anchoredFar, {obj=v})
                                v.Anchored = true
                            end
                        end
                    end

                    -- ═══ FORCE SHADOW (mọi part trừ UI) ═══
                    if cfg.forceShadow and v.CastShadow and not isUI then
                        table.insert(saved.materials, {obj=v, c=v.CastShadow})
                        v.CastShadow = false
                        nShadow = nShadow + 1
                    end
                end

                -- ═══ DECAL/TEXTURE ═══
                if cls == "Decal" or cls == "Texture" then
                    if cfg.killDecal then
                        if not isUIInstance(v) and not isPartOfAnyCharacter(v.Parent)
                           and not isBlacklisted(v.Parent) then
                            if not v:GetAttribute("DecalOrig") then
                                v:SetAttribute("DecalOrig", v.Transparency)
                                table.insert(saved.decalParts, {obj=v, t=v.Transparency})
                            end
                            v.Transparency = 1
                            nDecal = nDecal + 1
                        end
                    end
                end

                -- ═══ EFFECTS ═══
                if cfg.killEffects then
                    if cls == "ParticleEmitter" or cls == "Trail" or cls == "Beam"
                       or cls == "Fire" or cls == "Smoke" or cls == "Sparkles"
                       or cls == "Explosion" then
                        if not (char and v:IsDescendantOf(char)) and not isPartOfAnyCharacter(v) then
                            if cls == "Explosion" then v:Destroy()
                            else v.Enabled = false end
                        end
                    end
                end

                -- ═══ LIGHTS ═══
                if cfg.killLights then
                    if cls == "PointLight" or cls == "SpotLight" or cls == "SurfaceLight" then
                        table.insert(saved.lights, {obj=v, e=v.Enabled})
                        v.Enabled = false
                    end
                end

                -- ═══ SOUNDS ═══
                if cfg.killSounds then
                    if cls == "Sound" then
                        table.insert(saved.sounds, {obj=v, v=v.Volume})
                        v.Volume = 0
                    end
                end

                -- ═══ FIRE ═══
                if cfg.killFire then
                    if cls == "Fire" then
                        table.insert(saved.fires, {obj=v, k="Enabled", o=v.Enabled})
                        v.Enabled = false; v.Size = 0; v.Heat = 0
                    elseif cls == "Smoke" then
                        table.insert(saved.fires, {obj=v, k="Enabled", o=v.Enabled})
                        v.Enabled = false; v.Opacity = 0
                    end
                end
            end)

            -- Yield mỗi 2000 parts (NHANH GẤP 4X v4)
            if i % 2000 == 0 then
                if progressLabel and _G_statusBtn then
                    local pct = math.floor(i / total * 100)
                    pcall(function() _G_statusBtn.Text = string.format("%s %d%%", progressLabel, pct) end)
                end
                task.wait()
            end
        end

        applying = false
        print(string.format("⚡ MASTER APPLY: Ghost=%d, Plastic=%d, Decal=%d, Far=%d, Shadow=%d",
            nGhost, nPlastic, nDecal, nFar, nShadow))
    end)
end

-- =====================================================
-- Wrappers — gọi masterApply với 1 flag
-- =====================================================
local function mkFlagApplier(flagName, stateKey)
    return function(on)
        if on then
            masterApply({[flagName] = true})
        else
            -- Restore sẽ do fastOffAll đảm nhiệm
            if stateKey then state[stateKey] = false end
        end
    end
end

-- =====================================================
-- ⚡ FAST ALL-ON (1 pass duy nhất cho MỌI flag)
-- =====================================================
local function fastApplyAll()
    if allLoading then return end
    allLoading = true

    spawn(function()
        -- BƯỚC 1: Quick setup (không cần GetDescendants)
        local quickFns = {
            toggleLighting, togglePurgeLighting, toggleLowQuality,
            toggleThrottleRender, toggleCameraOptimize, toggleAtmosphere,
            toggleSkybox, toggleTerrain, toggleKillAllSound,
            toggleDebrisClean, toggleBlockSpawn, toggleInstantGC,
            toggleMemoryPurge, toggleAggressiveGC, toggleForceMinGraphics,
        }
        for i = 1, #quickFns do pcall(quickFns[i], true) end

        if _G_allBtn then
            pcall(function() _G_allBtn.Text = "🔥 BẬT TẤT CẢ... 20%" end)
        end
        task.wait()

        -- BƯỚC 2: 1 PASS duy nhất cho mọi thứ
        local all = Workspace:GetDescendants()
        local total = #all
        local char = LocalPlayer.Character
        local origin = char and char:FindFirstChild("HumanoidRootPart")
        local originPos = origin and origin.Position
        local cullD = state.cullDist
        local ghostLv = state.ghostLevel

        refreshCharCache()

        for i = 1, total do
            local v = all[i]
            pcall(function()
                local cls = v.ClassName
                local isChar = false
                local isProt = false
                local isUI = false

                if cls == "Part" or cls == "MeshPart" or cls == "UnionOperation"
                   or cls == "WedgePart" or cls == "TrussPart" or cls == "CornerWedgePart"
                   or cls == "NegateOperation" or cls == "IntersectOperation" then

                    isChar = isPartOfAnyCharacter(v)
                    isProt = isProtected(v)
                    isUI = isUIInstance(v)

                    -- BLACK (bao gồm NPC + player other)
                    if not isUI then
                        local parentModel = v:FindFirstAncestorOfClass("Model")
                        local p2 = parentModel and Players:GetPlayerFromCharacter(parentModel)
                        if isChar and parentModel and parentModel ~= char and (not p2 or p2 ~= LocalPlayer) then
                            if v.Material ~= Enum.Material.Neon and v.Material ~= Enum.Material.Glass
                               and v.Transparency <= 0.5 then
                                if not v:GetAttribute("BlackOrig") then
                                    v:SetAttribute("BlackOrig", v.Color)
                                    table.insert(saved.playerColors, {obj=v, c=v.Color, m=v.Material, t=v.Transparency})
                                end
                                v.Color = Color3.fromRGB(0,0,0)
                                v.Material = Enum.Material.SmoothPlastic
                                v.Transparency = 0
                                v.Reflectance = 0
                                v.CastShadow = false
                            end
                        end
                    end

                    if not isChar and not isProt and not isUI then
                        -- Kill invisible
                        if v.Transparency >= 0.95 then v:Destroy(); return end
                        -- Kill tiny
                        local s = v.Size
                        if s.X < 0.5 and s.Y < 0.5 and s.Z < 0.5 then v:Destroy(); return end
                        -- Force plastic
                        local m = v.Material
                        if m ~= Enum.Material.Plastic and m ~= Enum.Material.SmoothPlastic
                           and m ~= Enum.Material.Neon and m ~= Enum.Material.ForceField then
                            table.insert(saved.plasticParts, {obj=v, m=m})
                            v.Material = Enum.Material.Plastic
                        end
                        -- Ghost
                        if isSafeToGhost(v) then
                            if not v:GetAttribute("GhostOrig") then
                                v:SetAttribute("GhostOrig", v.Transparency)
                                table.insert(saved.ghostParts, {obj=v, t=v.Transparency})
                            end
                            v.Transparency = math.max(v.Transparency, ghostLv)
                        end
                        -- Hide far + physics + anchor far
                        if originPos and (v.Position - originPos).Magnitude > cullD then
                            if v.Transparency < 0.95 then
                                table.insert(saved.parts, {obj=v, trans=v.Transparency})
                                v.Transparency = 1
                            end
                            if v.CanTouch then
                                table.insert(saved.parts, {obj=v, canTouch=true, noPhysics=true})
                                v.CanTouch = false; v.CanQuery = false
                            end
                            if not v.Anchored then
                                table.insert(saved.anchoredFar, {obj=v})
                                v.Anchored = true
                            end
                        end
                    end

                    -- Shadow
                    if v.CastShadow and not isUI then
                        table.insert(saved.materials, {obj=v, c=v.CastShadow})
                        v.CastShadow = false
                    end
                end

                if cls == "Decal" or cls == "Texture" then
                    if not isUIInstance(v) and not isPartOfAnyCharacter(v.Parent) and not isBlacklisted(v.Parent) then
                        if not v:GetAttribute("DecalOrig") then
                            v:SetAttribute("DecalOrig", v.Transparency)
                            table.insert(saved.decalParts, {obj=v, t=v.Transparency})
                        end
                        v.Transparency = 1
                    end
                end

                if cls == "ParticleEmitter" or cls == "Trail" or cls == "Beam"
                   or cls == "Fire" or cls == "Smoke" or cls == "Sparkles"
                   or cls == "Explosion" then
                    if not (char and v:IsDescendantOf(char)) and not isPartOfAnyCharacter(v) then
                        if cls == "Explosion" then v:Destroy() else v.Enabled = false end
                    end
                end

                if cls == "PointLight" or cls == "SpotLight" or cls == "SurfaceLight" then
                    table.insert(saved.lights, {obj=v, e=v.Enabled})
                    v.Enabled = false
                end

                if cls == "Sound" then
                    table.insert(saved.sounds, {obj=v, v=v.Volume})
                    v.Volume = 0
                end
            end)

            if i % 2000 == 0 then
                if _G_allBtn then
                    local pct = 20 + math.floor(i / total * 80)
                    pcall(function() _G_allBtn.Text = string.format("🔥 BẬT TẤT CẢ... %d%%", pct) end)
                end
                task.wait()
            end
        end

        -- DONE
        state.ghostMap = true; state.playerBlack = true; state.npcBlack = true
        state.autoClean = true; state.turboFix = true
        allLoading = false

        if _G_allBtn then
            pcall(function()
                _G_allBtn.Text = "🔥 BẬT TẤT CẢ (100%)"
                _G_allBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
            end)
        end
    end)
end

-- ═══ FAST OFF ═══
local function fastOffAll()
    if allLoading or turboLoading then return end
    allLoading = true
    spawn(function()
        state.autoClean = false; state.ghostMap = false
        state.playerBlack = false; state.npcBlack = false; state.turboFix = false

        local restores = {
            {"ghostParts", function(d) if d.obj then d.obj.Transparency = d.t end end},
            {"plasticParts", function(d) if d.obj then d.obj.Material = d.m end end},
            {"decalParts", function(d) if d.obj then d.obj.Transparency = d.t end end},
            {"materials", function(d) if d.obj and d.c then d.obj.CastShadow = d.c end end},
            {"parts", function(d) 
                if d.obj then
                    if d.trans then d.obj.Transparency = d.trans end
                    if d.canTouch then d.obj.CanTouch = true; d.obj.CanQuery = true end
                end
            end},
            {"anchoredFar", function(d) if d.obj then d.obj.Anchored = false end end},
        }

        for _, entry in ipairs(restores) do
            local list = saved[entry[1]]
            for i = 1, #list do
                local d = list[i]
                pcall(function() if d.obj and d.obj.Parent then entry[2](d) end end)
            end
            saved[entry[1]] = {}
        end

        pcall(function() restoreChar(saved.playerColors); saved.playerColors = {} end)
        pcall(function() restoreChar(saved.npcColors); saved.npcColors = {} end)

        for _, key in ipairs({"debris","block","instantGC","memPurge","gc"}) do
            if saved.connections[key] then
                pcall(function() saved.connections[key]:Disconnect() end)
                saved.connections[key] = nil
            end
        end

        pcall(toggleLighting, false)
        pcall(toggleCameraOptimize, false)
        pcall(toggleAtmosphere, false)
        pcall(toggleSkybox, false)
        pcall(toggleTerrain, false)
        pcall(toggleLowQuality, false)
        pcall(toggleForceMinGraphics, false)

        forceEnableCoreGui()
        allLoading = false; turboLoading = false

        if _G_allBtn then
            pcall(function()
                _G_allBtn.Text = "🔥 BẬT TẤT CẢ\n(NHANH 5X)"
                _G_allBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
            end)
        end
        if _G_turboBtn then
            pcall(function()
                _G_turboBtn.Text = "🔥🔥🔥 TURBO LAG FIX"
                _G_turboBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 0)
            end)
        end
    end)
end

-- =====================================================
-- BLACK MODE HELPERS (dùng cho nút riêng)
-- =====================================================
local function makeBlack(char, saveList)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart") then
                if v.Material == Enum.Material.Neon or v.Material == Enum.Material.Glass then return end
                if v.Transparency > 0.5 then return end
                if not v:GetAttribute("BlackOrig") then
                    v:SetAttribute("BlackOrig", v.Color)
                    table.insert(saveList, {obj=v, c=v.Color, m=v.Material, t=v.Transparency})
                end
                v.Color = Color3.fromRGB(0,0,0)
                v.Material = Enum.Material.SmoothPlastic
                v.Transparency = 0
                v.Reflectance = 0
                v.CastShadow = false
            end
            if v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 end
            if v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") then
                table.insert(saveList, {obj=v, p=v.Parent}); v.Parent = nil
            end
            if v:IsA("Accessory") or v:IsA("Hat") then
                table.insert(saveList, {obj=v, p=v.Parent}); v.Parent = nil
            end
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
               or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                v.Enabled = false
            end
            if v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
                v.Enabled = false
            end
        end)
    end
end

local function restoreChar(saveList)
    for _, d in ipairs(saveList) do
        pcall(function()
            if d.obj and d.obj.Parent then
                if d.c then d.obj.Color = d.c end
                if d.m then d.obj.Material = d.m end
                if d.t then d.obj.Transparency = d.t end
                if d.p then d.obj.Parent = d.p end
            end
        end)
    end
end

local function togglePlayerBlack(on)
    if on then
        spawn(function()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    makeBlack(plr.Character, saved.playerColors)
                end
            end
        end)
    else
        restoreChar(saved.playerColors); saved.playerColors = {}
    end
end

local function toggleNpcBlack(on)
    if on then
        spawn(function()
            local all = Workspace:GetDescendants()
            for i = 1, #all do
                local v = all[i]
                if v:IsA("Humanoid") then
                    pcall(function()
                        local model = v.Parent
                        if model and model ~= LocalPlayer.Character then
                            local isPlayer = Players:GetPlayerFromCharacter(model)
                            if not isPlayer then makeBlack(model, saved.npcColors) end
                        end
                    end)
                end
                if i % 1000 == 0 then task.wait() end
            end
        end)
    else
        restoreChar(saved.npcColors); saved.npcColors = {}
    end
end

spawn(function()
    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function(char)
            task.wait(1)
            if state.playerBlack then makeBlack(char, saved.playerColors) end
        end)
    end)
end)

-- =====================================================
-- WRAPPERS CHO NÚT NHỎ (đều dùng masterApply)
-- =====================================================
local function wrapGhost(on)
    if on then masterApply({ghost = true}) else
        for _, d in ipairs(saved.ghostParts) do
            pcall(function() if d.obj and d.obj.Parent then d.obj.Transparency = d.t end end)
        end
        saved.ghostParts = {}
    end
end
local function wrapKillInvisible(on) if on then masterApply({killInvisible = true}) end end
local function wrapKillTiny(on) if on then masterApply({killTiny = true}) end end
local function wrapForcePlastic(on)
    if on then masterApply({forcePlastic = true}) else
        for _, p in ipairs(saved.plasticParts) do
            pcall(function() if p.obj and p.obj.Parent then p.obj.Material = p.m end end)
        end
        saved.plasticParts = {}
    end
end
local function wrapKillDecal(on)
    if on then masterApply({killDecal = true}) else
        for _, d in ipairs(saved.decalParts) do
            pcall(function() if d.obj and d.obj.Parent then d.obj.Transparency = d.t end end)
        end
        saved.decalParts = {}
    end
end
local function wrapForceShadow(on)
    if on then masterApply({forceShadow = true}) else
        for _, m in ipairs(saved.materials) do
            pcall(function() if m.obj and m.obj.Parent and m.c then m.obj.CastShadow = m.c end end)
        end
        saved.materials = {}
    end
end
local function wrapHideFar(on)
    if on then masterApply({hideFar = true}) else
        for _, p in ipairs(saved.parts) do
            pcall(function() if p.obj and p.obj.Parent and p.trans then p.obj.Transparency = p.trans end end)
        end
        saved.parts = {}
    end
end
local function wrapPhysics(on)
    if on then masterApply({physics = true}) else
        for _, p in ipairs(saved.parts) do
            pcall(function() if p.obj and p.obj.Parent and p.canTouch then p.obj.CanTouch = true; p.obj.CanQuery = true end end)
        end
    end
end
local function wrapAnchorFar(on)
    if on then masterApply({anchorFar = true}) else
        for _, a in ipairs(saved.anchoredFar) do
            pcall(function() if a.obj and a.obj.Parent then a.obj.Anchored = false end end)
        end
        saved.anchoredFar = {}
    end
end
local function wrapKillEffects(on)
    if on then masterApply({killEffects = true}) end
end
local function wrapKillLights(on)
    if on then masterApply({killLights = true}) else
        for _, l in ipairs(saved.lights) do
            pcall(function() if l.obj and l.obj.Parent then l.obj.Enabled = l.e end end)
        end
        saved.lights = {}
    end
end
local function wrapKillSounds(on)
    if on then masterApply({killSounds = true}) else
        for _, s in ipairs(saved.sounds) do
            pcall(function() if s.obj and s.obj.Parent then s.obj.Volume = s.v end end)
        end
        saved.sounds = {}
    end
end
local function wrapKillFire(on)
    if on then masterApply({killFire = true}) else
        for _, f in ipairs(saved.fires) do
            pcall(function() if f.obj and f.obj.Parent then f.obj[f.k] = f.o end end)
        end
        saved.fires = {}
    end
end

local function wrapStopAllAnim(on)
    if not on then return end
    local myChar = LocalPlayer.Character
    spawn(function()
        local all = Workspace:GetDescendants()
        for i = 1, #all do
            local v = all[i]
            if v:IsA("Animator") and not (myChar and v:IsDescendantOf(myChar)) then
                pcall(function()
                    for _, a in ipairs(v:GetPlayingAnimationTracks()) do a:Stop() end
                end)
            end
            if i % 1000 == 0 then task.wait() end
        end
    end)
end

local function wrapStopAnims(on)
    if on then
        spawn(function()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                    if hum then
                        local animator = hum:FindFirstChildOfClass("Animator")
                        if animator then
                            pcall(function()
                                for _, a in ipairs(animator:GetPlayingAnimationTracks()) do a:Stop() end
                            end)
                        end
                    end
                end
            end
        end)
    end
end

local function wrapSleepHumanoids(on)
    if not on then return end
    local origin, char = getOrigin(); if not origin then return end
    spawn(function()
        local all = Workspace:GetDescendants()
        for i = 1, #all do
            local v = all[i]
            if v:IsA("Humanoid") and v.Parent ~= char then
                pcall(function()
                    local hrp = v.Parent:FindFirstChild("HumanoidRootPart")
                    if hrp and (hrp.Position - origin).Magnitude > 80 then
                        v:SetStateEnabled(Enum.HumanoidStateType.Running, false)
                        v:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
                        v:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
                    end
                end)
            end
            if i % 1000 == 0 then task.wait() end
        end
    end)
end

-- =====================================================
-- GUI (GIỐNG v4)
-- =====================================================
local gui = Instance.new("ScreenGui")
gui.Name = "FIXLAG_VN"; gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true; gui.Parent = game.CoreGui

local fpsFrame = Instance.new("Frame")
fpsFrame.Size = UDim2.new(0, 220, 0, 70)
fpsFrame.Position = UDim2.new(0, 15, 0, 15)
fpsFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fpsFrame.BackgroundTransparency = 0.1
fpsFrame.BorderSizePixel = 0; fpsFrame.Active = true; fpsFrame.Draggable = true
fpsFrame.Parent = gui
Instance.new("UICorner", fpsFrame).CornerRadius = UDim.new(0, 10)
local fpsStroke = Instance.new("UIStroke", fpsFrame)
fpsStroke.Color = Color3.fromRGB(255, 100, 0); fpsStroke.Thickness = 2

local fpsText = Instance.new("TextLabel")
fpsText.Size = UDim2.new(1, -10, 1, -10); fpsText.Position = UDim2.new(0, 5, 0, 5)
fpsText.BackgroundTransparency = 1; fpsText.Font = Enum.Font.Code; fpsText.TextSize = 14
fpsText.TextColor3 = Color3.fromRGB(255, 200, 100)
fpsText.TextXAlignment = Enum.TextXAlignment.Left
fpsText.TextYAlignment = Enum.TextYAlignment.Top
fpsText.Text = "FPS: --\nPING: --\nDIST: 80"
fpsText.Parent = fpsFrame

spawn(function()
    while task.wait(0.25) do
        local f = getFPS()
        local c = Color3.fromRGB(0, 255, 100)
        if f < 60 then c = Color3.fromRGB(255, 210, 0) end
        if f < 30 then c = Color3.fromRGB(255, 60, 60) end
        fpsText.TextColor3 = c; fpsStroke.Color = c
        fpsText.Text = string.format("FPS: %d\nPING: %d\nDIST: %d", f, getPing(), state.cullDist)
    end
end)

local menu = Instance.new("Frame")
menu.Size = UDim2.new(0, 360, 0, 640)
menu.Position = UDim2.new(0, 15, 0, 95)
menu.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
menu.BorderSizePixel = 0; menu.Active = true; menu.Draggable = true; menu.Parent = gui
Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 14)
local mStroke = Instance.new("UIStroke", menu)
mStroke.Color = Color3.fromRGB(255, 100, 0); mStroke.Thickness = 2

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 34); title.Position = UDim2.new(0, 10, 0, 3)
title.BackgroundTransparency = 1; title.Text = "⚡ FIXLAG_VN v5 (FAST ENGINE)"
title.Font = Enum.Font.GothamBold; title.TextSize = 13
title.TextColor3 = Color3.fromRGB(255, 150, 50)
title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = menu

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 28, 0, 26); minBtn.Position = UDim2.new(1, -34, 0, 6)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80); minBtn.Text = "–"
minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 16
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255); minBtn.Parent = menu
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, -45); scroll.Position = UDim2.new(0, 0, 0, 45)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 150, 50)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollingDirection = Enum.ScrollingDirection.Y; scroll.Parent = menu

local collapsed = false
minBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed; scroll.Visible = not collapsed
    menu.Size = collapsed and UDim2.new(0, 360, 0, 40) or UDim2.new(0, 360, 0, 640)
    minBtn.Text = collapsed and "+" or "–"
end)

local buttons = {}
local function makeToggle(label, yPos, key, fn, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 30); btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = color or Color3.fromRGB(45, 45, 60)
    btn.Text = "○ " .. label; btn.Font = Enum.Font.GothamBold; btn.TextSize = 10
    btn.TextColor3 = Color3.fromRGB(200, 200, 200); btn.Parent = scroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function()
        state[key] = not state[key]; local on = state[key]
        btn.BackgroundColor3 = on and Color3.fromRGB(255, 100, 0) or (color or Color3.fromRGB(45, 45, 60))
        btn.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
        btn.Text = (on and "● " or "○ ") .. label
        pcall(fn, on)
    end)
    buttons[key] = {btn = btn, label = label, color = color}
end

local y = 5
local function add(label, key, fn, color)
    makeToggle(label, y, key, fn, color); y = y + 31
end
local function header(text, col)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 22); lbl.Position = UDim2.new(0, 10, 0, y)
    lbl.BackgroundTransparency = 1; lbl.Text = "━━ " .. text .. " ━━"
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
    lbl.TextColor3 = col or Color3.fromRGB(255, 180, 100)
    lbl.TextXAlignment = Enum.TextXAlignment.Center; lbl.Parent = scroll
    y = y + 26
end

-- BẬT TẤT CẢ
local allBtn = Instance.new("TextButton")
allBtn.Size = UDim2.new(1, -20, 0, 70); allBtn.Position = UDim2.new(0, 10, 0, y)
allBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
allBtn.Text = "🔥 BẬT TẤT CẢ (FAST ENGINE 5X)"
allBtn.Font = Enum.Font.GothamBold; allBtn.TextSize = 13
allBtn.TextColor3 = Color3.fromRGB(255, 255, 255); allBtn.Parent = scroll
Instance.new("UICorner", allBtn).CornerRadius = UDim.new(0, 10)
local allStroke = Instance.new("UIStroke", allBtn)
allStroke.Color = Color3.fromRGB(255, 50, 50); allStroke.Thickness = 4
_G_allBtn = allBtn

allBtn.MouseButton1Click:Connect(function()
    if allLoading then return end
    local newState = not (state.turboFix and state.ghostMap)
    if newState then
        fastApplyAll()
        for k, data in pairs(buttons) do
            state[k] = true
            data.btn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
            data.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            data.btn.Text = "● " .. data.label
        end
    else
        fastOffAll()
        for k, data in pairs(buttons) do
            state[k] = false
            data.btn.BackgroundColor3 = data.color or Color3.fromRGB(45, 45, 60)
            data.btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            data.btn.Text = "○ " .. data.label
        end
    end
end)

y = y + 76

-- TURBO (1 pass, không black)
local turboBtn = Instance.new("TextButton")
turboBtn.Size = UDim2.new(1, -20, 0, 60); turboBtn.Position = UDim2.new(0, 10, 0, y)
turboBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 0)
turboBtn.Text = "🔥🔥🔥 TURBO LAG FIX (FAST)"
turboBtn.Font = Enum.Font.GothamBold; turboBtn.TextSize = 12
turboBtn.TextColor3 = Color3.fromRGB(255, 255, 255); turboBtn.Parent = scroll
Instance.new("UICorner", turboBtn).CornerRadius = UDim.new(0, 10)
local turboStroke = Instance.new("UIStroke", turboBtn)
turboStroke.Color = Color3.fromRGB(255, 255, 0); turboStroke.Thickness = 3
_G_turboBtn = turboBtn

turboBtn.MouseButton1Click:Connect(function()
    if turboLoading then return end
    if not state.turboFix then
        turboLoading = true
        -- Quick
        pcall(toggleLighting, true); pcall(togglePurgeLighting, true)
        pcall(toggleLowQuality, true); pcall(toggleCameraOptimize, true)
        pcall(toggleAtmosphere, true); pcall(toggleSkybox, true)
        pcall(toggleTerrain, true); pcall(toggleKillAllSound, true)
        pcall(toggleDebrisClean, true); pcall(toggleBlockSpawn, true)
        pcall(toggleInstantGC, true); pcall(toggleMemoryPurge, true)
        -- Master 1 pass
        masterApply({
            killInvisible=true, killTiny=true, forcePlastic=true,
            killDecal=true, killEffects=true, killLights=true,
            killSounds=true, killFire=true, ghost=true,
            hideFar=true, physics=true, anchorFar=true, forceShadow=true,
        }, "🔥 TURBO")
        state.turboFix = true
        state.autoClean = true
        turboLoading = false
    else
        fastOffAll()
        state.autoClean = false
        state.turboFix = false
    end
end)

y = y + 66

header("👻 GHOST MAP", Color3.fromRGB(200, 200, 255))
add("👻 GHOST MAP", "ghostMap", wrapGhost, Color3.fromRGB(40, 40, 60))

local gLbl = Instance.new("TextLabel")
gLbl.Size = UDim2.new(1, -20, 0, 20); gLbl.Position = UDim2.new(0, 10, 0, y)
gLbl.BackgroundTransparency = 1; gLbl.Text = "Mức trong suốt: 30%"
gLbl.Font = Enum.Font.GothamBold; gLbl.TextSize = 11
gLbl.TextColor3 = Color3.fromRGB(200, 200, 255)
gLbl.TextXAlignment = Enum.TextXAlignment.Left; gLbl.Parent = scroll
y = y + 24

local gBg = Instance.new("Frame")
gBg.Size = UDim2.new(1, -20, 0, 8); gBg.Position = UDim2.new(0, 10, 0, y)
gBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60); gBg.BorderSizePixel = 0
gBg.Parent = scroll
Instance.new("UICorner", gBg).CornerRadius = UDim.new(0, 4)

local gFill = Instance.new("Frame")
gFill.Size = UDim2.new(0.3, 0, 1, 0)
gFill.BackgroundColor3 = Color3.fromRGB(200, 200, 255); gFill.BorderSizePixel = 0
gFill.Parent = gBg
Instance.new("UICorner", gFill).CornerRadius = UDim.new(0, 4)

local gBtn = Instance.new("TextButton")
gBtn.Size = UDim2.new(0, 16, 0, 16); gBtn.Position = UDim2.new(0.3, -8, 0, -4)
gBtn.BackgroundColor3 = Color3.fromRGB(230, 230, 255); gBtn.Text = ""
gBtn.Parent = gBg
Instance.new("UICorner", gBtn).CornerRadius = UDim.new(1, 0)

y = y + 20
local dragGhost = false
gBtn.MouseButton1Down:Connect(function() dragGhost = true end)
gBtn.MouseButton1Up:Connect(function() dragGhost = false end)

header("⚫ BLACK MODE", Color3.fromRGB(255, 50, 50))
add("⚫ PLAYER BLACK", "playerBlack", togglePlayerBlack, Color3.fromRGB(30, 0, 0))
add("⚫ NPC BLACK",    "npcBlack",    toggleNpcBlack,    Color3.fromRGB(30, 0, 0))

header("🔥 TURBO (AN TOÀN)", Color3.fromRGB(255, 100, 0))
add("💥 KILL INVISIBLE", "killInvisible", wrapKillInvisible, Color3.fromRGB(60, 20, 0))
add("💥 KILL TINY",      "killTiny",      wrapKillTiny,      Color3.fromRGB(60, 20, 0))
add("💥 FORCE PLASTIC",  "forcePlastic",  wrapForcePlastic,  Color3.fromRGB(60, 20, 0))
add("💥 KILL DECAL",     "killDecalTexture", wrapKillDecal, Color3.fromRGB(60, 20, 0))
add("💥 STOP ALL ANIM",  "stopAllAnim",   wrapStopAllAnim,   Color3.fromRGB(60, 20, 0))
add("💥 SLEEP HUMANOIDS","sleepHumanoids",wrapSleepHumanoids,Color3.fromRGB(60, 20, 0))
add("💥 ANCHOR XA",      "anchorFar",     wrapAnchorFar,     Color3.fromRGB(60, 20, 0))
add("💥 CAMERA OPT",     "cameraOptimize",toggleCameraOptimize,Color3.fromRGB(60, 20, 0))
add("💥 PURGE LIGHTING", "purgeLighting", togglePurgeLighting, Color3.fromRGB(60, 20, 0))
add("💥 THROTTLE",       "throttleRender",toggleThrottleRender,Color3.fromRGB(60, 20, 0))
add("💥 MEMORY PURGE",   "memoryPurge",   toggleMemoryPurge,   Color3.fromRGB(60, 20, 0))

header("⚙️ FIX LAG CƠ BẢN", Color3.fromRGB(100, 200, 255))
add("Tắt đèn & hậu kỳ",  "lighting",     toggleLighting)
add("Tắt hạt & effects",  "effects",      wrapKillEffects)
add("🔥 DIỆT LỬA",       "killFire",     wrapKillFire)
add("🧹 DỌN RÁC",        "debrisClean",  toggleDebrisClean)
add("☢️ KILL ALL BEAM",  "killAllBeam",  wrapKillEffects)
add("☢️ KILL ALL SOUND", "killAllSound", toggleKillAllSound)
add("🔇 Sound Killer",   "soundKill",    wrapKillSounds)
add("☢️ BLOCK SPAWN",    "blockSpawn",   toggleBlockSpawn)
add("☢️ STOP ANIM",      "stopAnims",    wrapStopAnims)
add("Ẩn vật thể xa",     "hideFar",      wrapHideFar)
add("Chất lượng thấp",   "lowQuality",   toggleLowQuality)
add("Tắt Atmosphere",    "atmosphere",   toggleAtmosphere)
add("Giảm Physics",      "physics",      wrapPhysics)
add("⚫ Xóa Skybox",     "skybox",       toggleSkybox)
add("⚫ Xóa Terrain",    "terrain",      toggleTerrain)
add("⚫ Kill Light",     "killLights",   wrapKillLights)
add("✦ Tắt Shadow",      "forceShadow",  wrapForceShadow)
add("💀 MIN GRAPHICS",   "forceMinGraphics", toggleForceMinGraphics)
add("💀 INSTANT GC",     "instantGC",    toggleInstantGC)
add("💀 AGGRESSIVE GC",  "aggressiveGC", toggleAggressiveGC)

y = y + 10

local offAllBtn = Instance.new("TextButton")
offAllBtn.Size = UDim2.new(1, -20, 0, 36); offAllBtn.Position = UDim2.new(0, 10, 0, y)
offAllBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 20)
offAllBtn.Text = "⏹ TẮT TẤT CẢ"
offAllBtn.Font = Enum.Font.GothamBold; offAllBtn.TextSize = 12
offAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255); offAllBtn.Parent = scroll
Instance.new("UICorner", offAllBtn).CornerRadius = UDim.new(0, 10)
offAllBtn.MouseButton1Click:Connect(function()
    fastOffAll()
    for _, data in pairs(buttons) do
        state[data.key or ""] = false
        data.btn.BackgroundColor3 = data.color or Color3.fromRGB(45, 45, 60)
        data.btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        data.btn.Text = "○ " .. data.label
    end
end)

y = y + 42
scroll.CanvasSize = UDim2.new(0, 0, 0, y + 15)

-- Slider
RunService.RenderStepped:Connect(function()
    local mouse = LocalPlayer:GetMouse()
    if dragGhost then
        local relX = math.clamp((mouse.X - gBg.AbsolutePosition.X) / gBg.AbsoluteSize.X, 0.05, 0.95)
        gFill.Size = UDim2.new(relX, 0, 1, 0)
        gBtn.Position = UDim2.new(relX, -8, 0, -4)
        local level = math.floor(relX * 100) / 100
        state.ghostLevel = level
        gLbl.Text = "Mức trong suốt: " .. math.floor(level * 100) .. "%"
    end
end)

gui.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragGhost = false
    end
end)

-- LOOPS
spawn(function()
    while task.wait(0.3) do
        if state.autoClean then
            local all = Workspace:GetDescendants()
            for i = 1, #all do
                local v = all[i]
                local c = v.ClassName
                if c == "Explosion" then v:Destroy()
                elseif c == "ParticleEmitter" or c == "Trail" or c == "Beam"
                   or c == "Fire" or c == "Smoke" or c == "Sparkles" then
                    v.Enabled = false
                end
                if i % 2000 == 0 then task.wait() end
            end
            collectgarbage("collect")
        end
    end
end)

spawn(function()
    while task.wait(2) do
        pcall(function() collectgarbage("collect") end)
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(2)
    forceEnableCoreGui()
end)

print("⚡ FIXLAG_VN TURBO v5 loaded! FAST ENGINE — Master single-pass, 5-10x nhanh hơn.")
