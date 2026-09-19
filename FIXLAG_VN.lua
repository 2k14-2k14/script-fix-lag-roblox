-- =====================================================
-- FIXLAG_VN 
-- Fix FPS + Fix xám đen + Giữ NPC
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
-- 🛡️ WHITELIST
-- =====================================================
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
        if root and p.Position.Y < root.Position.Y - 5 then return true end
        local s = p.Size
        if s.X > 100 or s.Z > 100 then return true end
    end
    return false
end

local function isNPC(model)
    if not model or model == LocalPlayer.Character then return false end
    if not model:IsA("Model") then return false end
    return model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- =====================================================
-- STATE
-- =====================================================
local state = {
    lighting=false, decals=false, effects=false, hideFar=false,
    lowQuality=false, accessories=false, npcFreeze=false, gui3d=false,
    atmosphere=false, physics=false, stripChar=false, skybox=false,
    terrain=false, killLights=false, bwMode=false,
    nametags=false, charSounds=false, forceShadow=false, removeEffects=false,
    killFire=false, debrisClean=false, textureKill=false, soundKill=false,
    -- NPC GRayscale
    npcGray=false, npcFlat=false, npcNoAnim=false,
    -- NUCLEAR
    killAllSound=false, killAllGui=false, killAllBeam=false,
    blockSpawn=false, killTools=false, stopAnims=false, killDecor2=false,
    aggressiveGC=false,
    -- ULTRA
    ultraDestroy=false, destroyOthers=false,
    killWelds=false, killHumanoids=false, massDeleteName=false,
    destroyAttachments=false, killScripts=false, unloadMeshes=false,
    killCoreGui=false, renderDistZero=false, instantGC=false,
    killAnimator=false, forceMinGraphics=false, deleteTools=false, killSoundsSvc=false,
    -- SAFE PURGE
    safePurge=false, purgeEffectsOnly=false, purgeDecalsSafe=false,
    purgeSmallPartsSafe=false, purgeByMoreNamesSafe=false,
    purgeParticleModels=false, purgeAccessoriesGlobal=false,
    -- Meta
    autoClean=false, cullDist=100, fpsTarget=60,
}

local saved = {
    decals={}, parts={}, lighting={}, accs={}, humans={},
    guis={}, atmo={}, physics={}, sky={}, lights={}, strippedChar={},
    quality=nil, nametags={}, charSounds={}, shadows={}, allEffects={},
    fires={}, textures={}, soundGroups={}, meshes={},
    nuked={}, anchored={}, allSounds={}, allGuis={}, allBeams={},
    materials={}, allTextures={}, tools={}, connections={},
    colliders={}, scripts={}, meshIds={},
    nulled={}, scripts2={}, camKids={}, playerGuis={},
    -- NPC gray
    npcColors={}, npcMaterials={}, npcAnims={},
}

-- =====================================================
-- FPS COUNTER (FIX)
-- =====================================================
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

local function getRealFPS()
    local ok, v = pcall(function() return Stats.RenderFPS:GetValue() end)
    if ok and type(v) == "number" and v > 0 and v < 1000 then return math.floor(v + 0.5) end
    ok, v = pcall(function() return Stats.FrameTime:GetValue() end)
    if ok and type(v) == "number" and v > 0 and v < 1 then return math.floor(1 / v + 0.5) end
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

local function shouldSkipPart(p, origin)
    local s = p.Size
    if s.X > 40 or s.Y > 40 or s.Z > 40 then return true end
    if isProtected(p) then return true end
    if origin and p.Position.Y < origin.Y - 3 then return true end
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
        or t:find("spark") or t:find("burn") or t:find("explosion")
end

-- =====================================================
-- 🎨 NPC GRAYSCALE — Chuyển NPC thành trắng đen
-- =====================================================
local function colorToGray(c)
    if not c then return Color3.new(0.5, 0.5, 0.5) end
    local gray = c.R * 0.299 + c.G * 0.587 + c.B * 0.114
    return Color3.new(gray, gray, gray)
end

local function toggleNpcGray(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                for _, v in ipairs(plr.Character:GetDescendants()) do
                    pcall(function()
                        if v:IsA("BasePart") then
                            -- Lưu màu gốc
                            if not v:GetAttribute("OrigColor") then
                                v:SetAttribute("OrigColor", v.Color)
                            end
                            table.insert(saved.npcColors, {obj=v, c=v.Color})
                            v.Color = colorToGray(v.Color)
                        end
                        if v:IsA("Decal") or v:IsA("Texture") then
                            if not v:GetAttribute("OrigTrans") then
                                v:SetAttribute("OrigTrans", v.Transparency)
                            end
                            table.insert(saved.npcColors, {obj=v, t=v.Transparency})
                            v.Transparency = 0.5
                        end
                        if v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") then
                            table.insert(saved.npcColors, {obj=v, t=v.Parent})
                            v.Parent = nil
                        end
                    end)
                end
            end
        end
        -- Theo dõi NPC mới spawn
        if saved.connections.npcGray then saved.connections.npcGray:Disconnect() end
        saved.connections.npcGray = Players.PlayerAdded:Connect(function(plr)
            plr.CharacterAdded:Connect(function(char)
                task.wait(2)
                if state.npcGray then
                    for _, v in ipairs(char:GetDescendants()) do
                        pcall(function()
                            if v:IsA("BasePart") then
                                table.insert(saved.npcColors, {obj=v, c=v.Color})
                                v.Color = colorToGray(v.Color)
                            end
                            if v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") then
                                table.insert(saved.npcColors, {obj=v, t=v.Parent})
                                v.Parent = nil
                            end
                        end)
                    end
                end
            end)
        end)
    else
        for _, d in ipairs(saved.npcColors) do
            pcall(function()
                if d.obj and d.obj.Parent then
                    if d.c then d.obj.Color = d.c end
                    if d.t and typeof(d.t) == "number" then d.obj.Transparency = d.t end
                    if d.t and typeof(d.t) == "Instance" then d.obj.Parent = d.t end
                end
            end)
        end
        saved.npcColors = {}
        if saved.connections.npcGray then
            saved.connections.npcGray:Disconnect()
            saved.connections.npcGray = nil
        end
    end
end

-- NPC FLAT — Material SmoothPlastic (render nhẹ hơn)
local function toggleNpcFlat(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                for _, v in ipairs(plr.Character:GetDescendants()) do
                    pcall(function()
                        if v:IsA("BasePart") and v.Material ~= Enum.Material.SmoothPlastic then
                            table.insert(saved.npcMaterials, {obj=v, m=v.Material})
                            v.Material = Enum.Material.SmoothPlastic
                        end
                        if v:IsA("Accessory") or v:IsA("Hat") then
                            table.insert(saved.npcMaterials, {obj=v, p=v.Parent})
                            v.Parent = nil
                        end
                    end)
                end
            end
        end
    else
        for _, m in ipairs(saved.npcMaterials) do
            pcall(function()
                if m.obj and m.obj.Parent then
                    if m.m then m.obj.Material = m.m end
                    if m.p then m.obj.Parent = m.p end
                end
            end)
        end
        saved.npcMaterials = {}
    end
end

-- NPC NO ANIM — Stop animation NPC
local function toggleNpcNoAnim(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    local animator = hum:FindFirstChildOfClass("Animator")
                    if animator then
                        pcall(function()
                            for _, a in ipairs(animator:GetPlayingAnimationTracks()) do
                                a:Stop()
                            end
                        end)
                    end
                end
            end
        end
        if saved.connections.npcNoAnim then saved.connections.npcNoAnim:Disconnect() end
        saved.connections.npcNoAnim = RunService.Heartbeat:Connect(function()
            if not state.npcNoAnim then return end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                    if hum then
                        local animator = hum:FindFirstChildOfClass("Animator")
                        if animator then
                            pcall(function()
                                for _, a in ipairs(animator:GetPlayingAnimationTracks()) do
                                    a:Stop()
                                end
                            end)
                        end
                    end
                end
            end
        end)
    else
        if saved.connections.npcNoAnim then
            saved.connections.npcNoAnim:Disconnect()
            saved.connections.npcNoAnim = nil
        end
    end
end

-- =====================================================
-- PRO MODULES
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

local function toggleDecals(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Decal") and not isProtected(v.Parent) then
                    table.insert(saved.decals, {obj=v, old=v.Texture}); v.Texture = ""
                end
            end)
        end
    else
        for _, d in ipairs(saved.decals) do
            pcall(function() if d.obj and d.obj.Parent then d.obj.Texture = d.old end end)
        end
        saved.decals = {}
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
                if v:IsA("BasePart") and not v:IsDescendantOf(char) and not shouldSkipPart(v, origin) then
                    if (v.Position - origin).Magnitude > state.cullDist and v.Transparency < 1 then
                        table.insert(saved.parts, {obj=v, trans=v.Transparency}); v.Transparency = 1
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
    else
        pcall(function() settings().Rendering.QualityLevel = saved.quality or Enum.QualityLevel.Automatic end)
    end
end

local function toggleAccessories(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                for _, a in ipairs(plr.Character:GetDescendants()) do
                    if a:IsA("Accessory") then
                        pcall(function()
                            table.insert(saved.accs, {obj=a, p=a.Parent}); a.Parent = nil
                        end)
                    end
                end
            end
        end
    else
        for _, a in ipairs(saved.accs) do
            pcall(function() if a.obj and a.p then a.obj.Parent = a.p end end)
        end
        saved.accs = {}
    end
end

local function toggleNpcFreeze(on)
    local origin, char = getOrigin(); if not origin then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("Humanoid") and v.Parent ~= char then
                local hrp = v.Parent:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - origin).Magnitude > 100 then
                    v.EvaluateStateMachine = not on
                end
            end
        end)
    end
end

local function toggleGui3d(on)
    local origin = getOrigin(); if not origin then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
                local ad = v.Adornee or v.Parent
                if ad and ad:IsA("BasePart") and (ad.Position - origin).Magnitude > 60 and v.Enabled and on then
                    table.insert(saved.guis, {obj=v}); v.Enabled = false
                end
            end
        end)
    end
    if not on then
        for _, g in ipairs(saved.guis) do
            pcall(function() if g.obj and g.obj.Parent then g.obj.Enabled = true end end)
        end
        saved.guis = {}
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
            if v:IsA("BasePart") and not v:IsDescendantOf(char) and not shouldSkipPart(v, origin) then
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

local function toggleStripChar(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                for _, v in ipairs(plr.Character:GetDescendants()) do
                    pcall(function()
                        if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") then
                            table.insert(saved.strippedChar, {obj=v, p=v.Parent}); v.Parent = nil
                        end
                    end)
                end
            end
        end
    else
        for _, s in ipairs(saved.strippedChar) do
            pcall(function() if s.obj and s.p then s.obj.Parent = s.p end end)
        end
        saved.strippedChar = {}
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

local function toggleBW(on)
    local old = Lighting:FindFirstChild("Potato_BW"); if old then old:Destroy() end
    if on then
        local bw = Instance.new("ColorCorrectionEffect")
        bw.Name = "Potato_BW"; bw.Saturation = -1; bw.Parent = Lighting
    end
end

local function toggleNametags(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                for _, v in ipairs(plr.Character:GetDescendants()) do
                    if v:IsA("BillboardGui") then
                        pcall(function()
                            table.insert(saved.nametags, {obj=v, e=v.Enabled}); v.Enabled = false
                        end)
                    end
                end
            end
        end
    else
        for _, n in ipairs(saved.nametags) do
            pcall(function() if n.obj and n.obj.Parent then n.obj.Enabled = n.e end end)
        end
        saved.nametags = {}
    end
end

local function toggleCharSounds(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                for _, v in ipairs(plr.Character:GetDescendants()) do
                    if v:IsA("Sound") then
                        pcall(function()
                            table.insert(saved.charSounds, {obj=v, v=v.Volume}); v.Volume = 0
                        end)
                    end
                end
            end
        end
    else
        for _, s in ipairs(saved.charSounds) do
            pcall(function() if s.obj and s.obj.Parent then s.obj.Volume = s.v end end)
        end
        saved.charSounds = {}
    end
end

local function toggleForceShadow(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") and v.CastShadow then
                    table.insert(saved.shadows, {obj=v, c=v.CastShadow}); v.CastShadow = false
                end
            end)
        end
    else
        for _, s in ipairs(saved.shadows) do
            pcall(function() if s.obj and s.obj.Parent then s.obj.CastShadow = s.c end end)
        end
        saved.shadows = {}
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
                if (v:IsA("PointLight") or v:IsA("SpotLight")) and isFireColor(v.Color) then
                    table.insert(saved.fires, {obj=v, k="Enabled", o=v.Enabled})
                    v.Enabled = false; v.Brightness = 0
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

local function toggleRemoveEffects(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Highlight") or v:IsA("ParticleEmitter") or v:IsA("Trail")
                   or v:IsA("Beam") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles")
                   or v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
                    table.insert(saved.allEffects, {obj=v, k="Enabled", o=v.Enabled}); v.Enabled = false
                end
                if v:IsA("Explosion") then v:Destroy() end
            end)
        end
        pcall(toggleAntiFire, true)
    else
        for _, e in ipairs(saved.allEffects) do
            pcall(function() if e.obj and e.obj.Parent then e.obj[e.k] = e.o end end)
        end
        saved.allEffects = {}
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
            end)
        end)
    else
        if saved.connections.debris then saved.connections.debris:Disconnect(); saved.connections.debris = nil end
    end
end

local function toggleTextureKill(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Texture") then
                    table.insert(saved.textures, {obj=v, k="Transparency", o=v.Transparency}); v.Transparency = 1
                end
            end)
        end
    else
        for _, t in ipairs(saved.textures) do
            pcall(function() if t.obj and t.obj.Parent then t.obj[t.k] = t.o end end)
        end
        saved.textures = {}
    end
end

local function toggleSoundKill(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Sound") then
                    table.insert(saved.soundGroups, {obj=v, v=v.Volume}); v.Volume = 0
                end
            end)
        end
    else
        for _, s in ipairs(saved.soundGroups) do
            pcall(function() if s.obj and s.obj.Parent then s.obj.Volume = s.v end end)
        end
        saved.soundGroups = {}
    end
end

local function toggleMeshKill(on)
    if not on then return end
    local char = LocalPlayer.Character
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("MeshPart") and not (char and v:IsDescendantOf(char)) and not isProtected(v) then
                v:Destroy()
            end
        end)
    end
end

-- =====================================================
-- NUCLEAR / ULTRA
-- =====================================================
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
                    table.insert(saved.allGuis, {obj=v, e=v.Enabled}); v.Enabled = false
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
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                   or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then v.Enabled = false end
                if v:IsA("BillboardGui") or v:IsA("SurfaceGui") then v.Enabled = false end
                if v:IsA("Explosion") then v:Destroy() end
                if v:IsA("Sound") then v.Volume = 0 end
                if v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then v.Enabled = false end
            end)
        end)
    else
        if saved.connections.block then saved.connections.block:Disconnect(); saved.connections.block = nil end
    end
end

local function toggleKillTools(on)
    if on then
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            for _, v in ipairs(bp:GetChildren()) do
                pcall(function()
                    if v:IsA("Tool") then
                        table.insert(saved.tools, {obj=v, p=v.Parent}); v.Parent = nil
                    end
                end)
            end
        end
    else
        for _, t in ipairs(saved.tools) do
            pcall(function() if t.obj then t.obj.Parent = t.p end end)
        end
        saved.tools = {}
    end
end

local function toggleStopAnims(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Animator") then
                    for _, a in ipairs(v:GetPlayingAnimationTracks()) do a:Stop() end
                end
            end)
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

local function toggleUltraDestroy(on)
    if on then
        local char = LocalPlayer.Character
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if (v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                    or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles")
                    or v:IsA("Highlight"))
                   and not (char and v:IsDescendantOf(char)) then
                    v:Destroy()
                end
            end)
        end
    end
end

local function toggleDestroyOthers(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                pcall(function()
                    table.insert(saved.nuked, {c=plr.Character, p=plr.Character.Parent})
                    plr.Character.Parent = nil
                end)
            end
        end
    else
        for _, n in ipairs(saved.nuked) do
            pcall(function() if n.c then n.c.Parent = n.p or Workspace end end)
        end
        saved.nuked = {}
    end
end

local function toggleKillWelds(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Weld") or v:IsA("Motor") or v:IsA("Motor6D") then
                    v:Destroy()
                end
            end)
        end
    end
end

local function toggleKillHumanoids(on)
    if not on then return end
    local origin, char = getOrigin(); if not origin then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("Humanoid") and v.Parent ~= char and v.Health > 0 then
                local hrp = v.Parent:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - origin).Magnitude > 50 then
                    v.Health = 0
                end
            end
        end)
    end
end

local function toggleMassDeleteName(on)
    if on then
        local patterns = {"wall","tree","bush","rock","grass","flower","decor",
                          "detail","plant","fence","prop","cloud","poster",
                          "sign","banner","particle"}
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") and not isProtected(v) then
                    local n = v.Name:lower()
                    for _, p in ipairs(patterns) do
                        if n:find(p) then v:Destroy(); break end
                    end
                end
            end)
        end
    end
end

local function toggleDestroyAttachments(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Attachment") or v:IsA("RopeConstraint")
                   or v:IsA("SpringConstraint") or v:IsA("RodConstraint") then
                    v:Destroy()
                end
            end)
        end
    end
end

local function toggleKillScripts(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Script") and v.Enabled then
                    table.insert(saved.scripts, {obj=v}); v.Enabled = false
                end
            end)
        end
    else
        for _, s in ipairs(saved.scripts) do
            pcall(function() if s.obj and s.obj.Parent then s.obj.Enabled = true end end)
        end
        saved.scripts = {}
    end
end

local function toggleUnloadMeshes(on)
    if not on then return end
    local char = LocalPlayer.Character
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("MeshPart") and not (char and v:IsDescendantOf(char)) and not isProtected(v) then
                v:Destroy()
            end
        end)
    end
end

local function toggleKillCoreGui(on)
    if on then
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
        end)
    else
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
        end)
    end
end

local function toggleRenderDistZero(on)
    if on then
        pcall(function() Cam.FarPlane = 0 end)
    else
        pcall(function() Cam.FarPlane = 100000 end)
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

local function toggleKillAnimator(on)
    if on then
        local char = LocalPlayer.Character
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Animator") and not (char and v:IsDescendantOf(char)) then
                    v:Destroy()
                end
            end)
        end
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

local function toggleDeleteTools(on)
    if on then
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            for _, v in ipairs(bp:GetChildren()) do
                pcall(function() if v:IsA("Tool") then v:Destroy() end end)
            end
        end
    end
end

local function toggleKillSoundsSvc(on)
    if on then
        pcall(function() SoundSvc.AmbientReverb = Enum.ReverbType.NoReverb end)
    end
end

-- =====================================================
-- SAFE PURGE
-- =====================================================
local function togglePurgeEffectsOnly(on)
    if not on then return end
    local char = LocalPlayer.Character
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if (v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles")
                or v:IsA("Highlight") or v:IsA("Explosion"))
               and not (char and v:IsDescendantOf(char)) then
                v:Destroy()
            end
        end)
    end
end

local function togglePurgeDecalsSafe(on)
    if not on then return end
    local char = LocalPlayer.Character
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if (v:IsA("Decal") or v:IsA("Texture"))
               and not (char and v:IsDescendantOf(char)) then
                local par = v.Parent
                if par and par:IsA("BasePart") and not isProtected(par) then
                    par:Destroy()
                else
                    v:Destroy()
                end
            end
        end)
    end
end

local function togglePurgeSmallPartsSafe(on)
    if not on then return end
    local char = LocalPlayer.Character
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart") and not (char and v:IsDescendantOf(char)) and not isProtected(v) then
                local s = v.Size
                if s.X < 0.5 and s.Y < 0.5 and s.Z < 0.5 then v:Destroy() end
            end
        end)
    end
end

local function togglePurgeByMoreNamesSafe(on)
    if not on then return end
    local char = LocalPlayer.Character
    local patterns = {"railing","lamp","street","crate","barrel","box","chest",
                      "window","roof","pillar","column","stairs","step",
                      "cable","wire","rope","pipe","brick","tile","panel",
                      "board","plank","ladder","table","chair","bench",
                      "statue","monument","poster","banner"}
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart") and not (char and v:IsDescendantOf(char)) and not isProtected(v) then
                local n = v.Name:lower()
                for _, p in ipairs(patterns) do
                    if n:find(p) then v:Destroy(); break end
                end
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
                if anc and anc:IsA("Model") and not isProtected(anc) and not isNPC(anc) then
                    table.insert(toDestroy, anc)
                end
            end
        end)
    end
    for _, m in ipairs(toDestroy) do
        pcall(function() m:Destroy() end)
    end
end

local function togglePurgeAccessoriesGlobal(on)
    if not on then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("Accessory") or v:IsA("Hat") then
                v:Destroy()
            end
        end)
    end
end

local function toggleSafePurgeAll(on)
    if not on then return end
    local char = LocalPlayer.Character
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if (v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles"))
               and not (char and v:IsDescendantOf(char)) then
                v:Destroy()
            end
            if v:IsA("Explosion") then v:Destroy() end
            if (v:IsA("Decal") or v:IsA("Texture"))
               and not (char and v:IsDescendantOf(char))
               and not isProtected(v.Parent) then
                v:Destroy()
            end
            if v:IsA("BasePart") and not (char and v:IsDescendantOf(char)) and not isProtected(v) then
                local s = v.Size
                if s.X < 0.5 and s.Y < 0.5 and s.Z < 0.5 then v:Destroy() end
            end
        end)
    end
end

-- =====================================================
-- APPLY / OFF
-- =====================================================
local safeKeys = {
    "lighting","decals","effects","hideFar","lowQuality","accessories",
    "npcFreeze","gui3d","atmosphere","physics","skybox","terrain",
    "killLights","nametags","charSounds","forceShadow","removeEffects",
    "killFire","debrisClean","textureKill","soundKill","meshKill",
    "killAllSound","killAllGui","killAllBeam",
    "blockSpawn","killTools","stopAnims","killDecor2","aggressiveGC",
    "ultraDestroy","destroyOthers",
    "killWelds","killHumanoids","massDeleteName",
    "destroyAttachments","killScripts","unloadMeshes","killCoreGui",
    "renderDistZero","instantGC","killAnimator",
    "forceMinGraphics","deleteTools","killSoundsSvc",
    "safePurge","purgeEffectsOnly","purgeDecalsSafe",
    "purgeSmallPartsSafe","purgeByMoreNamesSafe",
    "purgeParticleModels","purgeAccessoriesGlobal",
    -- NPC (giữ NPC, chỉ đổi màu)
    "npcGray","npcFlat","npcNoAnim",
}

local fnMap = {
    lighting=toggleLighting, decals=toggleDecals, effects=toggleEffects,
    hideFar=toggleHideFar, lowQuality=toggleLowQuality, accessories=toggleAccessories,
    npcFreeze=toggleNpcFreeze, gui3d=toggleGui3d, atmosphere=toggleAtmosphere,
    physics=togglePhysics, skybox=toggleSkybox, terrain=toggleTerrain,
    killLights=toggleKillLights, nametags=toggleNametags, charSounds=toggleCharSounds,
    forceShadow=toggleForceShadow, removeEffects=toggleRemoveEffects,
    killFire=toggleAntiFire, debrisClean=toggleDebrisClean, textureKill=toggleTextureKill,
    soundKill=toggleSoundKill, meshKill=toggleMeshKill,
    killAllSound=toggleKillAllSound, killAllGui=toggleKillAllGui, killAllBeam=toggleKillAllBeam,
    blockSpawn=toggleBlockSpawn, killTools=toggleKillTools, stopAnims=toggleStopAnims,
    killDecor2=toggleKillDecor2, aggressiveGC=toggleAggressiveGC,
    ultraDestroy=toggleUltraDestroy, destroyOthers=toggleDestroyOthers,
    killWelds=toggleKillWelds, killHumanoids=toggleKillHumanoids, massDeleteName=toggleMassDeleteName,
    destroyAttachments=toggleDestroyAttachments, killScripts=toggleKillScripts,
    unloadMeshes=toggleUnloadMeshes, killCoreGui=toggleKillCoreGui,
    renderDistZero=toggleRenderDistZero, instantGC=toggleInstantGC,
    killAnimator=toggleKillAnimator, forceMinGraphics=toggleForceMinGraphics,
    deleteTools=toggleDeleteTools, killSoundsSvc=toggleKillSoundsSvc,
    safePurge=toggleSafePurgeAll, purgeEffectsOnly=togglePurgeEffectsOnly,
    purgeDecalsSafe=togglePurgeDecalsSafe, purgeSmallPartsSafe=togglePurgeSmallPartsSafe,
    purgeByMoreNamesSafe=togglePurgeByMoreNamesSafe,
    purgeParticleModels=togglePurgeParticleModels,
    purgeAccessoriesGlobal=togglePurgeAccessoriesGlobal,
    -- NPC
    npcGray=toggleNpcGray, npcFlat=toggleNpcFlat, npcNoAnim=toggleNpcNoAnim,
}

local function applyAll(on)
    for _, k in ipairs(safeKeys) do state[k] = on end
    for _, k in ipairs(safeKeys) do
        local fn = fnMap[k]; if fn then pcall(fn, on) end
    end
end

local function offAll()
    applyAll(false)
    pcall(toggleStripChar, false); pcall(toggleBW, false)
    state.stripChar = false; state.bwMode = false
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
fpsFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
fpsFrame.BackgroundTransparency = 0.1
fpsFrame.BorderSizePixel = 0; fpsFrame.Active = true; fpsFrame.Draggable = true
fpsFrame.Parent = gui
Instance.new("UICorner", fpsFrame).CornerRadius = UDim.new(0, 10)
local fpsStroke = Instance.new("UIStroke", fpsFrame)
fpsStroke.Color = Color3.fromRGB(0, 220, 90); fpsStroke.Thickness = 1.5

local fpsText = Instance.new("TextLabel")
fpsText.Size = UDim2.new(1, -10, 1, -10); fpsText.Position = UDim2.new(0, 5, 0, 5)
fpsText.BackgroundTransparency = 1; fpsText.Font = Enum.Font.Code; fpsText.TextSize = 14
fpsText.TextColor3 = Color3.fromRGB(0, 255, 100)
fpsText.TextXAlignment = Enum.TextXAlignment.Left
fpsText.TextYAlignment = Enum.TextYAlignment.Top
fpsText.Text = "FPS: --\nPING: --\nDIST: 100 | LOCK: 60"
fpsText.Parent = fpsFrame

spawn(function()
    while task.wait(0.25) do
        local f = getRealFPS()
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
menu.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
menu.BorderSizePixel = 0; menu.Active = true; menu.Draggable = true; menu.Parent = gui
Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 14)
local mStroke = Instance.new("UIStroke", menu)
mStroke.Color = Color3.fromRGB(0, 255, 100); mStroke.Thickness = 2

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 34); title.Position = UDim2.new(0, 10, 0, 3)
title.BackgroundTransparency = 1; title.Text = "🎨 FIXLAG_VN GRAYSCALE"
title.Font = Enum.Font.GothamBold; title.TextSize = 14
title.TextColor3 = Color3.fromRGB(0, 255, 100)
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
scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 255, 100)
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
        btn.BackgroundColor3 = on and Color3.fromRGB(30, 130, 70) or (color or Color3.fromRGB(45, 45, 60))
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

header("🎨 NPC (GIỮ LẠI - CHỈ ĐỔI MÀU)", Color3.fromRGB(200, 200, 200))
add("🎨 NPC GRAYSCALE (trắng đen)", "npcGray",   toggleNpcGray,   Color3.fromRGB(60, 60, 60))
add("🎨 NPC FLAT (bỏ phụ kiện)",    "npcFlat",   toggleNpcFlat,   Color3.fromRGB(60, 60, 60))
add("🎨 NPC NO ANIM (đứng im)",     "npcNoAnim", toggleNpcNoAnim, Color3.fromRGB(60, 60, 60))

header("🛡️ SAFE PURGE", Color3.fromRGB(0, 255, 100))
add("🛡️ SAFE PURGE ALL",              "safePurge",              toggleSafePurgeAll,              Color3.fromRGB(0, 80, 30))
add("🌪️ PURGE EFFECTS ONLY",          "purgeEffectsOnly",       togglePurgeEffectsOnly,          Color3.fromRGB(0, 80, 30))
add("🌪️ PURGE DECALS (an toàn)",      "purgeDecalsSafe",        togglePurgeDecalsSafe,           Color3.fromRGB(0, 80, 30))
add("🌪️ PURGE SMALL PARTS (<0.5)",    "purgeSmallPartsSafe",    togglePurgeSmallPartsSafe,       Color3.fromRGB(0, 80, 30))
add("🌪️ PURGE BY MORE NAMES (safe)",  "purgeByMoreNamesSafe",   togglePurgeByMoreNamesSafe,      Color3.fromRGB(0, 80, 30))
add("🌪️ PURGE PARTICLE MODELS",       "purgeParticleModels",    togglePurgeParticleModels,       Color3.fromRGB(0, 80, 30))
add("🌪️ PURGE ACCESSORIES GLOBAL",    "purgeAccessoriesGlobal", togglePurgeAccessoriesGlobal,    Color3.fromRGB(0, 80, 30))

header("💀 ULTRA", Color3.fromRGB(255, 50, 50))
add("💀 ULTRA DESTROY effects", "ultraDestroy", toggleUltraDestroy, Color3.fromRGB(70, 10, 10))
add("💀 DESTROY OTHERS (Parent=nil)", "destroyOthers", toggleDestroyOthers, Color3.fromRGB(70, 10, 10))
add("💀 KILL WELDS/MOTORS",      "killWelds",     toggleKillWelds,     Color3.fromRGB(70, 10, 10))
add("💀 KILL HUMANOIDS XA",      "killHumanoids", toggleKillHumanoids, Color3.fromRGB(70, 10, 10))
add("💀 MASS DELETE BY NAME",    "massDeleteName", toggleMassDeleteName, Color3.fromRGB(70, 10, 10))
add("💀 DESTROY ATTACHMENTS",    "destroyAttachments", toggleDestroyAttachments, Color3.fromRGB(70, 10, 10))
add("💀 KILL SCRIPTS",           "killScripts",   toggleKillScripts,   Color3.fromRGB(70, 10, 10))
add("💀 UNLOAD MESHES",          "unloadMeshes",  toggleUnloadMeshes,  Color3.fromRGB(70, 10, 10))
add("💀 KILL COREGUI (Chat/BP)", "killCoreGui",   toggleKillCoreGui,   Color3.fromRGB(70, 10, 10))
add("💀 RENDER DIST = 0",        "renderDistZero", toggleRenderDistZero, Color3.fromRGB(70, 10, 10))
add("💀 INSTANT GC",             "instantGC",     toggleInstantGC,     Color3.fromRGB(70, 10, 10))
add("💀 KILL ANIMATOR",          "killAnimator",  toggleKillAnimator,  Color3.fromRGB(70, 10, 10))
add("💀 FORCE MIN GRAPHICS",     "forceMinGraphics", toggleForceMinGraphics, Color3.fromRGB(70, 10, 10))
add("💀 DELETE TOOLS",           "deleteTools",   toggleDeleteTools,   Color3.fromRGB(70, 10, 10))
add("💀 KILL SOUNDS SERVICE",    "killSoundsSvc", toggleKillSoundsSvc, Color3.fromRGB(70, 10, 10))

header("☢️ NUCLEAR", Color3.fromRGB(255, 150, 80))
add("☢️ KILL ALL SOUND", "killAllSound", toggleKillAllSound, Color3.fromRGB(80, 20, 20))
add("☢️ KILL ALL GUI 3D", "killAllGui", toggleKillAllGui, Color3.fromRGB(80, 20, 20))
add("☢️ KILL ALL BEAM",   "killAllBeam", toggleKillAllBeam, Color3.fromRGB(80, 20, 20))
add("☢️ BLOCK SPAWN FX",  "blockSpawn", toggleBlockSpawn, Color3.fromRGB(80, 20, 20))
add("☢️ KILL TOOLS",      "killTools",  toggleKillTools,  Color3.fromRGB(80, 20, 20))
add("☢️ STOP ANIMATIONS", "stopAnims",  toggleStopAnims,  Color3.fromRGB(80, 20, 20))
add("☢️ KILL TERRAIN",    "killDecor2", toggleKillDecor2, Color3.fromRGB(80, 20, 20))
add("☢️ AGGRESSIVE GC",   "aggressiveGC", toggleAggressiveGC, Color3.fromRGB(80, 20, 20))

header("🔥 ANTI-FIRE", Color3.fromRGB(255, 150, 80))
add("🔥 DIỆT LỬA MỌI MÀU", "killFire", toggleAntiFire, Color3.fromRGB(100, 40, 20))
add("🧹 DỌN RÁC EFFECT",   "debrisClean", toggleDebrisClean, Color3.fromRGB(100, 40, 20))

header("⚙️ PRO", Color3.fromRGB(100, 200, 255))
add("Tắt đèn & hậu kỳ", "lighting", toggleLighting)
add("Xóa Decal", "decals", toggleDecals)
add("Tắt hạt & âm thanh", "effects", toggleEffects)
add("🖼 Xóa Texture", "textureKill", toggleTextureKill)
add("🔇 Sound Killer", "soundKill", toggleSoundKill)
add("📦 Xóa Mesh Texture", "meshKill", toggleMeshKill)
add("Ẩn vật thể xa", "hideFar", toggleHideFar)
add("Chất lượng thấp nhất", "lowQuality", toggleLowQuality)
add("Xóa phụ kiện người khác", "accessories", toggleAccessories)
add("Đóng băng NPC xa", "npcFreeze", toggleNpcFreeze)
add("Tắt GUI 3D xa", "gui3d", toggleGui3d)
add("Tắt Atmosphere", "atmosphere", toggleAtmosphere)
add("Giảm Physics xa", "physics", togglePhysics)
add("⚫ Strip nhân vật", "stripChar", toggleStripChar)
add("⚫ Xóa Skybox", "skybox", toggleSkybox)
add("⚫ Xóa Terrain", "terrain", toggleTerrain)
add("⚫ Kill Light", "killLights", toggleKillLights)
add("⚫ TRẮNG ĐEN toàn màn hình", "bwMode", toggleBW)
add("✦ Tắt Nametag", "nametags", toggleNametags)
add("✦ Tắt âm thanh NV", "charSounds", toggleCharSounds)
add("✦ Tắt Shadow", "forceShadow", toggleForceShadow)
add("🔥 XÓA MỌI EFFECT", "removeEffects", toggleRemoveEffects)

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
distLabel.BackgroundTransparency = 1; distLabel.Text = "Cull Distance: 100"
distLabel.Font = Enum.Font.GothamBold; distLabel.TextSize = 11
distLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
distLabel.TextXAlignment = Enum.TextXAlignment.Left; distLabel.Parent = scroll

local sliderBg = Instance.new("Frame")
sliderBg.Size = UDim2.new(1, -20, 0, 8); sliderBg.Position = UDim2.new(0, 10, 0, y + 28)
sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60); sliderBg.BorderSizePixel = 0
sliderBg.Parent = scroll
Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0, 4)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.15, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(0, 200, 100); sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 4)

local sliderBtn = Instance.new("TextButton")
sliderBtn.Size = UDim2.new(0, 16, 0, 16); sliderBtn.Position = UDim2.new(0.15, -8, 0, -4)
sliderBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 150); sliderBtn.Text = ""
sliderBtn.Parent = sliderBg
Instance.new("UICorner", sliderBtn).CornerRadius = UDim.new(1, 0)

y = y + 42

local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, -20, 0, 30); autoBtn.Position = UDim2.new(0, 10, 0, y)
autoBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
autoBtn.Text = "○ AUTO CLEAN (0.5s)"; autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 10; autoBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
autoBtn.Parent = scroll
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 8)
autoBtn.MouseButton1Click:Connect(function()
    state.autoClean = not state.autoClean; local on = state.autoClean
    autoBtn.BackgroundColor3 = on and Color3.fromRGB(30, 130, 70) or Color3.fromRGB(45, 45, 60)
    autoBtn.Text = (on and "● " or "○ ") .. "AUTO CLEAN (0.5s)"
end)

y = y + 35

-- NPC GRAY BUTTON
local grayBtn = Instance.new("TextButton")
grayBtn.Size = UDim2.new(1, -20, 0, 80); grayBtn.Position = UDim2.new(0, 10, 0, y)
grayBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
grayBtn.Text = "🎨 NPC GRAYSCALE\n(GIỮ NPC, CHỈ TRẮNG ĐEN)"
grayBtn.Font = Enum.Font.GothamBold; grayBtn.TextSize = 14
grayBtn.TextColor3 = Color3.fromRGB(255, 255, 255); grayBtn.Parent = scroll
Instance.new("UICorner", grayBtn).CornerRadius = UDim.new(0, 10)
local grayStroke = Instance.new("UIStroke", grayBtn)
grayStroke.Color = Color3.fromRGB(255, 255, 255); grayStroke.Thickness = 3

grayBtn.MouseButton1Click:Connect(function()
    state.npcGray = not state.npcGray
    if state.npcGray then
        pcall(toggleNpcGray, true)
        pcall(toggleNpcFlat, true)
        state.npcFlat = true
        pcall(toggleNpcNoAnim, true)
        state.npcNoAnim = true
        grayBtn.Text = "🎨 NPC GRAYSCALE\n(ĐANG ÁP DỤNG...)"
        grayBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
        for _, k in ipairs({"npcGray","npcFlat","npcNoAnim"}) do
            local d = buttons[k]
            if d then
                d.btn.BackgroundColor3 = Color3.fromRGB(30, 130, 70)
                d.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                d.btn.Text = "● " .. d.label
            end
        end
    else
        pcall(toggleNpcGray, false)
        pcall(toggleNpcFlat, false)
        pcall(toggleNpcNoAnim, false)
        state.npcFlat = false
        state.npcNoAnim = false
        grayBtn.Text = "🎨 NPC GRAYSCALE\n(GIỮ NPC, CHỈ TRẮNG ĐEN)"
        grayBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        for _, k in ipairs({"npcGray","npcFlat","npcNoAnim"}) do
            local d = buttons[k]
            if d then
                d.btn.BackgroundColor3 = d.color or Color3.fromRGB(45, 45, 60)
                d.btn.TextColor3 = Color3.fromRGB(200, 200, 200)
                d.btn.Text = "○ " .. d.label
            end
        end
    end
end)

y = y + 86

local allBtn = Instance.new("TextButton")
allBtn.Size = UDim2.new(1, -20, 0, 36); allBtn.Position = UDim2.new(0, 10, 0, y)
allBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 50)
allBtn.Text = "🔥 BẬT TẤT CẢ (trừ NPC xóa)"
allBtn.Font = Enum.Font.GothamBold; allBtn.TextSize = 11
allBtn.TextColor3 = Color3.fromRGB(255, 255, 255); allBtn.Parent = scroll
Instance.new("UICorner", allBtn).CornerRadius = UDim.new(0, 10)
allBtn.MouseButton1Click:Connect(function()
    -- Không bật destroyOthers/destroyNPCs
    state.destroyOthers = false
    applyAll(true)
    state.destroyOthers = false  -- Đảm bảo không xóa player khác
    state.autoClean = true
    state.npcGray = true
    pcall(toggleNpcGray, true)
    pcall(toggleNpcFlat, true)
    pcall(toggleNpcNoAnim, true)
    state.npcFlat = true
    state.npcNoAnim = true
    autoBtn.BackgroundColor3 = Color3.fromRGB(30, 130, 70)
    autoBtn.Text = "● AUTO CLEAN (0.5s)"
    grayBtn.Text = "🎨 NPC GRAYSCALE\n(ĐANG ÁP DỤNG...)"
    grayBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    for k, data in pairs(buttons) do
        if state[k] then
            data.btn.BackgroundColor3 = Color3.fromRGB(30, 130, 70)
            data.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            data.btn.Text = "● " .. data.label
        end
    end
end)

y = y + 42

local offAllBtn = Instance.new("TextButton")
offAllBtn.Size = UDim2.new(1, -20, 0, 36); offAllBtn.Position = UDim2.new(0, 10, 0, y)
offAllBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 20)
offAllBtn.Text = "⏹ TẮT TẤT CẢ"
offAllBtn.Font = Enum.Font.GothamBold; offAllBtn.TextSize = 12
offAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255); offAllBtn.Parent = scroll
Instance.new("UICorner", offAllBtn).CornerRadius = UDim.new(0, 10)
offAllBtn.MouseButton1Click:Connect(function()
    offAll(); state.autoClean = false
    state.npcGray = false; state.npcFlat = false; state.npcNoAnim = false
    pcall(toggleNpcGray, false)
    pcall(toggleNpcFlat, false)
    pcall(toggleNpcNoAnim, false)
    autoBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    autoBtn.Text = "○ AUTO CLEAN (0.5s)"
    grayBtn.Text = "🎨 NPC GRAYSCALE\n(GIỮ NPC, CHỈ TRẮNG ĐEN)"
    grayBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
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
    end
end)
RunService.RenderStepped:Connect(function()
    if draggingDist then
        local mouse = LocalPlayer:GetMouse()
        local relX = math.clamp((mouse.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        sliderFill.Size = UDim2.new(relX, 0, 1, 0)
        sliderBtn.Position = UDim2.new(relX, -8, 0, -4)
        state.cullDist = math.floor(30 + relX * 370)
        distLabel.Text = "Cull Distance: " .. state.cullDist
    end
end)

-- LOOPS
spawn(function()
    while task.wait(0.5) do
        if state.autoClean then
            for _, v in ipairs(Workspace:GetDescendants()) do
                pcall(function()
                    if v:IsA("ParticleEmitter") or v:IsA("Trail")
                       or v:IsA("Beam") or v:IsA("Fire") or v:IsA("Smoke") then
                        v.Enabled = false
                    end
                    if v:IsA("Explosion") then v:Destroy() end
                end)
            end
            collectgarbage("collect")
        end
        -- Áp dụng grayscale NPC liên tục
        if state.npcGray then
            pcall(toggleNpcGray, true)
        end
    end
end)

spawn(function()
    while task.wait(0.5) do
        if state.killFire then pcall(toggleAntiFire, true) end
        if state.stopAnims then pcall(toggleStopAnims, true) end
        if state.killAnimator then pcall(toggleKillAnimator, true) end
        if state.npcNoAnim then pcall(toggleNpcNoAnim, true) end
    end
end)

spawn(function()
    while task.wait(1) do
        if state.hideFar then
            local origin, char = getOrigin()
            if origin and char then
                for i = #saved.parts, 1, -1 do
                    local p = saved.parts[i]
                    pcall(function()
                        if p.obj and p.obj.Parent then
                            if (p.obj.Position - origin).Magnitude < state.cullDist - 30 then
                                p.obj.Transparency = p.trans
                                table.remove(saved.parts, i)
                            end
                        else
                            table.remove(saved.parts, i)
                        end
                    end)
                end
                for _, v in ipairs(Workspace:GetDescendants()) do
                    pcall(function()
                        if v:IsA("BasePart") and not v:IsDescendantOf(char)
                           and not shouldSkipPart(v, origin) then
                            if (v.Position - origin).Magnitude > state.cullDist
                               and v.Transparency < 1 then
                                table.insert(saved.parts, {obj=v, trans=v.Transparency})
                                v.Transparency = 1
                            end
                        end
                    end)
                end
            end
        end
        if state.npcFreeze then pcall(toggleNpcFreeze, true) end
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
end)

print("🎨 FIXLAG_VN GRAYSCALE loaded! NPC giữ nguyên + chỉ trắng đen. FPS fix OK.")
