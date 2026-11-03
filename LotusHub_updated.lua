--!strict
--[[
    Module: Sequential Teleport, Optimized Auto-Arise & Anti-AFK System (v4)
    Architecture: Client-side LocalScript
    Target Path: workspace.Camera.ClientWorld.MapEffects
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- 1. STATE & CONFIGURATION
-- ==========================================
local State = {
    AutoTele = false,
    AutoArise = false,
    AntiAFK = true, -- Bật mặc định để treo máy an toàn ngay khi chạy script
    IsRunning = true,
    CurrentTarget = nil :: Instance?,
    LastAriseTime = 0,
    AriseInterval = 1.0, -- Chu kỳ ấn nút 1 giây / lần
    LastAfkPulse = os.clock(),
    AfkPulseInterval = 300, -- Gửi tín hiệu chống AFK nội bộ mỗi 5 phút (300 giây)
    TeleOffset = Vector3.new(0, 0.5, 3.5),
}

-- ==========================================
-- 2. LIGHTWEIGHT UI CREATION
-- ==========================================
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local existingGui = playerGui:FindFirstChild("MrDon_AriseController")
if existingGui then
    existingGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MrDon_AriseController"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.fromOffset(280, 275)
MainFrame.Position = UDim2.new(0.5, -140, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(65, 65, 85)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 34)
TitleBar.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 8)
TitleFix.Position = UDim2.new(0, 0, 1, -8)
TitleFix.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -40, 1, 0)
TitleLabel.Position = UDim2.fromOffset(12, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "MapEffects Controller v4"
TitleLabel.TextColor3 = Color3.fromRGB(235, 235, 245)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 12
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(26, 26)
CloseBtn.Position = UDim2.new(1, -30, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(190, 55, 55)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -24, 0, 20)
StatusLabel.Position = UDim2.fromOffset(12, 40)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Target: Đang chờ bật..."
StatusLabel.TextColor3 = Color3.fromRGB(165, 165, 185)
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextSize = 12
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
StatusLabel.Parent = MainFrame

local PromptStatusLabel = Instance.new("TextLabel")
PromptStatusLabel.Size = UDim2.new(1, -24, 0, 20)
PromptStatusLabel.Position = UDim2.fromOffset(12, 60)
PromptStatusLabel.BackgroundTransparency = 1
PromptStatusLabel.Text = "Anti-AFK: Đang bảo vệ (Active)"
PromptStatusLabel.TextColor3 = Color3.fromRGB(110, 215, 145)
PromptStatusLabel.Font = Enum.Font.Gotham
PromptStatusLabel.TextSize = 11
PromptStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
PromptStatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
PromptStatusLabel.Parent = MainFrame

local function createToggleButton(text: string, posY: number, defaultState: boolean, callback: (boolean) -> ()): TextButton
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -24, 0, 44)
    btn.Position = UDim2.fromOffset(12, posY)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.AutoButtonColor = false
    btn.Parent = MainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Parent = btn

    local isEnabled = defaultState

    local function updateVisual()
        if isEnabled then
            btn.BackgroundColor3 = Color3.fromRGB(40, 145, 85)
            btn.Text = text .. ": ON"
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            stroke.Color = Color3.fromRGB(70, 200, 115)
        else
            btn.BackgroundColor3 = Color3.fromRGB(42, 42, 54)
            btn.Text = text .. ": OFF"
            btn.TextColor3 = Color3.fromRGB(210, 210, 220)
            stroke.Color = Color3.fromRGB(70, 70, 90)
        end
    end

    updateVisual()

    btn.MouseButton1Click:Connect(function()
        isEnabled = not isEnabled
        updateVisual()
        callback(isEnabled)
    end)

    return btn
end

createToggleButton("Auto Tele To Model", 88, false, function(val)
    State.AutoTele = val
    if not val then
        State.CurrentTarget = nil
        StatusLabel.Text = "Target: Đã tắt Auto Tele"
    end
end)

createToggleButton("Auto Arise (1s / lần)", 144, false, function(val)
    State.AutoArise = val
    if not val then
        PromptStatusLabel.Text = "Arise: Đã tạm dừng"
    end
end)

createToggleButton("Anti-AFK Protection", 200, true, function(val)
    State.AntiAFK = val
    if val then
        PromptStatusLabel.Text = "Anti-AFK: Đang bảo vệ (Active)"
    else
        PromptStatusLabel.Text = "Anti-AFK: Đã tắt"
    end
end)

-- Kéo thả cửa sổ
local dragging = false
local dragInput: InputObject? = nil
local dragStart: Vector3? = nil
local startPos: UDim2? = nil

TitleBar.InputBegan:Connect(function(input: InputObject)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TitleBar.InputChanged:Connect(function(input: InputObject)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

local dragConnection = UserInputService.InputChanged:Connect(function(input: InputObject)
    if input == dragInput and dragging and dragStart and startPos then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- ==========================================
-- 3. ANTI-AFK SYSTEM (DUAL-LAYER PROTECTION)
-- ==========================================

-- Lớp 1: Chặn sự kiện Idled 20 phút mặc định của Roblox Engine
local idledConnection = LocalPlayer.Idled:Connect(function()
    if not State.IsRunning or not State.AntiAFK then return end

    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)

    PromptStatusLabel.Text = "Anti-AFK: Đã chặn Roblox Idle Kick"
end)

-- Lớp 2: Gửi xung nhịp phím nhẹ định kỳ để reset bộ đếm AFK riêng của game (nếu có)
local function performPeriodicAntiAFK()
    task.spawn(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:SetKeyDown("0x20")
            task.wait(0.05)
            VirtualUser:SetKeyUp("0x20")
        end)
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
        end)
    end)
end

-- ==========================================
-- 4. CORE LOGIC: O(1) TARGET & PROMPT LOOKUP
-- ==========================================

local function getMapEffectsFolder(): Instance?
    local cam = workspace:FindFirstChild("Camera") or workspace.CurrentCamera
    if not cam then return nil end

    local clientWorld = cam:FindFirstChild("ClientWorld")
    if not clientWorld then return nil end

    return clientWorld:FindFirstChild("MapEffects")
end

local function getTargetPivotPart(model: Instance): BasePart?
    if not model or not model.Parent then return nil end

    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        return hrp
    end

    if model:IsA("Model") and model.PrimaryPart then
        return model.PrimaryPart
    end

    return model:FindFirstChildWhichIsA("BasePart", true)
end

local function getDirectMonarchPrompt(model: Instance): ProximityPrompt?
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp then
        local anchor = hrp:FindFirstChild("ArisePromptAnchor")
        if anchor then
            local prompt = anchor:FindFirstChild("MonarchArise")
            if prompt and prompt:IsA("ProximityPrompt") then
                return prompt
            end
        end
    end

    local fallback = model:FindFirstChild("MonarchArise", true)
    if fallback and fallback:IsA("ProximityPrompt") then
        return fallback
    end

    return nil
end

local function isValidTarget(model: Instance?, folder: Instance?): boolean
    if not model or not folder then return false end
    if not model:IsDescendantOf(folder) then return false end
    return getTargetPivotPart(model) ~= nil
end

local function acquireNextTarget(folder: Instance): Instance?
    local children = folder:GetChildren()
    local validModels = {}

    for _, child in ipairs(children) do
        if getTargetPivotPart(child) ~= nil then
            table.insert(validModels, child)
        end
    end

    table.sort(validModels, function(a, b)
        return a.Name < b.Name
    end)

    return validModels[1]
end

-- ==========================================
-- 5. EXECUTION: TELEPORT & STREAMLINED ARISE
-- ==========================================

local function teleportToPart(targetPart: BasePart)
    local character = LocalPlayer.Character
    if not character then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not rootPart then return end

    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero

    local targetPos = targetPart.Position
    local standPos = targetPos + State.TeleOffset
    rootPart.CFrame = CFrame.lookAt(standPos, targetPos)
end

local function unlockPromptProperties(prompt: ProximityPrompt)
    prompt.Enabled = true
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 50
    prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
end

local function triggerOptimizedArise(model: Instance)
    local prompt = getDirectMonarchPrompt(model)
    local keyToPress = Enum.KeyCode.E
    local holdTime = 0.12

    if prompt then
        unlockPromptProperties(prompt)
        if prompt.KeyboardKeyCode ~= Enum.KeyCode.Unknown then
            keyToPress = prompt.KeyboardKeyCode
        end
        if prompt.HoldDuration > 0 then
            holdTime = prompt.HoldDuration + 0.05
        end
        PromptStatusLabel.Text = string.format("Arise: Đã nhấn [%s] -> %s", keyToPress.Name, prompt.Name)
    else
        PromptStatusLabel.Text = "Arise: Đã nhấn [E] (Mặc định)"
    end

    task.spawn(function()
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, keyToPress, false, game)
            task.wait(holdTime)
            VirtualInputManager:SendKeyEvent(false, keyToPress, false, game)
        end)
    end)
end

-- ==========================================
-- 6. MAIN RUNTIME LOOP
-- ==========================================

local mainLoopConnection: RBXScriptConnection? = nil

mainLoopConnection = RunService.Heartbeat:Connect(function()
    if not State.IsRunning then return end

    local now = os.clock()

    -- Kiểm tra xung nhịp Anti-AFK định kỳ (mỗi 5 phút) ngay cả khi đang chờ Model xuất hiện
    if State.AntiAFK and (now - State.LastAfkPulse >= State.AfkPulseInterval) then
        State.LastAfkPulse = now
        performPeriodicAntiAFK()
    end

    local folder = getMapEffectsFolder()
    if not folder then
        StatusLabel.Text = "Target: Không tìm thấy MapEffects"
        return
    end

    if not isValidTarget(State.CurrentTarget, folder) then
        State.CurrentTarget = acquireNextTarget(folder)
    end

    local currentModel = State.CurrentTarget
    if not currentModel then
        if State.AutoTele or State.AutoArise then
            StatusLabel.Text = "Target: Đang chờ Model xuất hiện..."
        end
        return
    end

    StatusLabel.Text = "Target: " .. currentModel.Name

    local activePrompt = getDirectMonarchPrompt(currentModel)
    if activePrompt then
        unlockPromptProperties(activePrompt)
    end

    if State.AutoTele then
        local targetPart = getTargetPivotPart(currentModel)
        if targetPart then
            teleportToPart(targetPart)
        end
    end

    if State.AutoArise then
        if now - State.LastAriseTime >= State.AriseInterval then
            State.LastAriseTime = now
            triggerOptimizedArise(currentModel)
        end
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    State.IsRunning = false
    State.AutoTele = false
    State.AutoArise = false
    State.AntiAFK = false
    if mainLoopConnection then
        mainLoopConnection:Disconnect()
    end
    if dragConnection then
        dragConnection:Disconnect()
    end
    if idledConnection then
        idledConnection:Disconnect()
    end
    ScreenGui:Destroy()
end)
