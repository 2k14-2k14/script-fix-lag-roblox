-- =====================================================
-- FIXLAG_VN v6 — NO-DELETE OPTIMIZER
-- Tăng FPS mà KHÔNG xóa part nào
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
-- CACHE
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

-- =====================================================
-- STATE
-- =====================================================
local state = {
    ghostMap=false, ghostLevel=0.3,
    playerBlack=false, npcBlack=false,
    -- NO-DELETE OPTIMIZERS
    noShadow=false,           -- Tắt shadow toàn bộ
    noTexture=false,          -- Bỏ texture (giữ part)
    noMaterial=false,         -- Đổi tất cả sang Plastic
    noGui3D=false,            -- Tắt SurfaceGui/BillboardGui
    noEffect=false,           -- Tắt Particle/Trail/Beam
    noLight=false,            -- Tắt đèn
    noSound=false,            -- Tắt âm thanh
    noAnim=false,             -- Stop animation
    noPhysics=false,          -- Anchor mọi thứ
    hideFar=false,            -- Ẩn part xa
    lighting=false,
    lowQuality=false,
    cameraOpt=false,
    autoClean=false,
    cullDist=150,
}

local saved = {
    shadows={}, textures={}, materials={},
    guis={}, effects={}, lights={}, sounds={},
    anims={}, physics={}, parts={},
    lighting={}, camSaved={}, connections={},
    playerColors={}, npcColors={},
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
    local ok, p = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    if ok and type(p) == "number" then return math.floor(p) end
    return 0
end

-- =====================================================
-- 🎨 NO-DELETE OPTIMIZER FUNCTIONS
-- =====================================================

-- 1. TẮT SHADOW (không xóa part)
local function toggleNoShadow(on)
    if on then
        spawn(function()
            local all = Workspace:GetDescendants()
            local n = 0
            for i = 1, #all do
                local v = all[i]
                pcall(function()
                    if v:IsA("BasePart") and v.CastShadow then
                        table.insert(saved.shadows, {obj=v})
                        v.CastShadow = false
                        n = n + 1
                    end
                end)
                if i % 2000 == 0 then task.wait() end
            end
            print("✅ Disabled shadow on", n, "parts")
        end)
    else
        for _, s in ipairs(saved.shadows) do
            pcall(function() if s.obj and s.obj.Parent then s.obj.CastShadow = true end end)
        end
        saved.shadows = {}
    end
end

-- 2. BỎ TEXTURE (giữ part, chỉ bỏ ảnh)
local function toggleNoTexture(on)
    if on then
        spawn(function()
            local all = Workspace:GetDescendants()
            local n = 0
            for i = 1, #all do
                local v = all[i]
                pcall(function()
                    -- MeshPart → TextureID = ""
                    if v:IsA("MeshPart") and v.TextureID ~= "" then
                        table.insert(saved.textures, {obj=v, key="TextureID", val=v.TextureID})
                        v.TextureID = ""
                        n = n + 1
                    end
                    -- Decal → Transparency = 1
                    if v:IsA("Decal") and v.Transparency < 1 then
                        table.insert(saved.textures, {obj=v, key="Transparency", val=v.Transparency})
                        v.Transparency = 1
                        n = n + 1
                    end
                    -- Texture → Transparency = 1
                    if v:IsA("Texture") and v.Transparency < 1 then
                        table.insert(saved.textures, {obj=v, key="Transparency", val=v.Transparency})
                        v.Transparency = 1
                        n = n + 1
                    end
                    -- SpecialMesh → TextureId = ""
                    if v:IsA("SpecialMesh") and v.TextureId ~= "" then
                        table.insert(saved.textures, {obj=v, key="TextureId", val=v.TextureId})
                        v.TextureId = ""
                        n = n + 1
                    end
                    -- SurfaceAppearance → AlphaMode = Overlay
                    if v:IsA("SurfaceAppearance") then
                        table.insert(saved.textures, {obj=v, key="AlphaMode", val=v.AlphaMode})
                        v.AlphaMode = Enum.AlphaMode.Overlay
                        n = n + 1
                    end
                end)
                if i % 2000 == 0 then task.wait() end
            end
            print("✅ Removed texture from", n, "objects")
        end)
    else
        for _, t in ipairs(saved.textures) do
            pcall(function()
                if t.obj and t.obj.Parent then t.obj[t.key] = t.val end
            end)
        end
        saved.textures = {}
    end
end

-- 3. ĐỔI MATERIAL → PLASTIC (giữ part)
local function toggleNoMaterial(on)
    if on then
        spawn(function()
            local all = Workspace:GetDescendants()
            local n = 0
            for i = 1, #all do
                local v = all[i]
                pcall(function()
                    if v:IsA("BasePart") then
                        local m = v.Material
                        if m ~= Enum.Material.Plastic and m ~= Enum.Material.SmoothPlastic then
                            table.insert(saved.materials, {obj=v, mat=m})
                            v.Material = Enum.Material.SmoothPlastic
                            v.Reflectance = 0
                            n = n + 1
                        end
                    end
                end)
                if i % 2000 == 0 then task.wait() end
            end
            print("✅ Forced plastic on", n, "parts")
        end)
    else
        for _, m in ipairs(saved.materials) do
            pcall(function() if m.obj and m.obj.Parent then m.obj.Material = m.mat end end)
        end
        saved.materials = {}
    end
end

-- 4. TẮT SURFACEGUI/BILLBOARDGUI (giữ, không xóa)
local function toggleNoGui3D(on)
    if on then
        spawn(function()
            local all = Workspace:GetDescendants()
            local n = 0
            for i = 1, #all do
                local v = all[i]
                pcall(function()
                    if v:IsA("SurfaceGui") or v:IsA("BillboardGui") then
                        if v.Enabled then
                            table.insert(saved.guis, {obj=v})
                            v.Enabled = false
                            n = n + 1
                        end
                    end
                end)
                if i % 2000 == 0 then task.wait() end
            end
            print("✅ Disabled", n, "Gui3D")
        end)
    else
        for _, g in ipairs(saved.guis) do
            pcall(function() if g.obj and g.obj.Parent then g.obj.Enabled = true end end)
        end
        saved.guis = {}
    end
end

-- 5. TẮT EFFECTS (giữ, không xóa)
local function toggleNoEffect(on)
    if on then
        spawn(function()
            local all = Workspace:GetDescendants()
            local n = 0
            for i = 1, #all do
                local v = all[i]
                pcall(function()
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                       or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles")
                       or v:IsA("Highlight") then
                        if v.Enabled then
                            table.insert(saved.effects, {obj=v})
                            v.Enabled = false
                            n = n + 1
                        end
                    end
                end)
                if i % 2000 == 0 then task.wait() end
            end
            print("✅ Disabled", n, "effects")
        end)
    else
        for _, e in ipairs(saved.effects) do
            pcall(function() if e.obj and e.obj.Parent then e.obj.Enabled = true end end)
        end
        saved.effects = {}
    end
end

-- 6. TẮT ĐÈN (giữ, không xóa)
local function toggleNoLight(on)
    if on then
        spawn(function()
            local all = Workspace:GetDescendants()
            local n = 0
            for i = 1, #all do
                local v = all[i]
                pcall(function()
                    if v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
                        if v.Enabled then
                            table.insert(saved.lights, {obj=v})
                            v.Enabled = false
                            n = n + 1
                        end
                    end
                end)
                if i % 2000 == 0 then task.wait() end
            end
            print("✅ Disabled", n, "lights")
        end)
    else
        for _, l in ipairs(saved.lights) do
            pcall(function() if l.obj and l.obj.Parent then l.obj.Enabled = true end end)
        end
        saved.lights = {}
    end
end

-- 7. TẮT ÂM THANH (giữ, volume = 0)
local function toggleNoSound(on)
    if on then
        spawn(function()
            local all = Workspace:GetDescendants()
            local n = 0
            for i = 1, #all do
                local v = all[i]
                pcall(function()
                    if v:IsA("Sound") and v.Volume > 0 then
                        table.insert(saved.sounds, {obj=v, vol=v.Volume})
                        v.Volume = 0
                        n = n + 1
                    end
                end)
                if i % 2000 == 0 then task.wait() end
            end
            pcall(function() SoundSvc.AmbientReverb = Enum.ReverbType.NoReverb end)
            print("✅ Muted", n, "sounds")
        end)
    else
        for _, s in ipairs(saved.sounds) do
            pcall(function() if s.obj and s.obj.Parent then s.obj.Volume = s.vol end end)
        end
        saved.sounds = {}
    end
end

-- 8. STOP ANIMATION NPC (giữ NPC)
local function toggleNoAnim(on)
    if on then
        spawn(function()
            local all = Workspace:GetDescendants()
            local myChar = LocalPlayer.Character
            local n = 0
            for i = 1, #all do
                local v = all[i]
                pcall(function()
                    if v:IsA("Animator") and not (myChar and v:IsDescendantOf(myChar)) then
                        for _, a in ipairs(v:GetPlayingAnimationTracks()) do a:Stop() end
                        n = n + 1
                    end
                end)
                if i % 2000 == 0 then task.wait() end
            end
            -- Humanoid NPC → tắt state
            for i = 1, #all do
                local v = all[i]
                pcall(function()
                    if v:IsA("Humanoid") and v.Parent ~= myChar then
                        v.EvaluateStateMachine = false
                        v:SetStateEnabled(Enum.HumanoidStateType.Running, false)
                        v:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
                        v:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
                        v:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    end
                end)
                if i % 2000 == 0 then task.wait() end
            end
            print("✅ Stopped", n, "animators")
        end)
    end
end

-- 9. FREEZE PHYSICS (giữ part, chỉ anchor)
local function toggleNoPhysics(on)
    if on then
        spawn(function()
            local all = Workspace:GetDescendants()
            local myChar = LocalPlayer.Character
            local n = 0
            for i = 1, #all do
                local v = all[i]
                pcall(function()
                    if v:IsA("BasePart") and not v.Anchored then
                        if v:IsDescendantOf(myChar) then return end
                        table.insert(saved.physics, {obj=v})
                        v.Anchored = true
                        v.CanTouch = false
                        v.CanQuery = false
                        n = n + 1
                    end
                end)
                if i % 2000 == 0 then task.wait() end
            end
            print("✅ Froze", n, "parts")
        end)
    else
        for _, p in ipairs(saved.physics) do
            pcall(function()
                if p.obj and p.obj.Parent then
                    p.obj.Anchored = false
                    p.obj.CanTouch = true
                    p.obj.CanQuery = true
                end
            end)
        end
        saved.physics = {}
    end
end

-- 10. ẨN PART XA (giữ, chỉ transparency = 1)
local function toggleHideFar(on)
    if on then
        spawn(function()
            local origin = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not origin then return end
            local originPos = origin.Position
            local all = Workspace:GetDescendants()
            local n = 0
            for i = 1, #all do
                local v = all[i]
                pcall(function()
                    if v:IsA("BasePart") and not isPartOfAnyCharacter(v) then
                        if (v.Position - originPos).Magnitude > state.cullDist then
                            if v.Transparency < 1 then
                                table.insert(saved.parts, {obj=v, trans=v.Transparency})
                                v.Transparency = 1
                                n = n + 1
                            end
                        end
                    end
                end)
                if i % 2000 == 0 then task.wait() end
            end
            print("✅ Hid", n, "far parts")
        end)
    else
        for _, p in ipairs(saved.parts) do
            pcall(function() if p.obj and p.obj.Parent then p.obj.Transparency = p.trans end end)
        end
        saved.parts = {}
    end
end

-- 11. TỐI ƯU LIGHTING (tắt post effects)
local function toggleLighting(on)
    if on then
        saved.lighting = {
            GS = Lighting.GlobalShadows,
            B = Lighting.Brightness,
            OA = Lighting.OutdoorAmbient,
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart,
            Tech = Lighting.Technology,
        }
        Lighting.GlobalShadows = false
        Lighting.Brightness = 1
        Lighting.OutdoorAmbient = Color3.fromRGB(120,120,120)
        Lighting.FogEnd = 300
        Lighting.FogStart = 100
        pcall(function()
            Lighting.Technology = Enum.Technology.Compatibility
        end)
        for _, v in ipairs(Lighting:GetChildren()) do
            pcall(function()
                if v:IsA("PostEffect") then v.Enabled = false
                elseif v:IsA("Atmosphere") or v:IsA("Clouds") then v.Enabled = false
                end
            end)
        end
    else
        if saved.lighting.GS ~= nil then
            Lighting.GlobalShadows = saved.lighting.GS
            Lighting.Brightness = saved.lighting.B
            Lighting.OutdoorAmbient = saved.lighting.OA
            Lighting.FogEnd = saved.lighting.FogEnd
            Lighting.FogStart = saved.lighting.FogStart
            pcall(function()
                if saved.lighting.Tech then
                    Lighting.Technology = saved.lighting.Tech
                end
            end)
        end
    end
end

-- 12. CHẤT LƯỢNG THẤP
local function toggleLowQuality(on)
    local ok, cur = pcall(function() return settings().Rendering.QualityLevel end)
    if on then
        saved.quality = ok and cur or Enum.QualityLevel.Automatic
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        pcall(function()
            settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        end)
    else
        pcall(function()
            settings().Rendering.QualityLevel = saved.quality or Enum.QualityLevel.Automatic
        end)
    end
end

-- 13. CAMERA OPTIMIZE (giảm FarPlane)
local function toggleCameraOpt(on)
    if on then
        saved.camSaved.FOV = Cam.FieldOfView
        saved.camSaved.FarPlane = Cam.FarPlane
        pcall(function() Cam.FieldOfView = 70 end)
        pcall(function() Cam.FarPlane = 200 end)
        for _, v in ipairs(Cam:GetChildren()) do
            pcall(function()
                if v:IsA("PostEffect") then
                    table.insert(saved.camSaved, {obj=v, e=v.Enabled})
                    v.Enabled = false
                end
            end)
        end
    else
        pcall(function() Cam.FieldOfView = saved.camSaved.FOV or 70 end)
        pcall(function() Cam.FarPlane = saved.camSaved.FarPlane or 100000 end)
        for _, s in ipairs(saved.camSaved) do
            pcall(function() if s.obj and s.obj.Parent then s.obj.Enabled = s.e end end)
        end
        saved.camSaved = {}
    end
end

-- =====================================================
-- ⚡ ONE-CLICK OPTIMIZE (không xóa gì cả)
-- =====================================================
local optimizing = false

local function runOptimize()
    if optimizing then return end
    optimizing = true

    spawn(function()
        local steps = {
            {fn = toggleLighting,      label = "Lighting",        wait = 0.05},
            {fn = toggleLowQuality,    label = "Quality",         wait = 0.05},
            {fn = toggleCameraOpt,     label = "Camera",          wait = 0.05},
            {fn = toggleNoShadow,      label = "Shadow",          wait = 0.1},
            {fn = toggleNoMaterial,    label = "Material",        wait = 0.1},
            {fn = toggleNoGui3D,       label = "Gui3D",           wait = 0.1},
            {fn = toggleNoEffect,      label = "Effects",         wait = 0.1},
            {fn = toggleNoTexture,     label = "Texture",         wait = 0.1},
            {fn = toggleNoLight,       label = "Lights",          wait = 0.1},
            {fn = toggleNoSound,       label = "Sounds",          wait = 0.1},
            {fn = toggleNoAnim,        label = "Animations",      wait = 0.1},
            {fn = toggleNoPhysics,     label = "Physics",         wait = 0.1},
            {fn = toggleHideFar,       label = "HideFar",         wait = 0.1},
        }

        for i, s in ipairs(steps) do
            pcall(s.fn, true)
            local pct = math.floor(i / #steps * 100)
            if _G_optBtn then
                pcall(function()
                    _G_optBtn.Text = string.format("⚡ ĐANG TỐI ƯU... %d%% (%s)", pct, s.label)
                end)
            end
            task.wait(s.wait)
        end

        state.autoClean = true
        optimizing = false

        if _G_optBtn then
            pcall(function()
                _G_optBtn.Text = "⚡ TỐI ƯU FPS (KHÔNG XÓA)\n(ĐÃ TỐI ƯU - FPS TĂNG)"
                _G_optBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
            end)
        end
        print("⚡ OPTIMIZE DONE! Không xóa bất cứ part nào.")
    end)
end

local function restoreAll()
    spawn(function()
        state.autoClean = false
        pcall(toggleHideFar, false)
        pcall(toggleNoPhysics, false)
        pcall(toggleNoAnim, false)
        pcall(toggleNoSound, false)
        pcall(toggleNoLight, false)
        pcall(toggleNoTexture, false)
        pcall(toggleNoEffect, false)
        pcall(toggleNoGui3D, false)
        pcall(toggleNoMaterial, false)
        pcall(toggleNoShadow, false)
        pcall(toggleCameraOpt, false)
        pcall(toggleLowQuality, false)
        pcall(toggleLighting, false)
        if _G_optBtn then
            pcall(function()
                _G_optBtn.Text = "⚡ TỐI ƯU FPS (KHÔNG XÓA)"
                _G_optBtn.BackgroundColor3 = Color3.fromRGB(20, 100, 180)
            end)
        end
    end)
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
fpsStroke.Color = Color3.fromRGB(0, 200, 255); fpsStroke.Thickness = 2

local fpsText = Instance.new("TextLabel")
fpsText.Size = UDim2.new(1, -10, 1, -10); fpsText.Position = UDim2.new(0, 5, 0, 5)
fpsText.BackgroundTransparency = 1; fpsText.Font = Enum.Font.Code; fpsText.TextSize = 14
fpsText.TextColor3 = Color3.fromRGB(0, 220, 255)
fpsText.TextXAlignment = Enum.TextXAlignment.Left
fpsText.TextYAlignment = Enum.TextYAlignment.Top
fpsText.Text = "FPS: --\nPING: --\nDIST: 150"
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
menu.BackgroundColor3 = Color3.fromRGB(5, 5, 10)
menu.BorderSizePixel = 0; menu.Active = true; menu.Draggable = true; menu.Parent = gui
Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 14)
local mStroke = Instance.new("UIStroke", menu)
mStroke.Color = Color3.fromRGB(0, 200, 255); mStroke.Thickness = 2

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 34); title.Position = UDim2.new(0, 10, 0, 3)
title.BackgroundTransparency = 1; title.Text = "⚡ FIXLAG_VN v6 (NO-DELETE)"
title.Font = Enum.Font.GothamBold; title.TextSize = 13
title.TextColor3 = Color3.fromRGB(0, 220, 255)
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
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 255)
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
    btn.BackgroundColor3 = color or Color3.fromRGB(30, 40, 55)
    btn.Text = "○ " .. label; btn.Font = Enum.Font.GothamBold; btn.TextSize = 10
    btn.TextColor3 = Color3.fromRGB(200, 200, 200); btn.Parent = scroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function()
        state[key] = not state[key]; local on = state[key]
        btn.BackgroundColor3 = on and Color3.fromRGB(0, 150, 220) or (color or Color3.fromRGB(30, 40, 55))
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
    lbl.TextColor3 = col or Color3.fromRGB(0, 200, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Center; lbl.Parent = scroll
    y = y + 26
end

-- MAIN BUTTON
local optBtn = Instance.new("TextButton")
optBtn.Size = UDim2.new(1, -20, 0, 80); optBtn.Position = UDim2.new(0, 10, 0, y)
optBtn.BackgroundColor3 = Color3.fromRGB(20, 100, 180)
optBtn.Text = "⚡ TỐI ƯU FPS (KHÔNG XÓA)\nTĂNG FPS MÀ GIỮ MAP NGUYÊN"
optBtn.Font = Enum.Font.GothamBold; optBtn.TextSize = 13
optBtn.TextColor3 = Color3.fromRGB(255, 255, 255); optBtn.Parent = scroll
Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 10)
local optStroke = Instance.new("UIStroke", optBtn)
optStroke.Color = Color3.fromRGB(0, 220, 255); optStroke.Thickness = 4
_G_optBtn = optBtn

optBtn.MouseButton1Click:Connect(function()
    if optimizing then return end
    if not state.autoClean then
        runOptimize()
        for k, data in pairs(buttons) do
            state[k] = true
            data.btn.BackgroundColor3 = Color3.fromRGB(0, 150, 220)
            data.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            data.btn.Text = "● " .. data.label
        end
    else
        restoreAll()
        for k, data in pairs(buttons) do
            state[k] = false
            data.btn.BackgroundColor3 = data.color or Color3.fromRGB(30, 40, 55)
            data.btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            data.btn.Text = "○ " .. data.label
        end
    end
end)

y = y + 86

header("⚡ NO-DELETE OPTIMIZERS", Color3.fromRGB(0, 220, 255))
add("🚫 Tắt SHADOW (tăng FPS 15%)",  "noShadow",   toggleNoShadow,   Color3.fromRGB(30, 40, 55))
add("🚫 Bỏ TEXTURE (giữ part)",      "noTexture",  toggleNoTexture,  Color3.fromRGB(30, 40, 55))
add("🚫 Đổi MATERIAL → Plastic",     "noMaterial", toggleNoMaterial, Color3.fromRGB(30, 40, 55))
add("🚫 Tắt GUI 3D (Surface/Bill)",  "noGui3D",    toggleNoGui3D,    Color3.fromRGB(30, 40, 55))
add("🚫 Tắt EFFECTS (Particle/Beam)","noEffect",   toggleNoEffect,   Color3.fromRGB(30, 40, 55))
add("🚫 Tắt ĐÈN (giữ nguyên)",       "noLight",    toggleNoLight,    Color3.fromRGB(30, 40, 55))
add("🚫 Tắt ÂM THANH (giữ part)",    "noSound",    toggleNoSound,    Color3.fromRGB(30, 40, 55))
add("🚫 Stop ANIMATION NPC",         "noAnim",     toggleNoAnim,     Color3.fromRGB(30, 40, 55))
add("🚫 Freeze PHYSICS (Anchor)",    "noPhysics",  toggleNoPhysics,  Color3.fromRGB(30, 40, 55))
add("🚫 Ẩn part XA (transparency=1)", "hideFar",   toggleHideFar,    Color3.fromRGB(30, 40, 55))

header("⚙️ RENDER SETTINGS", Color3.fromRGB(100, 200, 255))
add("💡 Tối ưu LIGHTING",      "lighting",    toggleLighting,    Color3.fromRGB(40, 50, 70))
add("📉 Chất lượng THẤP NHẤT", "lowQuality",  toggleLowQuality,  Color3.fromRGB(40, 50, 70))
add("📷 CAMERA OPTIMIZE",      "cameraOpt",   toggleCameraOpt,   Color3.fromRGB(40, 50, 70))

-- Slider
header("📏 CULL DISTANCE", Color3.fromRGB(255, 200, 100))
local distLabel = Instance.new("TextLabel")
distLabel.Size = UDim2.new(1, -20, 0, 20); distLabel.Position = UDim2.new(0, 10, 0, y)
distLabel.BackgroundTransparency = 1; distLabel.Text = "Khoảng cách: 150"
distLabel.Font = Enum.Font.GothamBold; distLabel.TextSize = 11
distLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
distLabel.TextXAlignment = Enum.TextXAlignment.Left; distLabel.Parent = scroll
y = y + 24

local sliderBg = Instance.new("Frame")
sliderBg.Size = UDim2.new(1, -20, 0, 8); sliderBg.Position = UDim2.new(0, 10, 0, y)
sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60); sliderBg.BorderSizePixel = 0
sliderBg.Parent = scroll
Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0, 4)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.3, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255); sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 4)

local sliderBtn = Instance.new("TextButton")
sliderBtn.Size = UDim2.new(0, 16, 0, 16); sliderBtn.Position = UDim2.new(0.3, -8, 0, -4)
sliderBtn.BackgroundColor3 = Color3.fromRGB(0, 220, 255); sliderBtn.Text = ""
sliderBtn.Parent = sliderBg
Instance.new("UICorner", sliderBtn).CornerRadius = UDim.new(1, 0)

y = y + 20

local draggingDist = false
sliderBtn.MouseButton1Down:Connect(function() draggingDist = true end)
sliderBtn.MouseButton1Up:Connect(function() draggingDist = false end)

-- Restore
local restoreBtn = Instance.new("TextButton")
restoreBtn.Size = UDim2.new(1, -20, 0, 40); restoreBtn.Position = UDim2.new(0, 10, 0, y)
restoreBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 20)
restoreBtn.Text = "⏹ KHÔI PHỤC TẤT CẢ"
restoreBtn.Font = Enum.Font.GothamBold; restoreBtn.TextSize = 12
restoreBtn.TextColor3 = Color3.fromRGB(255, 255, 255); restoreBtn.Parent = scroll
Instance.new("UICorner", restoreBtn).CornerRadius = UDim.new(0, 10)
restoreBtn.MouseButton1Click:Connect(function()
    restoreAll()
    for _, data in pairs(buttons) do
        state[data.key or ""] = false
        data.btn.BackgroundColor3 = data.color or Color3.fromRGB(30, 40, 55)
        data.btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        data.btn.Text = "○ " .. data.label
    end
end)

y = y + 46
scroll.CanvasSize = UDim2.new(0, 0, 0, y + 15)

-- Slider logic
RunService.RenderStepped:Connect(function()
    if draggingDist then
        local mouse = LocalPlayer:GetMouse()
        local relX = math.clamp((mouse.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        sliderFill.Size = UDim2.new(relX, 0, 1, 0)
        sliderBtn.Position = UDim2.new(relX, -8, 0, -4)
        state.cullDist = math.floor(50 + relX * 350)
        distLabel.Text = "Khoảng cách: " .. state.cullDist
    end
end)

gui.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        draggingDist = false
    end
end)

-- AUTO CLEAN
spawn(function()
    while task.wait(0.5) do
        if state.autoClean then
            for _, v in ipairs(Workspace:GetDescendants()) do
                pcall(function()
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
                       or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                        v.Enabled = false
                    end
                    if v:IsA("Explosion") then v:Destroy() end
                end)
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

print("⚡ FIXLAG_VN v6 NO-DELETE loaded! Tăng FPS mà không xóa gì.")
