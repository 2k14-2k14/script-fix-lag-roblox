-- =====================================================
-- FIXLAG_VN GHOST — Map trong suốt 40%, Player/NPC đen
-- Giữ map nguyên vẹn, chỉ làm mờ để giảm tải render
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

-- 🛡️ WHITELIST — Part KHÔNG được làm trong suốt
local PROTECTED_NAMES = {
    "baseplate","base","ground","floor","platform","spawn",
    "terrain","world","map","zone","area","region",
    "start","lobby","hub","main","center","root",
    "foundation","pavement","road","path","walkway",
}

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

local state = {
    -- GHOST MAP
    ghostMap=false, ghostLevel=0.4,
    -- BLACK MODE
    playerBlack=false, npcBlack=false,
    -- FIX LAG
    lighting=false, effects=false, hideFar=false,
    lowQuality=false, atmosphere=false, physics=false,
    skybox=false, terrain=false, killLights=false,
    killFire=false, debrisClean=false, soundKill=false,
    killAllSound=false, killAllGui=false, killAllBeam=false,
    blockSpawn=false, stopAnims=false, killDecor2=false,
    aggressiveGC=false, instantGC=false, renderDistZero=false,
    forceMinGraphics=false, forceShadow=false,
    purgeEffectsOnly=false, purgeParticleModels=false,
    -- Meta
    autoClean=false, cullDist=80, fpsTarget=60,
}

local saved = {
    parts={}, lighting={}, guis={}, atmo={}, physics={}, sky={},
    lights={}, allEffects={}, fires={}, sounds={}, allSounds={},
    allGuis={}, allBeams={}, materials={}, connections={},
    playerColors={}, npcColors={},
    -- GHOST MAP
    ghostParts={},
}

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
    local ok, p = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
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

local function isPartOfAnyCharacter(p)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and p:IsDescendantOf(plr.Character) then return true end
    end
    -- NPC (Model có Humanoid)
    local anc = p
    for i = 1, 5 do
        if not anc or anc == Workspace then break end
        anc = anc.Parent
        if anc and anc:IsA("Model") and anc:FindFirstChildOfClass("Humanoid") then return true end
    end
    return false
end

local function isFireColor(c)
    if not c then return false end
    local r, g, b = c.R, c.G, c.B
    return (r > 0.55 and g < 0.6 and b < 0.4)
        or (r > 0.7 and g > 0.25 and g < 0.85 and b < 0.35)
end

local function isFireTexture(t)
    if not t then return false end
    t = t:lower()
    return t:find("fire") or t:find("flame") or t:find("ember")
        or t:find("spark") or t:find("burn")
end

-- =====================================================
-- 👻 GHOST MAP — Làm trong suốt map 40%
-- =====================================================
local function toggleGhostMap(on)
    if on then
        local char = LocalPlayer.Character
        local level = state.ghostLevel

        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") and v ~= nil then
                    -- Bỏ qua: character (player/NPC)
                    if isPartOfAnyCharacter(v) then return end
                    -- Bỏ qua: baseplate/ground/spawn/terrain
                    if isProtected(v) then return end
                    -- Bỏ qua: part đã trong suốt sẵn
                    if v.Transparency >= 0.98 then return end

                    -- Lưu trans gốc
                    if not v:GetAttribute("GhostOrig") then
                        v:SetAttribute("GhostOrig", v.Transparency)
                        table.insert(saved.ghostParts, {obj=v, t=v.Transparency})
                    end

                    -- Áp dụng mức trong suốt (giữ max với transparency hiện tại)
                    local newT = math.max(v.Transparency, level)
                    v.Transparency = newT

                    -- Tắt shadow để giảm tải render
                    if v.CastShadow then
                        v:SetAttribute("GhostShadow", true)
                        v.CastShadow = false
                    end
                end

                -- Làm mờ Decal/Texture tường
                if (v:IsA("Decal") or v:IsA("Texture")) then
                    local par = v.Parent
                    if par and par:IsA("BasePart") and not isProtected(par)
                       and not isPartOfAnyCharacter(par) then
                        if not v:GetAttribute("GhostOrigT") then
                            v:SetAttribute("GhostOrigT", v.Transparency)
                            table.insert(saved.ghostParts, {obj=v, t=v.Transparency, isDecal=true})
                        end
                        v.Transparency = math.max(v.Transparency, level)
                    end
                end
            end)
        end

        -- Theo dõi part mới spawn
        if saved.connections.ghostMap then saved.connections.ghostMap:Disconnect() end
        saved.connections.ghostMap = Workspace.DescendantAdded:Connect(function(v)
            if not state.ghostMap then return end
            task.wait(0.3)
            pcall(function()
                if v:IsA("BasePart") and not isProtected(v) and not isPartOfAnyCharacter(v) then
                    if not v:GetAttribute("GhostOrig") then
                        v:SetAttribute("GhostOrig", v.Transparency)
                        table.insert(saved.ghostParts, {obj=v, t=v.Transparency})
                    end
                    v.Transparency = math.max(v.Transparency, state.ghostLevel)
                    if v.CastShadow then
                        v:SetAttribute("GhostShadow", true)
                        v.CastShadow = false
                    end
                end
            end)
        end)
    else
        -- Khôi phục
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
        if saved.connections.ghostMap then
            saved.connections.ghostMap:Disconnect()
            saved.connections.ghostMap = nil
        end
    end
end

-- =====================================================
-- ⚫ BLACK MODE — Player/NPC đen
-- =====================================================
local function makeBlack(char, saveList)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart") then
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
                        if not isPlayer then
                            makeBlack(model, saved.npcColors)
                        end
                    end
                end
            end)
        end
    else
        restoreChar(saved.npcColors)
        saved.npcColors = {}
    end
end

-- Watch player mới
local function setupBlackWatchers()
    if saved.connections.blackPlayers then saved.connections.blackPlayers:Disconnect() end
    saved.connections.blackPlayers = Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function(char)
            task.wait(1)
            if state.playerBlack then makeBlack(char, saved.playerColors) end
        end)
    end)
end
setupBlackWatchers()

-- =====================================================
-- FIX LAG MODULES
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
                    if not isPartOfAnyCharacter(v) then
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

local function toggleLowQuality(on)
    local ok, cur = pcall(function() return settings().Rendering.QualityLevel end)
    if on then
        saved.quality = ok and cur or Enum.QualityLevel.Automatic
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01 end)
    else
        pcall(function() settings().Rendering.QualityLevel = saved.quality or Enum.QualityLevel.Automatic end)
    end
end

local function toggleAtmosphere(on)
    if on then
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Atmosphere") or v:IsA("Clouds")
               or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
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

local function togglePhysics(on)
    local origin, char = getOrigin(); if not origin then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart") and not v:IsDescendantOf(char) and not isProtected(v) then
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
                    local c1 = v.Color and v.Color.Keypoints and v.Color.Keypoints[1]
                        and v.Color.Keypoints[1].Value
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

local function toggleKillAllSound(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Sound") then
                    table.insert(saved.allSounds, {obj=v, v=v.Volume}); v.Volume = 0
                end
            end)
        end
        pcall(function() SoundSvc.AmbientReverb = Enum.ReverbType.NoReverb end)
    else
        for _, s in ipairs(saved.allSounds) do
            pcall(function() if s.obj and s.obj.Parent then s.obj.Volume = s.v end end)
        end
        saved.allSounds = {}
    end
end

local function toggleKillAllGui(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
                    local par = v.Parent
                    if not isPartOfAnyCharacter(par or v) then
                        table.insert(saved.allGuis, {obj=v, e=v.Enabled}); v.Enabled = false
                    end
                end
            end)
        end
    else
        for _, g in ipairs(saved.allGuis) do
            pcall(function() if g.obj and g.obj.Parent then g.obj.Enabled = g.e end end)
        end
        saved.allGuis = {}
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

local function toggleBlockSpawn(on)
    if on then
        if saved.connections.block then saved.connections.block:Disconnect() end
        saved.connections.block = Workspace.DescendantAdded:Connect(function(v)
            pcall(function()
                if v:IsA("Explosion") then v:Destroy() end
                if v:IsA("Sound") then v.Volume = 0 end
                if v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then v.Enabled = false end
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                   or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                    v.Enabled = false
                end
            end)
        end)
    else
        if saved.connections.block then saved.connections.block:Disconnect(); saved.connections.block = nil end
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

local function toggleKillDecor2(on)
    local t = Workspace:FindFirstChildOfClass("Terrain"); if not t then return end
    pcall(function()
        if on then t.Decoration = false; t.WaterWaveSize = 0; t.WaterWaveSpeed = 0
        else t.Decoration = true; t.WaterWaveSize = 0.15; t.WaterWaveSpeed = 10 end
    end)
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

local function toggleRenderDistZero(on)
    if on then
        pcall(function() Cam.FarPlane = 0 end)
    else
        pcall(function() Cam.FarPlane = 100000 end)
    end
end

local function toggleForceMinGraphics(on)
    if on then
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01 end)
    else
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
    end
end

local function toggleForceShadow(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") and v.CastShadow then
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

local function togglePurgeEffectsOnly(on)
    if not on then return end
    local char = LocalPlayer.Character
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if (v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles")
                or v:IsA("Highlight") or v:IsA("Explosion"))
               and not (char and v:IsDescendantOf(char))
               and not isPartOfAnyCharacter(v) then
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
                if anc and anc:IsA("Model") and not isProtected(anc)
                   and not anc:FindFirstChildOfClass("Humanoid") then
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
-- APPLY / OFF
-- =====================================================
local safeKeys = {
    "lighting","effects","hideFar","lowQuality","atmosphere","physics",
    "skybox","terrain","killLights","killFire","debrisClean","soundKill",
    "killAllSound","killAllGui","killAllBeam","blockSpawn","stopAnims",
    "killDecor2","aggressiveGC","instantGC","renderDistZero",
    "forceMinGraphics","forceShadow",
    "purgeEffectsOnly","purgeParticleModels",
}

local fnMap = {
    lighting=toggleLighting, effects=toggleEffects, hideFar=toggleHideFar,
    lowQuality=toggleLowQuality, atmosphere=toggleAtmosphere, physics=togglePhysics,
    skybox=toggleSkybox, terrain=toggleTerrain, killLights=toggleKillLights,
    killFire=toggleAntiFire, debrisClean=toggleDebrisClean, soundKill=toggleSoundKill,
    killAllSound=toggleKillAllSound, killAllGui=toggleKillAllGui, killAllBeam=toggleKillAllBeam,
    blockSpawn=toggleBlockSpawn, stopAnims=toggleStopAnims, killDecor2=toggleKillDecor2,
    aggressiveGC=toggleAggressiveGC, instantGC=toggleInstantGC,
    renderDistZero=toggleRenderDistZero, forceMinGraphics=toggleForceMinGraphics,
    forceShadow=toggleForceShadow,
    purgeEffectsOnly=togglePurgeEffectsOnly, purgeParticleModels=togglePurgeParticleModels,
}

local function applyAll(on)
    for _, k in ipairs(safeKeys) do state[k] = on end
    for _, k in ipairs(safeKeys) do
        local fn = fnMap[k]; if fn then pcall(fn, on) end
    end
end

local function offAll()
    applyAll(false)
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
fpsStroke.Color = Color3.fromRGB(180, 180, 180); fpsStroke.Thickness = 1.5

local fpsText = Instance.new("TextLabel")
fpsText.Size = UDim2.new(1, -10, 1, -10); fpsText.Position = UDim2.new(0, 5, 0, 5)
fpsText.BackgroundTransparency = 1; fpsText.Font = Enum.Font.Code; fpsText.TextSize = 14
fpsText.TextColor3 = Color3.fromRGB(200, 200, 200)
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
menu.Size = UDim2.new(0, 340, 0, 640)
menu.Position = UDim2.new(0, 15, 0, 95)
menu.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
menu.BorderSizePixel = 0; menu.Active = true; menu.Draggable = true; menu.Parent = gui
Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 14)
local mStroke = Instance.new("UIStroke", menu)
mStroke.Color = Color3.fromRGB(180, 180, 180); mStroke.Thickness = 2

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 34); title.Position = UDim2.new(0, 10, 0, 3)
title.BackgroundTransparency = 1; title.Text = "👻 FIXLAG_VN GHOST"
title.Font = Enum.Font.GothamBold; title.TextSize = 14
title.TextColor3 = Color3.fromRGB(200, 200, 200)
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
scroll.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollingDirection = Enum.ScrollingDirection.Y; scroll.Parent = menu

local collapsed = false
minBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed; scroll.Visible = not collapsed
    menu.Size = collapsed and UDim2.new(0, 340, 0, 40) or UDim2.new(0, 340, 0, 640)
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
        btn.BackgroundColor3 = on and Color3.fromRGB(200, 200, 200) or (color or Color3.fromRGB(45, 45, 60))
        btn.TextColor3 = on and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(200, 200, 200)
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

header("👻 GHOST MAP (TRONG SUỐT)", Color3.fromRGB(200, 200, 255))
add("👻 GHOST MAP 40%", "ghostMap", toggleGhostMap, Color3.fromRGB(40, 40, 60))

-- Ghost level slider
local gLbl = Instance.new("TextLabel")
gLbl.Size = UDim2.new(1, -20, 0, 20); gLbl.Position = UDim2.new(0, 10, 0, y)
gLbl.BackgroundTransparency = 1; gLbl.Text = "Mức trong suốt: 40%"
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
gFill.Size = UDim2.new(0.4, 0, 1, 0)
gFill.BackgroundColor3 = Color3.fromRGB(200, 200, 255); gFill.BorderSizePixel = 0
gFill.Parent = gBg
Instance.new("UICorner", gFill).CornerRadius = UDim.new(0, 4)

local gBtn = Instance.new("TextButton")
gBtn.Size = UDim2.new(0, 16, 0, 16); gBtn.Position = UDim2.new(0.4, -8, 0, -4)
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

header("🔥 FIX LAG", Color3.fromRGB(255, 100, 50))
add("Tắt đèn & hậu kỳ",     "lighting",       toggleLighting)
add("Tắt hạt & effects",     "effects",        toggleEffects)
add("🔥 DIỆT LỬA MỌI MÀU",   "killFire",       toggleAntiFire)
add("🧹 DỌN RÁC EFFECT",     "debrisClean",    toggleDebrisClean)
add("🖼 PURGE EFFECTS ONLY", "purgeEffectsOnly", togglePurgeEffectsOnly)
add("🌪️ PURGE PARTICLE MODELS", "purgeParticleModels", togglePurgeParticleModels)
add("☢️ KILL ALL BEAM/TRAIL", "killAllBeam",    toggleKillAllBeam)
add("☢️ KILL ALL GUI 3D",     "killAllGui",     toggleKillAllGui)
add("☢️ KILL ALL SOUND",      "killAllSound",   toggleKillAllSound)
add("🔇 Sound Killer",         "soundKill",      toggleSoundKill)
add("☢️ BLOCK SPAWN FX",       "blockSpawn",     toggleBlockSpawn)
add("☢️ STOP ANIMATIONS",      "stopAnims",      toggleStopAnims)
add("Ẩn vật thể xa",          "hideFar",        toggleHideFar)
add("Chất lượng thấp nhất",   "lowQuality",     toggleLowQuality)
add("Tắt Atmosphere",         "atmosphere",     toggleAtmosphere)
add("Giảm Physics xa",        "physics",        togglePhysics)
add("⚫ Xóa Skybox",          "skybox",         toggleSkybox)
add("⚫ Xóa Terrain",         "terrain",        toggleTerrain)
add("⚫ Kill mọi Light",      "killLights",     toggleKillLights)
add("⚫ KILL TERRAIN 2",      "killDecor2",     toggleKillDecor2)
add("✦ Tắt Shadow toàn bộ",   "forceShadow",    toggleForceShadow)
add("💀 RENDER DIST = 0",      "renderDistZero", toggleRenderDistZero)
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
    btn.Size = UDim2.new(0, 70, 0, 36)
    btn.Position = UDim2.new(0, (i-1) * 74, 0, 0)
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
sliderFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50); sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 4)

local sliderBtn = Instance.new("TextButton")
sliderBtn.Size = UDim2.new(0, 16, 0, 16); sliderBtn.Position = UDim2.new(0.125, -8, 0, -4)
sliderBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100); sliderBtn.Text = ""
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

-- GHOST + BLACK BUTTON
local comboBtn = Instance.new("TextButton")
comboBtn.Size = UDim2.new(1, -20, 0, 70); comboBtn.Position = UDim2.new(0, 10, 0, y)
comboBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
comboBtn.Text = "👻⚫ GHOST + BLACK\n(MAP TRONG SUỐT + PLAYER ĐEN)"
comboBtn.Font = Enum.Font.GothamBold; comboBtn.TextSize = 13
comboBtn.TextColor3 = Color3.fromRGB(255, 255, 255); comboBtn.Parent = scroll
Instance.new("UICorner", comboBtn).CornerRadius = UDim.new(0, 10)
local comboStroke = Instance.new("UIStroke", comboBtn)
comboStroke.Color = Color3.fromRGB(200, 200, 255); comboStroke.Thickness = 3

comboBtn.MouseButton1Click:Connect(function()
    local newState = not (state.ghostMap and state.playerBlack and state.npcBlack)
    state.ghostMap = newState
    state.playerBlack = newState
    state.npcBlack = newState

    pcall(toggleGhostMap, newState)
    pcall(togglePlayerBlack, newState)
    pcall(toggleNpcBlack, newState)

    if newState then
        comboBtn.Text = "👻⚫ GHOST + BLACK\n(ĐANG ÁP DỤNG...)"
        comboBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
    else
        comboBtn.Text = "👻⚫ GHOST + BLACK\n(MAP TRONG SUỐT + PLAYER ĐEN)"
        comboBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    end

    for _, k in ipairs({"ghostMap","playerBlack","npcBlack"}) do
        local d = buttons[k]
        if d then
            d.btn.BackgroundColor3 = state[k] and Color3.fromRGB(200, 200, 200) or (d.color or Color3.fromRGB(45, 45, 60))
            d.btn.TextColor3 = state[k] and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(200, 200, 200)
            d.btn.Text = (state[k] and "● " or "○ ") .. d.label
        end
    end
end)

y = y + 76

-- BẬT TẤT CẢ
local allBtn = Instance.new("TextButton")
allBtn.Size = UDim2.new(1, -20, 0, 42); allBtn.Position = UDim2.new(0, 10, 0, y)
allBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
allBtn.Text = "🔥 BẬT TẤT CẢ (FIX LAG + GHOST + BLACK)"
allBtn.Font = Enum.Font.GothamBold; allBtn.TextSize = 11
allBtn.TextColor3 = Color3.fromRGB(255, 255, 255); allBtn.Parent = scroll
Instance.new("UICorner", allBtn).CornerRadius = UDim.new(0, 10)
allBtn.MouseButton1Click:Connect(function()
    applyAll(true)
    state.autoClean = true
    state.ghostMap = true
    state.playerBlack = true
    state.npcBlack = true
    pcall(toggleGhostMap, true)
    pcall(togglePlayerBlack, true)
    pcall(toggleNpcBlack, true)
    autoBtn.BackgroundColor3 = Color3.fromRGB(30, 130, 70)
    autoBtn.Text = "● AUTO CLEAN (0.3s)"
    comboBtn.Text = "👻⚫ GHOST + BLACK\n(ĐANG ÁP DỤNG...)"
    comboBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
    for k, data in pairs(buttons) do
        if state[k] then
            data.btn.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
            data.btn.TextColor3 = Color3.fromRGB(0, 0, 0)
            data.btn.Text = "● " .. data.label
        end
    end
end)

y = y + 47

-- TẮT TẤT CẢ
local offAllBtn = Instance.new("TextButton")
offAllBtn.Size = UDim2.new(1, -20, 0, 36); offAllBtn.Position = UDim2.new(0, 10, 0, y)
offAllBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 20)
offAllBtn.Text = "⏹ TẮT TẤT CẢ"
offAllBtn.Font = Enum.Font.GothamBold; offAllBtn.TextSize = 12
offAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255); offAllBtn.Parent = scroll
Instance.new("UICorner", offAllBtn).CornerRadius = UDim.new(0, 10)
offAllBtn.MouseButton1Click:Connect(function()
    offAll()
    state.autoClean = false
    state.ghostMap = false
    state.playerBlack = false
    state.npcBlack = false
    pcall(toggleGhostMap, false)
    pcall(togglePlayerBlack, false)
    pcall(toggleNpcBlack, false)
    autoBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    autoBtn.Text = "○ AUTO CLEAN (0.3s)"
    comboBtn.Text = "👻⚫ GHOST + BLACK\n(MAP TRONG SUỐT + PLAYER ĐEN)"
    comboBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    for _, data in pairs(buttons) do
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

    -- Ghost slider
    if dragGhost then
        local relX = math.clamp((mouse.X - gBg.AbsolutePosition.X) / gBg.AbsoluteSize.X, 0.1, 0.9)
        gFill.Size = UDim2.new(relX, 0, 1, 0)
        gBtn.Position = UDim2.new(relX, -8, 0, -4)
        local level = math.floor(relX * 100) / 100
        state.ghostLevel = level
        gLbl.Text = "Mức trong suốt: " .. math.floor(level * 100) .. "%"
    end

    -- Cull slider
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

-- Auto clean 0.3s
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

-- Loop black + ghost apply
spawn(function()
    while task.wait(0.5) do
        if state.playerBlack then pcall(togglePlayerBlack, true) end
        if state.npcBlack then pcall(toggleNpcBlack, true) end
    end
end)

-- Loop ghost map (part mới)
spawn(function()
    while task.wait(1) do
        if state.ghostMap then
            local level = state.ghostLevel
            local count = 0
            for _, v in ipairs(Workspace:GetDescendants()) do
                if count > 500 then break end
                pcall(function()
                    if v:IsA("BasePart") and not isProtected(v) and not isPartOfAnyCharacter(v) then
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

-- Anti-fire
spawn(function()
    while task.wait(0.5) do
        if state.killFire then pcall(toggleAntiFire, true) end
        if state.stopAnims then pcall(toggleStopAnims, true) end
    end
end)

spawn(function()
    while task.wait(2) do
        pcall(function() collectgarbage("collect") end)
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(2)
    for _, k in ipairs(safeKeys) do
        if state[k] then
            local fn = fnMap[k]; if fn then pcall(fn, true) end
        end
    end
    if state.ghostMap then pcall(toggleGhostMap, true) end
    if state.playerBlack then pcall(togglePlayerBlack, true) end
    if state.npcBlack then pcall(toggleNpcBlack, true) end
end)

print("👻 FIXLAG_VN GHOST loaded! Map trong suốt 40%, player/NPC đen, fix lag mạnh.")
