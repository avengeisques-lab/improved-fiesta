--[[
    ██████  ██    ██ ██████  ███████      ██████  ███████ ████████ ███████
    ██   ██ ██    ██ ██   ██ ██          ██    ██ ██         ██    ██
    ██████  ██    ██ ██████  █████       ██    ██ ███████    ██    █████
    ██   ██ ██    ██ ██   ██ ██          ██    ██      ██    ██    ██
    ██████   ██████  ██████  ███████      ██████  ███████    ██    ███████

    Universal Script for Roblox
    Works with most executors (Synapse, Krnl, Fluxus, etc.)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ═══════════════════════════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════════════════════════

local Config = {
    -- ESP
    EspEnabled = false,
    EspBox = true,
    EspName = true,
    EspHealth = true,
    EspDistance = true,
    EspTracers = false,
    EspSnaplines = false,
    EspTeamCheck = false,
    EspBoxColor = Color3.fromRGB(255, 50, 50),
    EspEnemyColor = Color3.fromRGB(255, 50, 50),
    EspTeamColor = Color3.fromRGB(50, 255, 50),

    -- Aimbot
    AimbotEnabled = false,
    AimbotFOV = 120,
    AimbotSmoothness = 0.5,
    AimbotKey = Enum.UserInputType.MouseButton2,
    AimbotPart = "Head",
    AimbotTeamCheck = false,
    AimbotShowFOV = true,
    AimbotFOVColor = Color3.fromRGB(255, 255, 255),

    -- Movement
    SpeedEnabled = false,
    SpeedValue = 50,
    FlyEnabled = false,
    FlySpeed = 80,
    FlyKey = Enum.KeyCode.F,
    InfiniteJumpEnabled = false,
    NoClipEnabled = false,

    -- Utility
    GodModeEnabled = false,
    AntiAFKEnabled = true,
    ClickTeleportEnabled = false,
    ClickTeleportKey = Enum.KeyCode.P,
}

-- ═══════════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════════

local ESPObjects = {}
local FlyBody = nil
local FlyBV = nil
local FlyBG = nil
local IsFlying = false
local FlyDirection = {}
local ConnectionQueue = {}
local IsAimbotHeld = false
local ClosestPlayer = nil

-- ═══════════════════════════════════════════════════════════════════
--  UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

local function GetCharacter(player)
    return player.Character or player.CharacterAdded:Wait()
end

local function IsAlive(player)
    local char = player.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function IsTeammate(player)
    if not Config.EspTeamCheck and not Config.AimbotTeamCheck then return false end
    if LocalPlayer.Team == nil or player.Team == nil then return false end
    return LocalPlayer.Team == player.Team
end

local function WorldToScreen(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function GetDistance(from, to)
    return (from - to).Magnitude
end

local function IsVisible(part)
    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin)
    local ray = Ray.new(origin, direction)
    local hit = Workspace:FindPartOnRayWithWhitelist(ray, {GetCharacter(LocalPlayer)})
    return hit == nil or hit:IsDescendantOf(part.Parent)
end

local function GetClosestPlayer()
    local closest = nil
    local shortestDist = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            if Config.AimbotTeamCheck and IsTeammate(player) then continue end
            local char = GetCharacter(player)
            local part = char:FindFirstChild(Config.AimbotPart) or char:FindFirstChild("Head")
            if part then
                local screenPos, onScreen = WorldToScreen(part.Position)
                if onScreen then
                    local mousePos = UserInputService:GetMouseLocation()
                    local dist = (screenPos - mousePos).Magnitude
                    if dist < Config.AimbotFOV and dist < shortestDist then
                        shortestDist = dist
                        closest = player
                    end
                end
            end
        end
    end
    return closest
end

local function GetHealth(player)
    local char = player.Character
    if not char then return 0, 100 end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return 0, 100 end
    return humanoid.Health, humanoid.MaxHealth
end

-- ═══════════════════════════════════════════════════════════════════
--  ESP SYSTEM
-- ═══════════════════════════════════════════════════════════════════

local function CreateESP(player)
    if ESPObjects[player] then return end

    local objects = {}

    -- Box
    local box = Drawing.new("Square")
    box.Thickness = 1.5
    box.Filled = false
    box.Transparency = 1
    box.Visible = false
    objects.Box = box

    -- Name
    local name = Drawing.new("Text")
    name.Center = true
    name.Outline = true
    name.OutlineColor = Color3.fromRGB(0, 0, 0)
    name.Size = 13
    name.Font = 2
    name.Visible = false
    objects.Name = name

    -- Health text
    local healthText = Drawing.new("Text")
    healthText.Center = true
    healthText.Outline = true
    healthText.OutlineColor = Color3.fromRGB(0, 0, 0)
    healthText.Size = 13
    healthText.Font = 2
    healthText.Visible = false
    objects.Health = healthText

    -- Distance text
    local distText = Drawing.new("Text")
    distText.Center = true
    distText.Outline = true
    distText.OutlineColor = Color3.fromRGB(0, 0, 0)
    distText.Size = 13
    distText.Font = 2
    distText.Visible = false
    objects.Distance = distText

    -- Tracer
    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Transparency = 1
    tracer.Visible = false
    objects.Tracer = tracer

    -- Snapline
    local snapline = Drawing.new("Line")
    snapline.Thickness = 1
    snapline.Transparency = 1
    snapline.Visible = false
    objects.Snapline = snapline

    -- Health bar
    local healthBarOutline = Drawing.new("Square")
    healthBarOutline.Thickness = 1
    healthBarOutline.Filled = false
    healthBarOutline.Transparency = 1
    healthBarOutline.Visible = false
    objects.HealthBarOutline = healthBarOutline

    local healthBarFill = Drawing.new("Square")
    healthBarFill.Thickness = 1
    healthBarFill.Filled = true
    healthBarFill.Transparency = 1
    healthBarFill.Visible = false
    objects.HealthBarFill = healthBarFill

    ESPObjects[player] = objects
end

local function RemoveESP(player)
    if not ESPObjects[player] then return end
    for _, obj in pairs(ESPObjects[player]) do
        pcall(function() obj:Remove() end)
    end
    ESPObjects[player] = nil
end

local function UpdateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        if not ESPObjects[player] then
            CreateESP(player)
        end

        local objects = ESPObjects[player]
        local char = player.Character

        if not char or not IsAlive(player) then
            for _, obj in pairs(objects) do
                if obj.Visible ~= nil then obj.Visible = false end
            end
            continue
        end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")

        if not rootPart or not head then
            for _, obj in pairs(objects) do
                if obj.Visible ~= nil then obj.Visible = false end
            end
            continue
        end

        local teamCheck = Config.EspTeamCheck and IsTeammate(player)
        local espColor = teamCheck and Config.EspTeamColor or Config.EspEnemyColor

        local rootPos, rootOnScreen = WorldToScreen(rootPart.Position)
        local headPos, headOnScreen = WorldToScreen(head.Position + Vector3.new(0, 0.5, 0))
        local legPos, legOnScreen = WorldToScreen(rootPart.Position - Vector3.new(0, 3, 0))

        if not rootOnScreen then
            for _, obj in pairs(objects) do
                if obj.Visible ~= nil then obj.Visible = false end
            end
            continue
        end

        if Config.EspEnabled then
            -- Box
            if Config.EspBox then
                local boxHeight = math.abs(headPos.Y - legPos.Y)
                local boxWidth = boxHeight * 0.5
                objects.Box.Size = Vector2.new(boxWidth, boxHeight)
                objects.Box.Position = Vector2.new(rootPos.X - boxWidth / 2, headPos.Y)
                objects.Box.Color = espColor
                objects.Box.Visible = true
            else
                objects.Box.Visible = false
            end

            -- Name
            if Config.EspName then
                objects.Name.Position = Vector2.new(rootPos.X, headPos.Y - 16)
                objects.Name.Text = player.DisplayName
                objects.Name.Color = espColor
                objects.Name.Visible = true
            else
                objects.Name.Visible = false
            end

            -- Health
            if Config.EspHealth and humanoid then
                local health, maxHealth = GetHealth(player)
                local pct = math.clamp(health / maxHealth, 0, 1)
                objects.Health.Position = Vector2.new(rootPos.X, legPos.Y + 2)
                objects.Health.Text = string.format("[%d/%d]", math.floor(health), math.floor(maxHealth))
                objects.Health.Color = Color3.new(1 - pct, pct, 0)
                objects.Health.Visible = true

                -- Health bar
                local boxHeight = math.abs(headPos.Y - legPos.Y)
                local barX = rootPos.X - (boxHeight * 0.5) / 2 - 5
                local barY = headPos.Y
                local barHeight = boxHeight
                local barWidth = 2

                objects.HealthBarOutline.Size = Vector2.new(barWidth, barHeight)
                objects.HealthBarOutline.Position = Vector2.new(barX, barY)
                objects.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
                objects.HealthBarOutline.Visible = true

                objects.HealthBarFill.Size = Vector2.new(barWidth, barHeight * pct)
                objects.HealthBarFill.Position = Vector2.new(barX, barY + barHeight * (1 - pct))
                objects.HealthBarFill.Color = Color3.new(1 - pct, pct, 0)
                objects.HealthBarFill.Visible = true
            else
                objects.Health.Visible = false
                objects.HealthBarOutline.Visible = false
                objects.HealthBarFill.Visible = false
            end

            -- Distance
            if Config.EspDistance and rootPart then
                local dist = math.floor(GetDistance(Camera.CFrame.Position, rootPart.Position))
                objects.Distance.Position = Vector2.new(rootPos.X, legPos.Y + 14)
                objects.Distance.Text = dist .. "m"
                objects.Distance.Color = espColor
                objects.Distance.Visible = true
            else
                objects.Distance.Visible = false
            end

            -- Tracers
            if Config.EspTracers then
                local viewportSize = Camera.ViewportSize
                objects.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
                objects.Tracer.To = Vector2.new(rootPos.X, legPos.Y)
                objects.Tracer.Color = espColor
                objects.Tracer.Visible = true
            else
                objects.Tracer.Visible = false
            end

            -- Snaplines
            if Config.EspSnaplines then
                local viewportSize = Camera.ViewportSize
                objects.Snapline.From = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
                objects.Snapline.To = Vector2.new(rootPos.X, rootPos.Y)
                objects.Snapline.Color = espColor
                objects.Snapline.Visible = true
            else
                objects.Snapline.Visible = false
            end
        else
            for _, obj in pairs(objects) do
                if obj.Visible ~= nil then obj.Visible = false end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════
--  AIMBOT SYSTEM
-- ═══════════════════════════════════════════════════════════════════

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 64
FOVCircle.Radius = Config.AimbotFOV
FOVCircle.Filled = false
FOVCircle.Color = Config.AimbotFOVColor
FOVCircle.Transparency = 1
FOVCircle.Visible = false

local function UpdateAimbot()
    if not Config.AimbotEnabled then
        FOVCircle.Visible = false
        return
    end

    FOVCircle.Radius = Config.AimbotFOV
    FOVCircle.Color = Config.AimbotFOVColor
    FOVCircle.Position = UserInputService:GetMouseLocation()

    if Config.AimbotShowFOV then
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end

    if IsAimbotHeld then
        local target = GetClosestPlayer()
        if target and IsAlive(target) then
            local char = GetCharacter(target)
            local part = char:FindFirstChild(Config.AimbotPart) or char:FindFirstChild("Head")
            if part then
                local targetPos = part.Position
                local currentCFrame = Camera.CFrame
                local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)

                if Config.AimbotSmoothness > 0 then
                    Camera.CFrame = currentCFrame:Lerp(targetCFrame, Config.AimbotSmoothness)
                else
                    Camera.CFrame = targetCFrame
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════
--  SPEED SYSTEM
-- ═══════════════════════════════════════════════════════════════════

local function UpdateSpeed()
    if not Config.SpeedEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = Config.SpeedValue
    end
end

-- ═══════════════════════════════════════════════════════════════════
--  FLY SYSTEM
-- ═══════════════════════════════════════════════════════════════════

local function StartFly()
    local char = LocalPlayer.Character
    if not char then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    IsFlying = true

    FlyBV = Instance.new("BodyVelocity")
    FlyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    FlyBV.Velocity = Vector3.new(0, 0, 0)
    FlyBV.Parent = rootPart

    FlyBG = Instance.new("BodyGyro")
    FlyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    FlyBG.P = 9e4
    FlyBG.Parent = rootPart

    FlyDirection = {w = false, a = false, s = false, d = false, space = false, shift = false}
end

local function StopFly()
    IsFlying = false
    if FlyBV then FlyBV:Destroy() FlyBV = nil end
    if FlyBG then FlyBG:Destroy() FlyBG = nil end
end

local function UpdateFly()
    if not IsFlying or not FlyBV or not FlyBG then return end

    local char = LocalPlayer.Character
    if not char then StopFly() return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then StopFly() return end

    local camCF = Camera.CFrame
    local direction = Vector3.new(0, 0, 0)

    if FlyDirection.w then direction = direction + camCF.LookVector end
    if FlyDirection.s then direction = direction - camCF.LookVector end
    if FlyDirection.a then direction = direction - camCF.RightVector end
    if FlyDirection.d then direction = direction + camCF.RightVector end
    if FlyDirection.space then direction = direction + Vector3.new(0, 1, 0) end
    if FlyDirection.shift then direction = direction - Vector3.new(0, 1, 0) end

    if direction.Magnitude > 0 then
        direction = direction.Unit * Config.FlySpeed
    end

    FlyBV.Velocity = direction
    FlyBG.CFrame = camCF
end

-- ═══════════════════════════════════════════════════════════════════
--  INFINITE JUMP
-- ═══════════════════════════════════════════════════════════════════

local InfiniteJumpConnection = nil
local function SetupInfiniteJump()
    if InfiniteJumpConnection then InfiniteJumpConnection:Disconnect() end
    InfiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
        if Config.InfiniteJumpEnabled then
            local char = LocalPlayer.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════
--  NOCLIP
-- ═══════════════════════════════════════════════════════════════════

local NoClipConnection = nil
local function SetupNoClip()
    if NoClipConnection then NoClipConnection:Disconnect() end
    NoClipConnection = RunService.Stepped:Connect(function()
        if Config.NoClipEnabled then
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════
--  GOD MODE
-- ═══════════════════════════════════════════════════════════════════

local GodModeConnection = nil
local function SetupGodMode()
    if GodModeConnection then GodModeConnection:Disconnect() end
    GodModeConnection = RunService.Heartbeat:Connect(function()
        if Config.GodModeEnabled then
            local char = LocalPlayer.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.Health = humanoid.MaxHealth
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════
--  ANTI-AFK
-- ═══════════════════════════════════════════════════════════════════

local function SetupAntiAFK()
    local VirtualUser = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        if Config.AntiAFKEnabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════
--  CLICK TELEPORT
-- ═══════════════════════════════════════════════════════════════════

local ClickTeleportConnection = nil
local function SetupClickTeleport()
    if ClickTeleportConnection then ClickTeleportConnection:Disconnect() end
    ClickTeleportConnection = UserInputService.InputBegan:Connect(function(input)
        if Config.ClickTeleportEnabled and input.KeyCode == Config.ClickTeleportKey then
            local mousePos = UserInputService:GetMouseLocation()
            local unitRay = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
            local ray = Ray.new(unitRay.Origin, unitRay.Direction * 1000)
            local hit, pos = Workspace:FindPartOnRay(ray, LocalPlayer.Character)
            if pos then
                local char = LocalPlayer.Character
                if char then
                    local rootPart = char:FindFirstChild("HumanoidRootPart")
                    if rootPart then
                        rootPart.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                    end
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════
--  GUI SYSTEM
-- ═══════════════════════════════════════════════════════════════════

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UniversalScript"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if syn then
    syn.protect_gui(ScreenGui)
end

ScreenGui.Parent = game:GetService("CoreGui")

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 500, 0, 350)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 6)
MainCorner.Parent = MainFrame

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 6)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -30, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "UNIVERSAL SCRIPT"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleBar

-- Tab Buttons Container
local TabContainer = Instance.new("Frame")
TabContainer.Name = "TabContainer"
TabContainer.Size = UDim2.new(1, 0, 0, 25)
TabContainer.Position = UDim2.new(0, 0, 0, 30)
TabContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
TabContainer.BorderSizePixel = 0
TabContainer.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 2)
TabLayout.Parent = TabContainer

-- Tab Content Container
local ContentContainer = Instance.new("Frame")
ContentContainer.Name = "ContentContainer"
ContentContainer.Size = UDim2.new(1, 0, 1, -55)
ContentContainer.Position = UDim2.new(0, 0, 0, 55)
ContentContainer.BackgroundTransparency = 1
ContentContainer.BorderSizePixel = 0
ContentContainer.ClipsDescendants = true
ContentContainer.Parent = MainFrame

-- Tab system
local Tabs = {}
local ActiveTab = nil

local function CreateTab(name, order)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0, 100, 0, 25)
    tabBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    tabBtn.BorderSizePixel = 0
    tabBtn.Text = name
    tabBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    tabBtn.TextSize = 12
    tabBtn.Font = Enum.Font.Gotham
    tabBtn.LayoutOrder = order
    tabBtn.Parent = TabContainer

    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Name = name .. "Content"
    contentFrame.Size = UDim2.new(1, 0, 1, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 4
    contentFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentFrame.Visible = false
    contentFrame.Parent = ContentContainer

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Padding = UDim.new(0, 4)
    contentLayout.Parent = contentFrame

    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingLeft = UDim.new(0, 8)
    contentPadding.PaddingRight = UDim.new(0, 8)
    contentPadding.PaddingTop = UDim.new(0, 8)
    contentPadding.Parent = contentFrame

    Tabs[name] = {button = tabBtn, content = contentFrame}

    tabBtn.MouseButton1Click:Connect(function()
        for tabName, tab in pairs(Tabs) do
            tab.content.Visible = false
            tab.button.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            tab.button.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        contentFrame.Visible = true
        tabBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        ActiveTab = name
    end)

    return contentFrame
end

-- GUI Element Helpers
local function CreateToggle(parent, text, default, callback, order)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(1, 0, 0, 28)
    toggleFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    toggleFrame.BorderSizePixel = 0
    toggleFrame.LayoutOrder = order
    toggleFrame.Parent = parent

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 4)
    toggleCorner.Parent = toggleFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggleFrame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 40, 0, 20)
    toggleBtn.Position = UDim2.new(1, -48, 0.5, -10)
    toggleBtn.BackgroundColor3 = default and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(80, 80, 80)
    toggleBtn.Text = default and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 10
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Parent = toggleFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = toggleBtn

    local state = default
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(80, 80, 80)
        toggleBtn.Text = state and "ON" or "OFF"
        callback(state)
    end)

    return toggleFrame
end

local function CreateSlider(parent, text, min, max, default, callback, order)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, 0, 0, 45)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.LayoutOrder = order
    sliderFrame.Parent = parent

    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 4)
    sliderCorner.Parent = sliderFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 2)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. tostring(default)
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = sliderFrame

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -20, 0, 8)
    sliderBar.Position = UDim2.new(0, 10, 0, 28)
    sliderBar.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = sliderFrame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 4)
    barCorner.Parent = sliderBar

    local fillBar = Instance.new("Frame")
    fillBar.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fillBar.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    fillBar.BorderSizePixel = 0
    fillBar.Parent = sliderBar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = fillBar

    local dragging = false
    local function UpdateSlider(input)
        local relX = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * relX)
        fillBar.Size = UDim2.new(relX, 0, 1, 0)
        label.Text = text .. ": " .. tostring(value)
        callback(value)
    end

    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            UpdateSlider(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateSlider(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    return sliderFrame
end

local function CreateButton(parent, text, callback, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextSize = 13
    btn.Font = Enum.Font.Gotham
    btn.LayoutOrder = order
    btn.Parent = parent

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(callback)

    return btn
end

-- ═══════════════════════════════════════════════════════════════════
--  BUILD TABS
-- ═══════════════════════════════════════════════════════════════════

-- ESP Tab
local espTab = CreateTab("ESP", 1)
CreateToggle(espTab, "ESP Enable", Config.EspEnabled, function(v) Config.EspEnabled = v end, 1)
CreateToggle(espTab, "Box ESP", Config.EspBox, function(v) Config.EspBox = v end, 2)
CreateToggle(espTab, "Name ESP", Config.EspName, function(v) Config.EspName = v end, 3)
CreateToggle(espTab, "Health ESP", Config.EspHealth, function(v) Config.EspHealth = v end, 4)
CreateToggle(espTab, "Distance ESP", Config.EspDistance, function(v) Config.EspDistance = v end, 5)
CreateToggle(espTab, "Tracers", Config.EspTracers, function(v) Config.EspTracers = v end, 6)
CreateToggle(espTab, "Snaplines", Config.EspSnaplines, function(v) Config.EspSnaplines = v end, 7)
CreateToggle(espTab, "Team Check", Config.EspTeamCheck, function(v) Config.EspTeamCheck = v end, 8)

-- Aimbot Tab
local aimTab = CreateTab("Aimbot", 2)
CreateToggle(aimTab, "Aimbot Enable", Config.AimbotEnabled, function(v) Config.AimbotEnabled = v end, 1)
CreateToggle(aimTab, "Show FOV Circle", Config.AimbotShowFOV, function(v) Config.AimbotShowFOV = v end, 2)
CreateToggle(aimTab, "Team Check", Config.AimbotTeamCheck, function(v) Config.AimbotTeamCheck = v end, 3)
CreateSlider(aimTab, "FOV Size", 20, 500, Config.AimbotFOV, function(v) Config.AimbotFOV = v end, 4)
CreateSlider(aimTab, "Smoothness", 0, 100, Config.AimbotSmoothness * 100, function(v) Config.AimbotSmoothness = v / 100 end, 5)

-- Movement Tab
local moveTab = CreateTab("Movement", 3)
CreateToggle(moveTab, "Speed Hack", Config.SpeedEnabled, function(v) Config.SpeedEnabled = v if not v then UpdateSpeed() end end, 1)
CreateSlider(moveTab, "Speed Value", 16, 200, Config.SpeedValue, function(v) Config.SpeedValue = v end, 2)
CreateToggle(moveTab, "Fly", Config.FlyEnabled, function(v)
    Config.FlyEnabled = v
    if v then StartFly() else StopFly() end
end, 3)
CreateSlider(moveTab, "Fly Speed", 10, 300, Config.FlySpeed, function(v) Config.FlySpeed = v end, 4)
CreateToggle(moveTab, "Infinite Jump", Config.InfiniteJumpEnabled, function(v) Config.InfiniteJumpEnabled = v end, 5)
CreateToggle(moveTab, "NoClip", Config.NoClipEnabled, function(v) Config.NoClipEnabled = v end, 6)

-- Utility Tab
local utilTab = CreateTab("Utility", 4)
CreateToggle(utilTab, "God Mode", Config.GodModeEnabled, function(v) Config.GodModeEnabled = v end, 1)
CreateToggle(utilTab, "Anti-AFK", Config.AntiAFKEnabled, function(v) Config.AntiAFKEnabled = v end, 2)
CreateToggle(utilTab, "Click Teleport (P)", Config.ClickTeleportEnabled, function(v) Config.ClickTeleportEnabled = v end, 3)

CreateButton(utilTab, "Teleport to Spawn", function()
    local spawns = Workspace:GetChildren()
    for _, obj in ipairs(spawns) do
        if obj:IsA("SpawnLocation") then
            local char = LocalPlayer.Character
            if char then
                local rootPart = char:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    rootPart.CFrame = obj.CFrame + Vector3.new(0, 3, 0)
                end
            end
            break
        end
    end
end, 4)

CreateButton(utilTab, "Server Hop", function()
    local gameId = game.GameId
    local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. gameId .. "/servers/Public?sortOrder=Asc&limit=100"))
    for _, server in ipairs(servers.data) do
        if server.id ~= game.JobId and server.playing < server.maxPlayers then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
            break
        end
    end
end, 5)

CreateButton(utilTab, "Rejoin", function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end, 6)

CreateButton(utilTab, "Copy Game ID", function()
    if setclipboard then
        setclipboard(tostring(game.PlaceId))
    end
end, 7)

-- Player list tab
local playerTab = CreateTab("Players", 5)

local function RefreshPlayerList()
    for _, child in ipairs(playerTab:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local order = 1
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local playerFrame = Instance.new("Frame")
            playerFrame.Size = UDim2.new(1, 0, 0, 28)
            playerFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
            playerFrame.BorderSizePixel = 0
            playerFrame.LayoutOrder = order
            playerFrame.Parent = playerTab

            local pCorner = Instance.new("UICorner")
            pCorner.CornerRadius = UDim.new(0, 4)
            pCorner.Parent = playerFrame

            local pLabel = Instance.new("TextLabel")
            pLabel.Size = UDim2.new(1, -80, 1, 0)
            pLabel.Position = UDim2.new(0, 10, 0, 0)
            pLabel.BackgroundTransparency = 1
            pLabel.Text = player.DisplayName .. " (@" .. player.Name .. ")"
            pLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            pLabel.TextSize = 12
            pLabel.Font = Enum.Font.Gotham
            pLabel.TextXAlignment = Enum.TextXAlignment.Left
            pLabel.TextTruncate = Enum.TextTruncate.AtEnd
            pLabel.Parent = playerFrame

            local tpBtn = Instance.new("TextButton")
            tpBtn.Size = UDim2.new(0, 60, 0, 20)
            tpBtn.Position = UDim2.new(1, -68, 0.5, -10)
            tpBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
            tpBtn.Text = "Teleport"
            tpBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            tpBtn.TextSize = 10
            tpBtn.Font = Enum.Font.Gotham
            tpBtn.BorderSizePixel = 0
            tpBtn.Parent = playerFrame

            local tpCorner = Instance.new("UICorner")
            tpCorner.CornerRadius = UDim.new(0, 4)
            tpCorner.Parent = tpBtn

            tpBtn.MouseButton1Click:Connect(function()
                if IsAlive(player) then
                    local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if targetRoot and myRoot then
                        myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
                    end
                end
            end)

            order = order + 1
        end
    end
end

RefreshPlayerList()
Players.PlayerAdded:Connect(function() RefreshPlayerList() end)
Players.PlayerRemoving:Connect(function() RefreshPlayerList() end)

-- ═══════════════════════════════════════════════════════════════════
--  DRAGGING
-- ═══════════════════════════════════════════════════════════════════

local dragging = false
local dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Close button
CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Toggle GUI with RightShift
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- ═══════════════════════════════════════════════════════════════════
--  INPUT HANDLING
-- ═══════════════════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- Aimbot hold
    if input.UserInputType == Config.AimbotKey then
        IsAimbotHeld = true
    end

    -- Fly toggle
    if input.KeyCode == Config.FlyKey then
        Config.FlyEnabled = not Config.FlyEnabled
        if Config.FlyEnabled then StartFly() else StopFly() end
    end

    -- Fly direction
    if IsFlying then
        if input.KeyCode == Enum.KeyCode.W then FlyDirection.w = true end
        if input.KeyCode == Enum.KeyCode.A then FlyDirection.a = true end
        if input.KeyCode == Enum.KeyCode.S then FlyDirection.s = true end
        if input.KeyCode == Enum.KeyCode.D then FlyDirection.d = true end
        if input.KeyCode == Enum.KeyCode.Space then FlyDirection.space = true end
        if input.KeyCode == Enum.KeyCode.LeftShift then FlyDirection.shift = true end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Config.AimbotKey then
        IsAimbotHeld = false
    end

    if input.KeyCode == Enum.KeyCode.W then FlyDirection.w = false end
    if input.KeyCode == Enum.KeyCode.A then FlyDirection.a = false end
    if input.KeyCode == Enum.KeyCode.S then FlyDirection.s = false end
    if input.KeyCode == Enum.KeyCode.D then FlyDirection.d = false end
    if input.KeyCode == Enum.KeyCode.Space then FlyDirection.space = false end
    if input.KeyCode == Enum.KeyCode.LeftShift then FlyDirection.shift = false end
end)

-- ═══════════════════════════════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════════════════════════════

SetupInfiniteJump()
SetupNoClip()
SetupGodMode()
SetupAntiAFK()
SetupClickTeleport()

-- Cleanup ESP on player leave
Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end)

RunService.RenderStepped:Connect(function()
    UpdateESP()
    UpdateAimbot()
    UpdateSpeed()
    UpdateFly()
end)

-- Select first tab
Tabs["ESP"].button.MouseButton1Click:Fire()

-- Notification
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Universal Script",
    Text = "Loaded! Press RightShift to toggle GUI.",
    Duration = 5
})
