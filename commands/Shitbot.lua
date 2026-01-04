-- Local Script: Place in StarterPlayerScripts or execute
-- Features: FOV Circle, Aim Assist, ESP, Teleport, Team Checks, Camera FOV, Auto Dodge
-- UI: Dollarware Library with Addon Support + Warning System

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Teams = game:GetService("Teams")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Script state
local ScriptLoaded = true
local Connections = {}
local CharacterConnections = {}

-- Store default camera FOV
local DefaultCameraFOV = 70

-- Bullet tracking
local TrackedBullets = {}
local LastDodgeTime = 0
local DodgeCooldown = 0.15

-- Aim tracking
local LastTargetPlayer = nil
local CachedScreenCenter = Vector2.new(0, 0)

-- Settings
local Settings = {
    -- Aim Assist
    AimEnabled = true,
    AimFOVRadius = 150,
    Smoothness = 0.3,
    AimPart = "Head",
    Prediction = true,
    PredictionAmount = 0.12,
    HeadshotChance = 70,
    BodyshotChance = 30,
    
    -- Advanced Aim Settings
    SmoothingType = "Linear", -- "Linear", "Ease-In", "Ease-Out", "Sigmoid"
    StickyTargetEnabled = true,
    StickyTargetMultiplier = 1.15, -- 15% larger FOV for current target
    HumanizeAim = true,
    DynamicSmoothing = true,
    
    -- Camera FOV
    CameraFOV = 70,
    CameraFOVEnabled = false,
    
    -- Auto Dodge Settings
    AutoDodgeEnabled = true,
    DodgeRadius = 50,
    DodgeDistance = 4,
    DodgeSmoothness = 0.3,
    DodgeNames = {"bullet", "Bullet", "BULLET", "projectile", "Projectile", "rocket", "Rocket", "arrow", "Arrow", "shot", "Shot", "shell", "Shell", "missile", "Missile", "grenade", "Grenade", "knife", "Knife", "shuriken", "kunai"},
    
    -- Team Settings
    TeamCheck = true,
    ShowTeammates = true,
    BlueBillboardTeamCheck = false,
    RedBillboardTeamCheck = false,
    
    -- ESP
    ESPEnabled = true,
    ShowBoxes = true,
    ShowNames = true,
    ShowDistance = true,
    ShowSkeleton = true,
    ShowHealthBar = true,
    ShowTracers = false,
    ShowAimFOV = true,
    BoxStyle = "Corners", -- "Full", "Corners"
    ShowTextBackgrounds = true,
    DistanceFade = true,
    
    -- Colors (Cherry Theme - Matching Dollarware UI)
    FOVColor = Color3.fromRGB(200, 200, 200),
    FOVColorActive = Color3.fromRGB(170, 50, 60), -- Cherry when aiming
    
    -- Enemy Colors (Cherry Red Theme)
    EnemyColor = Color3.fromRGB(255, 75, 85), -- Bright cherry red
    EnemyColorSecondary = Color3.fromRGB(170, 50, 60), -- Dollarware accent
    
    -- Teammate Colors (Cyan/Blue Theme)
    TeammateColor = Color3.fromRGB(85, 200, 255), -- Bright cyan
    TeammateColorSecondary = Color3.fromRGB(60, 140, 200), -- Darker blue
    
    -- Text Colors
    NameColor = Color3.fromRGB(255, 255, 255),
    TextBackgroundColor = Color3.fromRGB(20, 20, 20),
    
    -- Skeleton Colors
    SkeletonColor = Color3.fromRGB(255, 100, 255), -- Bright magenta
    TeamSkeletonColor = Color3.fromRGB(85, 200, 255), -- Cyan
    
    -- Health Colors (Gradient)
    HealthFullColor = Color3.fromRGB(85, 255, 100),
    HealthMidColor = Color3.fromRGB(255, 200, 0),
    HealthLowColor = Color3.fromRGB(255, 75, 85),
    
    -- Tracer Colors
    TracerColor = Color3.fromRGB(255, 75, 85), -- Cherry
    TeamTracerColor = Color3.fromRGB(85, 200, 255), -- Cyan
    
    TargetColor = Color3.fromRGB(255, 75, 85),
    HealthBarColor = Color3.fromRGB(85, 255, 100),
    
    -- Addon Settings
    TrustedAddons = {}
}

-- ==================== SETTINGS SAVE/LOAD SYSTEM ====================
local HttpService = game:GetService("HttpService")
local SETTINGS_FILE = "ShitbotV6_Settings.json"

-- Convert Color3 to saveable format
local function Color3ToTable(color)
    return {R = color.R, G = color.G, B = color.B}
end

-- Convert table back to Color3
local function TableToColor3(tbl)
    if tbl and tbl.R and tbl.G and tbl.B then
        return Color3.new(tbl.R, tbl.G, tbl.B)
    end
    return nil
end

-- Save settings to file
local function SaveSettings()
    -- Check if writefile exists (executor support)
    if not writefile then
        warn("[Shitbot] writefile not available - settings cannot be saved")
        return false
    end
    
    local success, err = pcall(function()
        -- Create saveable copy of settings
        local saveData = {}
        
        for key, value in pairs(Settings) do
            if typeof(value) == "Color3" then
                saveData[key] = {_type = "Color3", value = Color3ToTable(value)}
            elseif typeof(value) == "table" then
                -- Handle tables (like TrustedAddons, DodgeNames)
                saveData[key] = {_type = "table", value = value}
            elseif typeof(value) == "boolean" or typeof(value) == "number" or typeof(value) == "string" then
                saveData[key] = value
            end
        end
        
        local json = HttpService:JSONEncode(saveData)
        writefile(SETTINGS_FILE, json)
    end)
    
    if success then
        print("[Shitbot] Settings saved to " .. SETTINGS_FILE)
        return true
    else
        warn("[Shitbot] Failed to save settings: " .. tostring(err))
        return false
    end
end

-- Load settings from file
local function LoadSettings()
    -- Check if readfile and isfile exist (executor support)
    if not readfile or not isfile then
        warn("[Shitbot] readfile/isfile not available - cannot load settings")
        return false
    end
    
    if not isfile(SETTINGS_FILE) then
        print("[Shitbot] No saved settings found, using defaults")
        return false
    end
    
    local success, err = pcall(function()
        local json = readfile(SETTINGS_FILE)
        local saveData = HttpService:JSONDecode(json)
        
        local loadedCount = 0
        for key, value in pairs(saveData) do
            if typeof(value) == "table" and value._type then
                if value._type == "Color3" then
                    local color = TableToColor3(value.value)
                    if color then
                        Settings[key] = color
                        loadedCount = loadedCount + 1
                    end
                elseif value._type == "table" then
                    Settings[key] = value.value
                    loadedCount = loadedCount + 1
                end
            elseif typeof(value) == "boolean" or typeof(value) == "number" or typeof(value) == "string" then
                Settings[key] = value
                loadedCount = loadedCount + 1
            end
        end
        
        print("[Shitbot] Settings loaded successfully (" .. loadedCount .. " settings)")
    end)
    
    if not success then
        warn("[Shitbot] Failed to load settings: " .. tostring(err))
        return false
    end
    return true
end

-- Auto-save settings periodically
local function StartAutoSave()
    task.spawn(function()
        while ScriptLoaded do
            task.wait(30) -- Save every 30 seconds
            if ScriptLoaded then
                local saved = SaveSettings()
                if saved then
                    print("[Shitbot] Auto-saved settings")
                end
            end
        end
    end)
end

-- Load settings on startup
local settingsLoaded = LoadSettings()

-- Start auto-save
StartAutoSave()

-- Load Dollarware UI
local uiLoader = loadstring(game:HttpGet('https://raw.githubusercontent.com/topitbopit/dollarware/main/library.lua'))
local ui = uiLoader({
    rounding = true,
    theme = 'cherry',
    smoothDragging = true
})

ui.autoDisableToggles = true

-- ==================== ADDON WARNING SYSTEM ====================

-- Dollarware style colors
local DollarwareColors = {
    Background = Color3.fromRGB(20, 20, 20),
    Section = Color3.fromRGB(28, 28, 28),
    Border = Color3.fromRGB(45, 45, 45),
    Text = Color3.fromRGB(200, 200, 200),
    TextDim = Color3.fromRGB(140, 140, 140),
    Accent = Color3.fromRGB(170, 50, 60), -- Cherry red
    AccentHover = Color3.fromRGB(200, 60, 70),
    ButtonBg = Color3.fromRGB(35, 35, 35),
    ButtonHover = Color3.fromRGB(45, 45, 45),
    ToggleOff = Color3.fromRGB(50, 50, 50),
    ToggleOn = Color3.fromRGB(170, 50, 60)
}

-- Function to create warning popup matching Dollarware style
local function ShowAddonWarning(addonInfo)
    local accepted = false
    local declined = false
    local trustAddon = false
    local countdown = 5
    
    -- Create ScreenGui
    local WarningGui = Instance.new("ScreenGui")
    WarningGui.Name = "ShitbotAddonWarning"
    WarningGui.ResetOnSpawn = false
    WarningGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    WarningGui.DisplayOrder = 999
    WarningGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Main window frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "WarningWindow"
    mainFrame.Size = UDim2.new(0, 420, 0, 320)
    mainFrame.Position = UDim2.new(0.5, -210, 0.5, -160)
    mainFrame.BackgroundColor3 = DollarwareColors.Background
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = WarningGui
    
    -- Window border
    local mainBorder = Instance.new("UIStroke")
    mainBorder.Color = DollarwareColors.Border
    mainBorder.Thickness = 1
    mainBorder.Parent = mainFrame
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 24)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = DollarwareColors.Background
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleIcon = Instance.new("TextLabel")
    titleIcon.Size = UDim2.new(0, 20, 0, 24)
    titleIcon.Position = UDim2.new(0, 6, 0, 0)
    titleIcon.BackgroundTransparency = 1
    titleIcon.Text = "⚠"
    titleIcon.TextColor3 = DollarwareColors.Accent
    titleIcon.TextSize = 14
    titleIcon.Font = Enum.Font.SourceSans
    titleIcon.Parent = titleBar
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -80, 0, 24)
    titleText.Position = UDim2.new(0, 26, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "addon warning"
    titleText.TextColor3 = DollarwareColors.Text
    titleText.TextSize = 13
    titleText.Font = Enum.Font.SourceSans
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar
    
    -- Close button area (just visual, clicking decline closes)
    local closeArea = Instance.new("Frame")
    closeArea.Size = UDim2.new(0, 46, 0, 24)
    closeArea.Position = UDim2.new(1, -46, 0, 0)
    closeArea.BackgroundTransparency = 1
    closeArea.Parent = titleBar
    
    local closeBtn = Instance.new("TextLabel")
    closeBtn.Size = UDim2.new(0, 23, 0, 24)
    closeBtn.Position = UDim2.new(1, -23, 0, 0)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "×"
    closeBtn.TextColor3 = DollarwareColors.TextDim
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.SourceSans
    closeBtn.Parent = closeArea
    
    -- Title underline
    local titleLine = Instance.new("Frame")
    titleLine.Size = UDim2.new(1, 0, 0, 1)
    titleLine.Position = UDim2.new(0, 0, 0, 24)
    titleLine.BackgroundColor3 = DollarwareColors.Border
    titleLine.BorderSizePixel = 0
    titleLine.Parent = mainFrame
    
    -- Content area
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -16, 1, -32)
    content.Position = UDim2.new(0, 8, 0, 28)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame
    
    -- Left section
    local leftSection = Instance.new("Frame")
    leftSection.Name = "LeftSection"
    leftSection.Size = UDim2.new(0.5, -4, 1, 0)
    leftSection.Position = UDim2.new(0, 0, 0, 0)
    leftSection.BackgroundColor3 = DollarwareColors.Section
    leftSection.BorderSizePixel = 0
    leftSection.Parent = content
    
    local leftBorder = Instance.new("UIStroke")
    leftBorder.Color = DollarwareColors.Border
    leftBorder.Thickness = 1
    leftBorder.Parent = leftSection
    
    -- Left section header
    local leftHeader = Instance.new("Frame")
    leftHeader.Size = UDim2.new(1, 0, 0, 22)
    leftHeader.BackgroundColor3 = DollarwareColors.Section
    leftHeader.BorderSizePixel = 0
    leftHeader.Parent = leftSection
    
    local leftHeaderText = Instance.new("TextLabel")
    leftHeaderText.Size = UDim2.new(1, -8, 1, 0)
    leftHeaderText.Position = UDim2.new(0, 8, 0, 0)
    leftHeaderText.BackgroundTransparency = 1
    leftHeaderText.Text = "addon info"
    leftHeaderText.TextColor3 = DollarwareColors.TextDim
    leftHeaderText.TextSize = 12
    leftHeaderText.Font = Enum.Font.SourceSans
    leftHeaderText.TextXAlignment = Enum.TextXAlignment.Left
    leftHeaderText.Parent = leftHeader
    
    local leftHeaderLine = Instance.new("Frame")
    leftHeaderLine.Size = UDim2.new(1, 0, 0, 1)
    leftHeaderLine.Position = UDim2.new(0, 0, 1, -1)
    leftHeaderLine.BackgroundColor3 = DollarwareColors.Border
    leftHeaderLine.BorderSizePixel = 0
    leftHeaderLine.Parent = leftHeader
    
    -- Left content
    local leftContent = Instance.new("Frame")
    leftContent.Size = UDim2.new(1, -8, 1, -26)
    leftContent.Position = UDim2.new(0, 4, 0, 24)
    leftContent.BackgroundTransparency = 1
    leftContent.Parent = leftSection
    
    local leftLayout = Instance.new("UIListLayout")
    leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
    leftLayout.Padding = UDim.new(0, 2)
    leftLayout.Parent = leftContent
    
    -- Addon info labels
    local function createLabel(parent, text, order, color)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 18)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = color or DollarwareColors.Text
        label.TextSize = 13
        label.Font = Enum.Font.SourceSans
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.LayoutOrder = order
        label.Parent = parent
        return label
    end
    
    createLabel(leftContent, "name: " .. (addonInfo.name or "Unknown"), 1)
    createLabel(leftContent, "version: " .. (addonInfo.version or "1.0"), 2)
    createLabel(leftContent, "author: " .. (addonInfo.author or "Unknown"), 3)
    createLabel(leftContent, "", 4) -- spacer
    createLabel(leftContent, "⚠ WARNING", 5, DollarwareColors.Accent)
    createLabel(leftContent, "this addon is NOT made by", 6)
    createLabel(leftContent, "the creator of shitbot!", 7)
    createLabel(leftContent, "", 8)
    createLabel(leftContent, "only load addons from", 9, DollarwareColors.TextDim)
    createLabel(leftContent, "sources you trust.", 10, DollarwareColors.TextDim)
    
    -- Right section
    local rightSection = Instance.new("Frame")
    rightSection.Name = "RightSection"
    rightSection.Size = UDim2.new(0.5, -4, 1, 0)
    rightSection.Position = UDim2.new(0.5, 4, 0, 0)
    rightSection.BackgroundColor3 = DollarwareColors.Section
    rightSection.BorderSizePixel = 0
    rightSection.Parent = content
    
    local rightBorder = Instance.new("UIStroke")
    rightBorder.Color = DollarwareColors.Border
    rightBorder.Thickness = 1
    rightBorder.Parent = rightSection
    
    -- Right section header
    local rightHeader = Instance.new("Frame")
    rightHeader.Size = UDim2.new(1, 0, 0, 22)
    rightHeader.BackgroundColor3 = DollarwareColors.Section
    rightHeader.BorderSizePixel = 0
    rightHeader.Parent = rightSection
    
    local rightHeaderText = Instance.new("TextLabel")
    rightHeaderText.Size = UDim2.new(1, -8, 1, 0)
    rightHeaderText.Position = UDim2.new(0, 8, 0, 0)
    rightHeaderText.BackgroundTransparency = 1
    rightHeaderText.Text = "action required"
    rightHeaderText.TextColor3 = DollarwareColors.TextDim
    rightHeaderText.TextSize = 12
    rightHeaderText.Font = Enum.Font.SourceSans
    rightHeaderText.TextXAlignment = Enum.TextXAlignment.Left
    rightHeaderText.Parent = rightHeader
    
    local rightHeaderLine = Instance.new("Frame")
    rightHeaderLine.Size = UDim2.new(1, 0, 0, 1)
    rightHeaderLine.Position = UDim2.new(0, 0, 1, -1)
    rightHeaderLine.BackgroundColor3 = DollarwareColors.Border
    rightHeaderLine.BorderSizePixel = 0
    rightHeaderLine.Parent = rightHeader
    
    -- Right content
    local rightContent = Instance.new("Frame")
    rightContent.Size = UDim2.new(1, -8, 1, -26)
    rightContent.Position = UDim2.new(0, 4, 0, 24)
    rightContent.BackgroundTransparency = 1
    rightContent.Parent = rightSection
    
    local rightLayout = Instance.new("UIListLayout")
    rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rightLayout.Padding = UDim.new(0, 2)
    rightLayout.Parent = rightContent
    
    -- Risk labels
    createLabel(rightContent, "third-party addons can:", 1)
    createLabel(rightContent, "• steal your data", 2, DollarwareColors.Accent)
    createLabel(rightContent, "• get you banned", 3, DollarwareColors.Accent)
    createLabel(rightContent, "• crash your game", 4, DollarwareColors.Accent)
    createLabel(rightContent, "", 5)
    
    -- Trust toggle row
    local trustRow = Instance.new("Frame")
    trustRow.Size = UDim2.new(1, 0, 0, 20)
    trustRow.BackgroundTransparency = 1
    trustRow.LayoutOrder = 6
    trustRow.Parent = rightContent
    
    local trustLabel = Instance.new("TextLabel")
    trustLabel.Size = UDim2.new(1, -30, 1, 0)
    trustLabel.Position = UDim2.new(0, 0, 0, 0)
    trustLabel.BackgroundTransparency = 1
    trustLabel.Text = "trust this addon"
    trustLabel.TextColor3 = DollarwareColors.Text
    trustLabel.TextSize = 13
    trustLabel.Font = Enum.Font.SourceSans
    trustLabel.TextXAlignment = Enum.TextXAlignment.Left
    trustLabel.Parent = trustRow
    
    local trustToggle = Instance.new("TextButton")
    trustToggle.Size = UDim2.new(0, 20, 0, 20)
    trustToggle.Position = UDim2.new(1, -20, 0, 0)
    trustToggle.BackgroundColor3 = DollarwareColors.ToggleOff
    trustToggle.BorderSizePixel = 0
    trustToggle.Text = "✕"
    trustToggle.TextColor3 = DollarwareColors.Accent
    trustToggle.TextSize = 14
    trustToggle.Font = Enum.Font.SourceSansBold
    trustToggle.Parent = trustRow
    
    local trustToggleBorder = Instance.new("UIStroke")
    trustToggleBorder.Color = DollarwareColors.Border
    trustToggleBorder.Thickness = 1
    trustToggleBorder.Parent = trustToggle
    
    trustToggle.MouseButton1Click:Connect(function()
        trustAddon = not trustAddon
        if trustAddon then
            trustToggle.BackgroundColor3 = DollarwareColors.ToggleOn
            trustToggle.Text = ""
        else
            trustToggle.BackgroundColor3 = DollarwareColors.ToggleOff
            trustToggle.Text = "✕"
        end
    end)
    
    createLabel(rightContent, "", 7)
    
    -- Countdown label
    local countdownLabel = createLabel(rightContent, "wait " .. countdown .. " seconds...", 8, DollarwareColors.TextDim)
    
    createLabel(rightContent, "", 9)
    
    -- Buttons container
    local buttonsRow = Instance.new("Frame")
    buttonsRow.Size = UDim2.new(1, 0, 0, 24)
    buttonsRow.BackgroundTransparency = 1
    buttonsRow.LayoutOrder = 10
    buttonsRow.Parent = rightContent
    
    -- Decline button
    local declineBtn = Instance.new("TextButton")
    declineBtn.Size = UDim2.new(0.48, 0, 0, 24)
    declineBtn.Position = UDim2.new(0, 0, 0, 0)
    declineBtn.BackgroundColor3 = DollarwareColors.ButtonBg
    declineBtn.BorderSizePixel = 0
    declineBtn.Text = "decline"
    declineBtn.TextColor3 = DollarwareColors.Text
    declineBtn.TextSize = 13
    declineBtn.Font = Enum.Font.SourceSans
    declineBtn.Parent = buttonsRow
    
    local declineBorder = Instance.new("UIStroke")
    declineBorder.Color = DollarwareColors.Border
    declineBorder.Thickness = 1
    declineBorder.Parent = declineBtn
    
    declineBtn.MouseEnter:Connect(function()
        declineBtn.BackgroundColor3 = DollarwareColors.ButtonHover
    end)
    declineBtn.MouseLeave:Connect(function()
        declineBtn.BackgroundColor3 = DollarwareColors.ButtonBg
    end)
    declineBtn.MouseButton1Click:Connect(function()
        declined = true
    end)
    
    -- Accept button
    local acceptBtn = Instance.new("TextButton")
    acceptBtn.Size = UDim2.new(0.48, 0, 0, 24)
    acceptBtn.Position = UDim2.new(0.52, 0, 0, 0)
    acceptBtn.BackgroundColor3 = DollarwareColors.ButtonBg
    acceptBtn.BorderSizePixel = 0
    acceptBtn.Text = "accept (" .. countdown .. ")"
    acceptBtn.TextColor3 = DollarwareColors.TextDim
    acceptBtn.TextSize = 13
    acceptBtn.Font = Enum.Font.SourceSans
    acceptBtn.Parent = buttonsRow
    
    local acceptBorder = Instance.new("UIStroke")
    acceptBorder.Color = DollarwareColors.Border
    acceptBorder.Thickness = 1
    acceptBorder.Parent = acceptBtn
    
    acceptBtn.MouseEnter:Connect(function()
        if countdown <= 0 then
            acceptBtn.BackgroundColor3 = DollarwareColors.AccentHover
        end
    end)
    acceptBtn.MouseLeave:Connect(function()
        if countdown <= 0 then
            acceptBtn.BackgroundColor3 = DollarwareColors.Accent
        else
            acceptBtn.BackgroundColor3 = DollarwareColors.ButtonBg
        end
    end)
    acceptBtn.MouseButton1Click:Connect(function()
        if countdown <= 0 then
            accepted = true
        end
    end)
    
    -- Countdown timer
    task.spawn(function()
        while countdown > 0 and not declined and not accepted do
            task.wait(1)
            countdown = countdown - 1
            pcall(function()
                if countdown > 0 then
                    countdownLabel.Text = "wait " .. countdown .. " seconds..."
                    acceptBtn.Text = "accept (" .. countdown .. ")"
                else
                    countdownLabel.Text = "you may now accept"
                    countdownLabel.TextColor3 = DollarwareColors.Text
                    acceptBtn.Text = "accept risk"
                    acceptBtn.TextColor3 = DollarwareColors.Text
                    acceptBtn.BackgroundColor3 = DollarwareColors.Accent
                    acceptBorder.Color = DollarwareColors.Accent
                end
            end)
        end
    end)
    
    -- Wait for user decision
    while not accepted and not declined do
        task.wait(0.1)
    end
    
    -- Cleanup
    pcall(function()
        WarningGui:Destroy()
    end)
    
    return accepted, trustAddon
end

-- Check if addon is trusted
local function IsAddonTrusted(addonName)
    for _, name in pairs(Settings.TrustedAddons) do
        if name == addonName then
            return true
        end
    end
    return false
end

-- ==================== ADDON SYSTEM ====================
local ShitbotAPI = {}
ShitbotAPI.Addons = {}
ShitbotAPI.Settings = Settings
ShitbotAPI.Connections = Connections
ShitbotAPI.UI = ui
ShitbotAPI.Window = nil
ShitbotAPI.LocalPlayer = LocalPlayer
ShitbotAPI.Services = {
    Players = Players,
    RunService = RunService,
    UserInputService = UserInputService,
    Teams = Teams
}

-- Register the API globally
_G.ShitbotAPI = ShitbotAPI
shared.ShitbotAPI = ShitbotAPI

-- Function for addons to register themselves (with warning)
function ShitbotAPI:RegisterAddon(addonInfo)
    if not addonInfo or not addonInfo.name then
        warn("[Shitbot] Addon registration failed: No name provided")
        return nil
    end
    
    -- Check if addon already exists
    for _, addon in pairs(self.Addons) do
        if addon.name == addonInfo.name then
            warn("[Shitbot] Addon '" .. addonInfo.name .. "' is already registered")
            return nil
        end
    end
    
    -- Check if addon is trusted
    local isTrusted = IsAddonTrusted(addonInfo.name)
    
    if not isTrusted then
        -- Show warning and wait for user decision
        print("[Shitbot] Showing warning for addon: " .. addonInfo.name)
        
        local accepted, nowTrusted = ShowAddonWarning(addonInfo)
        
        if not accepted then
            warn("[Shitbot] Addon '" .. addonInfo.name .. "' was declined by user")
            ui.notify({
                title = 'Addon Declined',
                message = addonInfo.name .. ' was not loaded',
                duration = 3
            })
            return nil
        end
        
        -- Save trust preference if they checked the box
        if nowTrusted then
            table.insert(Settings.TrustedAddons, addonInfo.name)
            print("[Shitbot] Addon '" .. addonInfo.name .. "' is now trusted")
        end
    else
        print("[Shitbot] Addon '" .. addonInfo.name .. "' is trusted, skipping warning")
    end
    
    -- Create addon entry
    local addon = {
        name = addonInfo.name,
        version = addonInfo.version or "1.0",
        author = addonInfo.author or "Unknown",
        description = addonInfo.description or "",
        menus = {},
        onUnload = addonInfo.onUnload or function() end
    }
    
    table.insert(self.Addons, addon)
    
    ui.notify({
        title = 'Addon Loaded',
        message = addon.name .. ' v' .. addon.version,
        duration = 3
    })
    
    print("[Shitbot] Addon registered: " .. addon.name .. " v" .. addon.version)
    
    -- Update addon list in UI
    if self.UpdateAddonList then
        self:UpdateAddonList()
    end
    
    return addon
end

-- Function to add a menu from an addon
function ShitbotAPI:AddMenu(menuInfo)
    if not self.Window then
        warn("[Shitbot] Cannot add menu: Window not initialized yet")
        return nil
    end
    
    local menu = self.Window:addMenu({
        text = menuInfo.text or "Addon Menu"
    })
    
    return menu
end

-- Function to add connection that will be cleaned up on unload
function ShitbotAPI:AddConnection(connection)
    table.insert(self.Connections, connection)
    return connection
end

-- Function to get a utility
function ShitbotAPI:GetUtility(name)
    local utilities = {
        GetAllEnemyPlayers = GetAllEnemyPlayers,
        GetAllValidPlayers = GetAllValidPlayers,
        IsTeammate = IsTeammate,
        IsEnemy = IsEnemy,
        IsVisible = IsVisible,
        GetPlayerVelocity = GetPlayerVelocity,
        PredictPosition = PredictPosition
    }
    return utilities[name]
end

-- Function to notify
function ShitbotAPI:Notify(title, message, duration)
    ui.notify({
        title = title or 'Shitbot',
        message = message or '',
        duration = duration or 3
    })
end

-- Function to clear trusted addons
function ShitbotAPI:ClearTrustedAddons()
    Settings.TrustedAddons = {}
    ui.notify({
        title = 'Shitbot',
        message = 'Trusted addons list cleared',
        duration = 2
    })
end

-- Function to remove addon from trusted list
function ShitbotAPI:UntrustAddon(addonName)
    for i, name in pairs(Settings.TrustedAddons) do
        if name == addonName then
            table.remove(Settings.TrustedAddons, i)
            ui.notify({
                title = 'Shitbot',
                message = addonName .. ' removed from trusted list',
                duration = 2
            })
            return true
        end
    end
    return false
end

-- ==================== END ADDON SYSTEM ====================

-- Create GUI for ESP elements
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AimAssistESP"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- FOV Circle using Drawing API (better performance and accuracy)
local FOVCircle = nil
local FOVCircleEnabled = false

pcall(function()
    if Drawing and Drawing.new then
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Visible = Settings.ShowAimFOV
        FOVCircle.Filled = false
        FOVCircle.Thickness = 1.5
        FOVCircle.Transparency = 1
        FOVCircle.Color = Settings.FOVColor
        FOVCircle.Radius = Settings.AimFOVRadius
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircleEnabled = true
        print("[Shitbot] Using Drawing API for FOV circle")
    end
end)

-- Fallback to Frame-based FOV circle if Drawing API not available
local FOVCircleFallback = nil
local FOVStroke = nil

if not FOVCircleEnabled then
    FOVCircleFallback = Instance.new("Frame")
    FOVCircleFallback.Name = "FOVCircle"
    FOVCircleFallback.Size = UDim2.new(0, Settings.AimFOVRadius * 2, 0, Settings.AimFOVRadius * 2)
    FOVCircleFallback.Position = UDim2.new(0.5, -Settings.AimFOVRadius, 0.5, -Settings.AimFOVRadius)
    FOVCircleFallback.BackgroundTransparency = 1
    FOVCircleFallback.Parent = ScreenGui
    
    local FOVCorner = Instance.new("UICorner")
    FOVCorner.CornerRadius = UDim.new(1, 0)
    FOVCorner.Parent = FOVCircleFallback
    
    FOVStroke = Instance.new("UIStroke")
    FOVStroke.Color = Settings.FOVColor
    FOVStroke.Thickness = 1.5
    FOVStroke.Parent = FOVCircleFallback
    print("[Shitbot] Using fallback Frame for FOV circle")
end

-- Target indicator
local TargetIndicator = Instance.new("Frame")
TargetIndicator.Name = "TargetIndicator"
TargetIndicator.Size = UDim2.new(0, 10, 0, 10)
TargetIndicator.BackgroundColor3 = Settings.TargetColor
TargetIndicator.BorderSizePixel = 0
TargetIndicator.Visible = false
TargetIndicator.Parent = ScreenGui

local TargetCorner = Instance.new("UICorner")
TargetCorner.CornerRadius = UDim.new(1, 0)
TargetCorner.Parent = TargetIndicator

-- ESP Container
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ESPFolder"
ESPFolder.Parent = ScreenGui

-- Store ESP objects
local ESPObjects = {}
local PreviousPositions = {}

-- Bone connections for skeleton (R15)
local BoneConnections = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

-- R6 Bone connections
local R6BoneConnections = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

-- ==================== AUTO DODGE SYSTEM ====================

local function IsBulletName(name)
    local lowerName = string.lower(name)
    for _, bulletName in pairs(Settings.DodgeNames) do
        if string.find(lowerName, string.lower(bulletName)) then
            return true
        end
    end
    return false
end

local function GetPartVelocity(part)
    if part:IsA("BasePart") then
        local success, velocity = pcall(function()
            return part.AssemblyLinearVelocity
        end)
        
        if success and velocity and velocity.Magnitude > 1 then
            return velocity
        end
        
        local partId = tostring(part)
        local currentPos = part.Position
        local currentTime = tick()
        
        if TrackedBullets[partId] then
            local data = TrackedBullets[partId]
            local deltaTime = currentTime - data.time
            
            if deltaTime > 0.01 then
                local velocity = (currentPos - data.position) / deltaTime
                TrackedBullets[partId] = {position = currentPos, time = currentTime}
                return velocity
            end
            return data.lastVelocity or Vector3.new(0, 0, 0)
        else
            TrackedBullets[partId] = {position = currentPos, time = currentTime, lastVelocity = Vector3.new(0, 0, 0)}
            return Vector3.new(0, 0, 0)
        end
    end
    return Vector3.new(0, 0, 0)
end

local function IsBulletHeadingTowardsPlayer(bulletPos, bulletVelocity, playerPos)
    if bulletVelocity.Magnitude < 5 then return false end
    
    local toPlayer = (playerPos - bulletPos).Unit
    local bulletDirection = bulletVelocity.Unit
    local dot = toPlayer:Dot(bulletDirection)
    
    return dot > 0.3
end

local function GetClosestApproachDistance(bulletPos, bulletVelocity, playerPos)
    if bulletVelocity.Magnitude < 1 then return math.huge end
    
    local bulletDir = bulletVelocity.Unit
    local toPlayer = playerPos - bulletPos
    local projectionLength = toPlayer:Dot(bulletDir)
    local closestPoint = bulletPos + bulletDir * projectionLength
    local distance = (playerPos - closestPoint).Magnitude
    
    return distance, projectionLength
end

local function CalculateDodgeDirection(bulletPos, bulletVelocity, playerPos)
    local bulletDir = bulletVelocity.Unit
    local toPlayer = (playerPos - bulletPos)
    local rightVector = Vector3.new(-bulletDir.Z, 0, bulletDir.X).Unit
    local playerOffset = toPlayer - (toPlayer:Dot(bulletDir) * bulletDir)
    
    if playerOffset:Dot(rightVector) > 0 then
        return rightVector
    else
        return -rightVector
    end
end

local function AutoDodge()
    if not ScriptLoaded then return end
    if not Settings.AutoDodgeEnabled then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not humanoidRootPart or not humanoid then return end
    if humanoid.Health <= 0 then return end
    
    local playerPos = humanoidRootPart.Position
    local currentTime = tick()
    
    if currentTime - LastDodgeTime < DodgeCooldown then return end
    
    local closestThreat = nil
    local closestThreatDistance = math.huge
    local closestThreatVelocity = nil
    local closestThreatPos = nil
    
    local function ScanForBullets(parent)
        for _, obj in pairs(parent:GetChildren()) do
            if obj:IsA("Model") and Players:GetPlayerFromCharacter(obj) then
                continue
            end
            
            local shouldCheck = false
            local partToCheck = nil
            
            if obj:IsA("BasePart") and IsBulletName(obj.Name) then
                shouldCheck = true
                partToCheck = obj
            elseif obj:IsA("Model") and IsBulletName(obj.Name) then
                partToCheck = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
                if partToCheck then
                    shouldCheck = true
                end
            end
            
            if shouldCheck and partToCheck then
                local bulletPos = partToCheck.Position
                local distance = (bulletPos - playerPos).Magnitude
                
                if distance < Settings.DodgeRadius then
                    local bulletVelocity = GetPartVelocity(partToCheck)
                    
                    if IsBulletHeadingTowardsPlayer(bulletPos, bulletVelocity, playerPos) then
                        local approachDist, projectionLength = GetClosestApproachDistance(bulletPos, bulletVelocity, playerPos)
                        
                        if approachDist < 8 and projectionLength > 0 and projectionLength < distance + 10 then
                            local timeToImpact = projectionLength / bulletVelocity.Magnitude
                            
                            if timeToImpact < closestThreatDistance and timeToImpact < 1.5 then
                                closestThreatDistance = timeToImpact
                                closestThreat = partToCheck
                                closestThreatVelocity = bulletVelocity
                                closestThreatPos = bulletPos
                            end
                        end
                    end
                end
            end
            
            if #obj:GetChildren() > 0 and not obj:IsA("BasePart") then
                ScanForBullets(obj)
            end
        end
    end
    
    pcall(function()
        ScanForBullets(workspace)
    end)
    
    if closestThreat and closestThreatVelocity then
        local dodgeDirection = CalculateDodgeDirection(closestThreatPos, closestThreatVelocity, playerPos)
        local urgency = math.clamp(1 - (closestThreatDistance / 1.5), 0.3, 1)
        local dodgeAmount = Settings.DodgeDistance * urgency
        local targetPosition = playerPos + (dodgeDirection * dodgeAmount)
        
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {character}
        
        local rayResult = workspace:Raycast(playerPos, dodgeDirection * dodgeAmount, rayParams)
        
        if not rayResult then
            local currentCFrame = humanoidRootPart.CFrame
            local targetCFrame = CFrame.new(targetPosition) * CFrame.Angles(currentCFrame:ToEulerAnglesXYZ())
            humanoidRootPart.CFrame = currentCFrame:Lerp(targetCFrame, Settings.DodgeSmoothness)
            LastDodgeTime = currentTime
        end
    end
    
    for partId, data in pairs(TrackedBullets) do
        if currentTime - data.time > 2 then
            TrackedBullets[partId] = nil
        end
    end
end

-- ==================== CAMERA FOV FUNCTION ====================

-- ==================== TEAM CHECK FUNCTIONS ====================

-- Check if a color is a shade of blue
local function IsBlueColor(color)
    -- Blue detection: B value should be dominant and relatively high
    -- R and G should be lower than B
    local r, g, b = color.R, color.G, color.B
    
    -- Check if blue is the dominant channel and is significant
    if b > 0.3 and b > r and b > g then
        -- Make sure it's not purple (high red) or cyan (high green equal to blue)
        if r < b * 0.7 and g < b * 0.85 then
            return true
        end
    end
    
    -- Also check for cyan/light blue (similar G and B, low R)
    if b > 0.3 and g > 0.3 and r < 0.3 then
        if math.abs(b - g) < 0.3 then
            return true
        end
    end
    
    return false
end

-- Check if a color is a shade of red
local function IsRedColor(color)
    local r, g, b = color.R, color.G, color.B
    
    -- Check if red is the dominant channel and is significant
    if r > 0.3 and r > g and r > b then
        -- Make sure it's not purple (high blue) or orange/yellow (high green)
        if b < r * 0.7 and g < r * 0.7 then
            return true
        end
    end
    
    -- Also check for orange-red (some red, some green, low blue)
    if r > 0.5 and g > 0.1 and g < 0.5 and b < 0.3 then
        if r > g then
            return true
        end
    end
    
    -- Dark red / maroon
    if r > 0.2 and r > g * 2 and r > b * 2 then
        return true
    end
    
    return false
end

-- Check if player has a blue BillboardGui (teammate indicator)
local function HasBlueBillboard(player)
    if not Settings.BlueBillboardTeamCheck then
        return false
    end
    
    local character = player.Character
    if not character then return false end
    
    -- Search for BillboardGuis in character
    for _, descendant in pairs(character:GetDescendants()) do
        if descendant:IsA("BillboardGui") then
            -- Check all descendants of the BillboardGui for colored elements
            for _, guiElement in pairs(descendant:GetDescendants()) do
                -- Check TextLabels
                if guiElement:IsA("TextLabel") or guiElement:IsA("TextButton") then
                    if IsBlueColor(guiElement.TextColor3) then
                        return true
                    end
                    if guiElement.BackgroundTransparency < 1 and IsBlueColor(guiElement.BackgroundColor3) then
                        return true
                    end
                end
                
                -- Check Frames
                if guiElement:IsA("Frame") then
                    if guiElement.BackgroundTransparency < 1 and IsBlueColor(guiElement.BackgroundColor3) then
                        return true
                    end
                end
                
                -- Check ImageLabels
                if guiElement:IsA("ImageLabel") then
                    if IsBlueColor(guiElement.ImageColor3) then
                        return true
                    end
                    if guiElement.BackgroundTransparency < 1 and IsBlueColor(guiElement.BackgroundColor3) then
                        return true
                    end
                end
            end
            
            -- Also check the BillboardGui's direct children if it has any colored frames
            if descendant:FindFirstChildOfClass("Frame") then
                local frame = descendant:FindFirstChildOfClass("Frame")
                if frame.BackgroundTransparency < 1 and IsBlueColor(frame.BackgroundColor3) then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Check if player has a red BillboardGui (enemy indicator)
local function HasRedBillboard(player)
    if not Settings.RedBillboardTeamCheck then
        return false
    end
    
    local character = player.Character
    if not character then return false end
    
    -- Search for BillboardGuis in character
    for _, descendant in pairs(character:GetDescendants()) do
        if descendant:IsA("BillboardGui") then
            -- Check all descendants of the BillboardGui for colored elements
            for _, guiElement in pairs(descendant:GetDescendants()) do
                -- Check TextLabels
                if guiElement:IsA("TextLabel") or guiElement:IsA("TextButton") then
                    if IsRedColor(guiElement.TextColor3) then
                        return true
                    end
                    if guiElement.BackgroundTransparency < 1 and IsRedColor(guiElement.BackgroundColor3) then
                        return true
                    end
                end
                
                -- Check Frames
                if guiElement:IsA("Frame") then
                    if guiElement.BackgroundTransparency < 1 and IsRedColor(guiElement.BackgroundColor3) then
                        return true
                    end
                end
                
                -- Check ImageLabels
                if guiElement:IsA("ImageLabel") then
                    if IsRedColor(guiElement.ImageColor3) then
                        return true
                    end
                    if guiElement.BackgroundTransparency < 1 and IsRedColor(guiElement.BackgroundColor3) then
                        return true
                    end
                end
            end
            
            -- Also check the BillboardGui's direct children if it has any colored frames
            if descendant:FindFirstChildOfClass("Frame") then
                local frame = descendant:FindFirstChildOfClass("Frame")
                if frame.BackgroundTransparency < 1 and IsRedColor(frame.BackgroundColor3) then
                    return true
                end
            end
        end
    end
    
    return false
end

local function IsTeammate(player)
    -- Check red billboard (if enabled) - red = teammate
    if Settings.RedBillboardTeamCheck and HasRedBillboard(player) then
        return true
    end
    
    -- Check blue billboard (if enabled) - blue = teammate
    if Settings.BlueBillboardTeamCheck and HasBlueBillboard(player) then
        return true
    end
    
    if not Settings.TeamCheck then
        return false
    end
    
    local teamsExist = #Teams:GetTeams() > 0
    if not teamsExist then
        return false
    end
    
    local localTeam = LocalPlayer.Team
    if not localTeam then
        return false
    end
    
    local playerTeam = player.Team
    if not playerTeam then
        return false
    end
    
    return localTeam == playerTeam
end

local function IsEnemy(player)
    return not IsTeammate(player)
end

local function GetPlayerColor(player, colorType)
    local isTeammate = IsTeammate(player)
    
    if colorType == "box" then
        return isTeammate and Settings.TeammateColor or Settings.EnemyColor
    elseif colorType == "skeleton" then
        return isTeammate and Settings.TeamSkeletonColor or Settings.SkeletonColor
    elseif colorType == "tracer" then
        return isTeammate and Settings.TeamTracerColor or Settings.TracerColor
    else
        return isTeammate and Settings.TeammateColor or Settings.EnemyColor
    end
end

-- ==================== UTILITY FUNCTIONS ====================

local function SafeCreate(className, properties)
    local success, instance = pcall(function()
        local inst = Instance.new(className)
        for prop, value in pairs(properties) do
            inst[prop] = value
        end
        return inst
    end)
    return success and instance or nil
end

local function CreateESP(player)
    if not ScriptLoaded then return end
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end
    
    local esp = {
        Box = {},
        Name = nil,
        Distance = nil,
        Skeleton = {},
        HealthBarBG = nil,
        HealthBar = nil,
        Tracer = nil,
        TeamIndicator = nil
    }
    
    -- Create 8 lines for corner style (4 corners x 2 lines each) or full box
    for i = 1, 8 do
        local line = SafeCreate("Frame", {
            Name = "BoxLine" .. i,
            BackgroundColor3 = Settings.EnemyColor,
            BorderSizePixel = 0,
            Visible = false,
            Parent = ESPFolder
        })
        esp.Box[i] = line
    end
    
    esp.Name = SafeCreate("TextLabel", {
        Name = "NameLabel",
        BackgroundTransparency = 1,
        TextColor3 = Settings.NameColor,
        TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
        Font = Enum.Font.SourceSansBold,
        TextSize = 14,
        Visible = false,
        Parent = ESPFolder
    })
    
    esp.Distance = SafeCreate("TextLabel", {
        Name = "DistLabel",
        BackgroundTransparency = 1,
        TextColor3 = Settings.NameColor,
        TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
        Font = Enum.Font.SourceSans,
        TextSize = 12,
        Visible = false,
        Parent = ESPFolder
    })
    
    esp.TeamIndicator = SafeCreate("TextLabel", {
        Name = "TeamIndicator",
        BackgroundTransparency = 1,
        TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
        Font = Enum.Font.SourceSansBold,
        TextSize = 11,
        Visible = false,
        Parent = ESPFolder
    })
    
    esp.HealthBarBG = SafeCreate("Frame", {
        Name = "HealthBarBG",
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Visible = false,
        Parent = ESPFolder
    })
    
    esp.HealthBar = SafeCreate("Frame", {
        Name = "HealthBar",
        BackgroundColor3 = Settings.HealthBarColor,
        BorderSizePixel = 0,
        Visible = false,
        Parent = ESPFolder
    })
    
    esp.Tracer = SafeCreate("Frame", {
        Name = "Tracer",
        BackgroundColor3 = Settings.TracerColor,
        BorderSizePixel = 0,
        Visible = false,
        Parent = ESPFolder
    })
    
    for i = 1, 14 do
        local line = SafeCreate("Frame", {
            Name = "SkeletonLine" .. i,
            BackgroundColor3 = Settings.SkeletonColor,
            BorderSizePixel = 0,
            Visible = false,
            Parent = ESPFolder
        })
        esp.Skeleton[i] = line
    end
    
    ESPObjects[player] = esp
    
    local charConnection = player.CharacterAdded:Connect(function(char)
        if not ScriptLoaded then return end
        task.spawn(function()
            char:WaitForChild("HumanoidRootPart", 10)
            char:WaitForChild("Head", 10)
            char:WaitForChild("Humanoid", 10)
        end)
    end)
    
    CharacterConnections[player] = charConnection
end

local function RemoveESP(player)
    local esp = ESPObjects[player]
    if esp then
        pcall(function()
            for _, line in pairs(esp.Box) do
                if line then line:Destroy() end
            end
            if esp.Name then esp.Name:Destroy() end
            if esp.Distance then esp.Distance:Destroy() end
            if esp.TeamIndicator then esp.TeamIndicator:Destroy() end
            if esp.HealthBarBG then esp.HealthBarBG:Destroy() end
            if esp.HealthBar then esp.HealthBar:Destroy() end
            if esp.Tracer then esp.Tracer:Destroy() end
            for _, line in pairs(esp.Skeleton) do
                if line then line:Destroy() end
            end
        end)
        ESPObjects[player] = nil
    end
    
    if CharacterConnections[player] then
        CharacterConnections[player]:Disconnect()
        CharacterConnections[player] = nil
    end
    
    PreviousPositions[player] = nil
end

local function DrawLine(frame, p1, p2, thickness)
    if not frame then return end
    thickness = thickness or 1
    
    local dx = p2.X - p1.X
    local dy = p2.Y - p1.Y
    local distance = math.sqrt(dx * dx + dy * dy)
    local centerX = (p1.X + p2.X) / 2
    local centerY = (p1.Y + p2.Y) / 2
    local angle = math.atan2(dy, dx)
    
    frame.Size = UDim2.new(0, distance, 0, thickness)
    frame.Position = UDim2.new(0, centerX - distance / 2, 0, centerY - thickness / 2)
    frame.Rotation = math.deg(angle)
    frame.Visible = true
end

local function IsVisible(targetPart, targetCharacter)
    local character = LocalPlayer.Character
    if not character then return false end
    
    local head = character:FindFirstChild("Head")
    if not head then return false end
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {character, targetCharacter}
    rayParams.IgnoreWater = true
    
    local origin = head.Position
    local direction = (targetPart.Position - origin)
    local distance = direction.Magnitude
    
    direction = direction.Unit * (distance - 0.5)
    
    local result = workspace:Raycast(origin, direction, rayParams)
    
    return result == nil
end

-- Advanced velocity tracking with acceleration
local function GetPlayerVelocityAdvanced(player, currentPos)
    local prevData = PreviousPositions[player]
    local currentTime = tick()
    
    if not prevData or not prevData.lastVelocity then
        PreviousPositions[player] = {
            position = currentPos,
            time = currentTime,
            velocity = Vector3.new(0, 0, 0),
            lastVelocity = Vector3.new(0, 0, 0),
            acceleration = Vector3.new(0, 0, 0)
        }
        return Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)
    end
    
    local deltaTime = currentTime - prevData.time
    if deltaTime < 0.01 then
        return prevData.velocity or Vector3.new(0, 0, 0), prevData.acceleration or Vector3.new(0, 0, 0)
    end
    
    -- Calculate current velocity
    local velocity = (currentPos - prevData.position) / deltaTime
    
    -- Calculate acceleration (change in velocity)
    local acceleration = (velocity - prevData.lastVelocity) / deltaTime
    
    -- Clamp acceleration to avoid wild predictions
    local maxAccel = 100
    acceleration = Vector3.new(
        math.clamp(acceleration.X, -maxAccel, maxAccel),
        math.clamp(acceleration.Y, -maxAccel, maxAccel),
        math.clamp(acceleration.Z, -maxAccel, maxAccel)
    )
    
    PreviousPositions[player] = {
        position = currentPos,
        time = currentTime,
        velocity = velocity,
        lastVelocity = velocity,
        acceleration = acceleration
    }
    
    return velocity, acceleration
end

-- Legacy wrapper for compatibility
local function GetPlayerVelocity(player, currentPos)
    local velocity, _ = GetPlayerVelocityAdvanced(player, currentPos)
    return velocity
end

-- Advanced position prediction using kinematic equation
local function PredictPositionAdvanced(currentPos, velocity, acceleration)
    if not Settings.Prediction then
        return currentPos
    end
    
    local predTime = Settings.PredictionAmount
    
    -- Use kinematic equation: s = ut + 0.5at²
    local predictedPos = currentPos + 
                        (velocity * predTime) + 
                        (acceleration * 0.5 * predTime * predTime)
    
    return predictedPos
end

local function PredictPosition(currentPos, velocity)
    if not Settings.Prediction then
        return currentPos
    end
    
    local predictedPos = currentPos + (velocity * Settings.PredictionAmount)
    return predictedPos
end

-- Dynamic smoothing based on distance
local function GetDynamicSmoothness(distance)
    if not Settings.DynamicSmoothing then
        return Settings.Smoothness
    end
    
    -- Closer targets = smoother aim (harder to track fast movement up close)
    -- Further targets = faster aim (less pixel movement needed)
    if distance < 50 then
        return math.min(Settings.Smoothness * 1.5, 0.95) -- 50% smoother for close
    elseif distance < 100 then
        return math.min(Settings.Smoothness * 1.2, 0.9) -- 20% smoother
    elseif distance > 200 then
        return math.max(Settings.Smoothness * 0.7, 0.05) -- 30% faster for distant
    else
        return Settings.Smoothness
    end
end

-- Apply smoothing curve
local function ApplySmoothingCurve(alpha, smoothingType)
    if smoothingType == "Linear" then
        return alpha
    elseif smoothingType == "Ease-In" then
        -- Slower start, faster end
        return alpha * alpha
    elseif smoothingType == "Ease-Out" then
        -- Faster start, slower end
        return 1 - (1 - alpha) * (1 - alpha)
    elseif smoothingType == "Sigmoid" then
        -- S-curve: smooth acceleration and deceleration
        return alpha * alpha * (3 - 2 * alpha)
    end
    return alpha
end

-- Humanize aim movement with micro-adjustments
local function HumanizeAimOffset()
    if not Settings.HumanizeAim then
        return Vector3.new(0, 0, 0)
    end
    
    -- Add small random offset (very subtle)
    local humanizationFactor = math.random(-30, 30) / 10000
    return Vector3.new(humanizationFactor, humanizationFactor, 0)
end

local function GetAllValidPlayers(enemiesOnly)
    local validPlayers = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if enemiesOnly and IsTeammate(player) then
                continue
            end
            
            local character = player.Character
            local head = character:FindFirstChild("Head")
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            
            if head and humanoid and rootPart and humanoid.Health > 0 then
                table.insert(validPlayers, {
                    player = player,
                    head = head,
                    character = character,
                    humanoid = humanoid,
                    rootPart = rootPart,
                    isTeammate = IsTeammate(player)
                })
            end
        end
    end
    
    return validPlayers
end

local function GetAllEnemyPlayers()
    return GetAllValidPlayers(true)
end

-- Track current target to avoid switching aim part every frame
local CurrentTarget = nil
local CurrentAimPart = nil

local function GetRandomAimPart(character)
    local roll = math.random(1, 100)
    
    if roll <= Settings.HeadshotChance then
        -- Aim at head
        return character:FindFirstChild("Head")
    else
        -- Aim at body - try different body parts
        local bodyParts = {"HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso"}
        for _, partName in ipairs(bodyParts) do
            local part = character:FindFirstChild(partName)
            if part then
                return part
            end
        end
        -- Fallback to head if no body part found
        return character:FindFirstChild("Head")
    end
end

local function GetClosestPlayerInFOV()
    local closestPlayer = nil
    local closestPart = nil
    local closestDistance = math.huge -- Start with infinite distance
    local closestScreenPos = nil
    
    -- Get local player position
    local localChar = LocalPlayer.Character
    if not localChar then return nil, nil, nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil, nil, nil end
    local localPos = localRoot.Position
    
    -- Use mouse position for FOV check (player must be in FOV circle)
    local mousePos = UserInputService:GetMouseLocation()
    
    -- Give current target a larger effective FOV (sticky aim)
    local effectiveFOV = Settings.AimFOVRadius
    if Settings.StickyTargetEnabled and LastTargetPlayer and LastTargetPlayer.Parent then
        effectiveFOV = Settings.AimFOVRadius * Settings.StickyTargetMultiplier
    end
    
    local validPlayers = GetAllEnemyPlayers()
    
    for _, data in pairs(validPlayers) do
        local checkPart = data.head
        if not checkPart then continue end
        
        local velocity, acceleration = GetPlayerVelocityAdvanced(data.player, checkPart.Position)
        local predictedPos = PredictPositionAdvanced(checkPart.Position, velocity, acceleration)
        
        local screenPos, onScreen = Camera:WorldToScreenPoint(predictedPos)
        
        if onScreen and screenPos.Z > 0 then
            local screenPos2D = Vector2.new(screenPos.X, screenPos.Y)
            local screenDistance = (screenPos2D - mousePos).Magnitude
            
            -- Use larger FOV for current target (sticky aim)
            local fovToUse = (data.player == LastTargetPlayer) and effectiveFOV or Settings.AimFOVRadius
            
            -- Must be within FOV circle
            if screenDistance < fovToUse then
                if IsVisible(checkPart, data.character) then
                    -- Calculate actual 3D distance to player
                    local realDistance = (checkPart.Position - localPos).Magnitude
                    
                    -- Target the closest player by real distance
                    if realDistance < closestDistance then
                        closestDistance = realDistance
                        closestPlayer = data.player
                        closestPart = data.character
                        closestScreenPos = screenPos2D
                    end
                end
            end
        end
    end
    
    -- Update sticky target
    LastTargetPlayer = closestPlayer
    
    -- If target changed, pick new random aim part
    if closestPlayer ~= CurrentTarget then
        CurrentTarget = closestPlayer
        if closestPart then
            CurrentAimPart = GetRandomAimPart(closestPart)
        else
            CurrentAimPart = nil
        end
    end
    
    -- Return the actual aim part for this target
    local finalAimPart = CurrentAimPart
    if not finalAimPart and closestPart then
        finalAimPart = closestPart:FindFirstChild("Head")
    end
    
    return closestPlayer, finalAimPart, closestScreenPos
end

local function RefreshAllESP()
    if not ScriptLoaded then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not ESPObjects[player] then
                CreateESP(player)
            end
        end
    end
    
    local toRemove = {}
    for player, _ in pairs(ESPObjects) do
        if not player or not player.Parent or not Players:FindFirstChild(player.Name) then
            table.insert(toRemove, player)
        end
    end
    
    for _, player in pairs(toRemove) do
        RemoveESP(player)
    end
end

local function HideESP(esp)
    if not esp then return end
    
    pcall(function()
        for _, line in pairs(esp.Box) do
            if line then line.Visible = false end
        end
        if esp.Name then esp.Name.Visible = false end
        if esp.Distance then esp.Distance.Visible = false end
        if esp.TeamIndicator then esp.TeamIndicator.Visible = false end
        if esp.HealthBarBG then esp.HealthBarBG.Visible = false end
        if esp.HealthBar then esp.HealthBar.Visible = false end
        if esp.Tracer then esp.Tracer.Visible = false end
        for _, line in pairs(esp.Skeleton) do
            if line then line.Visible = false end
        end
    end)
end

local function UpdateESP()
    if not ScriptLoaded then return end
    
    RefreshAllESP()
    
    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    
    for player, esp in pairs(ESPObjects) do
        if not esp then continue end
        
        if not player or not player.Parent then
            HideESP(esp)
            continue
        end
        
        local isTeammate = IsTeammate(player)
        if isTeammate and not Settings.ShowTeammates then
            HideESP(esp)
            continue
        end
        
        local character = player.Character
        if not character or not Settings.ESPEnabled then
            HideESP(esp)
            continue
        end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local head = character:FindFirstChild("Head")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        
        if not humanoidRootPart or not head or not humanoid then
            HideESP(esp)
            continue
        end
        
        if humanoid.Health <= 0 then
            HideESP(esp)
            continue
        end
        
        if not localChar or not localRoot then
            HideESP(esp)
            continue
        end
        
        local distance = (humanoidRootPart.Position - localRoot.Position).Magnitude
        
        local rootPos, onScreen = Camera:WorldToScreenPoint(humanoidRootPart.Position)
        local headPos = Camera:WorldToScreenPoint(head.Position + Vector3.new(0, 0.5, 0))
        local feetPos = Camera:WorldToScreenPoint(humanoidRootPart.Position - Vector3.new(0, 3, 0))
        
        if not onScreen or rootPos.Z <= 0 then
            HideESP(esp)
            continue
        end
        
        local boxColor = GetPlayerColor(player, "box")
        local skeletonColor = GetPlayerColor(player, "skeleton")
        local tracerColor = GetPlayerColor(player, "tracer")
        
        local scaleFactor = 1 / (rootPos.Z * 0.05)
        scaleFactor = math.clamp(scaleFactor, 0.1, 5)
        
        local boxHeight = math.abs(feetPos.Y - headPos.Y) + 10
        boxHeight = math.clamp(boxHeight, 30, 600)
        local boxWidth = boxHeight * 0.5
        
        local topY = headPos.Y - 5
        local bottomY = topY + boxHeight
        local centerX = rootPos.X
        local leftX = centerX - boxWidth / 2
        local rightX = centerX + boxWidth / 2
        
        if Settings.ShowBoxes then
            pcall(function()
                -- Calculate opacity based on distance (fade distant ESP)
                local opacity = 1
                if Settings.DistanceFade then
                    local maxFadeDistance = 500
                    if distance > maxFadeDistance then
                        opacity = math.clamp(1 - ((distance - maxFadeDistance) / 500), 0.2, 1)
                    end
                end
                
                if Settings.BoxStyle == "Corners" then
                    -- Corner style - draw corner brackets (8 lines for 4 corners)
                    local cornerLength = math.min(boxWidth * 0.25, boxHeight * 0.25, 15)
                    local thickness = 2
                    
                    -- Top-left corner
                    if esp.Box[1] then
                        esp.Box[1].Size = UDim2.new(0, cornerLength, 0, thickness)
                        esp.Box[1].Position = UDim2.new(0, leftX, 0, topY)
                        esp.Box[1].BackgroundColor3 = boxColor
                        esp.Box[1].BackgroundTransparency = 1 - opacity
                        esp.Box[1].Visible = true
                    end
                    if esp.Box[2] then
                        esp.Box[2].Size = UDim2.new(0, thickness, 0, cornerLength)
                        esp.Box[2].Position = UDim2.new(0, leftX, 0, topY)
                        esp.Box[2].BackgroundColor3 = boxColor
                        esp.Box[2].BackgroundTransparency = 1 - opacity
                        esp.Box[2].Visible = true
                    end
                    
                    -- Top-right corner
                    if esp.Box[3] then
                        esp.Box[3].Size = UDim2.new(0, cornerLength, 0, thickness)
                        esp.Box[3].Position = UDim2.new(0, rightX - cornerLength, 0, topY)
                        esp.Box[3].BackgroundColor3 = boxColor
                        esp.Box[3].BackgroundTransparency = 1 - opacity
                        esp.Box[3].Visible = true
                    end
                    if esp.Box[4] then
                        esp.Box[4].Size = UDim2.new(0, thickness, 0, cornerLength)
                        esp.Box[4].Position = UDim2.new(0, rightX - thickness, 0, topY)
                        esp.Box[4].BackgroundColor3 = boxColor
                        esp.Box[4].BackgroundTransparency = 1 - opacity
                        esp.Box[4].Visible = true
                    end
                    
                    -- Bottom-left corner
                    if esp.Box[5] then
                        esp.Box[5].Size = UDim2.new(0, cornerLength, 0, thickness)
                        esp.Box[5].Position = UDim2.new(0, leftX, 0, bottomY - thickness)
                        esp.Box[5].BackgroundColor3 = boxColor
                        esp.Box[5].BackgroundTransparency = 1 - opacity
                        esp.Box[5].Visible = true
                    end
                    if esp.Box[6] then
                        esp.Box[6].Size = UDim2.new(0, thickness, 0, cornerLength)
                        esp.Box[6].Position = UDim2.new(0, leftX, 0, bottomY - cornerLength)
                        esp.Box[6].BackgroundColor3 = boxColor
                        esp.Box[6].BackgroundTransparency = 1 - opacity
                        esp.Box[6].Visible = true
                    end
                    
                    -- Bottom-right corner
                    if esp.Box[7] then
                        esp.Box[7].Size = UDim2.new(0, cornerLength, 0, thickness)
                        esp.Box[7].Position = UDim2.new(0, rightX - cornerLength, 0, bottomY - thickness)
                        esp.Box[7].BackgroundColor3 = boxColor
                        esp.Box[7].BackgroundTransparency = 1 - opacity
                        esp.Box[7].Visible = true
                    end
                    if esp.Box[8] then
                        esp.Box[8].Size = UDim2.new(0, thickness, 0, cornerLength)
                        esp.Box[8].Position = UDim2.new(0, rightX - thickness, 0, bottomY - cornerLength)
                        esp.Box[8].BackgroundColor3 = boxColor
                        esp.Box[8].BackgroundTransparency = 1 - opacity
                        esp.Box[8].Visible = true
                    end
                else
                    -- Full box style (only use first 4 lines)
                    if esp.Box[1] then
                        esp.Box[1].Size = UDim2.new(0, boxWidth, 0, 2)
                        esp.Box[1].Position = UDim2.new(0, leftX, 0, topY)
                        esp.Box[1].BackgroundColor3 = boxColor
                        esp.Box[1].BackgroundTransparency = 1 - opacity
                        esp.Box[1].Visible = true
                    end
                    
                    if esp.Box[2] then
                        esp.Box[2].Size = UDim2.new(0, boxWidth, 0, 2)
                        esp.Box[2].Position = UDim2.new(0, leftX, 0, bottomY)
                        esp.Box[2].BackgroundColor3 = boxColor
                        esp.Box[2].BackgroundTransparency = 1 - opacity
                        esp.Box[2].Visible = true
                    end
                    
                    if esp.Box[3] then
                        esp.Box[3].Size = UDim2.new(0, 2, 0, boxHeight)
                        esp.Box[3].Position = UDim2.new(0, leftX, 0, topY)
                        esp.Box[3].BackgroundColor3 = boxColor
                        esp.Box[3].BackgroundTransparency = 1 - opacity
                        esp.Box[3].Visible = true
                    end
                    
                    if esp.Box[4] then
                        esp.Box[4].Size = UDim2.new(0, 2, 0, boxHeight)
                        esp.Box[4].Position = UDim2.new(0, rightX, 0, topY)
                        esp.Box[4].BackgroundColor3 = boxColor
                        esp.Box[4].BackgroundTransparency = 1 - opacity
                        esp.Box[4].Visible = true
                    end
                    
                    -- Hide unused lines 5-8 for full box
                    for i = 5, 8 do
                        if esp.Box[i] then esp.Box[i].Visible = false end
                    end
                end
            end)
        else
            for _, line in pairs(esp.Box) do
                if line then line.Visible = false end
            end
        end
        
        if Settings.ShowNames and esp.Name then
            pcall(function()
                esp.Name.Text = player.Name
                esp.Name.Size = UDim2.new(0, 150, 0, 20)
                esp.Name.Position = UDim2.new(0, centerX - 75, 0, topY - 22)
                esp.Name.TextColor3 = boxColor
                esp.Name.Visible = true
            end)
        elseif esp.Name then
            esp.Name.Visible = false
        end
        
        if Settings.ShowNames and esp.TeamIndicator then
            pcall(function()
                local teamText = isTeammate and "[TEAM]" or "[ENEMY]"
                esp.TeamIndicator.Text = teamText
                esp.TeamIndicator.TextColor3 = boxColor
                esp.TeamIndicator.Size = UDim2.new(0, 100, 0, 15)
                esp.TeamIndicator.Position = UDim2.new(0, centerX - 50, 0, topY - 36)
                esp.TeamIndicator.Visible = true
            end)
        elseif esp.TeamIndicator then
            esp.TeamIndicator.Visible = false
        end
        
        if Settings.ShowDistance and esp.Distance then
            pcall(function()
                esp.Distance.Text = string.format("[%.0f studs]", distance)
                esp.Distance.Size = UDim2.new(0, 150, 0, 20)
                esp.Distance.Position = UDim2.new(0, centerX - 75, 0, bottomY + 2)
                esp.Distance.TextColor3 = boxColor
                esp.Distance.Visible = true
            end)
        elseif esp.Distance then
            esp.Distance.Visible = false
        end
        
        if Settings.ShowHealthBar and esp.HealthBarBG and esp.HealthBar then
            pcall(function()
                local healthPercent = humanoid.Health / humanoid.MaxHealth
                local barHeight = boxHeight
                local barWidth = 4
                
                esp.HealthBarBG.Size = UDim2.new(0, barWidth, 0, barHeight)
                esp.HealthBarBG.Position = UDim2.new(0, leftX - barWidth - 3, 0, topY)
                esp.HealthBarBG.Visible = true
                
                local fillHeight = barHeight * healthPercent
                esp.HealthBar.Size = UDim2.new(0, barWidth - 2, 0, fillHeight)
                esp.HealthBar.Position = UDim2.new(0, leftX - barWidth - 2, 0, topY + barHeight - fillHeight)
                
                -- Smooth gradient health color
                local healthColor
                if healthPercent > 0.6 then
                    -- Interpolate between full and mid
                    local t = (healthPercent - 0.6) / 0.4
                    healthColor = Settings.HealthMidColor:Lerp(Settings.HealthFullColor, t)
                elseif healthPercent > 0.3 then
                    -- Interpolate between low and mid
                    local t = (healthPercent - 0.3) / 0.3
                    healthColor = Settings.HealthLowColor:Lerp(Settings.HealthMidColor, t)
                else
                    -- Stay at low color
                    healthColor = Settings.HealthLowColor
                end
                esp.HealthBar.BackgroundColor3 = healthColor
                esp.HealthBar.Visible = true
            end)
        else
            if esp.HealthBarBG then esp.HealthBarBG.Visible = false end
            if esp.HealthBar then esp.HealthBar.Visible = false end
        end
        
        if Settings.ShowTracers and esp.Tracer then
            pcall(function()
                local screenBottom = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                local targetPos = Vector2.new(rootPos.X, bottomY)
                DrawLine(esp.Tracer, screenBottom, targetPos, 1)
                esp.Tracer.BackgroundColor3 = tracerColor
            end)
        elseif esp.Tracer then
            esp.Tracer.Visible = false
        end
        
        if Settings.ShowSkeleton then
            local isR15 = character:FindFirstChild("UpperTorso") ~= nil
            local bones = isR15 and BoneConnections or R6BoneConnections
            local lineIndex = 1
            
            for _, connection in pairs(bones) do
                if lineIndex > #esp.Skeleton then break end
                
                local part1 = character:FindFirstChild(connection[1])
                local part2 = character:FindFirstChild(connection[2])
                
                if part1 and part2 and esp.Skeleton[lineIndex] then
                    local pos1 = Camera:WorldToScreenPoint(part1.Position)
                    local pos2 = Camera:WorldToScreenPoint(part2.Position)
                    
                    if pos1.Z > 0 and pos2.Z > 0 then
                        pcall(function()
                            DrawLine(esp.Skeleton[lineIndex], Vector2.new(pos1.X, pos1.Y), Vector2.new(pos2.X, pos2.Y), 2)
                            esp.Skeleton[lineIndex].BackgroundColor3 = skeletonColor
                        end)
                    else
                        esp.Skeleton[lineIndex].Visible = false
                    end
                else
                    if esp.Skeleton[lineIndex] then
                        esp.Skeleton[lineIndex].Visible = false
                    end
                end
                lineIndex = lineIndex + 1
            end
            
            for i = lineIndex, #esp.Skeleton do
                if esp.Skeleton[i] then
                    esp.Skeleton[i].Visible = false
                end
            end
        else
            for _, line in pairs(esp.Skeleton) do
                if line then line.Visible = false end
            end
        end
    end
end

local function AimAssist()
    if not ScriptLoaded then return end
    if not Settings.AimEnabled then
        TargetIndicator.Visible = false
        CurrentTarget = nil
        CurrentAimPart = nil
        LastTargetPlayer = nil
        return
    end
    
    local isAiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    
    if not isAiming then
        TargetIndicator.Visible = false
        -- Reset target when releasing aim so new random part is picked next time
        CurrentTarget = nil
        CurrentAimPart = nil
        LastTargetPlayer = nil
        return
    end
    
    local target, targetPart, screenPos = GetClosestPlayerInFOV()
    
    if not target or not targetPart then
        TargetIndicator.Visible = false
        return
    end
    
    if screenPos then
        TargetIndicator.Position = UDim2.new(0, screenPos.X - 5, 0, screenPos.Y - 5)
        TargetIndicator.Visible = true
    end
    
    local localChar = LocalPlayer.Character
    if not localChar then return end
    
    -- Get velocity and acceleration for advanced prediction
    local velocity, acceleration = GetPlayerVelocityAdvanced(target, targetPart.Position)
    local predictedPos = PredictPositionAdvanced(targetPart.Position, velocity, acceleration)
    
    local currentCFrame = Camera.CFrame
    local targetCFrame = CFrame.new(currentCFrame.Position, predictedPos)
    
    -- Calculate distance to target for dynamic smoothing
    local distance = (targetPart.Position - currentCFrame.Position).Magnitude
    
    -- Get dynamic smoothness based on distance
    local smoothness = GetDynamicSmoothness(distance)
    
    local currentLook = currentCFrame.LookVector
    local targetLook = targetCFrame.LookVector
    
    -- Calculate alpha and apply smoothing curve
    local rawAlpha = 1 - smoothness
    local curvedAlpha = ApplySmoothingCurve(rawAlpha, Settings.SmoothingType)
    
    -- Lerp with curved alpha
    local newLook = currentLook:Lerp(targetLook, curvedAlpha)
    
    -- Add humanization micro-adjustments
    newLook = newLook + HumanizeAimOffset()
    
    local newCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + newLook)
    
    Camera.CFrame = newCFrame
end

local function TeleportBehindRandomPlayer()
    if not ScriptLoaded then return end
    
    local localChar = LocalPlayer.Character
    if not localChar then return end
    
    local humanoidRootPart = localChar:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local validPlayers = GetAllEnemyPlayers()
    if #validPlayers == 0 then
        ui.notify({
            title = 'Shitbot',
            message = 'No valid enemy players found!',
            duration = 3
        })
        return
    end
    
    local randomData = validPlayers[math.random(1, #validPlayers)]
    local targetRoot = randomData.rootPart
    
    if not targetRoot then return end
    
    local behindOffset = targetRoot.CFrame.LookVector * -6
    local teleportCFrame = CFrame.new(targetRoot.Position + behindOffset) * CFrame.Angles(0, math.rad(targetRoot.Orientation.Y), 0)
    
    humanoidRootPart.CFrame = teleportCFrame
    
    ui.notify({
        title = 'Teleport',
        message = 'Teleported behind: ' .. randomData.player.Name,
        duration = 3
    })
end

local function UpdateFOVCircle()
    if not ScriptLoaded then return end
    
    -- Get mouse position
    local mousePos = UserInputService:GetMouseLocation()
    local isAiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    
    if FOVCircleEnabled and FOVCircle then
        -- Using Drawing API
        FOVCircle.Visible = Settings.ShowAimFOV
        
        if Settings.ShowAimFOV then
            FOVCircle.Position = Vector2.new(mousePos.X, mousePos.Y)
            FOVCircle.Radius = Settings.AimFOVRadius
            
            if isAiming then
                FOVCircle.Color = Settings.FOVColorActive
                FOVCircle.Thickness = 2
            else
                FOVCircle.Color = Settings.FOVColor
                FOVCircle.Thickness = 1.5
            end
        end
    elseif FOVCircleFallback then
        -- Using fallback Frame
        FOVCircleFallback.Visible = Settings.ShowAimFOV
        
        if Settings.ShowAimFOV then
            FOVCircleFallback.Position = UDim2.new(0, mousePos.X - Settings.AimFOVRadius, 0, mousePos.Y - Settings.AimFOVRadius)
            FOVCircleFallback.Size = UDim2.new(0, Settings.AimFOVRadius * 2, 0, Settings.AimFOVRadius * 2)
            
            if FOVStroke then
                if isAiming then
                    FOVStroke.Color = Settings.FOVColorActive
                    FOVStroke.Thickness = 2
                else
                    FOVStroke.Color = Settings.FOVColor
                    FOVStroke.Thickness = 1
                end
            end
        end
    end
end

local function UnloadScript()
    ui.notify({
        title = 'Shitbot',
        message = 'Saving settings and unloading...',
        duration = 2
    })
    
    -- Save settings before unloading
    SaveSettings()
    
    ScriptLoaded = false
    
    -- Unload all addons first
    for _, addon in pairs(ShitbotAPI.Addons) do
        pcall(function()
            if addon.onUnload then
                addon.onUnload()
            end
        end)
        print("[Shitbot] Addon unloaded: " .. addon.name)
    end
    ShitbotAPI.Addons = {}
    
    pcall(function()
        workspace.CurrentCamera.FieldOfView = DefaultCameraFOV
    end)
    
    -- Clean up FOV circle (Drawing API)
    pcall(function()
        if FOVCircle and FOVCircleEnabled then
            FOVCircle:Remove()
        end
    end)
    
    for _, connection in pairs(Connections) do
        pcall(function()
            if connection then connection:Disconnect() end
        end)
    end
    Connections = {}
    
    for _, connection in pairs(CharacterConnections) do
        pcall(function()
            if connection then connection:Disconnect() end
        end)
    end
    CharacterConnections = {}
    
    for player, _ in pairs(ESPObjects) do
        RemoveESP(player)
    end
    ESPObjects = {}
    PreviousPositions = {}
    TrackedBullets = {}
    
    pcall(function()
        if ScreenGui then
            ScreenGui:Destroy()
        end
    end)
    
    pcall(function()
        window:destroy()
    end)
    
    -- Clean up global API
    _G.ShitbotAPI = nil
    shared.ShitbotAPI = nil
    
    print("Shitbot v6 Unloaded!")
end

-- Initialize ESP for existing players
for _, player in pairs(Players:GetPlayers()) do
    CreateESP(player)
end

-- Connect player events
table.insert(Connections, Players.PlayerAdded:Connect(function(player)
    if ScriptLoaded then
        task.wait(0.5)
        CreateESP(player)
    end
end))

table.insert(Connections, Players.PlayerRemoving:Connect(function(player)
    if ScriptLoaded then
        RemoveESP(player)
    end
end))

-- Main update loop
table.insert(Connections, RunService.RenderStepped:Connect(function()
    if not ScriptLoaded then return end
    
    pcall(function()
        Camera = workspace.CurrentCamera
        UpdateFOVCircle()
        UpdateESP()
        AimAssist()
        AutoDodge()
    end)
end))

-- Periodic full refresh
task.spawn(function()
    while ScriptLoaded do
        task.wait(2)
        if ScriptLoaded then
            RefreshAllESP()
        end
    end
end)

-- ==================== DOLLARWARE UI ====================

local window = ui.newWindow({
    text = 'Shitbot v6',
    resize = true,
    size = Vector2.new(550, 400)
})

-- Set window in API for addons to use
ShitbotAPI.Window = window

-- ========== AUTO DODGE MENU ==========
local dodgeMenu = window:addMenu({
    text = 'Auto Dodge'
})

local dodgeSection = dodgeMenu:addSection({
    text = 'Bullet Avoidance',
    side = 'left'
})

local autoDodgeToggle = dodgeSection:addToggle({
    text = 'Auto Dodge Enabled',
    state = Settings.AutoDodgeEnabled
})
autoDodgeToggle:bindToEvent('onToggle', function(state)
    Settings.AutoDodgeEnabled = state
    ui.notify({
        title = 'Auto Dodge',
        message = state and 'Enabled' or 'Disabled',
        duration = 2
    })
end)

dodgeSection:addSlider({
    text = 'Detection Radius',
    min = 10,
    max = 100,
    step = 1,
    val = Settings.DodgeRadius
}, function(val)
    Settings.DodgeRadius = val
end):setTooltip('How far to detect incoming bullets')

dodgeSection:addSlider({
    text = 'Dodge Distance',
    min = 1,
    max = 10,
    step = 0.5,
    val = Settings.DodgeDistance
}, function(val)
    Settings.DodgeDistance = val
end):setTooltip('How far to move when dodging')

dodgeSection:addSlider({
    text = 'Dodge Smoothness',
    min = 0.1,
    max = 1,
    step = 0.05,
    val = Settings.DodgeSmoothness
}, function(val)
    Settings.DodgeSmoothness = val
end):setTooltip('Lower = smoother dodging')

-- ========== AIM ASSIST MENU ==========
local aimMenu = window:addMenu({
    text = 'Aim Assist'
})

local aimSection = aimMenu:addSection({
    text = 'Aimbot Settings',
    side = 'left'
})

local aimToggle = aimSection:addToggle({
    text = 'Aim Assist Enabled',
    state = Settings.AimEnabled
})
aimToggle:bindToEvent('onToggle', function(state)
    Settings.AimEnabled = state
    ui.notify({
        title = 'Aim Assist',
        message = state and 'Enabled' or 'Disabled',
        duration = 2
    })
end)

local predictionToggle = aimSection:addToggle({
    text = 'Movement Prediction',
    state = Settings.Prediction
})
predictionToggle:bindToEvent('onToggle', function(state)
    Settings.Prediction = state
end)

local fovToggle = aimSection:addToggle({
    text = 'Show FOV Circle',
    state = Settings.ShowAimFOV
})
fovToggle:bindToEvent('onToggle', function(state)
    Settings.ShowAimFOV = state
end)

aimSection:addSlider({
    text = 'FOV Radius',
    min = 10,
    max = 500,
    step = 5,
    val = Settings.AimFOVRadius
}, function(val)
    Settings.AimFOVRadius = val
end):setTooltip('Aimbot detection radius')

aimSection:addSlider({
    text = 'Smoothness',
    min = 0.05,
    max = 0.95,
    step = 0.05,
    val = Settings.Smoothness
}, function(val)
    Settings.Smoothness = val
end):setTooltip('Lower = faster aiming')

aimSection:addSlider({
    text = 'Prediction Amount',
    min = 0.01,
    max = 0.5,
    step = 0.01,
    val = Settings.PredictionAmount
}, function(val)
    Settings.PredictionAmount = val
end)

-- Advanced Settings
aimSection:addLabel({
    text = ''
})

aimSection:addLabel({
    text = 'Advanced:'
})

local dynamicSmoothToggle = aimSection:addToggle({
    text = 'Dynamic Smoothing',
    state = Settings.DynamicSmoothing
})
dynamicSmoothToggle:bindToEvent('onToggle', function(state)
    Settings.DynamicSmoothing = state
end)
dynamicSmoothToggle:setTooltip('Adjust smoothing based on distance')

local humanizeToggle = aimSection:addToggle({
    text = 'Humanize Aim',
    state = Settings.HumanizeAim
})
humanizeToggle:bindToEvent('onToggle', function(state)
    Settings.HumanizeAim = state
end)
humanizeToggle:setTooltip('Add micro-adjustments for natural look')

local stickyToggle = aimSection:addToggle({
    text = 'Sticky Target',
    state = Settings.StickyTargetEnabled
})
stickyToggle:bindToEvent('onToggle', function(state)
    Settings.StickyTargetEnabled = state
end)
stickyToggle:setTooltip('Keep tracking current target')

local aimTargetSection = aimMenu:addSection({
    text = 'Hit Distribution',
    side = 'right'
})

aimTargetSection:addLabel({
    text = 'Smoothing Curve:'
})

aimTargetSection:addButton({
    text = 'Linear',
    style = 'small'
}, function()
    Settings.SmoothingType = "Linear"
    ui.notify({title = 'Aim', message = 'Smoothing: Linear', duration = 1.5})
end):setTooltip('Constant speed')

aimTargetSection:addButton({
    text = 'Ease-Out',
    style = 'small'
}, function()
    Settings.SmoothingType = "Ease-Out"
    ui.notify({title = 'Aim', message = 'Smoothing: Ease-Out (Recommended)', duration = 1.5})
end):setTooltip('Fast start, slow finish')

aimTargetSection:addButton({
    text = 'Sigmoid',
    style = 'small'
}, function()
    Settings.SmoothingType = "Sigmoid"
    ui.notify({title = 'Aim', message = 'Smoothing: Sigmoid (S-curve)', duration = 1.5})
end):setTooltip('Smooth S-curve acceleration')

aimTargetSection:addLabel({
    text = ''
})

aimTargetSection:addLabel({
    text = 'Aim Part Randomization'
})

local headshotSlider = aimTargetSection:addSlider({
    text = 'Headshot %',
    min = 0,
    max = 100,
    step = 5,
    val = Settings.HeadshotChance
}, function(val)
    Settings.HeadshotChance = val
    Settings.BodyshotChance = 100 - val
end)
headshotSlider:setTooltip('Chance to aim at head')

local bodyshotSlider = aimTargetSection:addSlider({
    text = 'Bodyshot %',
    min = 0,
    max = 100,
    step = 5,
    val = Settings.BodyshotChance
}, function(val)
    Settings.BodyshotChance = val
    Settings.HeadshotChance = 100 - val
end)
bodyshotSlider:setTooltip('Chance to aim at body')

aimTargetSection:addLabel({
    text = ''
})

aimTargetSection:addButton({
    text = 'All Headshots (100%)',
    style = 'small'
}, function()
    Settings.HeadshotChance = 100
    Settings.BodyshotChance = 0
    ui.notify({title = 'Aim', message = '100% Headshots', duration = 2})
end)

aimTargetSection:addButton({
    text = 'All Bodyshots (100%)',
    style = 'small'
}, function()
    Settings.HeadshotChance = 0
    Settings.BodyshotChance = 100
    ui.notify({title = 'Aim', message = '100% Bodyshots', duration = 2})
end)

aimTargetSection:addButton({
    text = 'Legit Mix (60/40)',
    style = 'small'
}, function()
    Settings.HeadshotChance = 60
    Settings.BodyshotChance = 40
    ui.notify({title = 'Aim', message = '60% Head / 40% Body', duration = 2})
end)

aimTargetSection:addButton({
    text = 'Force New Target',
    style = 'small'
}, function()
    CurrentTarget = nil
    CurrentAimPart = nil
    ui.notify({title = 'Aim', message = 'Target reset - will pick new aim spot', duration = 2})
end)

-- ========== ESP MENU ==========
local espMenu = window:addMenu({
    text = 'ESP'
})

local espSection = espMenu:addSection({
    text = 'ESP Toggles',
    side = 'left'
})

local espToggle = espSection:addToggle({
    text = 'ESP Enabled',
    state = Settings.ESPEnabled
})
espToggle:bindToEvent('onToggle', function(state)
    Settings.ESPEnabled = state
    ui.notify({
        title = 'ESP',
        message = state and 'Enabled' or 'Disabled',
        duration = 2
    })
end)

local boxToggle = espSection:addToggle({
    text = 'Player Boxes',
    state = Settings.ShowBoxes
})
boxToggle:bindToEvent('onToggle', function(state)
    Settings.ShowBoxes = state
end)

espSection:addButton({
    text = 'Box Style: Corners',
    style = 'small'
}, function()
    Settings.BoxStyle = "Corners"
    ui.notify({title = 'ESP', message = 'Box Style: Corners', duration = 1.5})
end):setTooltip('Modern corner brackets')

espSection:addButton({
    text = 'Box Style: Full',
    style = 'small'
}, function()
    Settings.BoxStyle = "Full"
    ui.notify({title = 'ESP', message = 'Box Style: Full Box', duration = 1.5})
end):setTooltip('Classic full box')

local distFadeToggle = espSection:addToggle({
    text = 'Distance Fade',
    state = Settings.DistanceFade
})
distFadeToggle:bindToEvent('onToggle', function(state)
    Settings.DistanceFade = state
end)
distFadeToggle:setTooltip('Fade ESP for distant players')

local nameToggle = espSection:addToggle({
    text = 'Player Names',
    state = Settings.ShowNames
})
nameToggle:bindToEvent('onToggle', function(state)
    Settings.ShowNames = state
end)

local distToggle = espSection:addToggle({
    text = 'Distance Display',
    state = Settings.ShowDistance
})
distToggle:bindToEvent('onToggle', function(state)
    Settings.ShowDistance = state
end)

local skeletonToggle = espSection:addToggle({
    text = 'Skeleton ESP',
    state = Settings.ShowSkeleton
})
skeletonToggle:bindToEvent('onToggle', function(state)
    Settings.ShowSkeleton = state
end)

local healthToggle = espSection:addToggle({
    text = 'Health Bars',
    state = Settings.ShowHealthBar
})
healthToggle:bindToEvent('onToggle', function(state)
    Settings.ShowHealthBar = state
end)

local tracerToggle = espSection:addToggle({
    text = 'Tracers',
    state = Settings.ShowTracers
})
tracerToggle:bindToEvent('onToggle', function(state)
    Settings.ShowTracers = state
end)

-- ESP Colors Section
local colorSection = espMenu:addSection({
    text = 'ESP Colors',
    side = 'right'
})

colorSection:addColorPicker({
    text = 'Enemy Color',
    color = Settings.EnemyColor
}, function(color)
    Settings.EnemyColor = color
end)

colorSection:addColorPicker({
    text = 'Teammate Color',
    color = Settings.TeammateColor
}, function(color)
    Settings.TeammateColor = color
end)

colorSection:addColorPicker({
    text = 'Skeleton Color',
    color = Settings.SkeletonColor
}, function(color)
    Settings.SkeletonColor = color
end)

colorSection:addColorPicker({
    text = 'FOV Circle Color',
    color = Settings.FOVColor
}, function(color)
    Settings.FOVColor = color
    FOVStroke.Color = color
end)

-- ========== TEAM & CAMERA MENU ==========
local miscMenu = window:addMenu({
    text = 'Teams & Camera'
})

local teamSection = miscMenu:addSection({
    text = 'Team Settings',
    side = 'left'
})

local teamCheckToggle = teamSection:addToggle({
    text = 'Team Check (Ignore Allies)',
    state = Settings.TeamCheck
})
teamCheckToggle:bindToEvent('onToggle', function(state)
    Settings.TeamCheck = state
end)

local showTeamToggle = teamSection:addToggle({
    text = 'Show Teammates ESP',
    state = Settings.ShowTeammates
})
showTeamToggle:bindToEvent('onToggle', function(state)
    Settings.ShowTeammates = state
end)

teamSection:addLabel({
    text = ''
})

teamSection:addLabel({
    text = 'Billboard Detection'
})

local blueBillboardToggle = teamSection:addToggle({
    text = 'Blue Billboard = Teammate',
    state = Settings.BlueBillboardTeamCheck
})
blueBillboardToggle:bindToEvent('onToggle', function(state)
    Settings.BlueBillboardTeamCheck = state
    ui.notify({
        title = 'Billboard Detection',
        message = state and 'Blue billboards treated as teammates' or 'Disabled',
        duration = 2
    })
end)
blueBillboardToggle:setTooltip('Players with blue name tags/indicators are allies')

local redBillboardToggle = teamSection:addToggle({
    text = 'Red Billboard = Teammate',
    state = Settings.RedBillboardTeamCheck
})
redBillboardToggle:bindToEvent('onToggle', function(state)
    Settings.RedBillboardTeamCheck = state
    ui.notify({
        title = 'Billboard Detection',
        message = state and 'Red billboards treated as teammates' or 'Disabled',
        duration = 2
    })
end)
redBillboardToggle:setTooltip('Players with red name tags/indicators are allies')

local cameraSection = miscMenu:addSection({
    text = 'Camera FOV',
    side = 'right'
})

-- Camera FOV dedicated loop connection
local CameraFOVConnection = nil

local function StartCameraFOV()
    -- Stop existing connection if any
    if CameraFOVConnection then
        CameraFOVConnection:Disconnect()
        CameraFOVConnection = nil
    end
    
    -- Start new loop that constantly applies FOV
    CameraFOVConnection = RunService.RenderStepped:Connect(function()
        if Settings.CameraFOVEnabled and ScriptLoaded then
            local cam = workspace.CurrentCamera
            if cam and cam.FieldOfView ~= Settings.CameraFOV then
                cam.FieldOfView = Settings.CameraFOV
            end
        end
    end)
    
    table.insert(Connections, CameraFOVConnection)
end

local function StopCameraFOV()
    if CameraFOVConnection then
        CameraFOVConnection:Disconnect()
        CameraFOVConnection = nil
    end
    pcall(function()
        workspace.CurrentCamera.FieldOfView = 70
    end)
end

-- Start the system
StartCameraFOV()

local cameraFOVToggle = cameraSection:addToggle({
    text = 'Enable Custom FOV',
    state = Settings.CameraFOVEnabled
})
cameraFOVToggle:bindToEvent('onToggle', function(state)
    Settings.CameraFOVEnabled = state
    if not state then
        pcall(function()
            workspace.CurrentCamera.FieldOfView = 70
        end)
    end
end)

cameraSection:addSlider({
    text = 'FOV Value',
    min = 30,
    max = 120,
    step = 1,
    val = Settings.CameraFOV
}, function(val)
    Settings.CameraFOV = val
    -- Auto enable when slider is used
    Settings.CameraFOVEnabled = true
end):setTooltip('30 = zoomed in, 120 = zoomed out')

cameraSection:addButton({
    text = 'Reset to Default (70)',
    style = 'small'
}, function()
    Settings.CameraFOV = 70
    Settings.CameraFOVEnabled = false
    pcall(function()
        workspace.CurrentCamera.FieldOfView = 70
    end)
end)

-- ========== ACTIONS MENU ==========
local actionsMenu = window:addMenu({
    text = 'Actions'
})

local actionSection = actionsMenu:addSection({
    text = 'Quick Actions',
    side = 'left'
})

actionSection:addButton({
    text = 'Teleport Behind Enemy',
    style = 'large'
}, function()
    TeleportBehindRandomPlayer()
end):setTooltip('Teleport behind a random enemy player')

local tpHotkey = actionSection:addHotkey({
    text = 'Teleport Hotkey'
})
tpHotkey:setHotkey(Enum.KeyCode.H)
tpHotkey:bindToEvent('onFire', function()
    TeleportBehindRandomPlayer()
end)

actionSection:addLabel({
    text = ''
})

actionSection:addButton({
    text = 'Save Settings',
    style = 'small'
}, function()
    SaveSettings()
    ui.notify({
        title = 'Settings',
        message = 'Settings saved!',
        duration = 2
    })
end):setTooltip('Save current settings to file')

actionSection:addButton({
    text = 'Reset to Defaults',
    style = 'small'
}, function()
    -- Reset all settings to defaults
    Settings.AimEnabled = true
    Settings.AimFOVRadius = 150
    Settings.Smoothness = 0.3
    Settings.Prediction = true
    Settings.PredictionAmount = 0.12
    Settings.HeadshotChance = 70
    Settings.BodyshotChance = 30
    Settings.CameraFOV = 70
    Settings.CameraFOVEnabled = false
    Settings.AutoDodgeEnabled = true
    Settings.DodgeRadius = 50
    Settings.DodgeDistance = 4
    Settings.DodgeSmoothness = 0.3
    Settings.TeamCheck = true
    Settings.ShowTeammates = true
    Settings.BlueBillboardTeamCheck = false
    Settings.RedBillboardTeamCheck = false
    Settings.ESPEnabled = true
    Settings.ShowBoxes = true
    Settings.ShowNames = true
    Settings.ShowDistance = true
    Settings.ShowSkeleton = true
    Settings.ShowHealthBar = true
    Settings.ShowTracers = false
    Settings.ShowAimFOV = true
    Settings.BoxStyle = "Corners"
    Settings.ShowTextBackgrounds = true
    Settings.DistanceFade = true
    
    -- Advanced Aim Settings
    Settings.SmoothingType = "Linear"
    Settings.StickyTargetEnabled = true
    Settings.StickyTargetMultiplier = 1.15
    Settings.HumanizeAim = true
    Settings.DynamicSmoothing = true
    
    -- Cherry Theme Colors
    Settings.FOVColor = Color3.fromRGB(200, 200, 200)
    Settings.FOVColorActive = Color3.fromRGB(170, 50, 60)
    Settings.EnemyColor = Color3.fromRGB(255, 75, 85)
    Settings.EnemyColorSecondary = Color3.fromRGB(170, 50, 60)
    Settings.TeammateColor = Color3.fromRGB(85, 200, 255)
    Settings.TeammateColorSecondary = Color3.fromRGB(60, 140, 200)
    Settings.SkeletonColor = Color3.fromRGB(255, 100, 255)
    Settings.TeamSkeletonColor = Color3.fromRGB(85, 200, 255)
    Settings.TracerColor = Color3.fromRGB(255, 75, 85)
    Settings.TeamTracerColor = Color3.fromRGB(85, 200, 255)
    Settings.HealthFullColor = Color3.fromRGB(85, 255, 100)
    Settings.HealthMidColor = Color3.fromRGB(255, 200, 0)
    Settings.HealthLowColor = Color3.fromRGB(255, 75, 85)
    
    -- Reset camera FOV
    pcall(function()
        workspace.CurrentCamera.FieldOfView = 70
    end)
    
    SaveSettings()
    ui.notify({
        title = 'Settings',
        message = 'Reset to defaults! Rejoin to apply all changes.',
        duration = 3
    })
end):setTooltip('Reset all settings to default values')

actionSection:addLabel({
    text = ''
})

actionSection:addButton({
    text = 'Unload Script',
    style = 'large'
}, function()
    UnloadScript()
end):setTooltip('Save settings and unload script')

local infoSection = actionsMenu:addSection({
    text = 'Information',
    side = 'right'
})

infoSection:addLabel({
    text = 'Controls:'
})
infoSection:addLabel({
    text = '[H] - Teleport Behind Enemy'
})
infoSection:addLabel({
    text = '[RMB] - Activate Aim Assist'
})
infoSection:addLabel({
    text = ''
})
infoSection:addLabel({
    text = 'Settings:'
})
infoSection:addLabel({
    text = 'Auto-saves every 30 sec'
})
infoSection:addLabel({
    text = 'Saves on unload'
})
infoSection:addLabel({
    text = ''
})
infoSection:addLabel({
    text = 'Loaded Addons:'
})

-- Dynamic addon list label
local addonListLabel = infoSection:addLabel({
    text = 'None'
})

-- ========== ADDON SETTINGS MENU ==========
local addonSettingsMenu = window:addMenu({
    text = 'Addon Settings'
})

local addonManageSection = addonSettingsMenu:addSection({
    text = 'Loaded Addons',
    side = 'left'
})

addonManageSection:addLabel({
    text = 'Currently Loaded:'
})

local loadedAddonsLabel = addonManageSection:addLabel({
    text = 'None'
})

local trustSection = addonSettingsMenu:addSection({
    text = 'Trusted Addons',
    side = 'right'
})

trustSection:addLabel({
    text = 'Trusted addons skip the'
})
trustSection:addLabel({
    text = '5-second warning screen.'
})
trustSection:addLabel({
    text = ''
})

local trustedListLabel = trustSection:addLabel({
    text = 'Trusted: None'
})

trustSection:addButton({
    text = 'Clear All Trusted',
    style = 'large'
}, function()
    Settings.TrustedAddons = {}
    ShitbotAPI:UpdateAddonList()
    ui.notify({
        title = 'Trusted Addons',
        message = 'All trusted addons cleared',
        duration = 2
    })
end):setTooltip('Remove all addons from trusted list')

-- Function to update displays
function ShitbotAPI:UpdateAddonList()
    -- Update loaded addons display
    local addonNames = {}
    for _, addon in pairs(self.Addons) do
        table.insert(addonNames, addon.name .. " v" .. addon.version)
    end
    
    if #addonNames > 0 then
        loadedAddonsLabel.text = table.concat(addonNames, ", ")
        addonListLabel.text = table.concat(addonNames, ", ")
    else
        loadedAddonsLabel.text = "None"
        addonListLabel.text = "None"
    end
    
    -- Update trusted addons display
    if #Settings.TrustedAddons > 0 then
        trustedListLabel.text = "Trusted: " .. table.concat(Settings.TrustedAddons, ", ")
    else
        trustedListLabel.text = "Trusted: None"
    end
end

-- Keybind for teleport
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not ScriptLoaded then return end
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.H then
        TeleportBehindRandomPlayer()
    end
end))

-- Startup notification
ui.notify({
    title = 'Shitbot v6',
    message = 'Loaded! Settings restored.',
    duration = 4
})

print("═══════════════════════════════════════════════════")
print("              Shitbot v6 Loaded!")
print("═══════════════════════════════════════════════════")
print("   [H] - Teleport Behind Random Enemy")
print("   [Right Click] - Activate Aim Assist")
print("═══════════════════════════════════════════════════")
print("   Settings: Auto-saves every 30 seconds")
print("   File: ShitbotV6_Settings.json")
print("═══════════════════════════════════════════════════")
print("   Addon System Active!")
print("   Use _G.ShitbotAPI or shared.ShitbotAPI")
print("═══════════════════════════════════════════════════")

-- Copy this function into any script:

local function msg(text, color)
    if _G.OperatorHubAddMessage then
        _G.OperatorHubAddMessage(text, _G.OperatorHubColors[color or "white"])
    end
end

-- Usage:

msg("Shitbot Loaded", "green")
msg("Shitbot Made By Spooky and Sanchez", "gold")
