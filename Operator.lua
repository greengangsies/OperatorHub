--[[
    OperatorHub - Minecraft-Style Admin Script
    Press ';' to open command bar
    
    Uses the Minecraft font sprite sheet with correct character mapping
]]

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Configuration
local CONFIG = {
    ToggleKey = Enum.KeyCode.Semicolon,
    MaxChatHistory = 100,
    MessageFadeTime = 3,
    MessageFadeDelay = 7,
    WorkspaceFolder = "OperatorHub",
    AssetsFolder = "assets",
    FontFile = "Minecraft.ttf",
    GitHubRepo = "greengangsies/OperatorHub", -- Change this to your GitHub repo (format: username/repository)
    GitHubBranch = "main",
    GitHubScriptsPath = "commands",
}

-- Font settings
local USE_CUSTOM_FONT = false
local CUSTOM_FONT = nil

-- Minecraft Font Sprite Sheet
local FONT_SHEET = "rbxassetid://3108589584"

-- Minecraft Colors
local MC = {
    black = Color3.fromRGB(0, 0, 0),
    dark_blue = Color3.fromRGB(0, 0, 170),
    dark_green = Color3.fromRGB(0, 170, 0),
    dark_aqua = Color3.fromRGB(0, 170, 170),
    dark_red = Color3.fromRGB(170, 0, 0),
    dark_purple = Color3.fromRGB(170, 0, 170),
    gold = Color3.fromRGB(255, 170, 0),
    gray = Color3.fromRGB(170, 170, 170),
    dark_gray = Color3.fromRGB(85, 85, 85),
    blue = Color3.fromRGB(85, 85, 255),
    green = Color3.fromRGB(85, 255, 85),
    aqua = Color3.fromRGB(85, 255, 255),
    red = Color3.fromRGB(255, 85, 85),
    light_purple = Color3.fromRGB(255, 85, 255),
    yellow = Color3.fromRGB(255, 255, 85),
    white = Color3.fromRGB(255, 255, 255),
}

-- Character sprite positions on the Minecraft font sheet (ImageRectOffset)
-- Format: [char] = {offsetX, offsetY, width}
local CHAR_DATA = {
    -- Row 1 (y=32) - Special chars and numbers
    [" "] = {0, 32, 4},
    ["!"] = {16, 32, 2},
    ['"'] = {32, 32, 5},
    ["#"] = {48, 32, 6},
    ["$"] = {64, 32, 6},
    ["%"] = {80, 32, 6},
    ["&"] = {96, 32, 6},
    ["'"] = {112, 32, 3},
    ["("] = {128, 32, 5},
    [")"] = {144, 32, 5},
    ["*"] = {160, 32, 5},
    ["+"] = {176, 32, 6},
    [","] = {192, 32, 2},
    ["-"] = {208, 32, 6},
    ["."] = {224, 32, 2},
    ["/"] = {240, 32, 6},
    
    -- Row 2 (y=48) - Numbers and some punctuation
    ["0"] = {0, 48, 6},
    ["1"] = {16, 48, 6},
    ["2"] = {32, 48, 6},
    ["3"] = {48, 48, 6},
    ["4"] = {64, 48, 6},
    ["5"] = {80, 48, 6},
    ["6"] = {96, 48, 6},
    ["7"] = {112, 48, 6},
    ["8"] = {128, 48, 6},
    ["9"] = {144, 48, 6},
    [":"] = {160, 48, 2},
    [";"] = {176, 48, 2},
    ["<"] = {192, 48, 5},
    ["="] = {208, 48, 6},
    [">"] = {224, 48, 5},
    ["?"] = {240, 48, 6},
    
    -- Row 3 (y=64) - @ and uppercase A-O
    ["@"] = {0, 64, 7},
    ["A"] = {16, 64, 6},
    ["B"] = {32, 64, 6},
    ["C"] = {48, 64, 6},
    ["D"] = {64, 64, 6},
    ["E"] = {80, 64, 6},
    ["F"] = {96, 64, 6},
    ["G"] = {112, 64, 6},
    ["H"] = {128, 64, 6},
    ["I"] = {144, 64, 4},
    ["J"] = {160, 64, 6},
    ["K"] = {176, 64, 6},
    ["L"] = {192, 64, 6},
    ["M"] = {208, 64, 6},
    ["N"] = {224, 64, 6},
    ["O"] = {240, 64, 6},
    
    -- Row 4 (y=80) - Uppercase P-Z and some symbols
    ["P"] = {0, 80, 6},
    ["Q"] = {16, 80, 6},
    ["R"] = {32, 80, 6},
    ["S"] = {48, 80, 6},
    ["T"] = {64, 80, 6},
    ["U"] = {80, 80, 6},
    ["V"] = {96, 80, 6},
    ["W"] = {112, 80, 6},
    ["X"] = {128, 80, 6},
    ["Y"] = {144, 80, 6},
    ["Z"] = {160, 80, 6},
    ["["] = {176, 80, 4},
    ["\\"] = {192, 80, 6},
    ["]"] = {208, 80, 4},
    ["^"] = {224, 80, 6},
    ["_"] = {240, 80, 6},
    
    -- Row 5 (y=96) - ` and lowercase a-o
    ["`"] = {0, 96, 3},
    ["a"] = {16, 96, 6},
    ["b"] = {32, 96, 6},
    ["c"] = {48, 96, 6},
    ["d"] = {64, 96, 6},
    ["e"] = {80, 96, 6},
    ["f"] = {96, 96, 5},
    ["g"] = {112, 96, 6},
    ["h"] = {128, 96, 6},
    ["i"] = {144, 96, 2},
    ["j"] = {160, 96, 6},
    ["k"] = {176, 96, 5},
    ["l"] = {192, 96, 3},
    ["m"] = {208, 96, 6},
    ["n"] = {224, 96, 6},
    ["o"] = {240, 96, 6},
    
    -- Row 6 (y=112) - Lowercase p-z and symbols
    ["p"] = {0, 112, 6},
    ["q"] = {16, 112, 6},
    ["r"] = {32, 112, 6},
    ["s"] = {48, 112, 6},
    ["t"] = {64, 112, 4},
    ["u"] = {80, 112, 6},
    ["v"] = {96, 112, 6},
    ["w"] = {112, 112, 6},
    ["x"] = {128, 112, 6},
    ["y"] = {144, 112, 6},
    ["z"] = {160, 112, 6},
    ["{"] = {176, 112, 5},
    ["|"] = {192, 112, 2},
    ["}"] = {208, 112, 5},
    ["~"] = {224, 112, 7},
}

-- State
local Commands = {}
local CommandHistory = {}
local ChatMessages = {}
local HistoryIndex = 0
local uiOpen = false
local GitHubCommands = {}

-- File system
local FS = {
    writefile = writefile or function() end,
    readfile = readfile or function() return "" end,
    isfile = isfile or function() return false end,
    isfolder = isfolder or function() return false end,
    makefolder = makefolder or function() end,
    listfiles = listfiles or function() return {} end,
}

local function HttpGet(url)
    if game.HttpGet then return game:HttpGet(url)
    elseif request then return request({Url = url}).Body
    elseif http_request then return http_request({Url = url}).Body
    elseif syn and syn.request then return syn.request({Url = url}).Body
    end
    return HttpService:GetAsync(url)
end

local function SetupFolders()
    pcall(function()
        if not FS.isfolder(CONFIG.WorkspaceFolder) then
            FS.makefolder(CONFIG.WorkspaceFolder)
        end
        if not FS.isfolder(CONFIG.WorkspaceFolder .. "/" .. CONFIG.AssetsFolder) then
            FS.makefolder(CONFIG.WorkspaceFolder .. "/" .. CONFIG.AssetsFolder)
        end
        
        -- Try to load custom Minecraft font
        local fontPath = CONFIG.WorkspaceFolder .. "/" .. CONFIG.AssetsFolder .. "/" .. CONFIG.FontFile
        if FS.isfile(fontPath) then
            local success, fontData = pcall(function()
                return FS.readfile(fontPath)
            end)
            if success and fontData and #fontData > 0 then
                -- Create a temporary asset for the font
                local tempAsset = Instance.new("Folder")
                tempAsset.Name = "MinecraftFont"
                
                -- Try to use getcustomasset or getsynasset
                local assetFunc = getcustomasset or getsynasset
                if assetFunc then
                    local success2, result = pcall(function()
                        return assetFunc(fontPath)
                    end)
                    if success2 then
                        CUSTOM_FONT = result
                        USE_CUSTOM_FONT = true
                        print("[OperatorHub] Loaded custom Minecraft font")
                    end
                end
            end
        end
    end)
end

-- Create a single character sprite with shadow
local function CreateChar(char, color, parent, xPos)
    local data = CHAR_DATA[char]
    if not data then
        data = CHAR_DATA[" "] or {0, 32, 4}
    end
    
    local offsetX, offsetY, charWidth = data[1], data[2], data[3]
    
    -- Shadow color (25% brightness)
    local shadowColor = Color3.fromRGB(
        math.floor(color.R * 255 * 0.25),
        math.floor(color.G * 255 * 0.25),
        math.floor(color.B * 255 * 0.25)
    )
    
    -- Shadow (behind, offset by 2 pixels)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(0, 16, 0, 16)
    shadow.Position = UDim2.new(0, xPos + 2, 0, 2)
    shadow.BackgroundTransparency = 1
    shadow.Image = FONT_SHEET
    shadow.ImageRectOffset = Vector2.new(offsetX, offsetY)
    shadow.ImageRectSize = Vector2.new(16, 16)
    shadow.ImageColor3 = shadowColor
    shadow.ScaleType = Enum.ScaleType.Fit
    shadow.ZIndex = 1
    shadow.Parent = parent
    
    -- Main character (in front)
    local main = Instance.new("ImageLabel")
    main.Name = char
    main.Size = UDim2.new(0, 16, 0, 16)
    main.Position = UDim2.new(0, xPos, 0, 0)
    main.BackgroundTransparency = 1
    main.Image = FONT_SHEET
    main.ImageRectOffset = Vector2.new(offsetX, offsetY)
    main.ImageRectSize = Vector2.new(16, 16)
    main.ImageColor3 = color
    main.ScaleType = Enum.ScaleType.Fit
    main.ZIndex = 2
    main.Parent = parent
    
    -- Return the advance width based on actual character width + spacing
    -- Scale the character width properly (multiply by 1.5) and add 2px spacing
    return math.floor(charWidth * 1.5) + 2
end

-- Create a line of text using sprite characters OR custom font
local function CreateTextLine(text, color, parent, layoutOrder)
    color = color or MC.white
    
    local container = Instance.new("Frame")
    container.Name = "TextLine"
    container.Size = UDim2.new(1, 0, 0, 16)
    container.BackgroundTransparency = 1
    container.LayoutOrder = layoutOrder or 0
    container.Parent = parent
    
    -- Use custom font if available
    if USE_CUSTOM_FONT and CUSTOM_FONT then
        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "Text"
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = text
        textLabel.TextColor3 = color
        textLabel.TextSize = 16
        textLabel.Font = Enum.Font.Code -- Fallback
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
        textLabel.TextYAlignment = Enum.TextYAlignment.Top
        
        -- Try to apply custom font
        pcall(function()
            textLabel.FontFace = Font.new(CUSTOM_FONT)
        end)
        
        textLabel.Parent = container
        return container, textLabel.TextBounds.X
    end
    
    -- Otherwise use sprite font
    local xPos = 0
    for i = 1, #text do
        local char = text:sub(i, i)
        local advance = CreateChar(char, color, container, xPos)
        xPos = xPos + advance
    end
    
    return container, xPos
end

-- GitHub functions
local function FetchGitHubScripts()
    if CONFIG.GitHubRepo == "" then return {} end
    local url = string.format("https://api.github.com/repos/%s/contents/%s?ref=%s",
        CONFIG.GitHubRepo, CONFIG.GitHubScriptsPath, CONFIG.GitHubBranch)
    local ok, result = pcall(function() return HttpGet(url) end)
    if not ok then return {} end
    local ok2, data = pcall(function() return HttpService:JSONDecode(result) end)
    if not ok2 or type(data) ~= "table" then return {} end
    local scripts = {}
    for _, file in ipairs(data) do
        if file.name and file.name:match("%.lua$") then
            scripts[file.name:gsub("%.lua$", ""):lower()] = {
                name = file.name:gsub("%.lua$", ""),
                url = file.download_url,
            }
        end
    end
    return scripts
end

local function ExecuteGitHubScript(info, args)
    local ok, content = pcall(function() return HttpGet(info.url) end)
    if not ok then return false, "Download failed" end
    local func, err = loadstring(content)
    if not func then return false, err end
    local ok2, result = pcall(func)
    if not ok2 then return false, result end
    if type(result) == "function" then pcall(result, args)
    elseif type(result) == "table" and result.Execute then pcall(result.Execute, args) end
    return true
end

-- Create UI
local function CreateUI()
    local existing = PlayerGui:FindFirstChild("OperatorHubUI")
    if existing then existing:Destroy() end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "OperatorHubUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 1
    gui.Parent = PlayerGui
    
    -- Command Bar (bottom of screen, like MC)
    local commandBar = Instance.new("Frame")
    commandBar.Name = "CommandBar"
    commandBar.AnchorPoint = Vector2.new(0.5, 1)
    commandBar.Size = UDim2.new(1, -10, 0, 26)
    commandBar.Position = UDim2.new(0.5, 0, 1, -5)
    commandBar.BackgroundColor3 = MC.black
    commandBar.BackgroundTransparency = 0.5
    commandBar.BorderSizePixel = 0
    commandBar.Visible = false
    commandBar.Parent = gui
    
    -- Input text container (inside command bar)
    local inputContainer = Instance.new("Frame")
    inputContainer.Name = "InputContainer"
    inputContainer.Size = UDim2.new(1, -10, 0, 16)
    inputContainer.Position = UDim2.new(0, 5, 0, 4)
    inputContainer.BackgroundTransparency = 1
    inputContainer.ClipsDescendants = true
    inputContainer.Parent = commandBar
    
    -- Typing cursor
    local cursor = Instance.new("ImageLabel")
    cursor.Name = "Cursor"
    cursor.Size = UDim2.new(0, 16, 0, 16)
    cursor.Position = UDim2.new(0, 0, 0, 0)
    cursor.BackgroundTransparency = 1
    cursor.Image = FONT_SHEET
    cursor.ImageRectOffset = Vector2.new(240, 80) -- underscore
    cursor.ImageRectSize = Vector2.new(16, 16)
    cursor.ImageColor3 = MC.white
    cursor.ZIndex = 3
    cursor.Parent = inputContainer
    
    -- Hidden textbox for input
    local hiddenInput = Instance.new("TextBox")
    hiddenInput.Name = "HiddenInput"
    hiddenInput.Size = UDim2.new(0, 1, 0, 1)
    hiddenInput.Position = UDim2.new(0, -1000, 0, -1000)
    hiddenInput.BackgroundTransparency = 1
    hiddenInput.Text = ""
    hiddenInput.TextTransparency = 1
    hiddenInput.ClearTextOnFocus = false
    hiddenInput.Parent = commandBar
    
    -- Chat history (above command bar)
    local chatHistory = Instance.new("Frame")
    chatHistory.Name = "ChatHistory"
    chatHistory.AnchorPoint = Vector2.new(0, 1)
    chatHistory.Size = UDim2.new(1, -20, 1, -128)
    chatHistory.Position = UDim2.new(0, 10, 1, -36)
    chatHistory.BackgroundTransparency = 1
    chatHistory.ClipsDescendants = true
    chatHistory.Parent = gui
    
    -- Chat scroll
    local chatScroll = Instance.new("ScrollingFrame")
    chatScroll.Name = "ChatScroll"
    chatScroll.Size = UDim2.new(1, 0, 1, 0)
    chatScroll.BackgroundTransparency = 1
    chatScroll.BorderSizePixel = 0
    chatScroll.ScrollBarThickness = 0
    chatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    chatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    chatScroll.ScrollingEnabled = false
    chatScroll.Parent = chatHistory
    
    local chatLayout = Instance.new("UIListLayout")
    chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
    chatLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    chatLayout.Padding = UDim.new(0, 4)
    chatLayout.Parent = chatScroll
    
    -- Command list panel (right side)
    local cmdPanel = Instance.new("Frame")
    cmdPanel.Name = "CommandPanel"
    cmdPanel.Size = UDim2.new(0, 160, 0, 250)
    cmdPanel.Position = UDim2.new(1, -170, 0.5, -125)
    cmdPanel.BackgroundColor3 = MC.black
    cmdPanel.BackgroundTransparency = 0.5
    cmdPanel.BorderSizePixel = 2
    cmdPanel.BorderColor3 = MC.black
    cmdPanel.Visible = false
    cmdPanel.Parent = gui
    
    -- Panel title
    local titleContainer = Instance.new("Frame")
    titleContainer.Size = UDim2.new(1, 0, 0, 20)
    titleContainer.Position = UDim2.new(0, 4, 0, 2)
    titleContainer.BackgroundTransparency = 1
    titleContainer.Parent = cmdPanel
    CreateTextLine("Commands", MC.white, titleContainer, 0)
    
    -- Command scroll
    local cmdScroll = Instance.new("ScrollingFrame")
    cmdScroll.Name = "CmdScroll"
    cmdScroll.Size = UDim2.new(1, -8, 1, -28)
    cmdScroll.Position = UDim2.new(0, 4, 0, 24)
    cmdScroll.BackgroundTransparency = 1
    cmdScroll.BorderSizePixel = 0
    cmdScroll.ScrollBarThickness = 4
    cmdScroll.ScrollBarImageColor3 = MC.gray
    cmdScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    cmdScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    cmdScroll.Parent = cmdPanel
    
    local cmdLayout = Instance.new("UIListLayout")
    cmdLayout.SortOrder = Enum.SortOrder.Name
    cmdLayout.Padding = UDim.new(0, 2)
    cmdLayout.Parent = cmdScroll
    
    return {
        Gui = gui,
        CommandBar = commandBar,
        InputContainer = inputContainer,
        Cursor = cursor,
        HiddenInput = hiddenInput,
        ChatHistory = chatHistory,
        ChatScroll = chatScroll,
        CmdPanel = cmdPanel,
        CmdScroll = cmdScroll,
    }
end

local UI = CreateUI()

-- Update input display
local function UpdateInputDisplay(text)
    -- Clear existing chars (except cursor)
    for _, child in pairs(UI.InputContainer:GetChildren()) do
        if child.Name ~= "Cursor" then
            child:Destroy()
        end
    end
    
    local xPos = 0
    for i = 1, #text do
        local char = text:sub(i, i)
        local advance = CreateChar(char, MC.white, UI.InputContainer, xPos)
        xPos = xPos + advance
    end
    
    -- Update cursor position
    UI.Cursor.Position = UDim2.new(0, xPos, 0, 0)
end

-- Add message to chat
local function AddMessage(text, color)
    color = color or MC.white
    
    -- Create message container with background
    local msgFrame = Instance.new("Frame")
    msgFrame.Name = "Message"
    msgFrame.Size = UDim2.new(0, 512, 0, 16)
    msgFrame.BackgroundColor3 = MC.black
    msgFrame.BackgroundTransparency = 0.5
    msgFrame.BorderSizePixel = 2
    msgFrame.BorderColor3 = MC.black
    msgFrame.LayoutOrder = #ChatMessages + 1
    msgFrame.Parent = UI.ChatScroll
    
    -- Create text inside
    local textContainer = Instance.new("Frame")
    textContainer.Size = UDim2.new(1, 0, 1, 0)
    textContainer.BackgroundTransparency = 1
    textContainer.Parent = msgFrame
    
    local xPos = 0
    for i = 1, #text do
        local char = text:sub(i, i)
        local advance = CreateChar(char, color, textContainer, xPos)
        xPos = xPos + advance
    end
    
    table.insert(ChatMessages, {
        Frame = msgFrame,
        Time = tick()
    })
    
    if #ChatMessages > CONFIG.MaxChatHistory then
        ChatMessages[1].Frame:Destroy()
        table.remove(ChatMessages, 1)
    end
    
    task.defer(function()
        UI.ChatScroll.CanvasPosition = Vector2.new(0, UI.ChatScroll.AbsoluteCanvasSize.Y)
    end)
end

-- Register command
local function RegisterCommand(name, desc, callback, usage)
    Commands[name:lower()] = {
        Name = name,
        Desc = desc or "",
        Callback = callback,
        Usage = usage or "/" .. name:lower()
    }
end

-- Update command list
local function UpdateCmdList()
    for _, c in pairs(UI.CmdScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local i = 1
    for name in pairs(Commands) do
        local f = Instance.new("Frame")
        f.Name = name
        f.Size = UDim2.new(1, 0, 0, 16)
        f.BackgroundTransparency = 1
        f.LayoutOrder = i
        f.Parent = UI.CmdScroll
        CreateTextLine("/" .. name, MC.yellow, f, i)
        i = i + 1
    end
end

-- Execute command
local function ExecuteCommand(input)
    if input == "" then return end
    table.insert(CommandHistory, input)
    HistoryIndex = #CommandHistory + 1
    AddMessage(input, MC.gray)
    
    if not input:match("^/") then
        AddMessage("Unknown command. Type /help", MC.red)
        -- Close UI after command execution
        if uiOpen then
            ToggleUI()
        end
        return
    end
    
    local parts = {}
    for p in input:gmatch("%S+") do table.insert(parts, p) end
    local name = parts[1]:sub(2):lower()
    local args = {}
    for i = 2, #parts do table.insert(args, parts[i]) end
    
    local cmd = Commands[name]
    if cmd then
        local ok, err = pcall(function() cmd.Callback(args) end)
        if not ok then AddMessage("Error: " .. tostring(err), MC.red) end
        -- Close UI after command execution
        if uiOpen then
            ToggleUI()
        end
        return
    end
    
    local gh = GitHubCommands[name]
    if gh then
        AddMessage("Loading from GitHub...", MC.gray)
        local ok, err = ExecuteGitHubScript(gh, args)
        if ok then AddMessage("Executed: " .. name, MC.green)
        else AddMessage("Error: " .. tostring(err), MC.red) end
        -- Close UI after command execution
        if uiOpen then
            ToggleUI()
        end
        return
    end
    
    AddMessage("Unknown command: /" .. name, MC.red)
    -- Close UI after command execution
    if uiOpen then
        ToggleUI()
    end
end

-- Load GitHub commands
local function LoadGitHubCommands()
    AddMessage("Checking GitHub...", MC.gray)
    GitHubCommands = FetchGitHubScripts()
    local count = 0
    for name, info in pairs(GitHubCommands) do
        RegisterCommand(name, "GitHub: " .. name, function(args)
            local ok, err = ExecuteGitHubScript(info, args)
            if ok then AddMessage("Executed: " .. name, MC.green)
            else AddMessage("Error: " .. tostring(err), MC.red) end
        end)
        count = count + 1
    end
    if count > 0 then AddMessage("Loaded " .. count .. " from GitHub", MC.green)
    else AddMessage("No GitHub commands", MC.gold) end
    UpdateCmdList()
end

-- Built-in commands
RegisterCommand("help", "Show commands", function(args)
    if args[1] then
        local c = Commands[args[1]:lower()]
        if c then
            AddMessage("/" .. c.Name .. " - " .. c.Desc, MC.green)
        else
            AddMessage("Unknown command", MC.red)
        end
    else
        AddMessage("--- Commands ---", MC.yellow)
        for n, c in pairs(Commands) do
            AddMessage("/" .. n, MC.gray)
        end
    end
end)

RegisterCommand("clear", "Clear chat", function()
    for _, m in pairs(ChatMessages) do m.Frame:Destroy() end
    ChatMessages = {}
end)

RegisterCommand("reload", "Reload GitHub", function()
    LoadGitHubCommands()
end)

RegisterCommand("say", "Send message", function(args)
    AddMessage("<" .. Player.Name .. "> " .. table.concat(args, " "), MC.white)
end)

RegisterCommand("speed", "Set speed", function(args)
    local s = tonumber(args[1]) or 16
    local c = Player.Character
    if c and c:FindFirstChild("Humanoid") then
        c.Humanoid.WalkSpeed = s
        AddMessage("Speed: " .. s, MC.gray)
    end
end)

RegisterCommand("jump", "Set jump", function(args)
    local j = tonumber(args[1]) or 50
    local c = Player.Character
    if c and c:FindFirstChild("Humanoid") then
        c.Humanoid.JumpPower = j
        AddMessage("Jump: " .. j, MC.gray)
    end
end)

RegisterCommand("tp", "Teleport xyz", function(args)
    local x, y, z = tonumber(args[1]) or 0, tonumber(args[2]) or 0, tonumber(args[3]) or 0
    local c = Player.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        c.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
        AddMessage("TP: " .. x .. "," .. y .. "," .. z, MC.gray)
    end
end)

RegisterCommand("goto", "Teleport to player", function(args)
    if not args[1] then return end
    for _, p in pairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1, #args[1]) == args[1]:lower() then
            local c1, c2 = Player.Character, p.Character
            if c1 and c2 and c1:FindFirstChild("HumanoidRootPart") and c2:FindFirstChild("HumanoidRootPart") then
                c1.HumanoidRootPart.CFrame = c2.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                AddMessage("TP to " .. p.Name, MC.gray)
                return
            end
        end
    end
    AddMessage("Player not found", MC.red)
end)

RegisterCommand("fly", "Toggle fly", function()
    local c = Player.Character
    if not c then return end
    local h = c:FindFirstChild("HumanoidRootPart")
    if not h then return end
    if h:FindFirstChild("FlyBV") then
        h.FlyBV:Destroy()
        h.FlyBG:Destroy()
        AddMessage("Fly off", MC.gray)
        return
    end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "FlyBV"
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = h
    local bg = Instance.new("BodyGyro")
    bg.Name = "FlyBG"
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.Parent = h
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not h:FindFirstChild("FlyBV") then conn:Disconnect() return end
        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.yAxis end
        bv.Velocity = dir * 50
        bg.CFrame = cam.CFrame
    end)
    AddMessage("Fly on", MC.gray)
end)

RegisterCommand("noclip", "Toggle noclip", function()
    local c = Player.Character
    if not c then return end
    if c:GetAttribute("NC") then
        c:SetAttribute("NC", false)
        for _, p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
        AddMessage("Noclip off", MC.gray)
        return
    end
    c:SetAttribute("NC", true)
    local conn
    conn = RunService.Stepped:Connect(function()
        if not c:GetAttribute("NC") then conn:Disconnect() return end
        for _, p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
    AddMessage("Noclip on", MC.gray)
end)

RegisterCommand("god", "Toggle god", function()
    local c = Player.Character
    if not c then return end
    local h = c:FindFirstChild("Humanoid")
    if not h then return end
    if c:GetAttribute("God") then
        c:SetAttribute("God", false)
        h.MaxHealth = 100
        h.Health = 100
        AddMessage("God off", MC.gray)
    else
        c:SetAttribute("God", true)
        h.MaxHealth = math.huge
        h.Health = math.huge
        AddMessage("God on", MC.gray)
    end
end)

RegisterCommand("gamemode", "0=survival 1=creative", function(args)
    local m = tonumber(args[1]) or 0
    local c = Player.Character
    if not c then return end
    if m == 1 then
        AddMessage("Creative Mode", MC.gray)
        local h = c:FindFirstChild("Humanoid")
        if h then c:SetAttribute("God", true) h.MaxHealth = math.huge h.Health = math.huge end
        -- Enable fly
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp and not hrp:FindFirstChild("FlyBV") then
            local bv = Instance.new("BodyVelocity") bv.Name = "FlyBV" bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge) bv.Parent = hrp
            local bg = Instance.new("BodyGyro") bg.Name = "FlyBG" bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge) bg.Parent = hrp
            local conn conn = RunService.RenderStepped:Connect(function()
                if not hrp:FindFirstChild("FlyBV") then conn:Disconnect() return end
                local cam = workspace.CurrentCamera local dir = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.yAxis end
                bv.Velocity = dir * 50 bg.CFrame = cam.CFrame
            end)
        end
        -- Enable noclip
        c:SetAttribute("NC", true)
        local conn conn = RunService.Stepped:Connect(function()
            if not c:GetAttribute("NC") then conn:Disconnect() return end
            for _, p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
        end)
    else
        AddMessage("Survival Mode", MC.gray)
        local h = c:FindFirstChild("Humanoid")
        if h then c:SetAttribute("God", false) h.MaxHealth = 100 h.Health = 100 end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            if hrp:FindFirstChild("FlyBV") then hrp.FlyBV:Destroy() end
            if hrp:FindFirstChild("FlyBG") then hrp.FlyBG:Destroy() end
        end
        c:SetAttribute("NC", false)
        for _, p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end
    end
end)

RegisterCommand("respawn", "Respawn", function()
    Player:LoadCharacter()
    AddMessage("Respawning...", MC.gray)
end)

RegisterCommand("unload", "Unload OperatorHub", function()
    AddMessage("Unloading OperatorHub...", MC.red)
    task.wait(0.5)
    
    -- Disconnect all connections
    for _, connection in pairs(getconnections and getconnections(RunService.RenderStepped) or {}) do
        pcall(function() connection:Disconnect() end)
    end
    
    for _, connection in pairs(getconnections and getconnections(RunService.Stepped) or {}) do
        pcall(function() connection:Disconnect() end)
    end
    
    for _, connection in pairs(getconnections and getconnections(UserInputService.InputBegan) or {}) do
        pcall(function() connection:Disconnect() end)
    end
    
    -- Remove UI
    if UI and UI.Gui then
        UI.Gui:Destroy()
    end
    
    -- Clean up character modifications
    local c = Player.Character
    if c then
        -- Remove fly
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            if hrp:FindFirstChild("FlyBV") then hrp.FlyBV:Destroy() end
            if hrp:FindFirstChild("FlyBG") then hrp.FlyBG:Destroy() end
        end
        
        -- Disable noclip
        c:SetAttribute("NC", false)
        for _, p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
        
        -- Reset god mode
        local h = c:FindFirstChild("Humanoid")
        if h then
            c:SetAttribute("God", false)
            h.MaxHealth = 100
            h.Health = 100
        end
    end
    
    print("[OperatorHub] Unloaded successfully")
end)

-- Events
UI.HiddenInput:GetPropertyChangedSignal("Text"):Connect(function()
    UpdateInputDisplay(UI.HiddenInput.Text)
end)

UI.HiddenInput.FocusLost:Connect(function(enter)
    if enter then
        ExecuteCommand(UI.HiddenInput.Text)
        UI.HiddenInput.Text = ""
        UpdateInputDisplay("")
    end
end)

-- Cursor blink
task.spawn(function()
    while true do
        UI.Cursor.Visible = not UI.Cursor.Visible
        task.wait(0.53)
    end
end)

-- Toggle UI
function ToggleUI()
    uiOpen = not uiOpen
    UI.CommandBar.Visible = uiOpen
    UI.CmdPanel.Visible = uiOpen
    
    if uiOpen then
        UI.HiddenInput:CaptureFocus()
        UpdateCmdList()
        -- Show all messages
        for _, m in pairs(ChatMessages) do
            m.Frame.BackgroundTransparency = 0.5
            for _, c in pairs(m.Frame:GetDescendants()) do
                if c:IsA("ImageLabel") then c.ImageTransparency = 0 end
            end
        end
    end
end

-- Message fading
RunService.RenderStepped:Connect(function()
    if uiOpen then return end
    local now = tick()
    for _, m in pairs(ChatMessages) do
        local age = now - m.Time
        if age > CONFIG.MessageFadeDelay then
            local fade = math.min(1, (age - CONFIG.MessageFadeDelay) / CONFIG.MessageFadeTime)
            m.Frame.BackgroundTransparency = 0.5 + (0.5 * fade)
            for _, c in pairs(m.Frame:GetDescendants()) do
                if c:IsA("ImageLabel") then c.ImageTransparency = fade end
            end
        end
    end
end)

-- Input
UserInputService.InputBegan:Connect(function(input, processed)
    -- Prevent semicolon from being typed when opening/closing UI
    if input.KeyCode == CONFIG.ToggleKey then
        if not UI.HiddenInput:IsFocused() then
            ToggleUI()
        end
        return
    end
    
    if processed and not UI.HiddenInput:IsFocused() then return end
    
    if input.KeyCode == Enum.KeyCode.Escape and uiOpen then
        ToggleUI()
    elseif input.KeyCode == Enum.KeyCode.Up and UI.HiddenInput:IsFocused() and #CommandHistory > 0 then
        HistoryIndex = math.max(1, HistoryIndex - 1)
        UI.HiddenInput.Text = CommandHistory[HistoryIndex] or ""
    elseif input.KeyCode == Enum.KeyCode.Down and UI.HiddenInput:IsFocused() and #CommandHistory > 0 then
        HistoryIndex = math.min(#CommandHistory + 1, HistoryIndex + 1)
        UI.HiddenInput.Text = CommandHistory[HistoryIndex] or ""
    elseif input.KeyCode == Enum.KeyCode.Tab and UI.HiddenInput:IsFocused() then
        local t = UI.HiddenInput.Text
        if t:match("^/") then
            local s = t:sub(2):lower()
            for n in pairs(Commands) do
                if n:sub(1, #s) == s then
                    UI.HiddenInput.Text = "/" .. n .. " "
                    break
                end
            end
        end
    end
end)

-- Init
SetupFolders()
UpdateCmdList()

if CONFIG.GitHubRepo ~= "" then
    task.spawn(LoadGitHubCommands)
end

task.delay(0.5, function()
    AddMessage("OperatorHub loaded. Press ;", MC.yellow)
    AddMessage("Type /help for commands", MC.gray)
    if CONFIG.GitHubRepo ~= "YourUsername/YourRepo" and CONFIG.GitHubRepo ~= "" then
        AddMessage("GitHub: " .. CONFIG.GitHubRepo, MC.gray)
    end
end)

print("[OperatorHub] Loaded! Press ; to open")
