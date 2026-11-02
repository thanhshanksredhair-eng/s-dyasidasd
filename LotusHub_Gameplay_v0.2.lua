--[[
    LotusHub | Gameplay v0.2
    Independent toggles:
      1) Auto Startgame
      2) Auto Active Auto Play

    Verified captures supplied by the user:
      Start Remote:    AV_GAME_WAVES_V1_BLINK_RELIABLE_REMOTE, buffer "\002"
      AutoPlay Remote: AV_GAME_AUTOPLAY_V1_BLINK_RELIABLE_REMOTE, buffer "\000"
      Notification:    AV_GAME_NOTIFICATIONS_POPUPS_V1_BLINK_RELIABLE_REMOTE

    Important integration note:
      The exact Start button GUI path/class/text has not been captured.
      Auto Startgame therefore uses a conservative candidate scan for a
      visible TextButton whose normalized text is exactly "Start".
      If the game uses another label/class, this part will wait rather
      than sending blind requests.

    AutoPlay:
      Uses the captured Enable/Disable notification strings as acknowledgements.
      The known DisplayText GUI path is also read:
      Auto Playing = ON; Auto Play = OFF; otherwise UNKNOWN.
      UNKNOWN never causes a blind remote call.

    This is a client-side executor script, not a server-side Roblox Script.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ENV = (type(getgenv) == "function" and getgenv()) or _G
local SESSION_KEY = "__LotusHubGameplayV02"

-- Stop an older copy before creating a new session.
local previous = ENV[SESSION_KEY]
if type(previous) == "table" and type(previous.Stop) == "function" then
    pcall(previous.Stop)
end

local CONFIG = {
    StartInitialDelay = 10,
    StartRetryInterval = 1,
    AutoPlayRetryInterval = 1,
    StatePollInterval = 0.15,
    RemoteWaitTimeout = 10,
}

local function getRemote(name)
    local remote = ReplicatedStorage:WaitForChild(name, CONFIG.RemoteWaitTimeout)
    assert(remote and remote:IsA("RemoteEvent"), "RemoteEvent unavailable: " .. name)
    return remote
end

local StartRemote = getRemote("AV_GAME_WAVES_V1_BLINK_RELIABLE_REMOTE")
local AutoPlayRemote = getRemote("AV_GAME_AUTOPLAY_V1_BLINK_RELIABLE_REMOTE")
local NotificationRemote = getRemote("AV_GAME_NOTIFICATIONS_POPUPS_V1_BLINK_RELIABLE_REMOTE")

local session = {
    Alive = true,
    AutoStartEnabled = false,
    AutoPlayEnabled = false,
    StartStatus = "OFF",
    AutoPlayStatus = "OFF",
    NotificationState = "UNKNOWN",
    NotificationVersion = 0,
    LastAction = "Ready",
    Connections = {},
}
ENV[SESSION_KEY] = session

local function log(message)
    print("[LotusHub] " .. tostring(message))
    session.LastAction = tostring(message)
end

local function normalized(text)
    return tostring(text or "")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

local function isGuiObjectVisible(object)
    if not object or not object:IsA("GuiObject") then
        return false
    end

    local current = object
    while current and current ~= PlayerGui do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        current = current.Parent
    end

    return true
end

local function getMatchStatusHUD()
    local guides = PlayerGui:FindFirstChild("Guides")
    local list = guides and guides:FindFirstChild("List")
    local hud = list and list:FindFirstChild("MatchStatusHUD")
    if hud and hud:IsA("GuiObject") and isGuiObjectVisible(hud) then
        return hud
    end
    return nil
end

local function getAutoPlayDisplay()
    local hud = getMatchStatusHUD()
    local buttons = hud and hud:FindFirstChild("Buttons")
    local autoPlay = buttons and buttons:FindFirstChild("AutoPlay")
    local display = autoPlay and autoPlay:FindFirstChild("DisplayText")

    if display and (display:IsA("TextLabel") or display:IsA("TextButton")) then
        return display
    end
    return nil
end

local function readAutoPlayGuiState()
    local display = getAutoPlayDisplay()
    if not display then
        return "UNKNOWN"
    end

    local text = normalized(display.Text)
    if text == "Auto Playing" then
        return "ON"
    elseif text == "Auto Play" then
        return "OFF"
    end

    return "UNKNOWN"
end

-- Candidate detection only: exact visible TextButton label "Start".
local function findVisibleStartButton()
    for _, object in ipairs(PlayerGui:GetDescendants()) do
        if object:IsA("TextButton")
            and isGuiObjectVisible(object)
            and normalized(object.Text) == "Start" then
            return object
        end
    end
    return nil
end

local function fireStart()
    local ok, err = pcall(function()
        StartRemote:FireServer(buffer.fromstring("\002"))
    end)

    if ok then
        log("Auto Startgame: Start remote sent")
    else
        warn("[LotusHub] Start remote error: " .. tostring(err))
        session.StartStatus = "ERROR"
    end
end

local function fireAutoPlay()
    local ok, err = pcall(function()
        AutoPlayRemote:FireServer(buffer.fromstring("\000"))
    end)

    if ok then
        log("Auto Play: activation request sent")
    else
        warn("[LotusHub] AutoPlay remote error: " .. tostring(err))
        session.AutoPlayStatus = "ERROR"
    end
    return ok
end

-- Notification listener is connected once and remains active while toggles change.
session.NotificationConnection = NotificationRemote.OnClientEvent:Connect(function(payload)
    if not session.Alive or typeof(payload) ~= "buffer" then
        return
    end

    local raw = buffer.tostring(payload)
    local lower = string.lower(raw)

    if string.find(lower, "successfully enabled auto play!", 1, true) then
        session.NotificationState = "ON"
        session.NotificationVersion = session.NotificationVersion + 1
        session.AutoPlayStatus = "ON"
        log("Notification confirmed: Auto Play ENABLED")
    elseif string.find(lower, "successfully disabled auto play!", 1, true) then
        session.NotificationState = "OFF"
        session.NotificationVersion = session.NotificationVersion + 1
        session.AutoPlayStatus = "OFF"
        log("Notification confirmed: Auto Play DISABLED")
    end
end)

-- Minimal menu UI.
local oldGui = PlayerGui:FindFirstChild("LotusHubGameplayMenu")
if oldGui then
    oldGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LotusHubGameplayMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui
session.ScreenGui = ScreenGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(300, 218)
Main.Position = UDim2.new(0, 28, 0.35, 0)
Main.BackgroundColor3 = Color3.fromRGB(22, 24, 31)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = Main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(75, 82, 102)
mainStroke.Thickness = 1
mainStroke.Parent = Main

local function makeLabel(parent, name, text, size, position, fontSize, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Size = size
    label.Position = position
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(235, 238, 245)
    label.Font = Enum.Font.Gotham
    label.TextSize = fontSize
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

makeLabel(
    Main, "Title", "LOTUSHUB",
    UDim2.new(1, -24, 0, 27), UDim2.fromOffset(14, 9),
    16, Color3.fromRGB(255, 255, 255)
)

makeLabel(
    Main, "Subtitle", "GAMEPLAY MODULE  |  v0.2",
    UDim2.new(1, -24, 0, 18), UDim2.fromOffset(14, 34),
    9, Color3.fromRGB(145, 154, 174)
)

local function makeToggleButton(name, y, caption)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(1, -28, 0, 38)
    button.Position = UDim2.fromOffset(14, y)
    button.BackgroundColor3 = Color3.fromRGB(55, 59, 72)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.TextColor3 = Color3.fromRGB(245, 247, 250)
    button.Text = caption .. "  [OFF]"
    button.Parent = Main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button
    return button
end

local StartButton = makeToggleButton("AutoStartToggle", 62, "AUTO STARTGAME")
local AutoPlayButton = makeToggleButton("AutoPlayToggle", 108, "AUTO ACTIVE AUTO PLAY")

local Status = makeLabel(
    Main, "Status",
    "Start: OFF   |   Auto Play: OFF",
    UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, 154),
    10, Color3.fromRGB(190, 198, 214)
)

local Detail = makeLabel(
    Main, "Detail",
    "Ready",
    UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 174),
    9, Color3.fromRGB(137, 148, 169)
)
Detail.TextWrapped = true

local function updateMenu()
    if not ScreenGui.Parent then
        return
    end

    StartButton.Text = "AUTO STARTGAME  [" .. (session.AutoStartEnabled and "ON" or "OFF") .. "]"
    StartButton.BackgroundColor3 = session.AutoStartEnabled
        and Color3.fromRGB(35, 125, 83)
        or Color3.fromRGB(55, 59, 72)

    AutoPlayButton.Text = "AUTO ACTIVE AUTO PLAY  [" .. (session.AutoPlayEnabled and "ON" or "OFF") .. "]"
    AutoPlayButton.BackgroundColor3 = session.AutoPlayEnabled
        and Color3.fromRGB(35, 125, 83)
        or Color3.fromRGB(55, 59, 72)

    Status.Text = "Start: " .. session.StartStatus .. "   |   Auto Play: " .. session.AutoPlayStatus
    Detail.Text = session.LastAction
end

-- Drag menu by its header area.
local dragging = false
local dragInput
local dragStart
local startPosition

Main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = Main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

table.insert(session.Connections, UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end))

StartButton.MouseButton1Click:Connect(function()
    session.AutoStartEnabled = not session.AutoStartEnabled
    session.StartStatus = session.AutoStartEnabled and "WAITING" or "OFF"
    log(session.AutoStartEnabled and "Auto Startgame enabled" or "Auto Startgame disabled")
    updateMenu()
end)

AutoPlayButton.MouseButton1Click:Connect(function()
    session.AutoPlayEnabled = not session.AutoPlayEnabled
    session.AutoPlayStatus = session.AutoPlayEnabled and "MONITORING" or "OFF"
    if session.AutoPlayEnabled then
        session.NotificationState = "UNKNOWN"
        log("Auto Active Auto Play enabled")
    else
        log("Auto Active Auto Play disabled; game Auto Play state is unchanged")
    end
    updateMenu()
end)

-- Auto Startgame:
-- Wait 10 seconds after a visible candidate Start button is first detected,
-- then send every 1 second while that button remains visible.
task.spawn(function()
    local trackedButton = nil

    while session.Alive do
        if not session.AutoStartEnabled then
            trackedButton = nil
            session.StartStatus = "OFF"
            task.wait(0.2)
        else
            local button = findVisibleStartButton()

            if not button then
                trackedButton = nil
                session.StartStatus = "WAITING FOR START BUTTON"
                task.wait(0.2)
            elseif button ~= trackedButton then
                trackedButton = button
                session.StartStatus = "10S DELAY"
                log("Start button detected; waiting 10 seconds")

                local deadline = os.clock() + CONFIG.StartInitialDelay
                while session.Alive
                    and session.AutoStartEnabled
                    and os.clock() < deadline
                    and findVisibleStartButton() do
                    task.wait(0.1)
                end

                if session.Alive
                    and session.AutoStartEnabled
                    and findVisibleStartButton() then
                    session.StartStatus = "RUNNING"
                    while session.Alive and session.AutoStartEnabled do
                        local currentButton = findVisibleStartButton()
                        if not currentButton then
                            log("Start button disappeared; Auto Startgame paused")
                            break
                        end

                        fireStart()
                        session.StartStatus = "RUNNING"
                        local untilTime = os.clock() + CONFIG.StartRetryInterval
                        while session.Alive
                            and session.AutoStartEnabled
                            and os.clock() < untilTime do
                            task.wait(0.1)
                        end
                    end
                end

                trackedButton = nil
            else
                task.wait(0.2)
            end
        end
    end
end)

-- Auto Active Auto Play:
-- Independent from Auto Startgame; begins monitoring as soon as Stage HUD exists.
-- A click/request is never sent when GUI state is UNKNOWN.
task.spawn(function()
    local wasInStage = false

    while session.Alive do
        if not session.AutoPlayEnabled then
            session.AutoPlayStatus = "OFF"
            wasInStage = false
            task.wait(0.2)
        else
            local hud = getMatchStatusHUD()
            local display = getAutoPlayDisplay()
            local inStage = hud ~= nil and display ~= nil

            if not inStage then
                wasInStage = false
                session.AutoPlayStatus = "WAITING FOR STAGE"
                task.wait(0.2)
            else
                if not wasInStage then
                    wasInStage = true
                    session.NotificationState = "UNKNOWN"
                    session.AutoPlayStatus = "MONITORING"
                    log("Stage detected; Auto Play monitor started")
                end

                local guiState = readAutoPlayGuiState()
                local effectiveState = guiState

                if session.NotificationState == "ON" then
                    effectiveState = "ON"
                elseif session.NotificationState == "OFF" then
                    effectiveState = "OFF"
                end

                if effectiveState == "ON" then
                    session.AutoPlayStatus = "ON"
                    task.wait(CONFIG.StatePollInterval)
                elseif effectiveState == "OFF" then
                    session.AutoPlayStatus = "ACTIVATING"
                    local versionBefore = session.NotificationVersion
                    local sent = fireAutoPlay()

                    if sent then
                        local deadline = os.clock() + CONFIG.AutoPlayRetryInterval
                        local acknowledged = false

                        while session.Alive
                            and session.AutoPlayEnabled
                            and os.clock() < deadline do

                            if session.NotificationState == "ON" then
                                acknowledged = true
                                break
                            end

                            -- A Disable notification is an acknowledgement that
                            -- the request was processed, but it means retry.
                            -- Keep the full 1-second interval before the next request.
                            if session.NotificationVersion ~= versionBefore
                                and session.NotificationState == "OFF" then
                                acknowledged = true
                            end

                            local latestGuiState = readAutoPlayGuiState()
                            if latestGuiState == "ON" then
                                session.NotificationState = "ON"
                                session.AutoPlayStatus = "ON"
                                acknowledged = true
                                break
                            end

                            if not getMatchStatusHUD() then
                                break
                            end

                            task.wait(0.1)
                        end

                        if session.NotificationState == "ON" then
                            session.AutoPlayStatus = "ON"
                        elseif session.NotificationState == "OFF" then
                            session.AutoPlayStatus = "OFF"
                        elseif not acknowledged then
                            session.AutoPlayStatus = "RETRYING"
                        end
                    end
                else
                    session.AutoPlayStatus = "UNKNOWN - NO REQUEST"
                    task.wait(CONFIG.StatePollInterval)
                end
            end
        end

        updateMenu()
        task.wait(0.05)
    end
end)

-- Menu/status refresh.
task.spawn(function()
    while session.Alive do
        updateMenu()
        task.wait(0.2)
    end
end)

function session.Stop()
    if not session.Alive then
        return
    end

    session.Alive = false
    session.AutoStartEnabled = false
    session.AutoPlayEnabled = false

    if session.NotificationConnection then
        pcall(function()
            session.NotificationConnection:Disconnect()
        end)
        session.NotificationConnection = nil
    end

    for _, connection in ipairs(session.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    if session.ScreenGui then
        pcall(function()
            session.ScreenGui:Destroy()
        end)
    end

    if ENV[SESSION_KEY] == session then
        ENV[SESSION_KEY] = nil
    end

    log("LotusHub stopped")
end

log("Menu loaded. Both toggles are OFF.")
updateMenu()
