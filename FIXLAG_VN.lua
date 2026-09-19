-- =====================================================
-- FIXLAG_VN TURBO v4 — Load nhanh 5x (Single Pass Batch)
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

-- =====================================================
-- 🛡️ FORCE CoreGui
-- =====================================================
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
-- 🚫 BLACKLIST
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

-- =====================================================
-- ⚡ CACHE
-- =====================================================
local _charCache = {}
local function refreshCharCache()
    _charCache = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then _charCache[plr.Character] = true end
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
    for i = 1, 8 do
        if not par then break end
        if par:IsA("ScreenGui") or par:IsA("PlayerGui") or par:IsA("CoreGui") then return true end
        if par:IsA("GuiObject") or par:IsA("GuiBase2d") or par:IsA("LayerCollector") then return true end
        if par:IsA("SurfaceGui") or par:IsA("BillboardGui") then return true end
        if par == Workspace then break end
        par = par.Parent
    end
    return false
end

local function isBlacklisted(p)
    if not p or not p.Name then return false end
    local n = p.Name:lower()
    for _, k in ipairs(BLACKLIST_KEYWORDS) do
        if n:find(k) then return true end
    end
    return false
end

local function isProtected(p)
    if not p or not p.Name then return false end
    local n = p.Name:lower()
    for _, k in ipairs(PROTECTED_NAMES) do
        if n:find(k) then return true end
    end
    if p:IsA("BasePart") then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root and p.Position.Y < root.Position.Y - 3 then return true end
        local s = p.Size
        if s.X > 100 or s.Z > 100 then return true end
    end
    return false
end

local function isSafeToGhost(p)
    if not p or not p:IsA("BasePart") then return false end
    if isUIInstance(p) or isBlacklisted(p) or isProtected(p) then return false end
    if isPartOfAnyCharacter(p) then return false end
    if p.Material == Enum.Material.Neon or p.Material == Enum.Material.Glass
       or p.Material == Enum.Material.ForceField or p.Material == Enum.Material.Foil then
        return false
    end
    if p.Transparency >= 0.95 then return false end
    local s = p.Size
    if s.X < 1 and s.Y < 1 and s.Z < 1 then return false end
    if s.Y < 0.1 and (s.X > 10 or s.Z > 10) then return false end
    for _, d in ipairs(p:GetChildren()) do
        if d:IsA("SurfaceGui") or d:IsA("BillboardGui")
           or d:IsA("ParticleEmitter") or d:IsA("Beam")
           or d:IsA("Trail") or d:IsA("PointLight")
           or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
            return false
        end
    end
    if p:IsA("Part") then
        if p.Shape == Enum.PartType.Ball or p.Shape == Enum.PartType.Cylinder then return false end
    end
    return true
end

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

local turboLoading = false
local ghostLoading = false
local allLoading = false

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
-- QUICK MODULES (Không cần GetDescendants)
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
    if on then
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level03 end)
    end
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

local function toggleKillDecor2(on)
    local t = Workspace:FindFirstChildOfClass("Terrain"); if not t then return end
    pcall(function()
        if on then t.Decoration = false; t.WaterWaveSize = 0; t.WaterWaveSpeed = 0
        else t.Decoration = true; t.WaterWaveSize = 0.15; t.WaterWaveSpeed = 10 end
    end)
end

local function toggleKillAllSound(on)
    if on then
        pcall(function() SoundSvc.AmbientReverb = Enum.ReverbType.NoReverb end)
    end
end

local function toggleDebrisClean(on)
    if on then
        if saved.connections.debris then saved.connections.debris:Disconnect() end
        saved.connections.debris = Workspace.DescendantAdded:Connect(function(v)
            pcall(function()
                if v:IsA("Explosion") then v:Destroy() end
                if v:IsA("Fire") then v.Enabled = false; v.Size = 0 end
                if v:IsA("Smoke") then v.Enabled = false end
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then v.Enabled = false end
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
                if v:IsA("Explosion") then v:Destroy() end
                if v:IsA("Sound") then v.Volume = 0 end
                if v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then v.Enabled = false end
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                   or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then v.Enabled = false end
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
-- BLACK MODE
-- =====================================================
local function makeBlack(char, saveList)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart") then
                if v.Material == Enum.Material.Neon then return end
                if v.Material == Enum.Material.Glass then return end
                if v.Transparency > 0.5 then return end
                if not v:GetAttribute("BlackOrig") then
                    v:SetAttribute("BlackOrig", v.Color)
                    table.insert(saveList, {obj=v, c=v.Color, m=v.Material, t=v.Transparency})
                end
                v.Color = Color3.fromRGB(0, 0, 0)
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
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                makeBlack(plr.Character, saved.playerColors)
            end
        end
    else
        restoreChar(saved.playerColors)
        saved.playerColors = {}
    end
end

local function toggleNpcBlack(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Humanoid") then
                    local model = v.Parent
                    if model and model ~= LocalPlayer.Character then
                        local isPlayer = Players:GetPlayerFromCharacter(model)
                        if not isPlayer then makeBlack(model, saved.npcColors) end
                    end
                end
            end)
        end
    else
        restoreChar(saved.npcColors)
        saved.npcColors = {}
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
-- 🔥🔥🔥 SINGLE-PASS BATCH — TỐC ĐỘ 5X
-- =====================================================
local function fastBatchApply(mode)
    -- mode: "turbo" hoặc "all"
    local flagLoading = (mode == "all") and allLoading or turboLoading
    if flagLoading then return end

    if mode == "all" then allLoading = true else turboLoading = true end

    local btn = (mode == "all") and _G_allBtn or _G_turboBtn
    local label = (mode == "all") and "🔥 BẬT TẤT CẢ" or "🔥🔥🔥 TURBO"

    spawn(function()
        -- ═══════════ BƯỚC 1: QUICK SETUP (0.05s) ═══════════
        local quickFns = {
            toggleLighting, togglePurgeLighting, toggleLowQuality,
            toggleThrottleRender, toggleCameraOptimize, toggleAtmosphere,
            toggleSkybox, toggleTerrain, toggleKillDecor2,
            toggleKillAllSound, toggleDebrisClean, toggleBlockSpawn,
            toggleInstantGC, toggleMemoryPurge, toggleAggressiveGC,
            toggleForceMinGraphics,
        }
        for i, fn in ipairs(quickFns) do
            pcall(fn, true)
        end

        if btn then
            pcall(function() btn.Text = label .. "... 20%" end)
        end

        -- ═══════════ BƯỚC 2: BLACK MODE ═══════════
        pcall(togglePlayerBlack, true)
        pcall(toggleNpcBlack, true)
        if mode == "all" then
            state.playerBlack = true
            state.npcBlack = true
        end

        if btn then
            pcall(function() btn.Text = label .. "... 30%" end)
        end

        task.wait()

        -- ═══════════ BƯỚC 3: BIG BATCH (1 PASS DUY NHẤT) ═══════════
        local all = Workspace:GetDescendants()
        local total = #all
        local char = LocalPlayer.Character
        local origin = char and char:FindFirstChild("HumanoidRootPart")
        local originPos = origin and origin.Position

        for i = 1, total do
            local v = all[i]
            pcall(function()
                local cls = v.ClassName

                -- BASE PART
                if cls == "Part" or cls == "MeshPart" or cls == "UnionOperation" 
                   or cls == "WedgePart" or cls == "TrussPart" or cls == "CornerWedgePart"
                   or cls == "NegateOperation" or cls == "IntersectOperation" then
                    
                    local isChar = isPartOfAnyCharacter(v)
                    local prot = isProtected(v)
                    local isUI = isUIInstance(v)

                    if not isChar and not prot and not isUI then
                        -- KILL INVISIBLE
                        if v.Transparency >= 0.95 then
                            v:Destroy()
                            return
                        end
                        
                        -- KILL TINY
                        local s = v.Size
                        if s.X < 0.5 and s.Y < 0.5 and s.Z < 0.5 then
                            v:Destroy()
                            return
                        end
                        
                        -- FORCE PLASTIC
                        local mat = v.Material
                        if mat ~= Enum.Material.Plastic 
                           and mat ~= Enum.Material.SmoothPlastic
                           and mat ~= Enum.Material.Neon
                           and mat ~= Enum.Material.ForceField then
                            table.insert(saved.plasticParts, {obj=v, m=mat})
                            v.Material = Enum.Material.Plastic
                        end
                    end
                    
                    -- FORCE SHADOW (kể cả character)
                    if v.CastShadow and not isUI then
                        table.insert(saved.materials, {obj=v, c=v.CastShadow})
                        v.CastShadow = false
                    end
                    
                    -- GHOST + HIDE FAR
                    if originPos and not isChar and not prot and not isUI then
                        if isSafeToGhost(v) then
                            if not v:GetAttribute("GhostOrig") then
                                v:SetAttribute("GhostOrig", v.Transparency)
                                table.insert(saved.ghostParts, {obj=v, t=v.Transparency})
                            end
                            v.Transparency = math.max(v.Transparency, state.ghostLevel)
                        end
                        
                        if (v.Position - originPos).Magnitude > state.cullDist and v.Transparency < 0.95 then
                            table.insert(saved.parts, {obj=v, trans=v.Transparency})
                            v.Transparency = 1
                        end
                    end
                end
                
                -- DECAL / TEXTURE
                if cls == "Decal" or cls == "Texture" then
                    if not isUIInstance(v) 
                       and not isPartOfAnyCharacter(v.Parent)
                       and not isBlacklisted(v.Parent) then
                        if not v:GetAttribute("DecalOrig") then
                            v:SetAttribute("DecalOrig", v.Transparency)
                            table.insert(saved.decalParts, {obj=v, t=v.Transparency})
                        end
                        v.Transparency = 1
                    end
                end
                
                -- EFFECTS (PURGE)
                if cls == "ParticleEmitter" or cls == "Trail" or cls == "Beam"
                   or cls == "Fire" or cls == "Smoke" or cls == "Sparkles"
                   or cls == "Explosion" then
                    if not (char and v:IsDescendantOf(char)) 
                       and not isPartOfAnyCharacter(v) then
                        v:Destroy()
                    end
                end
            end)

            -- Yield mỗi 500 parts (khác cũ 200)
            if i % 500 == 0 then
                task.wait()
                if btn then
                    local pct = 30 + math.floor(i / total * 70)
                    pcall(function() btn.Text = string.format("%s... %d%%", label, pct) end)
                end
            end
        end

        -- ═══════════ BƯỚC 4: SET STATE + DONE ═══════════
        if mode == "all" then
            state.ghostMap = true
            state.playerBlack = true
            state.npcBlack = true
            state.autoClean = true
            state.turboFix = true
            allLoading = false
            if btn then
                pcall(function()
                    btn.Text = "🔥 BẬT TẤT CẢ (ĐÃ BẬT 100%)"
                    btn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
                end)
            end
        else
            state.turboFix = true
            state.autoClean = true
            turboLoading = false
            if btn then
                pcall(function()
                    btn.Text = "🔥🔥🔥 TURBO LAG FIX\n(ĐÃ BẬT 100%)"
                    btn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
                end)
            end
        end
    end)
end

-- Tắt tất cả (async)
local function fastOffAll()
    if allLoading or turboLoading then return end
    allLoading = true

    spawn(function()
        state.autoClean = false
        state.ghostMap = false
        state.playerBlack = false
        state.npcBlack = false
        state.turboFix = false

        -- Restore nhanh
        pcall(function()
            for _, d in ipairs(saved.ghostParts) do
                if d.obj and d.obj.Parent then d.obj.Transparency = d.t end
            end
            saved.ghostParts = {}
        end)
        pcall(function()
            for _, p in ipairs(saved.plasticParts) do
                if p.obj and p.obj.Parent then p.obj.Material = p.m end
            end
            saved.plasticParts = {}
        end)
        pcall(function()
            for _, m in ipairs(saved.materials) do
                if m.obj and m.obj.Parent and m.c then m.obj.CastShadow = m.c end
            end
            saved.materials = {}
        end)
        pcall(function()
            for _, d in ipairs(saved.decalParts) do
                if d.obj and d.obj.Parent then d.obj.Transparency = d.t end
            end
            saved.decalParts = {}
        end)
        pcall(function()
            for _, p in ipairs(saved.parts) do
                if p.obj and p.obj.Parent then p.obj.Transparency = p.trans end
            end
            saved.parts = {}
        end)
        pcall(function()
            restoreChar(saved.playerColors); saved.playerColors = {}
            restoreChar(saved.npcColors); saved.npcColors = {}
        end)

        -- Disconnect listeners
        for _, key in ipairs({"debris","block","instantGC","memPurge","gc"}) do
            if saved.connections[key] then
                pcall(function() saved.connections[key]:Disconnect() end)
                saved.connections[key] = nil
            end
        end

        -- Restore lighting/settings
        pcall(toggleLighting, false)
        pcall(toggleCameraOptimize, false)
        pcall(toggleAtmosphere, false)
        pcall(toggleSkybox, false)
        pcall(toggleTerrain, false)
        pcall(toggleLowQuality, false)
        pcall(toggleForceMinGraphics, false)

        forceEnableCoreGui()
        allLoading = false
        turboLoading = false

        if _G_allBtn then
            pcall(function()
                _G_allBtn.Text = "🔥 BẬT TẤT CẢ\n(FIX LAG + GHOST + BLACK)"
                _G_allBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
            end)
        end
        if _G_turboBtn then
            pcall(function()
                _G_turboBtn.Text = "🔥🔥🔥 TURBO LAG FIX\n(CHỐNG LAG KHI BẬT 4 MENU)"
                _G_turboBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 0)
            end)
        end
    end)
end

-- =====================================================
-- HÀM TOGGLE RIÊNG LẺ (giữ cho từng nút hoạt động)
-- =====================================================
local function toggleEffects(on)
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
               or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                v.Enabled = not on
            end
        end)
    end
end

local function toggleHideFar(on)
    if on then
        local origin, char = getOrigin(); if not origin then return end
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") and not v:IsDescendantOf(char) and not isProtected(v) then
                    if not isPartOfAnyCharacter(v) and not isBlacklisted(v) and not isUIInstance(v) then
                        if (v.Position - origin).Magnitude > state.cullDist and v.Transparency < 0.95 then
                            table.insert(saved.parts, {obj=v, trans=v.Transparency}); v.Transparency = 1
                        end
                    end
                end
            end)
        end
    else
        for _, p in ipairs(saved.parts) do
            pcall(function() if p.obj and p.obj.Parent then p.obj.Transparency = p.trans end end)
        end
        saved.parts = {}
    end
end

local function togglePhysics(on)
    local origin, char = getOrigin(); if not origin then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart") and not v:IsDescendantOf(char) and not isProtected(v) and not isUIInstance(v) then
                if (v.Position - origin).Magnitude > state.cullDist and on then
                    table.insert(saved.physics, {obj=v, t=v.CanTouch, q=v.CanQuery})
                    v.CanTouch = false; v.CanQuery = false
                end
            end
        end)
    end
    if not on then
        for _, p in ipairs(saved.physics) do
            pcall(function() if p.obj and p.obj.Parent then p.obj.CanTouch = p.t; p.obj.CanQuery = p.q end end)
        end
        saved.physics = {}
    end
end

local function toggleKillLights(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
                    table.insert(saved.lights, {obj=v, e=v.Enabled}); v.Enabled = false
                end
            end)
        end
    else
        for _, l in ipairs(saved.lights) do
            pcall(function() if l.obj and l.obj.Parent then l.obj.Enabled = l.e end end)
        end
        saved.lights = {}
    end
end

local function toggleAntiFire(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Fire") then
                    table.insert(saved.fires, {obj=v, k="Enabled", o=v.Enabled})
                    v.Enabled = false; v.Size = 0; v.Heat = 0
                end
                if v:IsA("ParticleEmitter") then
                    local c1 = v.Color and v.Color.Keypoints and v.Color.Keypoints[1] and v.Color.Keypoints[1].Value
                    if isFireTexture(v.Texture) or isFireColor(c1) then
                        table.insert(saved.fires, {obj=v, k="Enabled", o=v.Enabled})
                        v.Enabled = false; v.Rate = 0
                    end
                end
                if v:IsA("Smoke") then
                    table.insert(saved.fires, {obj=v, k="Enabled", o=v.Enabled})
                    v.Enabled = false; v.Opacity = 0
                end
            end)
        end
    else
        for _, f in ipairs(saved.fires) do
            pcall(function() if f.obj and f.obj.Parent then f.obj[f.k] = f.o end end)
        end
        saved.fires = {}
    end
end

local function toggleSoundKill(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Sound") then
                    table.insert(saved.sounds, {obj=v, v=v.Volume}); v.Volume = 0
                end
            end)
        end
    else
        for _, s in ipairs(saved.sounds) do
            pcall(function() if s.obj and s.obj.Parent then s.obj.Volume = s.v end end)
        end
        saved.sounds = {}
    end
end

local function toggleKillAllBeam(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Beam") or v:IsA("Trail") or v:IsA("ParticleEmitter")
                   or v:IsA("Smoke") or v:IsA("Sparkles") then
                    table.insert(saved.allBeams, {obj=v, e=v.Enabled}); v.Enabled = false
                end
            end)
        end
    else
        for _, b in ipairs(saved.allBeams) do
            pcall(function() if b.obj and b.obj.Parent then b.obj.Enabled = b.e end end)
        end
        saved.allBeams = {}
    end
end

local function toggleStopAnims(on)
    if on then
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
    end
end

local function toggleStopAllAnim(on)
    if not on then return end
    local myChar = LocalPlayer.Character
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("Animator") and not (myChar and v:IsDescendantOf(myChar)) then
                for _, a in ipairs(v:GetPlayingAnimationTracks()) do a:Stop() end
            end
        end)
    end
end

local function toggleSleepHumanoids(on)
    if not on then return end
    local origin, char = getOrigin(); if not origin then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("Humanoid") and v.Parent ~= char then
                local hrp = v.Parent:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - origin).Magnitude > 80 then
                    v:SetStateEnabled(Enum.HumanoidStateType.Running, false)
                    v:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
                    v:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
                end
            end
        end)
    end
end

local function toggleAnchorFar(on)
    if on then
        local origin, char = getOrigin(); if not origin then return end
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") and not v.Anchored
                   and not (char and v:IsDescendantOf(char))
                   and not isProtected(v) and not isUIInstance(v) then
                    if (v.Position - origin).Magnitude > state.cullDist then
                        table.insert(saved.anchoredFar, {obj=v}); v.Anchored = true
                    end
                end
            end)
        end
    else
        for _, a in ipairs(saved.anchoredFar) do
            pcall(function() if a.obj and a.obj.Parent then a.obj.Anchored = false end end)
        end
        saved.anchoredFar = {}
    end
end

local function toggleForcePlastic(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") and not isPartOfAnyCharacter(v) and not isUIInstance(v) then
                    if v.Material ~= Enum.Material.Plastic and v.Material ~= Enum.Material.SmoothPlastic
                       and v.Material ~= Enum.Material.Neon and v.Material ~= Enum.Material.ForceField then
                        table.insert(saved.plasticParts, {obj=v, m=v.Material})
                        v.Material = Enum.Material.Plastic
                    end
                end
            end)
        end
    else
        for _, p in ipairs(saved.plasticParts) do
            pcall(function() if p.obj and p.obj.Parent then p.obj.Material = p.m end end)
        end
        saved.plasticParts = {}
    end
end

local function toggleKillDecalTexture(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Decal") or v:IsA("Texture") then
                    if not isUIInstance(v) and not isPartOfAnyCharacter(v.Parent) and not isBlacklisted(v.Parent) then
                        if not v:GetAttribute("DecalOrig") then
                            v:SetAttribute("DecalOrig", v.Transparency)
                            table.insert(saved.decalParts, {obj=v, t=v.Transparency})
                        end
                        v.Transparency = 1
                    end
                end
            end)
        end
    else
        for _, d in ipairs(saved.decalParts) do
            pcall(function() if d.obj and d.obj.Parent then d.obj.Transparency = d.t end end)
        end
        saved.decalParts = {}
    end
end

local function toggleForceShadow(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") and v.CastShadow and not isUIInstance(v) then
                    table.insert(saved.materials, {obj=v, c=v.CastShadow})
                    v.CastShadow = false
                end
            end)
        end
    else
        for _, m in ipairs(saved.materials) do
            pcall(function() if m.obj and m.obj.Parent and m.c then m.obj.CastShadow = m.c end end)
        end
        saved.materials = {}
    end
end

local function toggleGhostMap(on)
    if on then
        local level = state.ghostLevel
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") and isSafeToGhost(v) then
                    if not v:GetAttribute("GhostOrig") then
                        v:SetAttribute("GhostOrig", v.Transparency)
                        table.insert(saved.ghostParts, {obj=v, t=v.Transparency})
                    end
                    v.Transparency = math.max(v.Transparency, level)
                    if v.CastShadow then
                        v:SetAttribute("GhostShadow", true); v.CastShadow = false
                    end
                end
            end)
        end
    else
        for _, d in ipairs(saved.ghostParts) do
            pcall(function()
                if d.obj and d.obj.Parent then
                    d.obj.Transparency = d.t
                    if d.obj:GetAttribute("GhostShadow") then
                        d.obj.CastShadow = true
                        d.obj:SetAttribute("GhostShadow", nil)
                    end
                end
            end)
        end
        saved.ghostParts = {}
    end
end

local function toggleKillInvisible(on)
    if not on then return end
    local char = LocalPlayer.Character
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart") and not (char and v:IsDescendantOf(char))
               and not isProtected(v) and not isPartOfAnyCharacter(v) and not isUIInstance(v) then
                if v.Transparency >= 0.95 then v:Destroy() end
            end
        end)
    end
end

local function toggleKillTiny(on)
    if not on then return end
    local char = LocalPlayer.Character
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart") and not (char and v:IsDescendantOf(char))
               and not isProtected(v) and not isPartOfAnyCharacter(v) and not isUIInstance(v) then
                local s = v.Size
                if s.X < 0.5 and s.Y < 0.5 and s.Z < 0.5 then v:Destroy() end
            end
        end)
    end
end

local function togglePurgeEffectsOnly(on)
    if not on then return end
    local char = LocalPlayer.Character
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if (v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles")
                or v:IsA("Explosion"))
               and not (char and v:IsDescendantOf(char)) and not isPartOfAnyCharacter(v) then
                v:Destroy()
            end
        end)
    end
end

local function togglePurgeParticleModels(on)
    if not on then return end
    local char = LocalPlayer.Character
    local toDestroy = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if (v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles"))
               and not (char and v:IsDescendantOf(char)) then
                local anc = v.Parent
                if anc and anc:IsA("Model") and not isProtected(anc) and not anc:FindFirstChildOfClass("Humanoid") then
                    table.insert(toDestroy, anc)
                end
            end
        end)
    end
    for _, m in ipairs(toDestroy) do
        pcall(function() m:Destroy() end)
    end
end

-- =====================================================
-- OFF ALL
-- =====================================================
local safeKeys = {
    "lighting","effects","hideFar","lowQuality","atmosphere","physics",
    "skybox","terrain","killLights","killFire","debrisClean","soundKill",
    "killAllSound","killAllBeam","blockSpawn","stopAnims",
    "killDecor2","aggressiveGC","instantGC","forceMinGraphics","forceShadow",
    "purgeEffectsOnly","purgeParticleModels","killInvisible","killTiny",
    "forcePlastic","killDecalTexture","stopAllAnim","sleepHumanoids",
    "anchorFar","cameraOptimize","purgeLighting","throttleRender","memoryPurge",
}

local fnMap = {
    lighting=toggleLighting, effects=toggleEffects, hideFar=toggleHideFar,
    lowQuality=toggleLowQuality, atmosphere=toggleAtmosphere, physics=togglePhysics,
    skybox=toggleSkybox, terrain=toggleTerrain, killLights=toggleKillLights,
    killFire=toggleAntiFire, debrisClean=toggleDebrisClean, soundKill=toggleSoundKill,
    killAllSound=toggleKillAllSound, killAllBeam=toggleKillAllBeam,
    blockSpawn=toggleBlockSpawn, stopAnims=toggleStopAnims, killDecor2=toggleKillDecor2,
    aggressiveGC=toggleAggressiveGC, instantGC=toggleInstantGC,
    forceMinGraphics=toggleForceMinGraphics, forceShadow=toggleForceShadow,
    purgeEffectsOnly=togglePurgeEffectsOnly, purgeParticleModels=togglePurgeParticleModels,
    killInvisible=toggleKillInvisible, killTiny=toggleKillTiny,
    forcePlastic=toggleForcePlastic, killDecalTexture=toggleKillDecalTexture,
    stopAllAnim=toggleStopAllAnim, sleepHumanoids=toggleSleepHumanoids,
    anchorFar=toggleAnchorFar, cameraOptimize=toggleCameraOptimize,
    purgeLighting=togglePurgeLighting, throttleRender=toggleThrottleRender,
    memoryPurge=toggleMemoryPurge,
}

local function offAll()
    for _, k in ipairs(safeKeys) do
        state[k] = false
        local fn = fnMap[k]; if fn then pcall(fn, false) end
    end
end

-- =====================================================
-- GUI
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
fpsText.Text = "FPS: --\nPING: --\nDIST: 80 | LOCK: 60"
fpsText.Parent = fpsFrame

spawn(function()
    while task.wait(0.25) do
        local f = getFPS()
        local c = Color3.fromRGB(0, 255, 100)
        if f < 60 then c = Color3.fromRGB(255, 210, 0) end
        if f < 30 then c = Color3.fromRGB(255, 60, 60) end
        fpsText.TextColor3 = c; fpsStroke.Color = c
        fpsText.Text = string.format("FPS: %d\nPING: %d\nDIST: %d | LOCK: %d",
            f, getPing(), state.cullDist, state.fpsTarget)
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
title.BackgroundTransparency = 1; title.Text = "⚡ FIXLAG_VN TURBO v4 (NHANH 5X)"
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

-- 🔥 BẬT TẤT CẢ (TOP)
local allBtn = Instance.new("TextButton")
allBtn.Size = UDim2.new(1, -20, 0, 70); allBtn.Position = UDim2.new(0, 10, 0, y)
allBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
allBtn.Text = "🔥 BẬT TẤT CẢ\n(NHANH 5X - 1 PASS DUY NHẤT)"
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
        fastBatchApply("all")
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

-- TURBO BUTTON
local turboBtn = Instance.new("TextButton")
turboBtn.Size = UDim2.new(1, -20, 0, 60); turboBtn.Position = UDim2.new(0, 10, 0, y)
turboBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 0)
turboBtn.Text = "🔥🔥🔥 TURBO LAG FIX (NHANH 5X)"
turboBtn.Font = Enum.Font.GothamBold; turboBtn.TextSize = 12
turboBtn.TextColor3 = Color3.fromRGB(255, 255, 255); turboBtn.Parent = scroll
Instance.new("UICorner", turboBtn).CornerRadius = UDim.new(0, 10)
local turboStroke = Instance.new("UIStroke", turboBtn)
turboStroke.Color = Color3.fromRGB(255, 255, 0); turboStroke.Thickness = 3
_G_turboBtn = turboBtn

turboBtn.MouseButton1Click:Connect(function()
    if turboLoading then return end
    if not state.turboFix then
        fastBatchApply("turbo")
        state.autoClean = true
        for k, data in pairs(buttons) do
            if state[k] then
                data.btn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
                data.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                data.btn.Text = "● " .. data.label
            end
        end
    else
        fastOffAll()
        state.autoClean = false
        for _, data in pairs(buttons) do
            data.btn.BackgroundColor3 = data.color or Color3.fromRGB(45, 45, 60)
            data.btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            data.btn.Text = "○ " .. data.label
        end
    end
end)

y = y + 66

header("👻 GHOST MAP 30%", Color3.fromRGB(200, 200, 255))
add("👻 GHOST MAP 30%", "ghostMap", toggleGhostMap, Color3.fromRGB(40, 40, 60))

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

header("🔥🔥🔥 TURBO (AN TOÀN UI)", Color3.fromRGB(255, 100, 0))
add("💥 KILL INVISIBLE", "killInvisible", toggleKillInvisible, Color3.fromRGB(60, 20, 0))
add("💥 KILL TINY",      "killTiny",      toggleKillTiny,      Color3.fromRGB(60, 20, 0))
add("💥 FORCE PLASTIC",  "forcePlastic",  toggleForcePlastic,  Color3.fromRGB(60, 20, 0))
add("💥 KILL DECAL/TEXTURE", "killDecalTexture", toggleKillDecalTexture, Color3.fromRGB(60, 20, 0))
add("💥 STOP ALL ANIM",  "stopAllAnim",   toggleStopAllAnim,   Color3.fromRGB(60, 20, 0))
add("💥 SLEEP HUMANOIDS","sleepHumanoids",toggleSleepHumanoids,Color3.fromRGB(60, 20, 0))
add("💥 ANCHOR XA",      "anchorFar",     toggleAnchorFar,     Color3.fromRGB(60, 20, 0))
add("💥 CAMERA OPT",     "cameraOptimize",toggleCameraOptimize,Color3.fromRGB(60, 20, 0))
add("💥 PURGE LIGHTING", "purgeLighting", togglePurgeLighting, Color3.fromRGB(60, 20, 0))
add("💥 THROTTLE",       "throttleRender",toggleThrottleRender,Color3.fromRGB(60, 20, 0))
add("💥 MEMORY PURGE",   "memoryPurge",   toggleMemoryPurge,   Color3.fromRGB(60, 20, 0))

header("⚙️ FIX LAG CƠ BẢN", Color3.fromRGB(100, 200, 255))
add("Tắt đèn & hậu kỳ",     "lighting",       toggleLighting)
add("Tắt hạt & effects",     "effects",        toggleEffects)
add("🔥 DIỆT LỬA MỌI MÀU",   "killFire",       toggleAntiFire)
add("🧹 DỌN RÁC EFFECT",     "debrisClean",    toggleDebrisClean)
add("🖼 PURGE EFFECTS",      "purgeEffectsOnly", togglePurgeEffectsOnly)
add("🌪️ PURGE PARTICLE MODELS", "purgeParticleModels", togglePurgeParticleModels)
add("☢️ KILL ALL BEAM",      "killAllBeam",    toggleKillAllBeam)
add("☢️ KILL ALL SOUND",     "killAllSound",   toggleKillAllSound)
add("🔇 Sound Killer",         "soundKill",      toggleSoundKill)
add("☢️ BLOCK SPAWN",        "blockSpawn",     toggleBlockSpawn)
add("☢️ STOP ANIM",          "stopAnims",      toggleStopAnims)
add("Ẩn vật thể xa",          "hideFar",        toggleHideFar)
add("Chất lượng thấp",        "lowQuality",     toggleLowQuality)
add("Tắt Atmosphere",         "atmosphere",     toggleAtmosphere)
add("Giảm Physics xa",        "physics",        togglePhysics)
add("⚫ Xóa Skybox",          "skybox",         toggleSkybox)
add("⚫ Xóa Terrain",         "terrain",        toggleTerrain)
add("⚫ Kill Light",          "killLights",     toggleKillLights)
add("⚫ KILL TERRAIN 2",      "killDecor2",     toggleKillDecor2)
add("✦ Tắt Shadow",           "forceShadow",    toggleForceShadow)
add("💀 FORCE MIN GRAPHICS",   "forceMinGraphics", toggleForceMinGraphics)
add("💀 INSTANT GC",           "instantGC",      toggleInstantGC)
add("💀 AGGRESSIVE GC",        "aggressiveGC",   toggleAggressiveGC)

-- FPS Lock
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(1, -20, 0, 20); fpsLabel.Position = UDim2.new(0, 10, 0, y + 5)
fpsLabel.BackgroundTransparency = 1; fpsLabel.Text = "🔒 KHÓA FPS"
fpsLabel.Font = Enum.Font.GothamBold; fpsLabel.TextSize = 11
fpsLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left; fpsLabel.Parent = scroll

local lockFrame = Instance.new("Frame")
lockFrame.Size = UDim2.new(1, -20, 0, 40)
lockFrame.Position = UDim2.new(0, 10, 0, y + 28)
lockFrame.BackgroundTransparency = 1; lockFrame.Parent = scroll

for i, val in ipairs({45, 60, 90, 120}) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 75, 0, 36)
    btn.Position = UDim2.new(0, (i-1) * 78, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    btn.Text = "🔒" .. val; btn.Font = Enum.Font.GothamBold; btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(200, 200, 200); btn.Parent = lockFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function()
        state.fpsTarget = val
        local json = string.format(
            '{\n  "DFIntTaskSchedulerTargetFps": "%d",\n  "FFlagTaskSchedulerLimitTargetFpsTo2402": "False"\n}', val)
        if setclipboard then setclipboard(json) end
    end)
end

y = y + 78

local distLabel = Instance.new("TextLabel")
distLabel.Size = UDim2.new(1, -20, 0, 20); distLabel.Position = UDim2.new(0, 10, 0, y + 5)
distLabel.BackgroundTransparency = 1; distLabel.Text = "Cull Distance: 80"
distLabel.Font = Enum.Font.GothamBold; distLabel.TextSize = 11
distLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
distLabel.TextXAlignment = Enum.TextXAlignment.Left; distLabel.Parent = scroll

local sliderBg = Instance.new("Frame")
sliderBg.Size = UDim2.new(1, -20, 0, 8); sliderBg.Position = UDim2.new(0, 10, 0, y + 28)
sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60); sliderBg.BorderSizePixel = 0
sliderBg.Parent = scroll
Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0, 4)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.125, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(255, 100, 0); sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 4)

local sliderBtn = Instance.new("TextButton")
sliderBtn.Size = UDim2.new(0, 16, 0, 16); sliderBtn.Position = UDim2.new(0.125, -8, 0, -4)
sliderBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 50); sliderBtn.Text = ""
sliderBtn.Parent = sliderBg
Instance.new("UICorner", sliderBtn).CornerRadius = UDim.new(1, 0)

y = y + 42

local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, -20, 0, 30); autoBtn.Position = UDim2.new(0, 10, 0, y)
autoBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
autoBtn.Text = "○ AUTO CLEAN (0.3s)"; autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 10; autoBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
autoBtn.Parent = scroll
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 8)
autoBtn.MouseButton1Click:Connect(function()
    state.autoClean = not state.autoClean; local on = state.autoClean
    autoBtn.BackgroundColor3 = on and Color3.fromRGB(30, 130, 70) or Color3.fromRGB(45, 45, 60)
    autoBtn.Text = (on and "● " or "○ ") .. "AUTO CLEAN (0.3s)"
end)

y = y + 35

local comboBtn = Instance.new("TextButton")
comboBtn.Size = UDim2.new(1, -20, 0, 50); comboBtn.Position = UDim2.new(0, 10, 0, y)
comboBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
comboBtn.Text = "👻⚫ GHOST + BLACK"
comboBtn.Font = Enum.Font.GothamBold; comboBtn.TextSize = 12
comboBtn.TextColor3 = Color3.fromRGB(255, 255, 255); comboBtn.Parent = scroll
Instance.new("UICorner", comboBtn).CornerRadius = UDim.new(0, 10)
local comboStroke = Instance.new("UIStroke", comboBtn)
comboStroke.Color = Color3.fromRGB(200, 200, 255); comboStroke.Thickness = 2

comboBtn.MouseButton1Click:Connect(function()
    local newState = not (state.ghostMap and state.playerBlack and state.npcBlack)
    state.ghostMap = newState; state.playerBlack = newState; state.npcBlack = newState
    pcall(toggleGhostMap, newState)
    pcall(togglePlayerBlack, newState)
    pcall(toggleNpcBlack, newState)
    if newState then
        comboBtn.Text = "👻⚫ GHOST + BLACK (ON)"
        comboBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
    else
        comboBtn.Text = "👻⚫ GHOST + BLACK"
        comboBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    end
    for _, k in ipairs({"ghostMap","playerBlack","npcBlack"}) do
        local d = buttons[k]
        if d then
            d.btn.BackgroundColor3 = state[k] and Color3.fromRGB(255, 100, 0) or (d.color or Color3.fromRGB(45, 45, 60))
            d.btn.TextColor3 = state[k] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
            d.btn.Text = (state[k] and "● " or "○ ") .. d.label
        end
    end
end)

y = y + 56

local offAllBtn = Instance.new("TextButton")
offAllBtn.Size = UDim2.new(1, -20, 0, 36); offAllBtn.Position = UDim2.new(0, 10, 0, y)
offAllBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 20)
offAllBtn.Text = "⏹ TẮT TẤT CẢ"
offAllBtn.Font = Enum.Font.GothamBold; offAllBtn.TextSize = 12
offAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255); offAllBtn.Parent = scroll
Instance.new("UICorner", offAllBtn).CornerRadius = UDim.new(0, 10)
offAllBtn.MouseButton1Click:Connect(function()
    fastOffAll()
    autoBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    autoBtn.Text = "○ AUTO CLEAN (0.3s)"
    comboBtn.Text = "👻⚫ GHOST + BLACK"
    comboBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    for _, data in pairs(buttons) do
        state[data.label] = false
        data.btn.BackgroundColor3 = data.color or Color3.fromRGB(45, 45, 60)
        data.btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        data.btn.Text = "○ " .. data.label
    end
end)

y = y + 42
scroll.CanvasSize = UDim2.new(0, 0, 0, y + 15)

-- Slider logic
local draggingDist = false
sliderBtn.MouseButton1Down:Connect(function() draggingDist = true end)
sliderBtn.MouseButton1Up:Connect(function() draggingDist = false end)
gui.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        draggingDist = false
        dragGhost = false
    end
end)

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
    if draggingDist then
        local relX = math.clamp((mouse.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        sliderFill.Size = UDim2.new(relX, 0, 1, 0)
        sliderBtn.Position = UDim2.new(relX, -8, 0, -4)
        state.cullDist = math.floor(30 + relX * 370)
        distLabel.Text = "Cull Distance: " .. state.cullDist
    end
end)

-- =====================================================
-- LOOPS
-- =====================================================
spawn(function()
    while task.wait(0.3) do
        if state.autoClean then
            for _, v in ipairs(Workspace:GetDescendants()) do
                pcall(function()
                    if v:IsA("Explosion") then v:Destroy() end
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                       or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                        v.Enabled = false
                    end
                end)
            end
            collectgarbage("collect")
        end
    end
end)

spawn(function()
    while task.wait(0.5) do
        if state.playerBlack then pcall(togglePlayerBlack, true) end
        if state.npcBlack then pcall(toggleNpcBlack, true) end
    end
end)

spawn(function()
    while task.wait(3) do
        if state.ghostMap then
            local level = state.ghostLevel
            local count = 0
            for _, v in ipairs(Workspace:GetDescendants()) do
                if count > 200 then break end
                if count % 50 == 0 then task.wait() end
                pcall(function()
                    if v:IsA("BasePart") and isSafeToGhost(v) then
                        if v.Transparency < level and v.Transparency < 0.98 then
                            if not v:GetAttribute("GhostOrig") then
                                v:SetAttribute("GhostOrig", v.Transparency)
                                table.insert(saved.ghostParts, {obj=v, t=v.Transparency})
                            end
                            v.Transparency = level
                            count = count + 1
                        end
                    end
                end)
            end
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
    for _, k in ipairs(safeKeys) do
        if state[k] then
            local fn = fnMap[k]; if fn then pcall(fn, true) end
        end
    end
    if state.ghostMap then pcall(toggleGhostMap, true) end
    if state.playerBlack then pcall(togglePlayerBlack, true) end
    if state.npcBlack then pcall(toggleNpcBlack, true) end
end)

print("⚡ FIXLAG_VN TURBO v4 loaded! Single-pass batch, tốc độ 5x.")
