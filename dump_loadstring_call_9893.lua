local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local THEME = {
    Background = Color3.fromRGB(8, 8, 12),
    Surface = Color3.fromRGB(18, 18, 24),
    SurfaceHover = Color3.fromRGB(28, 28, 36),
    Border = Color3.fromRGB(45, 45, 55),
    Accent = Color3.fromRGB(255, 255, 255),
    Text = Color3.fromRGB(245, 245, 250),
    TextMuted = Color3.fromRGB(120, 120, 135),
    Font = Font.new("rbxassetid://11702779517", Enum.FontWeight.Medium),
    TitleFont = Font.new("rbxassetid://11702779517", Enum.FontWeight.Bold),
}
local function cleanupUI()
    if gethui then
        for _, child in ipairs(gethui():GetChildren()) do
            if child.Name == "SeraphinLite" then child:Destroy() end
        end
    elseif CoreGui:FindFirstChild("SeraphinLite") then
        CoreGui.SeraphinLite:Destroy()
    end
end
cleanupUI()
local function protectGui(gui)
    if syn and syn.protect_gui then
        syn.protect_gui(gui)
        gui.Parent = CoreGui
    elseif gethui then
        gui.Parent = gethui()
    else
        gui.Parent = CoreGui
    end
end
local function makeDraggable(handle, frame)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end
local function makeResizable(handle, frame, minSize)
    local resizing, startSize, startMouse
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            startSize = frame.AbsoluteSize
            startMouse = input.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startMouse
            local newW = math.max(minSize.X, startSize.X + delta.X)
            local newH = math.max(minSize.Y, startSize.Y + delta.Y)
            frame.Size = UDim2.new(0, newW, 0, newH)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
            resizing = false 
        end
    end)
end
local function createRipple(parent)
    local ripple = Instance.new("Frame")
    ripple.BackgroundColor3 = Color3.new(1, 1, 1)
    ripple.BackgroundTransparency = 0.85
    ripple.AnchorPoint = Vector2.new(0.5, 0.5)
    ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
    ripple.Size = UDim2.new(0, 0, 0, 0)
    ripple.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = ripple
    local tween = TweenService:Create(ripple, TweenInfo.new(0.4), {Size = UDim2.new(2, 0, 2, 0), BackgroundTransparency = 1})
    tween:Play()
    tween.Completed:Connect(function() ripple:Destroy() end)
end
local function safeWrite(file, data) pcall(function() writefile(file, data) end) end
local function safeRead(file) local s, d = pcall(function() return readfile(file) end) return s and d or nil end
local function safeFolder(folder) local s, r = pcall(function() return isfolder(folder) end) return s and r end
local function safeMakeFolder(folder) pcall(function() makefolder(folder) end) end
local function safeDelFile(file) pcall(function() delfile(file) end) end
local function safeListFiles(folder) local s, f = pcall(function() return listfiles(folder) end) return s and f or {} end
local Seraphin = {}
function Seraphin.CreateWindow(config)
    config = config or {}
    local title = config.Title or "Seraphin Lite"
    local logo = config.Logo or "rbxthumb://type=Asset&id=124970168560794&w=150&h=150"
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SeraphinLite"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false
    pcall(function() protectGui(ScreenGui) end)
    if not ScreenGui.Parent then ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
    local Camera = game:GetService("Workspace").CurrentCamera
    local viewportSize = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)
    local isMobile = viewportSize.X < 800
    local isTablet = viewportSize.X >= 800 and viewportSize.X < 1200
    local baseWidth = isMobile and math.min(viewportSize.X - 40, 360) or (isTablet and 480 or 520)
    local baseHeight = isMobile and math.min(viewportSize.Y - 80, 320) or (isTablet and 340 or 380)
    local minWidth = isMobile and 300 or 380
    local minHeight = isMobile and 250 or 280
    local sidebarWidth = isMobile and 80 or 110
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, baseWidth - 40, 0, baseHeight - 40)
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.BackgroundColor3 = THEME.Background
    Main.BackgroundTransparency = 1
    Main.BorderSizePixel = 0
    Main.ClipsDescendants = true
    Main.Parent = ScreenGui
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = Main
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = THEME.Border
    MainStroke.Transparency = 0.3
    MainStroke.Thickness = 1
    MainStroke.Parent = Main
    local InnerGlow = Instance.new("Frame")
    InnerGlow.Size = UDim2.new(1, 0, 0, 60)
    InnerGlow.BackgroundColor3 = Color3.new(1, 1, 1)
    InnerGlow.BackgroundTransparency = 0.97
    InnerGlow.BorderSizePixel = 0
    InnerGlow.Parent = Main
    local GlowCorner = Instance.new("UICorner")
    GlowCorner.CornerRadius = UDim.new(0, 12)
    GlowCorner.Parent = InnerGlow
    local GlowGrad = Instance.new("UIGradient")
    GlowGrad.Rotation = 90
    GlowGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
    GlowGrad.Parent = InnerGlow
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 38)
    TopBar.BackgroundTransparency = 1
    TopBar.Parent = Main
    makeDraggable(TopBar, Main)
    local Logo = Instance.new("ImageLabel")
    Logo.Size = UDim2.new(0, 26, 0, 26)
    Logo.Position = UDim2.new(0, 10, 0.5, 0)
    Logo.AnchorPoint = Vector2.new(0, 0.5)
    Logo.BackgroundTransparency = 1
    Logo.Image = logo
    Logo.Parent = TopBar
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0, 200, 1, 0)
    Title.Position = UDim2.new(0, 44, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = title
    Title.TextColor3 = THEME.Text
    Title.FontFace = THEME.TitleFont
    Title.TextSize = 15
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TopBar
    local function createBtn(icon, pos, callback)
        local btn = Instance.new("ImageButton")
        btn.Size = UDim2.new(0, 20, 0, 20)
        btn.Position = pos
        btn.AnchorPoint = Vector2.new(0, 0.5)
        btn.BackgroundTransparency = 1
        btn.Image = icon
        btn.ImageColor3 = THEME.TextMuted
        btn.Parent = TopBar
        btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {ImageColor3 = THEME.Accent}):Play() end)
        btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {ImageColor3 = THEME.TextMuted}):Play() end)
        btn.MouseButton1Click:Connect(callback)
        return btn
    end
    local Modal = Instance.new("Frame")
    Modal.Size = UDim2.new(1, 0, 1, 0)
    Modal.BackgroundColor3 = Color3.new(0, 0, 0)
    Modal.BackgroundTransparency = 1
    Modal.Visible = false
    Modal.ZIndex = 50
    Modal.Parent = ScreenGui
    local MContent = Instance.new("Frame")
    MContent.Size = UDim2.new(0, 0, 0, 0)
    MContent.AnchorPoint = Vector2.new(0.5, 0.5)
    MContent.Position = UDim2.new(0.5, 0, 0.5, 0)
    MContent.BackgroundColor3 = THEME.Surface
    MContent.ClipsDescendants = true
    MContent.Parent = Modal
    local MC = Instance.new("UICorner")
    MC.CornerRadius = UDim.new(0, 12)
    MC.Parent = MContent
    local MS = Instance.new("UIStroke")
    MS.Color = THEME.Border
    MS.Transparency = 0.5
    MS.Parent = MContent
    local MQ = Instance.new("TextLabel")
    MQ.Size = UDim2.new(1, 0, 0, 30)
    MQ.Position = UDim2.new(0, 0, 0, 15)
    MQ.BackgroundTransparency = 1
    MQ.Text = "Close Seraphin?"
    MQ.TextColor3 = THEME.Accent
    MQ.FontFace = THEME.TitleFont
    MQ.TextSize = 18
    MQ.Parent = MContent
    local MSub = Instance.new("TextLabel")
    MSub.Size = UDim2.new(1, 0, 0, 20)
    MSub.Position = UDim2.new(0, 0, 0, 45)
    MSub.BackgroundTransparency = 1
    MSub.Text = "Are you sure you want to exit?"
    MSub.TextColor3 = THEME.TextMuted
    MSub.FontFace = THEME.Font
    MSub.TextSize = 14
    MSub.Parent = MContent
    local function createMBtn(text, color, pos, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 100, 0, 32)
        btn.Position = pos
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = THEME.Text
        btn.FontFace = THEME.Font
        btn.TextSize = 14
        btn.AutoButtonColor = false
        btn.Parent = MContent
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
        btn.MouseButton1Click:Connect(callback)
        btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play() end)
        btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play() end)
    end
    createMBtn("Cancel", Color3.fromRGB(60, 60, 70), UDim2.new(0, 20, 1, -45), function()
        Modal.Visible = false
    end)
    createMBtn("Close", Color3.fromRGB(180, 60, 60), UDim2.new(1, -120, 1, -45), function()
         ScreenGui:Destroy()
    end)
    createBtn("rbxassetid://6031094678", UDim2.new(1, -28, 0.5, 0), function()
        Modal.Visible = true
        Modal.BackgroundTransparency = 0.6
        MContent.Size = UDim2.new(0, 260, 0, 140)
    end)
    createBtn("rbxassetid://71686683787518", UDim2.new(1, -54, 0.5, 0), function()
        Main.Visible = false
    end)
    local Sep = Instance.new("Frame")
    Sep.Size = UDim2.new(1, -20, 0, 1)
    Sep.Position = UDim2.new(0.5, 0, 0, 38)
    Sep.AnchorPoint = Vector2.new(0.5, 0)
    Sep.BackgroundColor3 = THEME.Border
    Sep.BackgroundTransparency = 0.5
    Sep.BorderSizePixel = 0
    Sep.Parent = Main
    local Body = Instance.new("Frame")
    Body.Name = "Body"
    Body.Size = UDim2.new(1, 0, 1, -42)
    Body.Position = UDim2.new(0, 0, 0, 42)
    Body.BackgroundTransparency = 1
    Body.Parent = Main
    local Sidebar = Instance.new("ScrollingFrame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, sidebarWidth, 1, -10)
    Sidebar.Position = UDim2.new(0, 8, 0, 5)
    Sidebar.BackgroundTransparency = 1
    Sidebar.ScrollBarThickness = 0
    Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Sidebar.Parent = Body
    local SideLayout = Instance.new("UIListLayout")
    SideLayout.Padding = UDim.new(0, 4)
    SideLayout.Parent = Sidebar
    local SidePad = Instance.new("UIPadding")
    SidePad.PaddingTop = UDim.new(0, 4)
    SidePad.Parent = Sidebar
    local PageContainer = Instance.new("Frame")
    PageContainer.Name = "Pages"
    PageContainer.Size = UDim2.new(1, -(sidebarWidth + 20), 1, -10)
    PageContainer.Position = UDim2.new(0, sidebarWidth + 12, 0, 5)
    PageContainer.BackgroundTransparency = 1
    PageContainer.Parent = Body
    Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local w = Main.AbsoluteSize.X
        local newSideWidth = w < 400 and 80 or 110
        Sidebar.Size = UDim2.new(0, newSideWidth, 1, -10)
        PageContainer.Size = UDim2.new(1, -(newSideWidth + 20), 1, -10)
        PageContainer.Position = UDim2.new(0, newSideWidth + 12, 0, 5)
    end)
    local ResizeHandle = Instance.new("TextButton")
    ResizeHandle.Size = UDim2.new(0, 18, 0, 18)
    ResizeHandle.Position = UDim2.new(1, -4, 1, -4)
    ResizeHandle.AnchorPoint = Vector2.new(1, 1)
    ResizeHandle.BackgroundColor3 = THEME.Border
    ResizeHandle.BackgroundTransparency = 0.7
    ResizeHandle.Text = ""
    ResizeHandle.AutoButtonColor = false
    ResizeHandle.ZIndex = 10
    ResizeHandle.Parent = Main
    local RHC = Instance.new("UICorner")
    RHC.CornerRadius = UDim.new(0, 4)
    RHC.Parent = ResizeHandle
    ResizeHandle.MouseEnter:Connect(function()
        TweenService:Create(ResizeHandle, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
    end)
    ResizeHandle.MouseLeave:Connect(function()
        TweenService:Create(ResizeHandle, TweenInfo.new(0.15), {BackgroundTransparency = 0.7}):Play()
    end)
    makeResizable(ResizeHandle, Main, Vector2.new(minWidth, minHeight))
    local NotifyContainer = Instance.new("Frame")
    NotifyContainer.Size = UDim2.new(0, 260, 1, -20)
    NotifyContainer.Position = UDim2.new(1, -270, 0, 10)
    NotifyContainer.BackgroundTransparency = 1
    NotifyContainer.Parent = ScreenGui
    local NotifyLayout = Instance.new("UIListLayout")
    NotifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotifyLayout.Padding = UDim.new(0, 8)
    NotifyLayout.Parent = NotifyContainer
    local Tabs = {}
    local currentTab = nil
    local Flags = {}
    local Events = {}
    local Window = {
        ScreenGui = ScreenGui,
        Main = Main,
        Flags = Flags,
        ToggleKey = toggleKey
    }
    function Window:Notify(cfg)
        local ntitle = cfg.Title or "Notice"
        local content = cfg.Content or ""
        local duration = cfg.Duration or 3
        local NFrame = Instance.new("Frame")
        NFrame.Size = UDim2.new(1, 0, 0, 0)
        NFrame.AutomaticSize = Enum.AutomaticSize.Y
        NFrame.Position = UDim2.new(1, 100, 0, 0)
        NFrame.BackgroundColor3 = THEME.Surface
        NFrame.Parent = NotifyContainer
        local NC = Instance.new("UICorner")
        NC.CornerRadius = UDim.new(0, 8)
        NC.Parent = NFrame
        local NS = Instance.new("UIStroke")
        NS.Color = THEME.Border
        NS.Transparency = 0.6
        NS.Parent = NFrame
        local NP = Instance.new("UIPadding")
        NP.PaddingTop = UDim.new(0, 10)
        NP.PaddingBottom = UDim.new(0, 10)
        NP.PaddingLeft = UDim.new(0, 12)
        NP.PaddingRight = UDim.new(0, 12)
        NP.Parent = NFrame
        local NTitle = Instance.new("TextLabel")
        NTitle.Size = UDim2.new(1, 0, 0, 16)
        NTitle.BackgroundTransparency = 1
        NTitle.Text = ntitle
        NTitle.TextColor3 = THEME.Accent
        NTitle.FontFace = THEME.TitleFont
        NTitle.TextSize = 13
        NTitle.TextXAlignment = Enum.TextXAlignment.Left
        NTitle.Parent = NFrame
        local NContent = Instance.new("TextLabel")
        NContent.Size = UDim2.new(1, 0, 0, 0)
        NContent.Position = UDim2.new(0, 0, 0, 20)
        NContent.AutomaticSize = Enum.AutomaticSize.Y
        NContent.BackgroundTransparency = 1
        NContent.Text = content
        NContent.TextColor3 = THEME.TextMuted
        NContent.FontFace = THEME.Font
        NContent.TextSize = 12
        NContent.TextXAlignment = Enum.TextXAlignment.Left
        NContent.TextWrapped = true
        NContent.Parent = NFrame
        TweenService:Create(NFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0, 0, 0, 0)}):Play()
        task.delay(duration, function()
            local t = TweenService:Create(NFrame, TweenInfo.new(0.25), {Position = UDim2.new(1, 100, 0, 0)})
            t:Play()
            t.Completed:Connect(function() NFrame:Destroy() end)
        end)
    end
    function Window:SaveConfig(name)
        local data = {}
        for flag, val in pairs(Flags) do
            if not flag:match("^_") then
                if typeof(val) == "Color3" then
                    data[flag] = {_t = "c3", r = val.R, g = val.G, b = val.B}
                elseif typeof(val) == "EnumItem" then
                    data[flag] = {_t = "enum", n = val.Name, e = tostring(val.EnumType)}
                else
                    data[flag] = val
                end
            end
        end
        if not safeFolder("SeraphinConfigsNew") then safeMakeFolder("SeraphinConfigsNew") end
        safeWrite("SeraphinConfigsNew/" .. name .. ".json", HttpService:JSONEncode(data))
    end
    function Window:LoadConfig(name)
        local raw = safeRead("SeraphinConfigsNew/" .. name .. ".json")
        if raw then
            local data = HttpService:JSONDecode(raw)
            for flag, val in pairs(data) do
                if type(val) == "table" and val._t == "c3" then
                    val = Color3.new(val.r, val.g, val.b)
                elseif type(val) == "table" and val._t == "enum" then
                    local en = val.e:gsub("Enum%.", "")
                    if Enum[en] and Enum[en][val.n] then val = Enum[en][val.n] end
                end
                Flags[flag] = val
                if Events[flag] and Events[flag].Set then Events[flag].Set(val) end
            end
        end
    end
    function Window:DeleteConfig(name)
        safeDelFile("SeraphinConfigsNew/" .. name .. ".json")
    end
    function Window:GetConfigs()
        if not safeFolder("SeraphinConfigsNew") then safeMakeFolder("SeraphinConfigsNew") end
        local files = safeListFiles("SeraphinConfigsNew")
        local configs = {}
        for _, f in ipairs(files) do
            local n = f:match("([^/^\\]+)%.json$")
            if n then table.insert(configs, n) end
        end
        return configs
    end
    function Window:ConfigTab(tabName)
        tabName = tabName or "Config"
        local Tab = self:Tab(tabName)
        local selectedConfig = nil
        local configDropdown = nil
        local newConfigName = "NewConfig"
        Tab:Paragraph({
            Title = "Configuration",
            Content = "Save and load your settings. Select a config from the dropdown or create a new one."
        })
        Tab:Divider()
        local configs = self:GetConfigs()
        configDropdown = Tab:Dropdown("Select Config", configs, "None", function(opt)
            selectedConfig = opt
        end, "_ConfigDropdown")
        selectedConfig = nil
        Tab:TextInput("New Config Name", "Enter name...", function(text)
            newConfigName = text
        end, "_NewConfigName")
        Tab:Keybind("Toggle Keybind", Enum.KeyCode.RightControl, function(keyCode)
            self.ToggleKey = keyCode
            if self.SetKeybindCooldown then self.SetKeybindCooldown() end
        end, "_ToggleKeybind")
        Tab:Divider()
        Tab._layoutCounter = Tab._layoutCounter + 1
        local Row1 = Instance.new("Frame")
        Row1.Size = UDim2.new(1, 0, 0, 32)
        Row1.BackgroundTransparency = 1
        Row1.LayoutOrder = Tab._layoutCounter
        Row1.Parent = Tab.Container
        local R1L = Instance.new("UIListLayout")
        R1L.FillDirection = Enum.FillDirection.Horizontal
        R1L.Padding = UDim.new(0, 8)
        R1L.Parent = Row1
        Tab._layoutCounter = Tab._layoutCounter + 1
        local Row2 = Instance.new("Frame")
        Row2.Size = UDim2.new(1, 0, 0, 32)
        Row2.BackgroundTransparency = 1
        Row2.LayoutOrder = Tab._layoutCounter
        Row2.Parent = Tab.Container
        local R2L = Instance.new("UIListLayout")
        R2L.FillDirection = Enum.FillDirection.Horizontal
        R2L.Padding = UDim.new(0, 8)
        R2L.Parent = Row2
        local function createActionBtn(text, color, parent, callback)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.5, -4, 1, 0)
            btn.BackgroundColor3 = color
            btn.Text = text
            btn.TextColor3 = THEME.Text
            btn.FontFace = THEME.Font
            btn.TextSize = 12
            btn.AutoButtonColor = false
            btn.Parent = parent
            local bc = Instance.new("UICorner")
            bc.CornerRadius = UDim.new(0, 6)
            bc.Parent = btn
            btn.MouseEnter:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.new(
                    math.min(color.R + 0.1, 1),
                    math.min(color.G + 0.1, 1),
                    math.min(color.B + 0.1, 1)
                )}):Play()
            end)
            btn.MouseLeave:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = color}):Play()
            end)
            btn.MouseButton1Click:Connect(function()
                createRipple(btn)
                callback()
            end)
            return btn
        end
        local btnColor = Color3.fromRGB(45, 45, 55)
        createActionBtn("Save New", btnColor, Row1, function()
            local name = newConfigName ~= "" and newConfigName or "Config_" .. os.time()
            self:SaveConfig(name)
            configs = self:GetConfigs()
            configDropdown.Refresh(configs)
            configDropdown.Set(name)
            selectedConfig = name
            self:Notify({Title = "Saved", Content = "Config '" .. name .. "' saved!", Duration = 2})
        end)
        createActionBtn("Load", btnColor, Row1, function()
            if selectedConfig and selectedConfig ~= "None" then
                self:LoadConfig(selectedConfig)
                self:Notify({Title = "Loaded", Content = "Config '" .. selectedConfig .. "' loaded!", Duration = 2})
            else
                self:Notify({Title = "Error", Content = "No config selected!", Duration = 2})
            end
        end)
        createActionBtn("Overwrite", btnColor, Row2, function()
            if selectedConfig and selectedConfig ~= "None" then
                self:SaveConfig(selectedConfig)
                self:Notify({Title = "Overwritten", Content = "Config '" .. selectedConfig .. "' updated!", Duration = 2})
            else
                self:Notify({Title = "Error", Content = "No config selected to overwrite!", Duration = 2})
            end
        end)
        createActionBtn("Delete", btnColor, Row2, function()
            if selectedConfig and selectedConfig ~= "None" then
                self:DeleteConfig(selectedConfig)
                configs = self:GetConfigs()
                configDropdown.Refresh(configs)
                selectedConfig = nil
                configDropdown.Set(configs[1] or "None")
                selectedConfig = configs[1] or nil
                self:Notify({Title = "Deleted", Content = "Config deleted!", Duration = 2})
            else
                self:Notify({Title = "Error", Content = "No config selected!", Duration = 2})
            end
        end)
        Tab:Divider()
        Tab:Paragraph({
            Title = "Auto Load",
            Content = "Enable auto load."
        })
        local autoLoadSettings = {enabled = false, config = "None"}
        local autoLoadRaw = safeRead("SeraphinConfigsAutoLoad/_AutoLoad.json")
        if autoLoadRaw then
            local s, data = pcall(function() return HttpService:JSONDecode(autoLoadRaw) end)
            if s and data then autoLoadSettings = data end
        end
        local autoLoadDropdown = nil
        local selectedAutoLoad = autoLoadSettings.config or "None"
        local function saveAutoLoadSettings()
            if not safeFolder("SeraphinConfigsAutoLoad") then safeMakeFolder("SeraphinConfigsAutoLoad") end
            safeWrite("SeraphinConfigsAutoLoad/_AutoLoad.json", HttpService:JSONEncode(autoLoadSettings))
        end
        Tab:Toggle("Enable Auto Load", autoLoadSettings.enabled, function(state)
            autoLoadSettings.enabled = state
            saveAutoLoadSettings()
            if state then
                self:Notify({Title = "Auto Load", Content = "Will load '" .. selectedAutoLoad .. "' on next start", Duration = 2})
            end
        end)
        local autoLoadConfigs = {"None"}
        for _, c in ipairs(configs) do table.insert(autoLoadConfigs, c) end
        autoLoadDropdown = Tab:Dropdown("Select Auto Load Config", autoLoadConfigs, selectedAutoLoad, function(opt)
            selectedAutoLoad = opt
            autoLoadSettings.config = opt
            saveAutoLoadSettings()
        end)
        local originalRefresh = configDropdown.Refresh
        configDropdown.Refresh = function(newConfigs)
            originalRefresh(newConfigs)
            local newAutoLoadConfigs = {"None"}
            for _, c in ipairs(newConfigs) do table.insert(newAutoLoadConfigs, c) end
            autoLoadDropdown.Refresh(newAutoLoadConfigs)
        end
        return Tab
    end
    function Window:Tab(name, icon)
        local Page = Instance.new("ScrollingFrame")
        Page.Name = name
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.ScrollBarThickness = 2
        Page.ScrollBarImageColor3 = THEME.TextMuted
        Page.CanvasSize = UDim2.new(0, 0, 0, 0)
        Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        Page.Visible = false
        Page.Parent = PageContainer
        local PP = Instance.new("UIPadding")
        PP.PaddingTop = UDim.new(0, 8)
        PP.PaddingBottom = UDim.new(0, 8)
        PP.PaddingLeft = UDim.new(0, 8)
        PP.PaddingRight = UDim.new(0, 8)
        PP.Parent = Page
        local PL = Instance.new("UIListLayout")
        PL.Padding = UDim.new(0, 10)
        PL.SortOrder = Enum.SortOrder.LayoutOrder
        PL.Parent = Page
        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(1, -4, 0, 30)
        TabBtn.BackgroundTransparency = 1
        TabBtn.BackgroundColor3 = THEME.Accent
        TabBtn.Text = ""
        TabBtn.AutoButtonColor = false
        TabBtn.Parent = Sidebar
        local TCorner = Instance.new("UICorner")
        TCorner.CornerRadius = UDim.new(0, 6)
        TCorner.Parent = TabBtn
        local Indicator = Instance.new("Frame")
        Indicator.Size = UDim2.new(0, 3, 0, 14)
        Indicator.Position = UDim2.new(0, 0, 0.5, 0)
        Indicator.AnchorPoint = Vector2.new(0, 0.5)
        Indicator.BackgroundColor3 = THEME.Accent
        Indicator.BackgroundTransparency = 1
        Indicator.Parent = TabBtn
        local IC = Instance.new("UICorner")
        IC.CornerRadius = UDim.new(1, 0)
        IC.Parent = Indicator
        local TLabel = Instance.new("TextLabel")
        TLabel.Size = UDim2.new(1, -16, 1, 0)
        TLabel.Position = UDim2.new(0, 12, 0, 0)
        TLabel.BackgroundTransparency = 1
        TLabel.Text = name
        TLabel.TextColor3 = THEME.TextMuted
        TLabel.FontFace = THEME.Font
        TLabel.TextSize = 13
        TLabel.TextXAlignment = Enum.TextXAlignment.Left
        TLabel.Parent = TabBtn
        local function Activate()
            if currentTab then
                TweenService:Create(currentTab.Btn, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                TweenService:Create(currentTab.Label, TweenInfo.new(0.2), {TextColor3 = THEME.TextMuted}):Play()
                TweenService:Create(currentTab.Ind, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                currentTab.Page.Visible = false
            end
            currentTab = {Btn = TabBtn, Label = TLabel, Ind = Indicator, Page = Page}
            TweenService:Create(TabBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.92}):Play()
            TweenService:Create(TLabel, TweenInfo.new(0.2), {TextColor3 = THEME.Accent}):Play()
            TweenService:Create(Indicator, TweenInfo.new(0.25, Enum.EasingStyle.Back), {BackgroundTransparency = 0}):Play()
            Page.Visible = true
        end
        TabBtn.MouseButton1Click:Connect(function()
            createRipple(TabBtn)
            Activate()
        end)
        TabBtn.MouseEnter:Connect(function()
            if currentTab and currentTab.Btn == TabBtn then return end
            TweenService:Create(TabBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.95}):Play()
        end)
        TabBtn.MouseLeave:Connect(function()
            if currentTab and currentTab.Btn == TabBtn then return end
            TweenService:Create(TabBtn, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
        end)
        if #Tabs == 0 then Activate() end
        table.insert(Tabs, {Btn = TabBtn, Page = Page})
        local Tab = {Container = Page, _layoutCounter = 0}
        function Tab:Section(text)
            self._layoutCounter = self._layoutCounter + 1
            local SFrame = Instance.new("Frame")
            SFrame.Name = text .. "_Section"
            SFrame.Size = UDim2.new(1, 0, 0, 32)
            SFrame.BackgroundColor3 = THEME.Surface
            SFrame.ClipsDescendants = true
            SFrame.LayoutOrder = self._layoutCounter
            SFrame.Parent = self.Container
            SFrame.BackgroundTransparency = 0
            local SC = Instance.new("UICorner")
            SC.CornerRadius = UDim.new(0, 8)
            SC.Parent = SFrame
            local SS = Instance.new("UIStroke")
            SS.Color = THEME.Border
            SS.Transparency = 0.7
            SS.Parent = SFrame
            local Header = Instance.new("TextButton")
            Header.Size = UDim2.new(1, 0, 0, 32)
            Header.BackgroundTransparency = 1
            Header.Text = ""
            Header.Parent = SFrame
            local STitle = Instance.new("TextLabel")
            STitle.Size = UDim2.new(1, -36, 1, 0)
            STitle.Position = UDim2.new(0, 10, 0, 0)
            STitle.BackgroundTransparency = 1
            STitle.Text = text
            STitle.TextColor3 = THEME.Accent
            STitle.FontFace = THEME.TitleFont
            STitle.TextSize = 13
            STitle.TextXAlignment = Enum.TextXAlignment.Left
            STitle.Parent = Header
            local Arrow = Instance.new("ImageLabel")
            Arrow.Size = UDim2.new(0, 16, 0, 16)
            Arrow.Position = UDim2.new(1, -24, 0.5, 0)
            Arrow.AnchorPoint = Vector2.new(0, 0.5)
            Arrow.BackgroundTransparency = 1
            Arrow.Image = "rbxassetid://6031091004"
            Arrow.ImageColor3 = THEME.TextMuted
            Arrow.Parent = Header
            local Content = Instance.new("Frame")
            Content.Name = "Content"
            Content.Size = UDim2.new(1, -16, 0, 0)
            Content.Position = UDim2.new(0, 8, 0, 32)
            Content.BackgroundTransparency = 1
            Content.ClipsDescendants = true
            Content.Visible = false
            Content.Parent = SFrame
            local CL = Instance.new("UIListLayout")
            CL.Padding = UDim.new(0, 8)
            CL.SortOrder = Enum.SortOrder.LayoutOrder
            CL.Parent = Content
            local CP = Instance.new("UIPadding")
            CP.PaddingTop = UDim.new(0, 4)
            CP.PaddingBottom = UDim.new(0, 8)
            CP.Parent = Content
            local expanded = false
            local function UpdateSize()
                local h = expanded and (CL.AbsoluteContentSize.Y + 12) or 0
                Content.Size = UDim2.new(1, -16, 0, h)
                TweenService:Create(SFrame, TweenInfo.new(0.25), {Size = UDim2.new(1, 0, 0, 32 + h)}):Play()
            end
            CL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                if expanded then UpdateSize() end
            end)
            Header.MouseButton1Click:Connect(function()
                expanded = not expanded
                Content.Visible = true
                SFrame.BackgroundTransparency = 1
                TweenService:Create(Arrow, TweenInfo.new(0.2), {Rotation = expanded and 180 or 0}):Play()
                TweenService:Create(SFrame, TweenInfo.new(0.2), {BackgroundTransparency = expanded and 0.6 or 0}):Play()
                UpdateSize()
                if not expanded then 
                    task.delay(0.25, function() 
                        if not expanded then 
                            SFrame.BackgroundTransparency = 0
                            Content.Visible = false 
                        end 
                    end) 
                end
            end)
            local Sec = {}
            local layoutCounter = 0
            for k, v in pairs(Tab) do 
                if type(v) == "function" then
                    Sec[k] = function(self, ...)
                        layoutCounter = layoutCounter + 1
                        local result = v(self, ...)
                        if result and result.Frame then
                            result.Frame.LayoutOrder = layoutCounter
                        end
                        return result
                    end
                else
                    Sec[k] = v
                end
            end
            Sec.Container = Content
            return Sec
        end
        function Tab:Divider()
            self._layoutCounter = self._layoutCounter + 1
            local D = Instance.new("Frame")
            D.Size = UDim2.new(1, 0, 0, 1)
            D.BackgroundColor3 = THEME.Border
            D.BackgroundTransparency = 0.5
            D.BorderSizePixel = 0
            D.LayoutOrder = self._layoutCounter
            D.Parent = self.Container
        end
        function Tab:Paragraph(cfg)
            self._layoutCounter = self._layoutCounter + 1
            local PFrame = Instance.new("Frame")
            PFrame.Size = UDim2.new(1, 0, 0, 0)
            PFrame.AutomaticSize = Enum.AutomaticSize.Y
            PFrame.BackgroundColor3 = THEME.Surface
            PFrame.LayoutOrder = self._layoutCounter
            PFrame.Parent = self.Container
            local PC = Instance.new("UICorner")
            PC.CornerRadius = UDim.new(0, 8)
            PC.Parent = PFrame
            local PP = Instance.new("UIPadding")
            PP.PaddingTop = UDim.new(0, 10)
            PP.PaddingBottom = UDim.new(0, 10)
            PP.PaddingLeft = UDim.new(0, 10)
            PP.PaddingRight = UDim.new(0, 10)
            PP.Parent = PFrame
            local PT = Instance.new("TextLabel")
            PT.Size = UDim2.new(1, 0, 0, 16)
            PT.BackgroundTransparency = 1
            PT.Text = cfg.Title or "Title"
            PT.TextColor3 = THEME.Accent
            PT.FontFace = THEME.TitleFont
            PT.TextSize = 13
            PT.TextXAlignment = Enum.TextXAlignment.Left
            PT.Parent = PFrame
            local PContent = Instance.new("TextLabel")
            PContent.Size = UDim2.new(1, 0, 0, 0)
            PContent.Position = UDim2.new(0, 0, 0, 20)
            PContent.AutomaticSize = Enum.AutomaticSize.Y
            PContent.BackgroundTransparency = 1
            PContent.Text = cfg.Content or ""
            PContent.TextColor3 = THEME.Text
            PContent.FontFace = THEME.Font
            PContent.TextSize = 12
            PContent.TextXAlignment = Enum.TextXAlignment.Left
            PContent.TextWrapped = true
            PContent.Parent = PFrame
            return {Frame = PFrame, SetTitle = function(t) PT.Text = t end, SetContent = function(c) PContent.Text = c end}
        end
        function Tab:Button(textOrConfig, callback)
            local text, btnColor, txtColor
            if type(textOrConfig) == "table" then
                text = textOrConfig.Text or "Button"
                btnColor = textOrConfig.ButtonColor or THEME.Surface
                txtColor = textOrConfig.TextColor or THEME.Text
                callback = textOrConfig.Callback or callback
            else
                text = textOrConfig
                btnColor = THEME.Surface
                txtColor = THEME.Text
            end
            local hoverColor = Color3.new(
                math.min(btnColor.R + 0.05, 1),
                math.min(btnColor.G + 0.05, 1),
                math.min(btnColor.B + 0.05, 1)
            )
            self._layoutCounter = self._layoutCounter + 1
            local BFrame = Instance.new("Frame")
            BFrame.Size = UDim2.new(1, 0, 0, 32)
            BFrame.BackgroundTransparency = 1
            BFrame.LayoutOrder = self._layoutCounter
            BFrame.Parent = self.Container
            local Btn = Instance.new("TextButton")
            Btn.Size = UDim2.new(1, 0, 1, 0)
            Btn.BackgroundColor3 = btnColor
            Btn.Text = text
            Btn.TextColor3 = txtColor
            Btn.FontFace = THEME.Font
            Btn.TextSize = 13
            Btn.AutoButtonColor = false
            Btn.Parent = BFrame
            local BC = Instance.new("UICorner")
            BC.CornerRadius = UDim.new(0, 6)
            BC.Parent = Btn
            local BS = Instance.new("UIStroke")
            BS.Color = THEME.Border
            BS.Transparency = 0.7
            BS.Parent = Btn
            Btn.MouseEnter:Connect(function()
                TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
                TweenService:Create(BS, TweenInfo.new(0.15), {Transparency = 0.4}):Play()
            end)
            Btn.MouseLeave:Connect(function()
                TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = btnColor}):Play()
                TweenService:Create(BS, TweenInfo.new(0.15), {Transparency = 0.7}):Play()
            end)
            Btn.MouseButton1Click:Connect(function()
                createRipple(Btn)
                if callback then callback() end
            end)
            return {
                Frame = BFrame, 
                SetText = function(t) Btn.Text = t end,
                SetTextColor = function(c) txtColor = c Btn.TextColor3 = c end,
                SetButtonColor = function(c) 
                    btnColor = c 
                    hoverColor = Color3.new(math.min(c.R + 0.05, 1), math.min(c.G + 0.05, 1), math.min(c.B + 0.05, 1))
                    Btn.BackgroundColor3 = c 
                end,
                Delete = function() BFrame:Destroy() end
            }
        end
        
        function Tab:Button2(textOrConfig, callback)
            callback = callback or function() end

            Tab._layoutCounter = Tab._layoutCounter or 0
            Tab._currentRow = Tab._currentRow or nil
            Tab._rowButtonCount = Tab._rowButtonCount or 0

            local function createRow()
                Tab._layoutCounter += 1
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 32)
                row.BackgroundTransparency = 1
                row.LayoutOrder = Tab._layoutCounter
                row.Parent = Tab.Container

                local layout = Instance.new("UIListLayout")
                layout.FillDirection = Enum.FillDirection.Horizontal
                layout.Padding = UDim.new(0, 8)
                layout.Parent = row

                Tab._currentRow = row
                Tab._rowButtonCount = 0
            end

            -- buat row baru kalau belum ada atau sudah 2 button
            if not Tab._currentRow or Tab._rowButtonCount >= 2 then
                createRow()
            end

            -- === CONFIG ===
            local text = "Button"
            local color = Color3.fromRGB(18, 18, 24)

            if type(textOrConfig) == "table" then
                text = textOrConfig.Text or text
                color = textOrConfig.Color or color
            else
                text = tostring(textOrConfig)
            end

            -- === BUTTON ===
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.5, -4, 1, 0)
            btn.BackgroundColor3 = color
            btn.Text = text
            btn.TextColor3 = THEME.Text
            btn.FontFace = THEME.Font
            btn.TextSize = 12
            btn.AutoButtonColor = false
            btn.Parent = Tab._currentRow

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = btn

            btn.MouseEnter:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.15), {
                    BackgroundColor3 = color:Lerp(Color3.new(1,1,1), 0.1)
                }):Play()
            end)

            btn.MouseLeave:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.15), {
                    BackgroundColor3 = color
                }):Play()
            end)

            btn.MouseButton1Click:Connect(function()
                createRipple(btn)
                callback()
            end)

            Tab._rowButtonCount += 1
            return btn
        end

        function Tab:Toggle(text, default, callback, flag)
            local useFlag = flag ~= nil
            if useFlag then
                default = Flags[flag] ~= nil and Flags[flag] or default
                Flags[flag] = default
            end
            self._layoutCounter = self._layoutCounter + 1
            local TFrame = Instance.new("Frame")
            TFrame.Size = UDim2.new(1, 0, 0, 34)
            TFrame.BackgroundColor3 = THEME.Surface
            TFrame.LayoutOrder = self._layoutCounter
            TFrame.Parent = self.Container
            local TC = Instance.new("UICorner")
            TC.CornerRadius = UDim.new(0, 6)
            TC.Parent = TFrame
            local TS = Instance.new("UIStroke")
            TS.Color = THEME.Border
            TS.Transparency = 0.7
            TS.Parent = TFrame
            local TLabel = Instance.new("TextLabel")
            TLabel.Size = UDim2.new(1, -56, 1, 0)
            TLabel.Position = UDim2.new(0, 10, 0, 0)
            TLabel.BackgroundTransparency = 1
            TLabel.Text = text
            TLabel.TextColor3 = THEME.Text
            TLabel.FontFace = THEME.Font
            TLabel.TextSize = 13
            TLabel.TextXAlignment = Enum.TextXAlignment.Left
            TLabel.Parent = TFrame
            local TBtn = Instance.new("Frame")
            TBtn.Size = UDim2.new(0, 36, 0, 18)
            TBtn.Position = UDim2.new(1, -46, 0.5, 0)
            TBtn.AnchorPoint = Vector2.new(0, 0.5)
            TBtn.BackgroundColor3 = default and THEME.Accent or Color3.fromRGB(50, 50, 60)
            TBtn.Parent = TFrame
            local TBC = Instance.new("UICorner")
            TBC.CornerRadius = UDim.new(1, 0)
            TBC.Parent = TBtn
            local Circle = Instance.new("Frame")
            Circle.Size = UDim2.new(0, 14, 0, 14)
            Circle.Position = default and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
            Circle.AnchorPoint = Vector2.new(0, 0.5)
            Circle.BackgroundColor3 = Color3.new(1, 1, 1)
            Circle.Parent = TBtn
            local CC = Instance.new("UICorner")
            CC.CornerRadius = UDim.new(1, 0)
            CC.Parent = Circle
            local toggled = default
            local function SetState(state)
                toggled = state
                if useFlag then Flags[flag] = state end
                if callback then task.spawn(function() callback(state) end) end
                TweenService:Create(Circle, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Position = state and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)}):Play()
                TweenService:Create(TBtn, TweenInfo.new(0.2), {BackgroundColor3 = state and THEME.Accent or Color3.fromRGB(50, 50, 60)}):Play()
            end
            if useFlag then Events[flag] = {Set = SetState} end
            local ClickBtn = Instance.new("TextButton")
            ClickBtn.Size = UDim2.new(1, 0, 1, 0)
            ClickBtn.BackgroundTransparency = 1
            ClickBtn.Text = ""
            ClickBtn.Parent = TFrame
            ClickBtn.MouseButton1Click:Connect(function() SetState(not toggled) end)
            ClickBtn.MouseEnter:Connect(function()
                TweenService:Create(TFrame, TweenInfo.new(0.15), {BackgroundColor3 = THEME.SurfaceHover}):Play()
                TweenService:Create(TS, TweenInfo.new(0.15), {Transparency = 0.4}):Play()
                TweenService:Create(TBtn, TweenInfo.new(0.15), {Size = UDim2.new(0, 38, 0, 19)}):Play()
            end)
            ClickBtn.MouseLeave:Connect(function()
                TweenService:Create(TFrame, TweenInfo.new(0.15), {BackgroundColor3 = THEME.Surface}):Play()
                TweenService:Create(TS, TweenInfo.new(0.15), {Transparency = 0.7}):Play()
                TweenService:Create(TBtn, TweenInfo.new(0.15), {Size = UDim2.new(0, 36, 0, 18)}):Play()
            end)
            if default and callback then
                task.spawn(function() callback(default) end)
            end
            return {Frame = TFrame, SetState = SetState}
        end
        function Tab:Slider(text, min, max, default, callback, flag)
            local useFlag = flag ~= nil
            if useFlag then
                default = Flags[flag] or default
                Flags[flag] = default
            end
            self._layoutCounter = self._layoutCounter + 1
            local SFrame = Instance.new("Frame")
            SFrame.Size = UDim2.new(1, 0, 0, 46)
            SFrame.BackgroundTransparency = 1
            SFrame.LayoutOrder = self._layoutCounter
            SFrame.Parent = self.Container
            local SLabel = Instance.new("TextLabel")
            SLabel.Size = UDim2.new(1, -50, 0, 18)
            SLabel.BackgroundTransparency = 1
            SLabel.Text = text
            SLabel.TextColor3 = THEME.Text
            SLabel.FontFace = THEME.Font
            SLabel.TextSize = 13
            SLabel.TextXAlignment = Enum.TextXAlignment.Left
            SLabel.Parent = SFrame
            local SVal = Instance.new("TextLabel")
            SVal.Size = UDim2.new(0, 40, 0, 18)
            SVal.Position = UDim2.new(1, -40, 0, 0)
            SVal.BackgroundTransparency = 1
            SVal.Text = tostring(default)
            SVal.TextColor3 = THEME.TextMuted
            SVal.FontFace = THEME.Font
            SVal.TextSize = 12
            SVal.TextXAlignment = Enum.TextXAlignment.Right
            SVal.Parent = SFrame
            local SBar = Instance.new("TextButton")
            SBar.Size = UDim2.new(1, 0, 0, 4)
            SBar.Position = UDim2.new(0, 0, 0, 28)
            SBar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
            SBar.Text = ""
            SBar.AutoButtonColor = false
            SBar.Parent = SFrame
            local SBC = Instance.new("UICorner")
            SBC.CornerRadius = UDim.new(1, 0)
            SBC.Parent = SBar
            local Fill = Instance.new("Frame")
            Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
            Fill.BackgroundColor3 = THEME.Accent
            Fill.BorderSizePixel = 0
            Fill.Parent = SBar
            local FC = Instance.new("UICorner")
            FC.CornerRadius = UDim.new(1, 0)
            FC.Parent = Fill
            local function SetValue(val)
                val = math.clamp(math.floor(val), min, max)
                if useFlag then Flags[flag] = val end
                SVal.Text = tostring(val)
                TweenService:Create(Fill, TweenInfo.new(0.1), {Size = UDim2.new((val - min) / (max - min), 0, 1, 0)}):Play()
                if callback then callback(val) end
            end
            if useFlag then Events[flag] = {Set = SetValue} end
            local dragging = false
            SBar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    local pct = math.clamp((input.Position.X - SBar.AbsolutePosition.X) / SBar.AbsoluteSize.X, 0, 1)
                    SetValue(min + (max - min) * pct)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local pct = math.clamp((input.Position.X - SBar.AbsolutePosition.X) / SBar.AbsoluteSize.X, 0, 1)
                    SetValue(min + (max - min) * pct)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
            return {Frame = SFrame, SetValue = SetValue}
        end
        function Tab:Dropdown(text, options, default, callback, flag, searchEnabled)
            local useFlag = flag ~= nil
            if useFlag then
                default = Flags[flag] or default
                Flags[flag] = default
            end
            searchEnabled = searchEnabled ~= false
            self._layoutCounter = self._layoutCounter + 1
            local DFrame = Instance.new("Frame")
            DFrame.Size = UDim2.new(1, 0, 0, 32)
            DFrame.BackgroundColor3 = THEME.Surface
            DFrame.ClipsDescendants = true
            DFrame.LayoutOrder = self._layoutCounter
            DFrame.Parent = self.Container
            local DC = Instance.new("UICorner")
            DC.CornerRadius = UDim.new(0, 6)
            DC.Parent = DFrame
            local DS = Instance.new("UIStroke")
            DS.Color = THEME.Border
            DS.Transparency = 0.7
            DS.Parent = DFrame
            local DBtn = Instance.new("TextButton")
            DBtn.Size = UDim2.new(1, 0, 0, 32)
            DBtn.BackgroundTransparency = 1
            DBtn.Text = ""
            DBtn.Parent = DFrame
            local DLabel = Instance.new("TextLabel")
            DLabel.Size = UDim2.new(1, -30, 1, 0)
            DLabel.Position = UDim2.new(0, 10, 0, 0)
            DLabel.BackgroundTransparency = 1
            DLabel.Text = text .. ": " .. (default or "Select...")
            DLabel.TextColor3 = THEME.Text
            DLabel.FontFace = THEME.Font
            DLabel.TextSize = 13
            DLabel.TextXAlignment = Enum.TextXAlignment.Left
            DLabel.Parent = DBtn
            local Arrow = Instance.new("ImageLabel")
            Arrow.Size = UDim2.new(0, 16, 0, 16)
            Arrow.Position = UDim2.new(1, -22, 0.5, 0)
            Arrow.AnchorPoint = Vector2.new(0, 0.5)
            Arrow.BackgroundTransparency = 1
            Arrow.Image = "rbxassetid://6031091004"
            Arrow.ImageColor3 = THEME.TextMuted
            Arrow.Parent = DBtn
            local SearchBox = Instance.new("TextBox")
            SearchBox.Size = UDim2.new(1, -8, 0, 24)
            SearchBox.Position = UDim2.new(0, 4, 0, 34)
            SearchBox.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
            SearchBox.Text = ""
            SearchBox.PlaceholderText = "Search..."
            SearchBox.TextColor3 = Color3.new(1, 1, 1)
            SearchBox.PlaceholderColor3 = THEME.TextMuted
            SearchBox.FontFace = THEME.Font
            SearchBox.TextSize = 11
            SearchBox.ClearTextOnFocus = false
            SearchBox.Visible = searchEnabled
            SearchBox.Parent = DFrame
            local SBC = Instance.new("UICorner")
            SBC.CornerRadius = UDim.new(0, 4)
            SBC.Parent = SearchBox
            local SBP = Instance.new("UIPadding")
            SBP.PaddingLeft = UDim.new(0, 6)
            SBP.Parent = SearchBox
            local listOffset = searchEnabled and 62 or 34
            local List = Instance.new("ScrollingFrame")
            List.Size = UDim2.new(1, -8, 0, 100)
            List.Position = UDim2.new(0, 4, 0, listOffset)
            List.BackgroundTransparency = 1
            List.ScrollBarThickness = 2
            List.ScrollBarImageColor3 = THEME.TextMuted
            List.CanvasSize = UDim2.new(0, 0, 0, 0)
            List.AutomaticCanvasSize = Enum.AutomaticSize.Y
            List.Visible = false
            List.Parent = DFrame
            local LL = Instance.new("UIListLayout")
            LL.Padding = UDim.new(0, 2)
            LL.Parent = List
            local isOpen = false
            local current = default
            local filteredOptions = options
            local function SetOption(opt)
                current = opt
                if useFlag then Flags[flag] = opt end
                DLabel.Text = text .. ": " .. opt
                if callback then callback(opt) end
            end
            local isResetting = false
            local function RenderOptions(filter)
                for _, c in ipairs(List:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                filteredOptions = {}
                for _, opt in ipairs(options) do
                    if not filter or filter == "" or string.find(string.lower(opt), string.lower(filter)) then
                        table.insert(filteredOptions, opt)
                    end
                end
                for _, opt in ipairs(filteredOptions) do
                    local OBtn = Instance.new("TextButton")
                    OBtn.Size = UDim2.new(1, 0, 0, 26)
                    OBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
                    OBtn.BackgroundTransparency = 0.5
                    OBtn.Text = opt
                    OBtn.TextColor3 = opt == current and THEME.Accent or THEME.TextMuted
                    OBtn.FontFace = THEME.Font
                    OBtn.TextSize = 12
                    OBtn.Parent = List
                    local OC = Instance.new("UICorner")
                    OC.CornerRadius = UDim.new(0, 4)
                    OC.Parent = OBtn
                    OBtn.MouseButton1Click:Connect(function()
                        SetOption(opt)
                        isOpen = false
                        isResetting = true
                        SearchBox.Text = ""
                        List.Visible = false
                        List.Size = UDim2.new(1, -8, 0, 0)
                        if searchEnabled then SearchBox.Visible = false end
                        TweenService:Create(Arrow, TweenInfo.new(0.15), {Rotation = 0}):Play()
                        TweenService:Create(DFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 32)}):Play()
                        task.spawn(function()
                            task.wait(0.25)
                            DFrame.Size = UDim2.new(1, 0, 0, 32)
                            isResetting = false
                            RenderOptions("")
                        end)
                    end)
                end
            end
            local function Refresh(opts)
                options = opts or options
                RenderOptions(SearchBox.Text)
            end
            SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
                if isResetting then return end
                RenderOptions(SearchBox.Text)
                local h = math.min(#filteredOptions * 28 + listOffset + 6, 180)
                TweenService:Create(DFrame, TweenInfo.new(0.15), {Size = UDim2.new(1, 0, 0, h)}):Play()
            end)
            Refresh()
            if useFlag then Events[flag] = {Set = SetOption} end
            DBtn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                if isOpen then
                    isResetting = true
                    SearchBox.Text = ""
                    RenderOptions("")
                    task.defer(function() isResetting = false end)
                end
                local h = isOpen and math.min(#filteredOptions * 28 + listOffset + 6, 180) or 32
                TweenService:Create(Arrow, TweenInfo.new(0.15), {Rotation = isOpen and 180 or 0}):Play()
                TweenService:Create(DFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, h)}):Play()
                List.Visible = isOpen
                if searchEnabled then SearchBox.Visible = isOpen end
                List.Size = UDim2.new(1, -8, 0, math.max(0, h - listOffset - 6))
            end)
            local function SetState(visible)
                DFrame.Visible = visible
            end
            local function Clear()
                options = {}
                filteredOptions = {}
                for _, c in ipairs(List:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                current = nil
                if useFlag then Flags[flag] = nil end
                DLabel.Text = text .. ": Select..."
            end
            return {Frame = DFrame, Set = SetOption, Refresh = Refresh, SetState = SetState, SetVisible = SetState, Clear = Clear}
        end
        function Tab:MultiDropdown(text, options, default, callback, search, flag)
            local useFlag = flag ~= nil
            if useFlag then
                default = Flags[flag] or default or {}
                Flags[flag] = default
            else
                default = default or {}
            end
            local searchEnabled = search
            local selected = {}
            for _, v in ipairs(default) do selected[v] = true end
            self._layoutCounter = self._layoutCounter + 1
            local DFrame = Instance.new("Frame")
            DFrame.Size = UDim2.new(1, 0, 0, 32)
            DFrame.BackgroundColor3 = THEME.Surface
            DFrame.ClipsDescendants = true
            DFrame.LayoutOrder = self._layoutCounter
            DFrame.Parent = self.Container
            local DC = Instance.new("UICorner")
            DC.CornerRadius = UDim.new(0, 6)
            DC.Parent = DFrame
            local DS = Instance.new("UIStroke")
            DS.Color = THEME.Border
            DS.Transparency = 0.7
            DS.Parent = DFrame
            local DBtn = Instance.new("TextButton")
            DBtn.Size = UDim2.new(1, 0, 0, 32)
            DBtn.BackgroundTransparency = 1
            DBtn.Text = ""
            DBtn.Parent = DFrame
            local function GetLabel()
                local s = {}
                for k in pairs(selected) do table.insert(s, k) end
                return #s > 0 and table.concat(s, ", ") or "None"
            end
            local DLabel = Instance.new("TextLabel")
            DLabel.Size = UDim2.new(1, -30, 1, 0)
            DLabel.Position = UDim2.new(0, 10, 0, 0)
            DLabel.BackgroundTransparency = 1
            DLabel.Text = text .. ": " .. GetLabel()
            DLabel.TextColor3 = THEME.Text
            DLabel.FontFace = THEME.Font
            DLabel.TextSize = 13
            DLabel.TextXAlignment = Enum.TextXAlignment.Left
            DLabel.Parent = DBtn
            local Arrow = Instance.new("ImageLabel")
            Arrow.Size = UDim2.new(0, 16, 0, 16)
            Arrow.Position = UDim2.new(1, -22, 0.5, 0)
            Arrow.AnchorPoint = Vector2.new(0, 0.5)
            Arrow.BackgroundTransparency = 1
            Arrow.Image = "rbxassetid://6031091004"
            Arrow.ImageColor3 = THEME.TextMuted
            Arrow.Parent = DBtn
            local SearchBox = Instance.new("TextBox")
            SearchBox.Size = UDim2.new(1, -8, 0, 24)
            SearchBox.Position = UDim2.new(0, 4, 0, 34)
            SearchBox.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
            SearchBox.Text = ""
            SearchBox.PlaceholderText = "Search..."
            SearchBox.TextColor3 = Color3.new(1, 1, 1)
            SearchBox.PlaceholderColor3 = THEME.TextMuted
            SearchBox.FontFace = THEME.Font
            SearchBox.TextSize = 11
            SearchBox.ClearTextOnFocus = false
            SearchBox.Visible = searchEnabled
            SearchBox.Parent = DFrame
            local SBC = Instance.new("UICorner")
            SBC.CornerRadius = UDim.new(0, 4)
            SBC.Parent = SearchBox
            local SBP = Instance.new("UIPadding")
            SBP.PaddingLeft = UDim.new(0, 6)
            SBP.Parent = SearchBox
            local listOffset = searchEnabled and 62 or 34
            local List = Instance.new("ScrollingFrame")
            List.Size = UDim2.new(1, -8, 0, 100)
            List.Position = UDim2.new(0, 4, 0, listOffset)
            List.BackgroundTransparency = 1
            List.ScrollBarThickness = 2
            List.ScrollBarImageColor3 = THEME.TextMuted
            List.CanvasSize = UDim2.new(0, 0, 0, 0)
            List.AutomaticCanvasSize = Enum.AutomaticSize.Y
            List.Visible = false
            List.Parent = DFrame
            local LL = Instance.new("UIListLayout")
            LL.Padding = UDim.new(0, 2)
            LL.Parent = List
            local isOpen = false
            local filteredOptions = options
            local function UpdateFlags()
                local r = {}
                for k in pairs(selected) do table.insert(r, k) end
                if useFlag then Flags[flag] = r end
                DLabel.Text = text .. ": " .. GetLabel()
                if callback then callback(r) end
            end
            local function RenderOptions(filter)
                for _, c in ipairs(List:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                filteredOptions = {}
                for _, opt in ipairs(options) do
                    if not filter or filter == "" or string.find(string.lower(opt), string.lower(filter)) then
                        table.insert(filteredOptions, opt)
                    end
                end
                for _, opt in ipairs(filteredOptions) do
                    local OBtn = Instance.new("TextButton")
                    OBtn.Size = UDim2.new(1, 0, 0, 26)
                    OBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
                    OBtn.BackgroundTransparency = 0.5
                    OBtn.Text = opt
                    OBtn.TextColor3 = selected[opt] and THEME.Accent or THEME.TextMuted
                    OBtn.FontFace = THEME.Font
                    OBtn.TextSize = 12
                    OBtn.Parent = List
                    local OC = Instance.new("UICorner")
                    OC.CornerRadius = UDim.new(0, 4)
                    OC.Parent = OBtn
                    OBtn.MouseButton1Click:Connect(function()
                        if selected[opt] then selected[opt] = nil else selected[opt] = true end
                        OBtn.TextColor3 = selected[opt] and THEME.Accent or THEME.TextMuted
                        UpdateFlags()
                    end)
                end
            end
            local function Refresh(opts)
                options = opts or options
                RenderOptions(SearchBox.Text)
            end
            Refresh()
            SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
                RenderOptions(SearchBox.Text)
                local h = math.min(#filteredOptions * 28 + listOffset + 6, 180)
                TweenService:Create(DFrame, TweenInfo.new(0.15), {Size = UDim2.new(1, 0, 0, h)}):Play()
            end)
            if useFlag then Events[flag] = {Set = SetOptions} end
            DBtn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                if isOpen then
                    SearchBox.Text = ""
                    RenderOptions("")
                end
                local h = isOpen and math.min(#filteredOptions * 28 + listOffset + 6, 180) or 32
                TweenService:Create(Arrow, TweenInfo.new(0.15), {Rotation = isOpen and 180 or 0}):Play()
                TweenService:Create(DFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, h)}):Play()
                List.Visible = isOpen
                if searchEnabled then SearchBox.Visible = isOpen end
                List.Size = UDim2.new(1, -8, 0, math.max(0, h - listOffset - 6))
            end)
            local function SetOptions(opts)
                selected = {}
                for _, v in ipairs(opts) do selected[v] = true end
                UpdateFlags()
                Refresh()
            end
            return {
                Frame = DFrame, 
                Set = SetOptions, 
                Refresh = Refresh, 
                Clear = function() selected = {} UpdateFlags() Refresh() end,
                SetState = function(visible) DFrame.Visible = visible end,
                SetVisible = function(visible) DFrame.Visible = visible end
            }
        end
        function Tab:TextInput(text, placeholder, callback, flag)
            local useFlag = flag ~= nil
            local default = ""
            if useFlag then
                default = Flags[flag] or ""
                Flags[flag] = default
            end
            self._layoutCounter = self._layoutCounter + 1
            local IFrame = Instance.new("Frame")
            IFrame.Size = UDim2.new(1, 0, 0, 52)
            IFrame.BackgroundTransparency = 1
            IFrame.LayoutOrder = self._layoutCounter
            IFrame.Parent = self.Container
            local ILabel = Instance.new("TextLabel")
            ILabel.Size = UDim2.new(1, 0, 0, 18)
            ILabel.BackgroundTransparency = 1
            ILabel.Text = text
            ILabel.TextColor3 = THEME.Text
            ILabel.FontFace = THEME.Font
            ILabel.TextSize = 13
            ILabel.TextXAlignment = Enum.TextXAlignment.Left
            ILabel.Parent = IFrame
            local IBFrame = Instance.new("Frame")
            IBFrame.Size = UDim2.new(1, 0, 0, 28)
            IBFrame.Position = UDim2.new(0, 0, 0, 22)
            IBFrame.BackgroundColor3 = THEME.Surface
            IBFrame.Parent = IFrame
            local IBC = Instance.new("UICorner")
            IBC.CornerRadius = UDim.new(0, 6)
            IBC.Parent = IBFrame
            local IBS = Instance.new("UIStroke")
            IBS.Color = THEME.Border
            IBS.Transparency = 0.7
            IBS.Parent = IBFrame
            local IBox = Instance.new("TextBox")
            IBox.Size = UDim2.new(1, -16, 1, 0)
            IBox.Position = UDim2.new(0, 8, 0, 0)
            IBox.BackgroundTransparency = 1
            IBox.Text = default
            IBox.PlaceholderText = placeholder or "..."
            IBox.TextColor3 = THEME.Text
            IBox.PlaceholderColor3 = THEME.TextMuted
            IBox.FontFace = THEME.Font
            IBox.TextSize = 12
            IBox.TextXAlignment = Enum.TextXAlignment.Left
            IBox.Parent = IBFrame
            local function SetText(t)
                IBox.Text = t or ""
                if useFlag then Flags[flag] = t end
                if callback then callback(t) end
            end
            if useFlag then Events[flag] = {Set = SetText} end
            IBox.FocusLost:Connect(function()
                if useFlag then Flags[flag] = IBox.Text end
                if callback then callback(IBox.Text) end
            end)
            return {Frame = IFrame, SetText = SetText}
        end
        function Tab:InputText2(text, placeholder, callback, flag)
            local useFlag = flag ~= nil
            local default = ""
            if useFlag then
                default = Flags[flag] or ""
                Flags[flag] = default
            end
            self._layoutCounter = self._layoutCounter + 1
            local IFrame = Instance.new("Frame")
            IFrame.Size = UDim2.new(1, 0, 0, 34)
            IFrame.BackgroundColor3 = THEME.Surface
            IFrame.LayoutOrder = self._layoutCounter
            IFrame.Parent = self.Container
            local IC = Instance.new("UICorner")
            IC.CornerRadius = UDim.new(0, 6)
            IC.Parent = IFrame
            local IS = Instance.new("UIStroke")
            IS.Color = THEME.Border
            IS.Transparency = 0.7
            IS.Parent = IFrame
            local ILabel = Instance.new("TextLabel")
            ILabel.Size = UDim2.new(1, -100, 1, 0)
            ILabel.Position = UDim2.new(0, 10, 0, 0)
            ILabel.BackgroundTransparency = 1
            ILabel.Text = text
            ILabel.TextColor3 = THEME.Text
            ILabel.FontFace = THEME.Font
            ILabel.TextSize = 13
            ILabel.TextXAlignment = Enum.TextXAlignment.Left
            ILabel.Parent = IFrame
            local IBFrame = Instance.new("Frame")
            IBFrame.Size = UDim2.new(0, 80, 0, 22)
            IBFrame.Position = UDim2.new(1, -90, 0.5, 0)
            IBFrame.AnchorPoint = Vector2.new(0, 0.5)
            IBFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            IBFrame.Parent = IFrame
            local IBC = Instance.new("UICorner")
            IBC.CornerRadius = UDim.new(0, 4)
            IBC.Parent = IBFrame
            local IBox = Instance.new("TextBox")
            IBox.Size = UDim2.new(1, -10, 1, 0)
            IBox.Position = UDim2.new(0, 5, 0, 0)
            IBox.BackgroundTransparency = 1
            IBox.Text = default
            IBox.PlaceholderText = placeholder or "..."
            IBox.TextColor3 = Color3.new(1, 1, 1)
            IBox.PlaceholderColor3 = THEME.TextMuted
            IBox.FontFace = THEME.Font
            IBox.TextSize = 11
            IBox.TextXAlignment = Enum.TextXAlignment.Center
            IBox.Parent = IBFrame
            local function SetText(t)
                IBox.Text = t or ""
                if useFlag then Flags[flag] = t end
                if callback then callback(t) end
            end
            if useFlag then Events[flag] = {Set = SetText} end
            IBox.FocusLost:Connect(function()
                if useFlag then Flags[flag] = IBox.Text end
                if callback then callback(IBox.Text) end
            end)
            return {Frame = IFrame, SetText = SetText}
        end
        function Tab:Keybind(text, default, callback, flag)
            local useFlag = flag ~= nil
            local currentKey = default or Enum.KeyCode.RightControl
            if useFlag then
                currentKey = Flags[flag] or currentKey
                Flags[flag] = currentKey
            end
            self._layoutCounter = self._layoutCounter + 1
            local function getKeyName(keyCode)
                local name = keyCode.Name
                if name:match("^%a$") then return name end
                if name:match("^One$") then return "1" end
                if name:match("^Two$") then return "2" end
                if name:match("^Three$") then return "3" end
                if name:match("^Four$") then return "4" end
                if name:match("^Five$") then return "5" end
                if name:match("^Six$") then return "6" end
                if name:match("^Seven$") then return "7" end
                if name:match("^Eight$") then return "8" end
                if name:match("^Nine$") then return "9" end
                if name:match("^Zero$") then return "0" end
                return name
            end
            local KFrame = Instance.new("Frame")
            KFrame.Size = UDim2.new(1, 0, 0, 32)
            KFrame.BackgroundColor3 = THEME.Surface
            KFrame.LayoutOrder = self._layoutCounter
            KFrame.Parent = self.Container
            local KC = Instance.new("UICorner")
            KC.CornerRadius = UDim.new(0, 6)
            KC.Parent = KFrame
            local KS = Instance.new("UIStroke")
            KS.Color = THEME.Border
            KS.Transparency = 0.7
            KS.Parent = KFrame
            local KLabel = Instance.new("TextLabel")
            KLabel.Size = UDim2.new(1, -100, 1, 0)
            KLabel.Position = UDim2.new(0, 10, 0, 0)
            KLabel.BackgroundTransparency = 1
            KLabel.Text = text
            KLabel.TextColor3 = THEME.Text
            KLabel.FontFace = THEME.Font
            KLabel.TextSize = 13
            KLabel.TextXAlignment = Enum.TextXAlignment.Left
            KLabel.Parent = KFrame
            local KBtn = Instance.new("TextButton")
            KBtn.Size = UDim2.new(0, 80, 0, 22)
            KBtn.Position = UDim2.new(1, -90, 0.5, 0)
            KBtn.AnchorPoint = Vector2.new(0, 0.5)
            KBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            KBtn.Text = getKeyName(currentKey)
            KBtn.TextColor3 = THEME.Text
            KBtn.FontFace = THEME.Font
            KBtn.TextSize = 11
            KBtn.AutoButtonColor = false
            KBtn.Parent = KFrame
            local KBC = Instance.new("UICorner")
            KBC.CornerRadius = UDim.new(0, 4)
            KBC.Parent = KBtn
            local listening = false
            local connection = nil
            local function SetKey(keyCode)
                currentKey = keyCode
                if useFlag then Flags[flag] = keyCode end
                KBtn.Text = getKeyName(keyCode)
                if callback then callback(keyCode) end
            end
            if useFlag then Events[flag] = {Set = SetKey} end
            KBtn.MouseButton1Click:Connect(function()
                if listening then return end
                listening = true
                KBtn.Text = "..."
                TweenService:Create(KBtn, TweenInfo.new(0.15), {BackgroundColor3 = THEME.Accent}):Play()
                connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        listening = false
                        SetKey(input.KeyCode)
                        TweenService:Create(KBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(35, 35, 45)}):Play()
                        if connection then connection:Disconnect() connection = nil end
                    end
                end)
            end)
            return {Frame = KFrame, SetKey = SetKey}
        end
        return Tab
    end
    local OpenBtn = Instance.new("ImageButton")
    OpenBtn.Size = UDim2.new(0, 44, 0, 44)
    OpenBtn.Position = UDim2.new(0, 20, 0, 20)
    OpenBtn.BackgroundColor3 = THEME.Surface
    OpenBtn.BackgroundTransparency = 0.2
    OpenBtn.Image = logo
    OpenBtn.Parent = ScreenGui
    local OBC = Instance.new("UICorner")
    OBC.CornerRadius = UDim.new(0, 10)
    OBC.Parent = OpenBtn
    local OBS = Instance.new("UIStroke")
    OBS.Color = THEME.Border
    OBS.Transparency = 0.5
    OBS.Parent = OpenBtn
    OpenBtn.MouseEnter:Connect(function()
        TweenService:Create(OpenBtn, TweenInfo.new(0.2), {Size = UDim2.new(0, 48, 0, 48), BackgroundTransparency = 0.1}):Play()
        TweenService:Create(OBS, TweenInfo.new(0.2), {Transparency = 0.2}):Play()
    end)
    OpenBtn.MouseLeave:Connect(function()
        TweenService:Create(OpenBtn, TweenInfo.new(0.2), {Size = UDim2.new(0, 44, 0, 44), BackgroundTransparency = 0.2}):Play()
        TweenService:Create(OBS, TweenInfo.new(0.2), {Transparency = 0.5}):Play()
    end)
    makeDraggable(OpenBtn, OpenBtn)
    OpenBtn.MouseButton1Click:Connect(function()
        Main.Visible = not Main.Visible
    end)
    task.spawn(function()
        task.wait(0.1)
        Main.Visible = true
        Main.BackgroundTransparency = 0.15
        Main.Size = UDim2.new(0, baseWidth, 0, baseHeight)
        TweenService:Create(Main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.15
        }):Play()
    end)
    local keybindCooldown = false
    Window.SetKeybindCooldown = function()
        keybindCooldown = true
        task.delay(0.3, function() keybindCooldown = false end)
    end
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if keybindCooldown then return end
        if input.KeyCode == Window.ToggleKey then
            Main.Visible = not Main.Visible
        end
    end)
    task.spawn(function()
        task.wait(0.2)

        local autoLoadRaw = safeRead("SeraphinConfigsAutoLoad/_AutoLoad.json")
        if autoLoadRaw then
            local s, autoSettings = pcall(function() return HttpService:JSONDecode(autoLoadRaw) end)
            if s and autoSettings and autoSettings.enabled and autoSettings.config and autoSettings.config ~= "None" then
                local configPath = "SeraphinConfigsNew/" .. autoSettings.config .. ".json"
                local configRaw = safeRead(configPath)
                if configRaw then
                    Window:LoadConfig(autoSettings.config)
                    Window:Notify({
                        Title = "Auto Loaded",
                        Content = "Config '" .. autoSettings.config .. "' loaded!",
                        Duration = 3
                    })
                end
            end
        end
    end)
    return Window
end
return Seraphin
