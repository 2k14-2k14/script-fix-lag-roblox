-- =====================================================
-- FIXLAG_VN
-- Menu scroll + FPS lock preset 45/60/90 + 20 module tối ưu
-- =====================================================
local Lighting    = game:GetService("Lighting")
local Workspace   = game:GetService("Workspace")
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Stats       = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

for _, v in ipairs(game.CoreGui:GetChildren()) do
    if v.Name == "FIXLAG_VN" then v:Destroy() end
end

-- =====================================================
-- STATE
-- =====================================================
local state = {
    lighting=false, decals=false, effects=false, hideFar=false,
    lowQuality=false, accessories=false, npcFreeze=false, gui3d=false,
    atmosphere=false, physics=false, stripChar=false, skybox=false,
    terrain=false, animation=false, killLights=false, bwMode=false,
    nametags=false, charSounds=false, forceShadow=false,
    removeEffects=false,
    autoClean=false, cullDist=200, fpsTarget=60,
}

local saved = {
    decals={}, sounds={}, parts={}, lighting={}, accs={}, humans={},
    guis={}, atmo={}, physics={}, sky={}, lights={}, strippedChar={},
    quality=nil, nametags={}, charSounds={}, shadows={}, allEffects={},
}

-- =====================================================
-- FPS + PING
-- =====================================================
local fpsFallback, frames, startTime, lastCall = 0, 0, os.clock(), 0
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    if now - lastCall < 0.001 then return end
    lastCall = now
    frames = frames + 1
    if now - startTime >= 1 then
        fpsFallback = math.floor(frames / (now - startTime) + 0.5)
        frames, startTime = 0, now
    end
end)

local function getRealFPS()
    local ok, v = pcall(function() return Stats.RenderFPS:GetValue() end)
    if ok and type(v) == "number" and v > 0 and v < 1000 then return math.floor(v + 0.5) end
    ok, v = pcall(function() return Stats.FrameTime:GetValue() end)
    if ok and type(v) == "number" and v > 0 and v < 1 then return math.floor(1/v + 0.5) end
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
    local n = p.Name:lower()
    if n:find("baseplate") or n:find("ground") or n:find("floor")
       or n:find("platform") or n:find("spawn") or n:find("terrain") then
        return true
    end
    if origin and p.Position.Y < origin.Y - 3 then return true end
    if p.Anchored and s.Y > 10 then return true end
    return false
end

-- =====================================================
-- 1. LIGHTING
-- =====================================================
local function toggleLighting(on)
    if on then
        saved.lighting = {
            GlobalShadows = Lighting.GlobalShadows,
            EnvDiffuse = Lighting.EnvironmentDiffuseScale,
            EnvSpecular = Lighting.EnvironmentSpecularScale,
            Brightness = Lighting.Brightness,
            OutdoorAmbient = Lighting.OutdoorAmbient,
        }
        Lighting.GlobalShadows = false
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        Lighting.Brightness = 1
        Lighting.OutdoorAmbient = Color3.fromRGB(80,80,80)
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") and not v:IsA("ColorCorrectionEffect") then
                v.Enabled = false
            end
        end
    else
        if saved.lighting.GlobalShadows ~= nil then
            Lighting.GlobalShadows = saved.lighting.GlobalShadows
            Lighting.EnvironmentDiffuseScale = saved.lighting.EnvDiffuse
            Lighting.EnvironmentSpecularScale = saved.lighting.EnvSpecular
            Lighting.Brightness = saved.lighting.Brightness
            Lighting.OutdoorAmbient = saved.lighting.OutdoorAmbient
        end
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") then v.Enabled = true end
        end
    end
end

-- 2. DECALS
local function toggleDecals(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Decal") then
                    table.insert(saved.decals, {obj = v, old = v.Texture})
                    v.Texture = ""
                end
            end)
        end
    else
        for _, d in ipairs(saved.decals) do
            pcall(function()
                if d.obj and d.obj.Parent then d.obj.Texture = d.old end
            end)
        end
        saved.decals = {}
    end
end

-- 3. EFFECTS
local function toggleEffects(on)
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
               or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                v.Enabled = not on
            end
            if on and v:IsA("Sound") then
                table.insert(saved.sounds, {obj = v, vol = v.Volume})
                v.Volume = 0
            end
        end)
    end
    if not on then
        for _, s in ipairs(saved.sounds) do
            pcall(function()
                if s.obj and s.obj.Parent then s.obj.Volume = s.vol end
            end)
        end
        saved.sounds = {}
    end
end

-- 4. HIDE FAR
local function hideFarPass()
    local origin, char = getOrigin()
    if not origin then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart")
               and not v:IsDescendantOf(char)
               and not shouldSkipPart(v, origin) then
                local dist = (v.Position - origin).Magnitude
                if dist > state.cullDist and v.Transparency < 1 then
                    table.insert(saved.parts, {
                        obj = v, trans = v.Transparency, shadow = v.CastShadow,
                    })
                    v.Transparency = 1
                    v.CastShadow = false
                end
            end
        end)
    end
end

local function toggleHideFar(on)
    if on then
        hideFarPass()
    else
        for _, p in ipairs(saved.parts) do
            pcall(function()
                if p.obj and p.obj.Parent then
                    p.obj.Transparency = p.trans
                    p.obj.CastShadow = p.shadow
                end
            end)
        end
        saved.parts = {}
    end
end

-- 5. QUALITY
local function toggleLowQuality(on)
    local ok, cur = pcall(function() return settings().Rendering.QualityLevel end)
    if on then
        saved.quality = ok and cur or Enum.QualityLevel.Automatic
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    else
        settings().Rendering.QualityLevel = saved.quality or Enum.QualityLevel.Automatic
    end
end

-- 6. ACCESSORIES
local function toggleAccessories(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                for _, acc in ipairs(plr.Character:GetDescendants()) do
                    if acc:IsA("Accessory") or acc:IsA("Hat") then
                        pcall(function()
                            table.insert(saved.accs, {obj = acc, parent = acc.Parent})
                            acc.Parent = nil
                        end)
                    end
                end
            end
        end
    else
        for _, a in ipairs(saved.accs) do
            pcall(function()
                if a.obj and a.parent then a.obj.Parent = a.parent end
            end)
        end
        saved.accs = {}
    end
end

-- 7. NPC FREEZE
local function toggleNpcFreeze(on)
    local origin, char = getOrigin()
    if not origin then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("Humanoid") and v.Parent ~= char then
                local hrp = v.Parent:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - origin).Magnitude > 100 then
                    if on then v.EvaluateStateMachine = false
                    else v.EvaluateStateMachine = true end
                end
            end
        end)
    end
end

-- 8. GUI 3D
local function toggleGui3d(on)
    local origin = getOrigin()
    if not origin then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
                local adornee = v.Adornee or v.Parent
                if adornee and adornee:IsA("BasePart")
                   and (adornee.Position - origin).Magnitude > 60 and v.Enabled then
                    if on then
                        table.insert(saved.guis, {obj = v})
                        v.Enabled = false
                    end
                end
            end
        end)
    end
    if not on then
        for _, g in ipairs(saved.guis) do
            pcall(function()
                if g.obj and g.obj.Parent then g.obj.Enabled = true end
            end)
        end
        saved.guis = {}
    end
end

-- 9. ATMOSPHERE
local function toggleAtmosphere(on)
    if on then
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Atmosphere") or v:IsA("Clouds")
               or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
                pcall(function()
                    table.insert(saved.atmo, {obj = v})
                    v.Parent = nil
                end)
            end
        end
        saved.lighting.FogEnd = Lighting.FogEnd
        saved.lighting.FogStart = Lighting.FogStart
        Lighting.FogEnd = 500
        Lighting.FogStart = 100
    else
        for _, a in ipairs(saved.atmo) do
            pcall(function()
                if a.obj then a.obj.Parent = Lighting end
            end)
        end
        saved.atmo = {}
        if saved.lighting.FogEnd then
            Lighting.FogEnd = saved.lighting.FogEnd
            Lighting.FogStart = saved.lighting.FogStart
        end
    end
end

-- 10. PHYSICS
local function togglePhysics(on)
    local origin, char = getOrigin()
    if not origin then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("BasePart")
               and not v:IsDescendantOf(char)
               and not shouldSkipPart(v, origin) then
                if (v.Position - origin).Magnitude > state.cullDist then
                    if on then
                        table.insert(saved.physics, {
                            obj = v, touch = v.CanTouch, query = v.CanQuery,
                        })
                        v.CanTouch = false
                        v.CanQuery = false
                    end
                end
            end
        end)
    end
    if not on then
        for _, p in ipairs(saved.physics) do
            pcall(function()
                if p.obj and p.obj.Parent then
                    p.obj.CanTouch = p.touch
                    p.obj.CanQuery = p.query
                end
            end)
        end
        saved.physics = {}
    end
end

-- 11. STRIP CHAR
local function stripOneChar(char)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        pcall(function()
            if v:IsA("Accessory") or v:IsA("Hat") or v:IsA("Shirt")
               or v:IsA("Pants") or v:IsA("ShirtGraphic") then
                table.insert(saved.strippedChar, {obj = v, parent = v.Parent})
                v.Parent = nil
            end
        end)
    end
end

local function toggleStripChar(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            stripOneChar(plr.Character)
        end
    else
        for _, s in ipairs(saved.strippedChar) do
            pcall(function()
                if s.obj and s.parent then s.obj.Parent = s.parent end
            end)
        end
        saved.strippedChar = {}
    end
end

-- 12. SKYBOX
local function toggleSkybox(on)
    if on then
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Sky") then
                table.insert(saved.sky, {obj = v})
                v.Parent = nil
            end
        end
        local graySky = Instance.new("Sky")
        graySky.Name = "PotatoGraySky"
        graySky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
        graySky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
        graySky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
        graySky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
        graySky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
        graySky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
        graySky.Parent = Lighting
    else
        for _, s in ipairs(saved.sky) do
            pcall(function()
                if s.obj then s.obj.Parent = Lighting end
            end)
        end
        saved.sky = {}
        local gray = Lighting:FindFirstChild("PotatoGraySky")
        if gray then gray:Destroy() end
    end
end

-- 13. TERRAIN
local function toggleTerrain(on)
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if not terrain then return end
    pcall(function()
        if on then
            terrain.Decoration = false
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
        else
            terrain.Decoration = true
            terrain.WaterWaveSize = 0.15
            terrain.WaterWaveSpeed = 10
        end
    end)
end

-- 14. ANIMATION
local function toggleAnimation(on)
    local origin, char = getOrigin()
    if not origin then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("Humanoid") and v.Parent ~= char then
                local hrp = v.Parent:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - origin).Magnitude > 80 and on then
                    local animator = v:FindFirstChildOfClass("Animator")
                    if animator then
                        for _, anim in ipairs(animator:GetPlayingAnimationTracks()) do
                            anim:Stop()
                        end
                    end
                end
            end
        end)
    end
end

-- 15. KILL LIGHTS
local function toggleKillLights(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
                    table.insert(saved.lights, {obj = v, enabled = v.Enabled})
                    v.Enabled = false
                end
            end)
        end
    else
        for _, l in ipairs(saved.lights) do
            pcall(function()
                if l.obj and l.obj.Parent then l.obj.Enabled = l.enabled end
            end)
        end
        saved.lights = {}
    end
end

-- 16. B&W
local function toggleBW(on)
    local old = Lighting:FindFirstChild("Potato_BW")
    if old then old:Destroy() end
    if on then
        local bw = Instance.new("ColorCorrectionEffect")
        bw.Name = "Potato_BW"
        bw.Brightness = 0
        bw.Contrast = 0
        bw.Saturation = -1
        bw.TintColor = Color3.fromRGB(255, 255, 255)
        bw.Parent = Lighting
    end
end

-- 17. NAMETAG
local function toggleNametags(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                for _, v in ipairs(plr.Character:GetDescendants()) do
                    if v:IsA("BillboardGui") or (v:IsA("TextLabel") and v.Name == "NameTag") then
                        pcall(function()
                            table.insert(saved.nametags, {obj = v, enabled = v.Enabled})
                            v.Enabled = false
                        end)
                    end
                end
            end
        end
    else
        for _, n in ipairs(saved.nametags) do
            pcall(function()
                if n.obj and n.obj.Parent then n.obj.Enabled = n.enabled end
            end)
        end
        saved.nametags = {}
    end
end

-- 18. CHAR SOUND
local function toggleCharSounds(on)
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                for _, v in ipairs(plr.Character:GetDescendants()) do
                    if v:IsA("Sound") then
                        pcall(function()
                            table.insert(saved.charSounds, {obj = v, vol = v.Volume})
                            v.Volume = 0
                        end)
                    end
                end
            end
        end
    else
        for _, s in ipairs(saved.charSounds) do
            pcall(function()
                if s.obj and s.obj.Parent then s.obj.Volume = s.vol end
            end)
        end
        saved.charSounds = {}
    end
end

-- 19. FORCE SHADOW OFF
local function toggleForceShadow(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") and v.CastShadow then
                    table.insert(saved.shadows, {obj = v, cast = v.CastShadow})
                    v.CastShadow = false
                end
            end)
        end
    else
        for _, s in ipairs(saved.shadows) do
            pcall(function()
                if s.obj and s.obj.Parent then s.obj.CastShadow = s.cast end
            end)
        end
        saved.shadows = {}
    end
end

-- 20. XÓA MỌI HIỆU ỨNG
local function toggleRemoveEffects(on)
    if on then
        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:IsA("PostEffect") then
                pcall(function()
                    table.insert(saved.allEffects, {obj=v, key="Enabled", old=v.Enabled})
                    v.Enabled = false
                end)
            end
        end
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Highlight") then
                    table.insert(saved.allEffects, {obj=v, key="Enabled", old=v.Enabled})
                    v.Enabled = false
                end
                if v:IsA("SelectionBox") or v:IsA("SelectionSphere") then
                    table.insert(saved.allEffects, {obj=v, key="Visible", old=v.Visible})
                    v.Visible = false
                end
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                   or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                    table.insert(saved.allEffects, {obj=v, key="Enabled", old=v.Enabled})
                    v.Enabled = false
                end
                if v:IsA("Explosion") then v:Destroy() end
                if v:IsA("ForceField") then
                    table.insert(saved.allEffects, {obj=v, key="Visible", old=v.Visible})
                    v.Visible = false
                end
                if v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
                    table.insert(saved.allEffects, {obj=v, key="Enabled", old=v.Enabled})
                    v.Enabled = false
                end
                if v:IsA("Sound") then
                    table.insert(saved.allEffects, {obj=v, key="Volume", old=v.Volume})
                    v.Volume = 0
                end
            end)
        end
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Sky") or v:IsA("Atmosphere") or v:IsA("Clouds") then
                pcall(function()
                    table.insert(saved.allEffects, {obj=v, key="Parent", old=v.Parent})
                    v.Parent = nil
                end)
            end
        end
    else
        for _, e in ipairs(saved.allEffects) do
            pcall(function()
                if e.obj and e.obj.Parent then
                    e.obj[e.key] = e.old
                elseif e.obj and e.key == "Parent" and e.old then
                    e.obj.Parent = e.old
                end
            end)
        end
        saved.allEffects = {}
    end
end

-- =====================================================
-- APPLY / OFF ALL
-- =====================================================
local safeKeys = {
    "lighting", "decals", "effects", "hideFar", "lowQuality",
    "accessories", "npcFreeze", "gui3d", "atmosphere",
    "physics", "skybox", "terrain", "animation", "killLights",
    "nametags", "charSounds", "forceShadow", "removeEffects",
}

local function applyAll(on)
    for _, k in ipairs(safeKeys) do state[k] = on end
    pcall(toggleLighting, on); pcall(toggleDecals, on); pcall(toggleEffects, on)
    pcall(toggleHideFar, on); pcall(toggleLowQuality, on); pcall(toggleAccessories, on)
    pcall(toggleNpcFreeze, on); pcall(toggleGui3d, on); pcall(toggleAtmosphere, on)
    pcall(togglePhysics, on); pcall(toggleSkybox, on); pcall(toggleTerrain, on)
    pcall(toggleAnimation, on); pcall(toggleKillLights, on)
    pcall(toggleNametags, on); pcall(toggleCharSounds, on); pcall(toggleForceShadow, on)
    pcall(toggleRemoveEffects, on)
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
gui.Name = "FIXLAG_VN"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = game.CoreGui

-- FPS FLOATING
local fpsFrame = Instance.new("Frame")
fpsFrame.Size = UDim2.new(0, 220, 0, 70)
fpsFrame.Position = UDim2.new(0, 15, 0, 15)
fpsFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
fpsFrame.BackgroundTransparency = 0.1
fpsFrame.BorderSizePixel = 0
fpsFrame.Active = true
fpsFrame.Draggable = true
fpsFrame.Parent = gui
Instance.new("UICorner", fpsFrame).CornerRadius = UDim.new(0, 10)

local fpsStroke = Instance.new("UIStroke", fpsFrame)
fpsStroke.Color = Color3.fromRGB(0, 220, 90)
fpsStroke.Thickness = 1.5

local fpsText = Instance.new("TextLabel")
fpsText.Size = UDim2.new(1, -10, 1, -10)
fpsText.Position = UDim2.new(0, 5, 0, 5)
fpsText.BackgroundTransparency = 1
fpsText.Font = Enum.Font.Code
fpsText.TextSize = 14
fpsText.TextColor3 = Color3.fromRGB(0, 255, 100)
fpsText.TextXAlignment = Enum.TextXAlignment.Left
fpsText.TextYAlignment = Enum.TextYAlignment.Top
fpsText.Text = "FPS: --\nPING: --\nDIST: 200 | LOCK: 60"
fpsText.Parent = fpsFrame

spawn(function()
    while task.wait(0.25) do
        local f = getRealFPS()
        local c = Color3.fromRGB(0, 255, 100)
        if f < 60 then c = Color3.fromRGB(255, 210, 0) end
        if f < 30 then c = Color3.fromRGB(255, 60, 60) end
        fpsText.TextColor3 = c
        fpsStroke.Color = c
        fpsText.Text = string.format("FPS: %d\nPING: %d\nDIST: %d | LOCK: %d",
            f, getPing(), state.cullDist, state.fpsTarget)
    end
end)

-- MENU
local menu = Instance.new("Frame")
menu.Size = UDim2.new(0, 300, 0, 540)
menu.Position = UDim2.new(0, 15, 0, 95)
menu.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
menu.BorderSizePixel = 0
menu.Active = true
menu.Draggable = true
menu.Parent = gui
Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 14)
local mStroke = Instance.new("UIStroke", menu)
mStroke.Color = Color3.fromRGB(80, 180, 100)
mStroke.Thickness = 2

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 34)
title.Position = UDim2.new(0, 10, 0, 3)
title.BackgroundTransparency = 1
title.Text = "🔧 FIXLAG_VN"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(100, 255, 130)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = menu

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 28, 0, 26)
minBtn.Position = UDim2.new(1, -34, 0, 6)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
minBtn.Text = "–"
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.Parent = menu
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, -45)
scroll.Position = UDim2.new(0, 0, 0, 45)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.Parent = menu

local collapsed = false
minBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    scroll.Visible = not collapsed
    menu.Size = collapsed and UDim2.new(0, 300, 0, 40) or UDim2.new(0, 300, 0, 540)
    minBtn.Text = collapsed and "+" or "–"
end)

-- ===== NÚT TOGGLE =====
local buttons = {}
local function makeToggle(label, yPos, key, fn)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 30)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    btn.Text = "○ " .. label
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Parent = scroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function()
        state[key] = not state[key]
        local on = state[key]
        btn.BackgroundColor3 = on and Color3.fromRGB(30, 130, 70) or Color3.fromRGB(45, 45, 60)
        btn.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
        btn.Text = (on and "● " or "○ ") .. label
        pcall(fn, on)
    end)
    buttons[key] = {btn = btn, label = label}
end

local y = 5
local function add(label, key, fn)
    makeToggle(label, y, key, fn)
    y = y + 31
end

add("Tắt đèn & hậu kỳ",       "lighting",    toggleLighting)
add("Xóa Decal (an toàn)",    "decals",      toggleDecals)
add("Tắt hạt & âm thanh",     "effects",     toggleEffects)
add("Ẩn vật thể xa",          "hideFar",     toggleHideFar)
add("Chất lượng thấp nhất",   "lowQuality",  toggleLowQuality)
add("Xóa phụ kiện người khác","accessories", toggleAccessories)
add("Đóng băng NPC xa",       "npcFreeze",   toggleNpcFreeze)
add("Tắt GUI 3D xa",          "gui3d",       toggleGui3d)
add("Tắt Atmosphere/Clouds",  "atmosphere",  toggleAtmosphere)
add("Giảm Physics xa",        "physics",     togglePhysics)
add("⚫ Strip nhân vật",      "stripChar",   toggleStripChar)
add("⚫ Xóa Skybox (xám)",    "skybox",      toggleSkybox)
add("⚫ Xóa Terrain (cỏ)",    "terrain",     toggleTerrain)
add("⚫ Tắt Animation xa",    "animation",   toggleAnimation)
add("⚫ Kill mọi Light",      "killLights",  toggleKillLights)
add("⚫ Chế độ TRẮNG ĐEN",    "bwMode",      toggleBW)
add("✦ Tắt Nametag",          "nametags",    toggleNametags)
add("✦ Tắt âm thanh nhân vật","charSounds",  toggleCharSounds)
add("✦ Tắt Shadow toàn bộ",   "forceShadow", toggleForceShadow)
add("🔥 XÓA MỌI HIỆU ỨNG",    "removeEffects", toggleRemoveEffects)

-- ===== KHÓA FPS PRESET 45/60/90 =====
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(1, -20, 0, 20)
fpsLabel.Position = UDim2.new(0, 10, 0, y + 5)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "🔒 KHÓA FPS (chọn mức)"
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 11
fpsLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.Parent = scroll

local lockFrame = Instance.new("Frame")
lockFrame.Size = UDim2.new(1, -20, 0, 40)
lockFrame.Position = UDim2.new(0, 10, 0, y + 28)
lockFrame.BackgroundTransparency = 1
lockFrame.Parent = scroll

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(1, -20, 0, 32)
copyBtn.Position = UDim2.new(0, 10, 0, y + 110)
copyBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
copyBtn.Text = "📋 COPY FAST FLAG (60 FPS)"
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 11
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.Parent = scroll
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)

local lockPresets = {45, 60, 90}
local lockBtns = {}

local function updateLockHighlight(active)
    for _, data in pairs(lockBtns) do
        if data.value == active then
            data.btn.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
            data.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            data.btn.BorderSizePixel = 2
            data.btn.BorderColor3 = Color3.fromRGB(150, 220, 255)
        else
            data.btn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
            data.btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            data.btn.BorderSizePixel = 0
        end
    end
end

for i, val in ipairs(lockPresets) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 86, 0, 36)
    btn.Position = UDim2.new(0, (i-1) * 90, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    btn.Text = "🔒 " .. val .. " FPS"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Parent = lockFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        state.fpsTarget = val
        updateLockHighlight(val)
        copyBtn.Text = "📋 COPY FAST FLAG (" .. val .. " FPS)"

        local json = string.format(
            '{\n  "DFIntTaskSchedulerTargetFps": "%d",\n  "FFlagTaskSchedulerLimitTargetFpsTo2402": "False"\n}',
            val)
        if setclipboard then
            setclipboard(json)
            copyBtn.Text = "✅ ĐÃ COPY KHÓA " .. val .. "! Dán vào Bloxstrap"
            task.wait(2.5)
            copyBtn.Text = "📋 COPY FAST FLAG (" .. val .. " FPS)"
        else
            copyBtn.Text = "⚠️ " .. val .. " - Executor không hỗ trợ clipboard"
        end
    end)
    lockBtns[#lockBtns+1] = {btn = btn, value = val}
end

state.fpsTarget = 60
updateLockHighlight(60)

copyBtn.MouseButton1Click:Connect(function()
    local json = string.format(
        '{\n  "DFIntTaskSchedulerTargetFps": "%d",\n  "FFlagTaskSchedulerLimitTargetFpsTo2402": "False"\n}',
        state.fpsTarget)
    if setclipboard then
        setclipboard(json)
        copyBtn.Text = "✅ ĐÃ COPY KHÓA " .. state.fpsTarget .. "!"
        task.wait(2)
        copyBtn.Text = "📋 COPY FAST FLAG (" .. state.fpsTarget .. " FPS)"
    else
        copyBtn.Text = "❌ Executor không hỗ trợ clipboard"
        task.wait(2)
        copyBtn.Text = "📋 COPY FAST FLAG (" .. state.fpsTarget .. " FPS)"
    end
end)

local noteLabel = Instance.new("TextLabel")
noteLabel.Size = UDim2.new(1, -20, 0, 55)
noteLabel.Position = UDim2.new(0, 10, 0, y + 148)
noteLabel.BackgroundTransparency = 1
noteLabel.Text = "• Bấm 45/60/90 → tự copy JSON\n• Dán vào Bloxstrap → FastFlags → Import JSON\n• Khởi động lại Roblox qua Bloxstrap"
noteLabel.Font = Enum.Font.Gotham
noteLabel.TextSize = 9
noteLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
noteLabel.TextXAlignment = Enum.TextXAlignment.Left
noteLabel.TextYAlignment = Enum.TextYAlignment.Top
noteLabel.TextWrapped = true
noteLabel.Parent = scroll

y = y + 210

-- ===== CULL DISTANCE SLIDER =====
local distLabel = Instance.new("TextLabel")
distLabel.Size = UDim2.new(1, -20, 0, 20)
distLabel.Position = UDim2.new(0, 10, 0, y + 5)
distLabel.BackgroundTransparency = 1
distLabel.Text = "Cull Distance: 200"
distLabel.Font = Enum.Font.GothamBold
distLabel.TextSize = 11
distLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
distLabel.TextXAlignment = Enum.TextXAlignment.Left
distLabel.Parent = scroll

local sliderBg = Instance.new("Frame")
sliderBg.Size = UDim2.new(1, -20, 0, 8)
sliderBg.Position = UDim2.new(0, 10, 0, y + 28)
sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
sliderBg.BorderSizePixel = 0
sliderBg.Parent = scroll
Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0, 4)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.4, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 4)

local sliderBtn = Instance.new("TextButton")
sliderBtn.Size = UDim2.new(0, 16, 0, 16)
sliderBtn.Position = UDim2.new(0.4, -8, 0, -4)
sliderBtn.BackgroundColor3 = Color3.fromRGB(100, 220, 120)
sliderBtn.Text = ""
sliderBtn.Parent = sliderBg
Instance.new("UICorner", sliderBtn).CornerRadius = UDim.new(1, 0)

y = y + 42

-- ===== AUTO CLEAN =====
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, -20, 0, 30)
autoBtn.Position = UDim2.new(0, 10, 0, y)
autoBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
autoBtn.Text = "○ AUTO CLEAN (2s)"
autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 10
autoBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
autoBtn.Parent = scroll
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 8)
autoBtn.MouseButton1Click:Connect(function()
    state.autoClean = not state.autoClean
    local on = state.autoClean
    autoBtn.BackgroundColor3 = on and Color3.fromRGB(30, 130, 70) or Color3.fromRGB(45, 45, 60)
    autoBtn.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
    autoBtn.Text = (on and "● " or "○ ") .. "AUTO CLEAN (2s)"
end)

y = y + 35

-- ===== NÚT BẬT TẤT CẢ =====
local allBtn = Instance.new("TextButton")
allBtn.Size = UDim2.new(1, -20, 0, 42)
allBtn.Position = UDim2.new(0, 10, 0, y)
allBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 50)
allBtn.Text = "🔥 BẬT TẤT CẢ"
allBtn.Font = Enum.Font.GothamBold
allBtn.TextSize = 13
allBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
allBtn.Parent = scroll
Instance.new("UICorner", allBtn).CornerRadius = UDim.new(0, 10)
allBtn.MouseButton1Click:Connect(function()
    applyAll(true)
    state.autoClean = true
    autoBtn.BackgroundColor3 = Color3.fromRGB(30, 130, 70)
    autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoBtn.Text = "● AUTO CLEAN (2s)"
    for k, data in pairs(buttons) do
        if state[k] then
            data.btn.BackgroundColor3 = Color3.fromRGB(30, 130, 70)
            data.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            data.btn.Text = "● " .. data.label
        end
    end
end)

y = y + 47

-- ===== NÚT TẮT TẤT CẢ =====
local offAllBtn = Instance.new("TextButton")
offAllBtn.Size = UDim2.new(1, -20, 0, 42)
offAllBtn.Position = UDim2.new(0, 10, 0, y)
offAllBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 20)
offAllBtn.Text = "⏹ TẮT TẤT CẢ"
offAllBtn.Font = Enum.Font.GothamBold
offAllBtn.TextSize = 12
offAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
offAllBtn.Parent = scroll
Instance.new("UICorner", offAllBtn).CornerRadius = UDim.new(0, 10)
offAllBtn.MouseButton1Click:Connect(function()
    offAll()
    state.autoClean = false
    autoBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    autoBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    autoBtn.Text = "○ AUTO CLEAN (2s)"
    for _, data in pairs(buttons) do
        data.btn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
        data.btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        data.btn.Text = "○ " .. data.label
    end
end)

y = y + 47

-- ===== KHÔI PHỤC =====
local offBtn = Instance.new("TextButton")
offBtn.Size = UDim2.new(1, -20, 0, 32)
offBtn.Position = UDim2.new(0, 10, 0, y)
offBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
offBtn.Text = "🔄 KHÔI PHỤC GỐC"
offBtn.Font = Enum.Font.GothamBold
offBtn.TextSize = 11
offBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
offBtn.Parent = scroll
Instance.new("UICorner", offBtn).CornerRadius = UDim.new(0, 8)
offBtn.MouseButton1Click:Connect(function()
    offAll()
    state.autoClean = false
    autoBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    autoBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    autoBtn.Text = "○ AUTO CLEAN (2s)"
    for _, data in pairs(buttons) do
        data.btn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
        data.btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        data.btn.Text = "○ " .. data.label
    end
end)

y = y + 40
scroll.CanvasSize = UDim2.new(0, 0, 0, y + 15)

-- ===== SLIDER LOGIC =====
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
        state.cullDist = math.floor(80 + relX * 420)
        distLabel.Text = "Cull Distance: " .. state.cullDist
    end
end)

-- ===== LOOPS =====
spawn(function()
    while task.wait(0.5) do
        if state.hideFar then
            local origin, char = getOrigin()
            if origin and char then
                for i = #saved.parts, 1, -1 do
                    local p = saved.parts[i]
                    pcall(function()
                        if p.obj and p.obj.Parent then
                            local d = (p.obj.Position - origin).Magnitude
                            if d < state.cullDist - 30 then
                                p.obj.Transparency = p.trans
                                p.obj.CastShadow = p.shadow
                                table.remove(saved.parts, i)
                            end
                        else
                            table.remove(saved.parts, i)
                        end
                    end)
                end
                hideFarPass()
            end
        end
        if state.npcFreeze then pcall(toggleNpcFreeze, true) end
    end
end)

spawn(function()
    while task.wait(2) do
        if state.autoClean then
            if state.effects then
                for _, v in ipairs(Workspace:GetDescendants()) do
                    pcall(function()
                        if v:IsA("ParticleEmitter") or v:IsA("Trail")
                           or v:IsA("Beam") or v:IsA("Fire") or v:IsA("Smoke") then
                            v.Enabled = false
                        end
                    end)
                end
            end
            if state.removeEffects then
                for _, v in ipairs(Workspace:GetDescendants()) do
                    pcall(function()
                        if v:IsA("Highlight") then v.Enabled = false end
                        if v:IsA("SelectionBox") or v:IsA("SelectionSphere") then v.Visible = false end
                    end)
                end
                for _, v in ipairs(Lighting:GetChildren()) do
                    if v:IsA("PostEffect") then v.Enabled = false end
                end
            end
            collectgarbage("collect")
        end
    end
end)

-- ===== RESPAWN =====
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(2)
    if state.lighting      then pcall(toggleLighting,      true) end
    if state.decals        then pcall(toggleDecals,        true) end
    if state.effects       then pcall(toggleEffects,       true) end
    if state.hideFar       then saved.parts = {}; pcall(toggleHideFar, true) end
    if state.lowQuality    then pcall(toggleLowQuality,    true) end
    if state.accessories   then pcall(toggleAccessories,   true) end
    if state.npcFreeze     then pcall(toggleNpcFreeze,     true) end
    if state.gui3d         then pcall(toggleGui3d,         true) end
    if state.physics       then pcall(togglePhysics,       true) end
    if state.stripChar     then pcall(toggleStripChar,     true) end
    if state.killLights    then pcall(toggleKillLights,    true) end
    if state.nametags      then pcall(toggleNametags,      true) end
    if state.charSounds    then pcall(toggleCharSounds,    true) end
    if state.forceShadow   then pcall(toggleForceShadow,   true) end
    if state.removeEffects then pcall(toggleRemoveEffects, true) end
end)

print("🔧 FIXLAG_VN loaded! FPS Lock 45/60/90 sẵn sàng.")