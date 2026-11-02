--[[
    LotusHub | Auto Meta Account
    Standalone UI + verified Auto Active AutoPlay module.

    Evidence notes:
    VERIFIED (capture supplied):
      ReplicatedStorage.AV_GAME_AUTOPLAY_V1_BLINK_RELIABLE_REMOTE
      payload: buffer.fromstring("\000")
    CANDIDATE (GUI path supplied; runtime Text/ClassName still needs confirmation):
      PlayerGui.Guides.List.MatchStatusHUD.Buttons.AutoPlay.DisplayText
      "Auto Play" = OFF, "Auto Playing" = ON
    MISSING:
      Start button GUI path / reliable Stage-entry discriminator;
      Replay/Next and Teleport remotes + state conditions;
      implementation evidence for the specialist quest modules.

    This script deliberately does not invent missing remotes or GUI paths.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ENV = (type(getgenv) == "function" and getgenv()) or _G
local SESSION_KEY = "__LotusHub_MainSession"

-- Stop an older copy before creating a new one.
if type(ENV[SESSION_KEY]) == "table" and ENV[SESSION_KEY].Stop then
    pcall(ENV[SESSION_KEY].Stop)
end

local Session = { Active = true, AutoPlay = false, StartGame = false, ExecuteAt = os.clock(), Connections = {}, Threads = {} }
ENV[SESSION_KEY] = Session

local function trackConnection(connection)
    table.insert(Session.Connections, connection)
    return connection
end

local function disconnectAll()
    for _, connection in ipairs(Session.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Session.Connections)
end

local function stopSession()
    if not Session.Active then return end
    Session.Active = false
    Session.AutoPlay = false
    Session.StartGame = false
    disconnectAll()
    if ENV[SESSION_KEY] == Session then ENV[SESSION_KEY] = nil end
end
Session.Stop = stopSession

local COLORS = {
    Background = Color3.fromRGB(13, 15, 19),
    Panel = Color3.fromRGB(23, 26, 32),
    Panel2 = Color3.fromRGB(30, 33, 40),
    Stroke = Color3.fromRGB(83, 89, 101),
    Silver = Color3.fromRGB(190, 196, 208),
    White = Color3.fromRGB(235, 238, 244),
    Muted = Color3.fromRGB(145, 152, 166),
    Accent = Color3.fromRGB(177, 185, 199),
    On = Color3.fromRGB(205, 211, 222),
    Off = Color3.fromRGB(63, 68, 78),
}

local function create(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    create("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function stroke(parent, color, transparency, thickness)
    create("UIStroke", {
        Color = color or COLORS.Stroke,
        Transparency = transparency or 0.45,
        Thickness = thickness or 1,
    }, parent)
end

local oldGui = PlayerGui:FindFirstChild("LotusHubUI")
if oldGui then oldGui:Destroy() end

local Screen = create("ScreenGui", {
    Name = "LotusHubUI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

local Main = create("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(780, 520),
    BackgroundColor3 = COLORS.Background,
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
}, Screen)
corner(Main, 18)
stroke(Main, COLORS.Silver, 0.28, 1.25)

local Scale = create("UIScale", { Scale = 1 }, Main)
local function updateScale()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    Scale.Scale = math.clamp(math.min(viewport.X / 900, viewport.Y / 650), 0.62, 1)
end
updateScale()

-- Header
local Header = create("Frame", {
    Name = "Header", Size = UDim2.new(1, 0, 0, 76),
    BackgroundColor3 = Color3.fromRGB(18, 20, 25),
    BackgroundTransparency = 0.08, BorderSizePixel = 0,
}, Main)
corner(Header, 18)
create("Frame", {
    Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18),
    BackgroundColor3 = Color3.fromRGB(18, 20, 25), BorderSizePixel = 0,
}, Header)
create("TextLabel", {
    Name = "Brand", Position = UDim2.fromOffset(25, 12), Size = UDim2.fromOffset(260, 32),
    BackgroundTransparency = 1, Text = "LotusHub", Font = Enum.Font.GothamBold,
    TextSize = 25, TextColor3 = COLORS.White, TextXAlignment = Enum.TextXAlignment.Left,
}, Header)
create("TextLabel", {
    Position = UDim2.fromOffset(27, 43), Size = UDim2.fromOffset(250, 20),
    BackgroundTransparency = 1, Text = "Auto Meta Account", Font = Enum.Font.Gotham,
    TextSize = 13, TextColor3 = COLORS.Muted, TextXAlignment = Enum.TextXAlignment.Left,
}, Header)

local function headerButton(text, x, callback)
    local button = create("TextButton", {
        Position = UDim2.new(1, x, 0, 15), Size = UDim2.fromOffset(34, 34),
        BackgroundTransparency = 1, Text = text, Font = Enum.Font.Gotham,
        TextSize = 21, TextColor3 = COLORS.Silver, AutoButtonColor = false,
    }, Header)
    button.MouseButton1Click:Connect(callback)
    return button
end
local minimized = false
local normalSize = UDim2.fromOffset(780, 520)
local compactSize = UDim2.fromOffset(650, 440)

local RestoreChip = create("TextButton", {
    Name = "RestoreChip", AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 18, 1, -18), Size = UDim2.fromOffset(150, 42),
    BackgroundColor3 = COLORS.Panel, BackgroundTransparency = 0.05,
    BorderSizePixel = 0, Text = "LotusHub  +",
    Font = Enum.Font.GothamSemibold, TextSize = 14,
    TextColor3 = COLORS.White, Visible = false, AutoButtonColor = true,
}, Screen)
corner(RestoreChip, 12)
stroke(RestoreChip, COLORS.Silver, 0.25, 1)

local function restoreWindow()
    minimized = false
    Main.Visible = true
    Main.Size = normalSize
    RestoreChip.Visible = false
    updateScale()
end
RestoreChip.MouseButton1Click:Connect(restoreWindow)

headerButton("—", -116, function()
    minimized = true
    Main.Visible = false
    RestoreChip.Visible = true
end)
headerButton("□", -72, function()
    Main.Size = Main.Size == normalSize and compactSize or normalSize
    updateScale()
end)
headerButton("×", -34, function()
    stopSession()
    Screen:Destroy()
end)

-- Drag window from header.
do
    local dragging, dragStart, startPos = false, nil, nil
    trackConnection(Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, Main.Position
        end
    end))
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
    trackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
end

local Sidebar = create("Frame", {
    Position = UDim2.fromOffset(0, 77), Size = UDim2.new(0, 215, 1, -77),
    BackgroundColor3 = Color3.fromRGB(17, 19, 24), BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
}, Main)
create("Frame", { Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = COLORS.Stroke, BackgroundTransparency = 0.55, BorderSizePixel = 0 }, Sidebar)

local Content = create("Frame", {
    Position = UDim2.fromOffset(216, 77), Size = UDim2.new(1, -216, 1, -77),
    BackgroundTransparency = 1,
}, Main)

local NavList = create("Frame", { Position = UDim2.fromOffset(12, 18), Size = UDim2.new(1, -24, 1, -36), BackgroundTransparency = 1 }, Sidebar)
create("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, NavList)

local pages = {
    { name = "\1" },
    { name = "\1" },
    { name = "\1" },
    { name = "\1" },
    { name = "\1" },
    { name = "\1" },
}

local pageFrames, navButtons = {}, {}
local function setPage(name)
    for pageName, frame in pairs(pageFrames) do frame.Visible = pageName == name end
    for pageName, button in pairs(navButtons) do
        local selected = pageName == name
        button.BackgroundColor3 = selected and Color3.fromRGB(48, 51, 60) or COLORS.Panel
        button.BackgroundTransparency = selected and 0.08 or 1
        button.TextColor3 = selected and COLORS.White or COLORS.Muted
        local bar = button:FindFirstChild("SelectedBar")
        if bar then bar.Visible = selected end
    end
end

for index, page in ipairs(pages) do
    local nav = create("TextButton", {
        Name = "Nav_" .. index, Size = UDim2.new(1, 0, 0, 54),
        BackgroundColor3 = COLORS.Panel, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false,
        Text = page.name, Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = COLORS.Muted, TextWrapped = true,
    }, NavList)
    corner(nav, 10)
    local bar = create("Frame", { Name = "SelectedBar", Position = UDim2.fromOffset(0, 7), Size = UDim2.new(0, 3, 1, -14), BackgroundColor3 = COLORS.Silver, BorderSizePixel = 0, Visible = false }, nav)
    corner(bar, 3)
    navButtons[page.name] = nav
    nav.MouseButton1Click:Connect(function() setPage(page.name) end)

    local pageFrame = create("ScrollingFrame", {
        Name = "Page_" .. index, Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = COLORS.Silver,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, Content)
    create("UIPadding", { PaddingTop = UDim.new(0, 22), PaddingLeft = UDim.new(0, 24), PaddingRight = UDim.new(0, 22), PaddingBottom = UDim.new(0, 20) }, pageFrame)
    create("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, pageFrame)
    pageFrames[page.name] = pageFrame

    create("TextLabel", {
        Size = UDim2.new(1, -4, 0, 38), BackgroundTransparency = 1,
        Text = page.name, Font = Enum.Font.GothamBold, TextSize = 27,
        TextColor3 = COLORS.White, TextXAlignment = Enum.TextXAlignment.Left,
    }, pageFrame)
    create("Frame", { Size = UDim2.new(1, -4, 0, 1), BackgroundColor3 = COLORS.Stroke, BackgroundTransparency = 0.45, BorderSizePixel = 0 }, pageFrame)
end

local function addInfo(pageName, title, status)
    local parent = pageFrames[pageName]
    local row = create("Frame", {
        Size = UDim2.new(1, -4, 0, 62), BackgroundColor3 = COLORS.Panel2,
        BackgroundTransparency = 0.13, BorderSizePixel = 0,
    }, parent)
    corner(row, 12); stroke(row, COLORS.Stroke, 0.62, 1)
    create("TextLabel", {
        Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -155, 1, 0),
        BackgroundTransparency = 1, Text = title, Font = Enum.Font.GothamSemibold,
        TextSize = 15, TextColor3 = COLORS.White, TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -17, 0.5, 0),
        Size = UDim2.fromOffset(115, 28), BackgroundTransparency = 1,
        Text = status, Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = COLORS.Muted, TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    return row
end

local function addToggle(pageName, title, initial, callback)
    local parent = pageFrames[pageName]
    local row = create("Frame", {
        Size = UDim2.new(1, -4, 0, 66), BackgroundColor3 = COLORS.Panel2,
        BackgroundTransparency = 0.13, BorderSizePixel = 0,
    }, parent)
    corner(row, 12); stroke(row, COLORS.Stroke, 0.62, 1)
    create("TextLabel", {
        Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -110, 1, 0),
        BackgroundTransparency = 1, Text = title, Font = Enum.Font.GothamSemibold,
        TextSize = 15, TextColor3 = COLORS.White, TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local toggle = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0),
        Size = UDim2.fromOffset(52, 27), BackgroundColor3 = initial and COLORS.On or COLORS.Off,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
    }, row)
    corner(toggle, 20)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = initial and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.fromOffset(19, 19), BackgroundColor3 = initial and Color3.fromRGB(28, 31, 37) or COLORS.Silver,
        BorderSizePixel = 0,
    }, toggle)
    corner(knob, 20)
    local enabled = initial == true
    local busy = false
    local function render()
        TweenService:Create(toggle, TweenInfo.new(0.14), { BackgroundColor3 = enabled and COLORS.On or COLORS.Off }):Play()
        TweenService:Create(knob, TweenInfo.new(0.14), {
            Position = enabled and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 4, 0.5, 0),
            BackgroundColor3 = enabled and Color3.fromRGB(28, 31, 37) or COLORS.Silver,
        }):Play()
    end
    toggle.MouseButton1Click:Connect(function()
        if busy or not Session.Active then return end
        enabled = not enabled
        render()
        if callback then
            busy = true
            local ok, err = pcall(callback, enabled)
            busy = false
            if not ok then warn("[LotusHub] " .. tostring(err)) end
        end
    end)
    return {
        Set = function(value) enabled = value == true; render() end,
        Get = function() return enabled end,
    }
end

-- Gameplay: StartGame uses the captured remote after a fixed 10-second delay.
local startGameRemote = ReplicatedStorage:FindFirstChild("AV_GAME_WAVES_V1_BLINK_RELIABLE_REMOTE")
local startGameAvailable = startGameRemote ~= nil
    and startGameRemote:IsA("RemoteEvent")
    and type(buffer) == "table"
    and type(buffer.fromstring) == "function"

local startGameToggle
local function runStartGameLoop()
    task.spawn(function()
        while Session.Active and Session.StartGame and os.clock() - Session.ExecuteAt < 10 do
            task.wait(0.1)
        end
        if not (Session.Active and Session.StartGame) then return end

        while Session.Active and Session.StartGame do
            local ok, err = pcall(function()
                startGameRemote:FireServer(buffer.fromstring("\\002"))
            end)
            if not ok then warn("[LotusHub] StartGame remote error: " .. tostring(err)) end
            task.wait(1)
        end
    end)
end

startGameToggle = addToggle("Gameplay", "Auto StartGame", false, function(enabled)
    Session.StartGame = enabled
    if enabled then
        if not startGameAvailable then
            warn("[LotusHub] StartGame RemoteEvent or buffer API unavailable.")
            Session.StartGame = false
            startGameToggle.Set(false)
            return
        end
        runStartGameLoop()
    end
end)

local autoPlayRemote = ReplicatedStorage:FindFirstChild("AV_GAME_AUTOPLAY_V1_BLINK_RELIABLE_REMOTE")
local autoPlayAvailable = autoPlayRemote ~= nil and autoPlayRemote:IsA("RemoteEvent") and type(buffer) == "table" and type(buffer.fromstring) == "function"

local function readAutoPlayState()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then return "UNKNOWN" end
    local names = { "Guides", "List", "MatchStatusHUD", "Buttons", "AutoPlay", "DisplayText" }
    local node = gui
    for _, name in ipairs(names) do
        node = node:FindFirstChild(name)
        if not node then return "UNKNOWN" end
    end
    if not (node:IsA("TextLabel") or node:IsA("TextButton")) then return "UNKNOWN" end
    local value = node.Text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "Auto Playing" then return "ON" end
    if value == "Auto Play" then return "OFF" end
    return "UNKNOWN"
end

local autoPlayToggle
local function runAutoPlayMonitor()
    task.spawn(function()
        while Session.Active and Session.AutoPlay do
            local state = readAutoPlayState()
            if state == "OFF" and autoPlayAvailable then
                -- Re-check immediately before firing; never click on UNKNOWN.
                if Session.Active and Session.AutoPlay and readAutoPlayState() == "OFF" then
                    local ok, err = pcall(function()
                        autoPlayRemote:FireServer(buffer.fromstring("\000"), nil)
                    end)
                    if not ok then warn("[LotusHub] AutoPlay remote error: " .. tostring(err)) end
                end
            end
            task.wait(1)
        end
    end)
end

autoPlayToggle = addToggle("Gameplay", "Auto Active AutoPlay", false, function(enabled)
    Session.AutoPlay = enabled
    if enabled then
        if not autoPlayAvailable then
            warn("[LotusHub] AutoPlay RemoteEvent hoặc buffer API không khả dụng.")
            Session.AutoPlay = false
            autoPlayToggle.Set(false)
            return
        end
        runAutoPlayMonitor()
    end
end)
addInfo("Gameplay", "Auto Replay", "MISSING")
addInfo("Gameplay", "Auto Press Teleport to Lobby", "MISSING")

-- Other categories: show requested modules without pretending they are implemented.
local moduleRows = {
    ["Sung Jin Woo Vanguard"] = {
        {"\1"},
        {"\1"},
        {"\1"},
        {"\1"},
        {"\1"},
    },
    ["True Shadow Monarch"] = {
        {"\1"},
        {"\1"},
        {"\1"},
    },
    ["System And Shadow"] = {
        {"\1"},
        {"\1"},
        {"\1"},
        {"\1"},
    },
    ["Summon"] = {
        {"\1"},
        {"\1"},
        {"\1"},
        {"\1"},
    },
    ["Adventure Odyssey"] = {
        {"\1"},
        {"\1"},
    },
}

for pageName, rows in pairs(moduleRows) do
    for _, item in ipairs(rows) do addInfo(pageName, item[1], "UNTESTED") end
end

setPage("Gameplay")

-- Keep scale responsive when viewport changes.
if workspace.CurrentCamera then
    trackConnection(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
end

print("[LotusHub] UI loaded. StartGame waits 10 seconds, then fires every 1 second while enabled.")
