-- =====================================================
-- 💀💀💀 NUCLEAR MODE — Xóa THẬT để tăng FPS tối đa
-- Chỉ giữ: baseplate, character, đồ cần thiết
-- =====================================================
local function toggleNuclear(on)
    if not on then return end
    if _G_nuclearLoading then return end
    _G_nuclearLoading = true

    local char = LocalPlayer.Character
    local origin = char and char:FindFirstChild("HumanoidRootPart")
    local originPos = origin and origin.Position

    if _G_nukeBtn then
        pcall(function() _G_nukeBtn.Text = "💀 ĐANG XÓA... 10%" end)
    end

    -- ═══ BƯỚC 1: TẮT LIGHTING TECHNOLOGY (tăng FPS 15-25%) ═══
    pcall(function()
        Lighting.Technology = Enum.Technology.Compatibility
    end)
    pcall(function() Lighting.GlobalShadows = false end)
    pcall(function() Lighting.FogEnd = 100 end)
    pcall(function() Lighting.FogStart = 30 end)
    pcall(function() Lighting.Brightness = 1 end)
    pcall(function() Lighting.OutdoorAmbient = Color3.fromRGB(120,120,120) end)

    -- Tắt hết PostEffects
    for _, v in ipairs(Lighting:GetChildren()) do
        pcall(function()
            if v:IsA("PostEffect") or v:IsA("Atmosphere")
               or v:IsA("Clouds") or v:IsA("Sky") then
                v.Enabled = false
                if v:IsA("Atmosphere") or v:IsA("Clouds") or v:IsA("Sky") then
                    v.Parent = nil
                end
            end
        end)
    end

    task.wait()

    if _G_nukeBtn then
        pcall(function() _G_nukeBtn.Text = "💀 ĐANG XÓA... 20%" end)
    end

    -- ═══ BƯỚC 2: XÓA SURFACEGUI + BILLBOARDGUI (tăng FPS 10-15%) ═══
    local all = Workspace:GetDescendants()
    local charCache = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then charCache[plr.Character] = true end
    end

    for i = 1, #all do
        local v = all[i]
        pcall(function()
            if v:IsA("SurfaceGui") or v:IsA("BillboardGui") then
                local anc = v:FindFirstAncestorOfClass("Model")
                local isChar = false
                if anc then
                    for c in pairs(charCache) do
                        if anc == c or anc:IsDescendantOf(c) then isChar = true; break end
                    end
                end
                if not isChar then
                    v:Destroy()
                end
            end
        end)
        if i % 2000 == 0 then task.wait() end
    end

    if _G_nukeBtn then
        pcall(function() _G_nukeBtn.Text = "💀 ĐANG XÓA... 35%" end)
    end

    -- ═══ BƯỚC 3: XÓA PART XA + UNION + MESH (tăng FPS 20-30%) ═══
    local cullD = state.cullDist
    local all2 = Workspace:GetDescendants()

    for i = 1, #all2 do
        local v = all2[i]
        pcall(function()
            -- UNION/MESH xa → XÓA HẲN (tốn GPU nhất)
            if v:IsA("UnionOperation") or v:IsA("MeshPart")
               or v:IsA("NegateOperation") or v:IsA("IntersectOperation") then
                if originPos then
                    if (v.Position - originPos).Magnitude > cullD then
                        v:Destroy()
                    end
                end
            end

            -- Part thường xa → XÓA HẲN
            if v:IsA("BasePart") and not v:Anchored then
                if originPos and (v.Position - originPos).Magnitude > cullD * 2 then
                    v:Destroy()
                end
            end

            -- Decorations xa
            if v:IsA("Decal") or v:IsA("Texture") then
                local par = v.Parent
                if par and par:IsA("BasePart") and originPos then
                    if (par.Position - originPos).Magnitude > cullD then
                        v:Destroy()
                    end
                end
            end
        end)
        if i % 2000 == 0 then task.wait() end
    end

    if _G_nukeBtn then
        pcall(function() _G_nukeBtn.Text = "💀 ĐANG XÓA... 55%" end)
    end

    -- ═══ BƯỚC 4: XÓA MỌI EFFECT CÒN LẠI ═══
    local all3 = Workspace:GetDescendants()
    for i = 1, #all3 do
        local v = all3[i]
        pcall(function()
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
               or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles")
               or v:IsA("Highlight") or v:IsA("Explosion") then
                local isChar = false
                for c in pairs(charCache) do
                    if v:IsDescendantOf(c) then isChar = true; break end
                end
                if not isChar then v:Destroy() end
            end
            if v:IsA("Sound") then v.Volume = 0 end
            if v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
                v.Enabled = false
            end
        end)
        if i % 2000 == 0 then task.wait() end
    end

    if _G_nukeBtn then
        pcall(function() _G_nukeBtn.Text = "💀 ĐANG XÓA... 75%" end)
    end

    -- ═══ BƯỚC 5: XÓA ANIMATION + PHYSICS ═══
    local all4 = Workspace:GetDescendants()
    for i = 1, #all4 do
        local v = all4[i]
        pcall(function()
            if v:IsA("Animator") then
                local isMyChar = char and v:IsDescendantOf(char)
                if not isMyChar then
                    for _, a in ipairs(v:GetPlayingAnimationTracks()) do a:Stop() end
                end
            end
            if v:IsA("Humanoid") and v.Parent ~= char then
                v:SetStateEnabled(Enum.HumanoidStateType.Running, false)
                v:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
                v:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
                v.EvaluateStateMachine = false
            end
            if v:IsA("BasePart") and not v.Anchored and v ~= (char and char:FindFirstChild("HumanoidRootPart")) then
                if not v:FindFirstAncestorOfClass("Accessory") then
                    pcall(function() v.Anchored = true end)
                end
            end
        end)
        if i % 2000 == 0 then task.wait() end
    end

    if _G_nukeBtn then
        pcall(function() _G_nukeBtn.Text = "💀 ĐANG XÓA... 90%" end)
    end

    -- ═══ BƯỚC 6: TỐI ƯU CAMERA ═══
    pcall(function()
        Cam.FieldOfView = 70
        Cam.CFrame = Cam.CFrame
    end)

    -- ═══ BƯỚC 7: GC + DONE ═══
    for _ = 1, 3 do
        pcall(function() collectgarbage("collect") end)
        task.wait()
    end

    _G_nuclearLoading = false
    state.autoClean = true

    if _G_nukeBtn then
        pcall(function()
            _G_nukeBtn.Text = "💀💀💀 NUCLEAR (ĐÃ XÓA)"
            _G_nukeBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 100)
        end)
    end

    print("💀 NUCLEAR DONE! FPS sẽ tăng sau 2-3 giây.")
end

-- Nút NUCLEAR
local nukeBtn = Instance.new("TextButton")
nukeBtn.Size = UDim2.new(1, -20, 0, 60)
nukeBtn.Position = UDim2.new(0, 10, 0, y)
nukeBtn.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
nukeBtn.Text = "💀💀💀 NUCLEAR MODE\n(XÓA THẬT - FPS TĂNG 2-3X)"
nukeBtn.Font = Enum.Font.GothamBold
nukeBtn.TextSize = 12
nukeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
nukeBtn.Parent = scroll
Instance.new("UICorner", nukeBtn).CornerRadius = UDim.new(0, 10)
local nukeStroke = Instance.new("UIStroke", nukeBtn)
nukeStroke.Color = Color3.fromRGB(255, 0, 100)
nukeStroke.Thickness = 4
_G_nukeBtn = nukeBtn

nukeBtn.MouseButton1Click:Connect(function()
    toggleNuclear(true)
end)

y = y + 66
scroll.CanvasSize = UDim2.new(0, 0, 0, y + 15)
