--[[
    ███████╗████████╗ █████╗ ██████╗ ███████╗██████╗     ██████╗  █████╗ ███████╗ ██████╗
    ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██╔══██╗    ██╔══██╗██╔══██╗██╔════╝██╔════╝
    ███████╗   ██║   ███████║██████╔╝█████╗   ██████╔╝    ██████╔╝███████║███████╗██║     
    ╚════██║   ██║   ██╔══██║██╔══██╗██╔══╝   ██╔══██╗    ██╔═══╝ ██╔══██║╚════██║██║     
    ███████║   ██║   ██║  ██║██║  ██║███████╗██║  ██║    ██║     ██║  ██║███████║╚██████╗
    ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝    ╚═╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝

    Steal a Brainrot Script
    Desync / God Mode / Hitbox Expander / No Ragdoll
    Press End to toggle GUI
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ═══════════════════════════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════════════════════════

local Config = {
    -- Desync
    DesyncEnabled = false,
    DesyncStrength = 5,
    DesyncHolePunch = false,
    DesyncSpin = false,
    DesyncSpinSpeed = 15,

    -- God Mode
    GodModeEnabled = false,
    GodModeMethod = "health", -- "health", "state", "both"

    -- Hitbox Expander
    HitboxEnabled = false,
    HitboxSize = 15,
    HitboxTransparency = 0.7,
    HitboxESP = false,
    HitboxColor = Color3.fromRGB(255, 0, 255),
    HitboxPart = "HumanoidRootPart",
    HitboxTeamCheck = false,

    -- No Ragdoll
    NoRagdollEnabled = false,

    -- ESP
    EspEnabled = false,
    EspBox = true,
    EspName = true,
    EspHealth = true,
    EspDistance = true,
    EspTracers = false,
    EspTeamCheck = false,
    EspEnemyColor = Color3.fromRGB(255, 0, 255),
    EspTeamColor = Color3.fromRGB(0, 255, 128),

    -- Aimbot
    AimbotEnabled = false,
    AimbotFOV = 120,
    AimbotSmoothness = 0.4,
    AimbotKey = Enum.UserInputType.MouseButton2,
    AimbotPart = "Head",
    AimbotTeamCheck = false,
    AimbotShowFOV = true,
    AimbotFOVColor = Color3.fromRGB(255, 0, 255),

    -- Steal
    AutoStealEnabled = false,
    StealRange = 30,
}

-- ═══════════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════════

local ESPObjects = {}
local IsAimbotHeld = false
local HitboxHighlights = {}
local OriginalHitboxSizes = {}
local DesyncVelocity = nil
local DesyncPositionOffset = Vector3.new(0, 0, 0)
local DesyncAngle = 0
local RagdollConnections = {}

-- ═══════════════════════════════════════════════════════════════════
--  UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

local function FindRootPart(char)
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then return root end
    root = char:FindFirstChild("Torso")
    if root then return root end
    root = char:FindFirstChild("UpperTorso")
    if root then return root end
    root = char:FindFirstChild("Body")
    if root then return root end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            return part
        end
    end
    return nil
end

local function FindHeadPart(char)
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head end
    head = char:FindFirstChild("head")
    if head and head:IsA("BasePart") then return head end
    local highest = nil
    local highestY = -math.huge
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Position.Y > highestY then
            highestY = part.Position.Y
            highest = part
        end
    end
    return highest
end

local function FindHitboxPart(char)
    if not char then return nil end
    local part = char:FindFirstChild(Config.HitboxPart)
    if part and part:IsA("BasePart") then return part end
    part = char:FindFirstChild("HumanoidRootPart")
    if part and part:IsA("BasePart") then return part end
    part = char:FindFirstChild("Head")
    if part and part:IsA("BasePart") then return part end
    part = char:FindFirstChild("Torso")
    if part and part:IsA("BasePart") then return part end
    part = char:FindFirstChild("UpperTorso")
    if part and part:IsA("BasePart") then return part end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            return p
        end
    end
    return nil
end

local function IsAlive(player)
    local char = player.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    return humanoid.Health > 0
end

local function IsTeammate(player)
    if not Config.EspTeamCheck and not Config.AimbotTeamCheck and not Config.HitboxTeamCheck then return false end
    if LocalPlayer.Team == nil or player.Team == nil then return false end
    return LocalPlayer.Team == player.Team
end

local function WorldToScreen(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function GetClosestTarget()
    local closest = nil
    local closestPart = nil
    local shortestDist = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            if Config.AimbotTeamCheck and IsTeammate(player) then continue end
            local char = player.Character
            local part = char:FindFirstChild(Config.AimbotPart)
            if not part or not part:IsA("BasePart") then part = FindHeadPart(char) end
            if part then
                local screenPos, onScreen = WorldToScreen(part.Position)
                if onScreen then
                    local mousePos = UserInputService:GetMouseLocation()
                    local dist = (screenPos - mousePos).Magnitude
                    if dist < Config.AimbotFOV and dist < shortestDist then
                        shortestDist = dist
                        closest = player
                        closestPart = part
                    end
                end
            end
        end
    end
    return closest, closestPart
end

-- ═══════════════════════════════════════════════════════════════════
--  DESYNC SYSTEM
--  Creates a position desync between client and server
--  Other players see you in one spot while you're actually elsewhere
-- ═══════════════════════════════════════════════════════════════════

local function SetupDesync()
    if DesyncVelocity then
        DesyncVelocity:Destroy()
        DesyncVelocity = nil
    end

    if not Config.DesyncEnabled then return end

    local char = LocalPlayer.Character
    if not char then return end
    local rootPart = FindRootPart(char)
    if not rootPart then return end

    -- BodyVelocity that cancels server-side physics replication
    DesyncVelocity = Instance.new("BodyVelocity")
    DesyncVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    DesyncVelocity.Velocity = Vector3.new(0, 0, 0)
    DesyncVelocity.Parent = rootPart

    -- Set network ownership to nil so server doesn't replicate
    pcall(function()
        rootPart:SetNetworkOwner(nil)
    end)
end

local function UpdateDesync()
    if not Config.DesyncEnabled then
        if DesyncVelocity then
            DesyncVelocity:Destroy()
            DesyncVelocity = nil
        end
        return
    end

    local char = LocalPlayer.Character
    if not char then return end
    local rootPart = FindRootPart(char)
    if not rootPart then return end

    -- Ensure BodyVelocity exists
    if not DesyncVelocity or DesyncVelocity.Parent ~= rootPart then
        SetupDesync()
    end

    -- Hole punch: periodically reset velocity to 0 to prevent server correction
    if Config.DesyncHolePunch then
        pcall(function()
            if DesyncVelocity then
                DesyncVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end)
    end

    -- Spin desync: rotate the root part rapidly to confuse other players
    if Config.DesyncSpin then
        DesyncAngle = DesyncAngle + (Config.DesyncSpinSpeed / 10)
        pcall(function()
            rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(Config.DesyncSpinSpeed), 0)
        end)
    end

    -- Apply desync offset (pushes your position on client away from server)
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.MoveDirection.Magnitude > 0 then
        local moveDir = humanoid.MoveDirection.Unit * Config.DesyncStrength
        pcall(function()
            if DesyncVelocity then
                DesyncVelocity.Velocity = Vector3.new(moveDir.X, 0, moveDir.Z)
            end
        end)
    else
        pcall(function()
            if DesyncVelocity then
                DesyncVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════
--  GOD MODE
-- ═══════════════════════════════════════════════════════════════════

local function UpdateGodMode()
    if not Config.GodModeEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if Config.GodModeMethod == "health" or Config.GodModeMethod == "both" then
        humanoid.Health = humanoid.MaxHealth
    end

    if Config.GodModeMethod == "state" or Config.GodModeMethod == "both" then
        -- Force the humanoid into a state where it can't take damage
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
        -- Remove any damage-related state changes
        for _, conn in ipairs(humanoid:GetChildren()) do
            if conn:IsA("StringValue") and conn.Name == "ragdoll" then
                conn:Destroy()
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════
--  HITBOX EXPANDER
-- ═══════════════════════════════════════════════════════════════════

local function ApplyHitboxToCharacter(char, key)
    if not char or not char.Parent then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        if HitboxHighlights[key] then
            HitboxHighlights[key]:Destroy()
            HitboxHighlights[key] = nil
        end
        if OriginalHitboxSizes[key] then
            OriginalHitboxSizes[key] = nil
        end
        return
    end

    local part = FindHitboxPart(char)
    if not part then return end

    if Config.HitboxEnabled then
        if not OriginalHitboxSizes[key] then
            OriginalHitboxSizes[key] = part.Size
        end
        pcall(function()
            part.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
            part.Transparency = Config.HitboxTransparency
            part.CanCollide = false
            part.Massless = true
        end)
    else
        if OriginalHitboxSizes[key] then
            pcall(function()
                part.Size = OriginalHitboxSizes[key]
                part.Transparency = 0
            end)
            OriginalHitboxSizes[key] = nil
        end
    end

    -- Hitbox ESP (Highlight)
    if Config.HitboxESP and Config.HitboxEnabled then
        if not HitboxHighlights[key] or HitboxHighlights[key].Parent ~= char then
            if HitboxHighlights[key] then
                HitboxHighlights[key]:Destroy()
            end
            local highlight = Instance.new("Highlight")
            highlight.Name = "HitboxHighlight"
            highlight.FillColor = Config.HitboxColor
            highlight.OutlineColor = Config.HitboxColor
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = char
            HitboxHighlights[key] = highlight
        else
            HitboxHighlights[key].FillColor = Config.HitboxColor
            HitboxHighlights[key].OutlineColor = Config.HitboxColor
        end
    else
        if HitboxHighlights[key] then
            HitboxHighlights[key]:Destroy()
            HitboxHighlights[key] = nil
        end
    end
end

local function UpdateHitbox()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.HitboxTeamCheck and IsTeammate(player) then continue end
        local char = player.Character
        ApplyHitboxToCharacter(char, player)
    end
end

local function CleanupHitbox()
    for key, highlight in pairs(HitboxHighlights) do
        if highlight then highlight:Destroy() end
    end
    HitboxHighlights = {}

    for key, originalSize in pairs(OriginalHitboxSizes) do
        local char = nil
        if type(key) == "userdata" and key.IsA then
            char = key.Character
        end
        if char then
            local part = FindHitboxPart(char)
            if part then
                pcall(function()
                    part.Size = originalSize
                    part.Transparency = 0
                end)
            end
        end
    end
    OriginalHitboxSizes = {}
end

-- ═══════════════════════════════════════════════════════════════════
--  NO RAGDOLL
--  Prevents the character from entering ragdoll state
--  Works by intercepting ragdoll-related events and state changes
-- ═══════════════════════════════════════════════════════════════════

local function DisableRagdollForCharacter(char)
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- Prevent ragdoll state
    humanoid.StateChanged:Connect(function(_, newState)
        if Config.NoRagdollEnabled then
            if newState == Enum.HumanoidStateType.FallingDown
                or newState == Enum.HumanoidStateType.Ragdoll
                or newState == Enum.HumanoidStateType.PlatformStanding
                or newState == Enum.HumanoidStateType.Swimming then
                pcall(function()
                    humanoid:ChangeState(Enum.HumanoidStateType.Running)
                end)
            end
        end
    end)

    -- Destroy ragdoll-related objects
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BoolValue") and (obj.Name == "Ragdoll" or obj.Name == "ragdoll" or obj.Name == "IsRagdoll") then
            obj:Destroy()
        end
        if obj:IsA("StringValue") and (obj.Name == "Ragdoll" or obj.Name == "ragdoll") then
            obj:Destroy()
        end
        -- Disable ragdoll ball socket constraints
        if obj:IsA("BallSocketConstraint") or obj:IsA("HingeConstraint") then
            if obj.Name:lower():find("ragdoll") then
                obj:Destroy()
            end
        end
    end

    -- Keep getting up
    spawn(function()
        while Config.NoRagdollEnabled and char and char.Parent do
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local state = hum:GetState()
                if state == Enum.HumanoidStateType.FallingDown
                    or state == Enum.HumanoidStateType.Ragdoll
                    or state == Enum.HumanoidStateType.PlatformStanding then
                    pcall(function()
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end)
                end
            end
            wait(0.1)
        end
    end)
end

local function SetupNoRagdoll()
    local char = LocalPlayer.Character
    if char then
        DisableRagdollForCharacter(char)
    end

    LocalPlayer.CharacterAdded:Connect(function(newChar)
        if Config.NoRagdollEnabled then
            newChar:WaitForChild("Humanoid")
            DisableRagdollForCharacter(newChar)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════
--  ESP SYSTEM
-- ═══════════════════════════════════════════════════════════════════

local function CreateESP(player)
    if ESPObjects[player] then return end
    local objects = {}

    local box = Drawing.new("Square")
    box.Thickness = 1.5
    box.Filled = false
    box.Transparency = 1
    box.Visible = false
    objects.Box = box

    local name = Drawing.new("Text")
    name.Center = true
    name.Outline = true
    name.OutlineColor = Color3.fromRGB(0, 0, 0)
    name.Size = 13
    name.Font = 2
    name.Visible = false
    objects.Name = name

    local healthText = Drawing.new("Text")
    healthText.Center = true
    healthText.Outline = true
    healthText.OutlineColor = Color3.fromRGB(0, 0, 0)
    healthText.Size = 13
    healthText.Font = 2
    healthText.Visible = false
    objects.Health = healthText

    local distText = Drawing.new("Text")
    distText.Center = true
    distText.Outline = true
    distText.OutlineColor = Color3.fromRGB(0, 0, 0)
    distText.Size = 13
    distText.Font = 2
    distText.Visible = false
    objects.Distance = distText

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Transparency = 1
    tracer.Visible = false
    objects.Tracer = tracer

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
        local rootPart = FindRootPart(char)
        local head = FindHeadPart(char)

        if not rootPart then
            for _, obj in pairs(objects) do
                if obj.Visible ~= nil then obj.Visible = false end
            end
            continue
        end

        local teamCheck = Config.EspTeamCheck and IsTeammate(player)
        local espColor = teamCheck and Config.EspTeamColor or Config.EspEnemyColor

        local rootPos, rootOnScreen = WorldToScreen(rootPart.Position)
        local headPos, headOnScreen
        if head and head:IsA("BasePart") then
            headPos, headOnScreen = WorldToScreen(head.Position + Vector3.new(0, 0.5, 0))
        else
            headPos = rootPos
            headOnScreen = rootOnScreen
        end
        local legPos = WorldToScreen(rootPart.Position - Vector3.new(0, 3, 0))

        if not rootOnScreen then
            for _, obj in pairs(objects) do
                if obj.Visible ~= nil then obj.Visible = false end
            end
            continue
        end

        if Config.EspEnabled then
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

            if Config.EspName then
                objects.Name.Position = Vector2.new(rootPos.X, headPos.Y - 16)
                objects.Name.Text = player.DisplayName
                objects.Name.Color = espColor
                objects.Name.Visible = true
            else
                objects.Name.Visible = false
            end

            if Config.EspHealth and humanoid then
                local health = humanoid.Health
                local maxHealth = humanoid.MaxHealth
                local pct = math.clamp(health / maxHealth, 0, 1)
                objects.Health.Position = Vector2.new(rootPos.X, legPos.Y + 2)
                objects.Health.Text = string.format("[%d/%d]", math.floor(health), math.floor(maxHealth))
                objects.Health.Color = Color3.new(1 - pct, pct, 0)
                objects.Health.Visible = true

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

            if Config.EspDistance and rootPart then
                local dist = math.floor((Camera.CFrame.Position - rootPart.Position).Magnitude)
                objects.Distance.Position = Vector2.new(rootPos.X, legPos.Y + 14)
                objects.Distance.Text = dist .. "m"
                objects.Distance.Color = espColor
                objects.Distance.Visible = true
            else
                objects.Distance.Visible = false
            end

            if Config.EspTracers then
                local viewportSize = Camera.ViewportSize
                objects.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
                objects.Tracer.To = Vector2.new(rootPos.X, legPos.Y)
                objects.Tracer.Color = espColor
                objects.Tracer.Visible = true
            else
                objects.Tracer.Visible = false
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
        local target, targetPart = GetClosestTarget()
        if target and targetPart then
            local targetPos = targetPart.Position
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

-- ═══════════════════════════════════════════════════════════════════
--  AUTO STEAL
--  Automatically walks toward the nearest brainrot item to steal it
-- ═══════════════════════════════════════════════════════════════════

local function FindNearestBrainrot()
    local closest = nil
    local shortestDist = math.huge
    local char = LocalPlayer.Character
    if not char then return nil end
    local rootPart = FindRootPart(char)
    if not rootPart then return nil end

    -- Search workspace for brainrot items
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = obj.Name:lower()
            if name:find("brainrot") or name:find("brain_rot") or name:find("steal")
                or name:find("item") or name:find("collect") or name:find("pickup")
                or name:find("loot") or name:find("gem") or name:find("coin")
                or name:find("money") or name:find("cash") then

                local part = obj:IsA("BasePart") and obj or (obj:IsA("Model") and obj:FindFirstChildWhichIsA("BasePart"))
                if part then
                    local dist = (part.Position - rootPart.Position).Magnitude
                    if dist < Config.StealRange and dist < shortestDist then
                        shortestDist = dist
                        closest = part
                    end
                end
            end
        end
    end

    return closest
end

local function UpdateAutoSteal()
    if not Config.AutoStealEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local rootPart = FindRootPart(char)
    if not rootPart then return end

    local target = FindNearestBrainrot()
    if target then
        pcall(function()
            rootPart.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════
--  GUI SYSTEM
-- ═══════════════════════════════════════════════════════════════════

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BrainrotScript"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if syn then
    syn.protect_gui(ScreenGui)
end

ScreenGui.Parent = game:GetService("CoreGui")

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 460, 0, 360)
MainFrame.Position = UDim2.new(0.5, -230, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 6)
MainCorner.Parent = MainFrame

-- Accent border
local AccentFrame = Instance.new("Frame")
AccentFrame.Size = UDim2.new(1, 0, 0, 2)
AccentFrame.Position = UDim2.new(0, 0, 0, 30)
AccentFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
AccentFrame.BorderSizePixel = 0
AccentFrame.Parent = MainFrame

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 6)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -30, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "STEAL A BRAINROT"
TitleLabel.TextColor3 = Color3.fromRGB(255, 0, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

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
TabContainer.Size = UDim2.new(1, 0, 0, 25)
TabContainer.Position = UDim2.new(0, 0, 0, 32)
TabContainer.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
TabContainer.BorderSizePixel = 0
TabContainer.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 2)
TabLayout.Parent = TabContainer

-- Content Container
local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, 0, 1, -57)
ContentContainer.Position = UDim2.new(0, 0, 0, 57)
ContentContainer.BackgroundTransparency = 1
ContentContainer.BorderSizePixel = 0
ContentContainer.ClipsDescendants = true
ContentContainer.Parent = MainFrame

local Tabs = {}
local ActiveTab = nil

local function CreateTab(name, order)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0, 80, 0, 25)
    tabBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    tabBtn.BorderSizePixel = 0
    tabBtn.Text = name
    tabBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    tabBtn.TextSize = 11
    tabBtn.Font = Enum.Font.Gotham
    tabBtn.LayoutOrder = order
    tabBtn.Parent = TabContainer

    local contentFrame = Instance.new("ScrollingFrame")
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
            tab.button.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
            tab.button.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        contentFrame.Visible = true
        tabBtn.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
        tabBtn.TextColor3 = Color3.fromRGB(255, 0, 255)
        ActiveTab = name
    end)

    return contentFrame
end

-- GUI Element Helpers
local function CreateToggle(parent, text, default, callback, order)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(1, 0, 0, 28)
    toggleFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
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
    toggleBtn.BackgroundColor3 = default and Color3.fromRGB(255, 0, 255) or Color3.fromRGB(60, 60, 65)
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
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(255, 0, 255) or Color3.fromRGB(60, 60, 65)
        toggleBtn.Text = state and "ON" or "OFF"
        callback(state)
    end)

    return toggleFrame
end

local function CreateSlider(parent, text, min, max, default, callback, order)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, 0, 0, 45)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
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
    sliderBar.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = sliderFrame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 4)
    barCorner.Parent = sliderBar

    local fillBar = Instance.new("Frame")
    fillBar.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fillBar.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
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
    btn.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
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

-- Desync Tab
local desyncTab = CreateTab("Desync", 1)
CreateToggle(desyncTab, "Desync Enable", Config.DesyncEnabled, function(v)
    Config.DesyncEnabled = v
    if v then SetupDesync() end
end, 1)
CreateToggle(desyncTab, "Hole Punch", Config.DesyncHolePunch, function(v) Config.DesyncHolePunch = v end, 2)
CreateToggle(desyncTab, "Spin Desync", Config.DesyncSpin, function(v) Config.DesyncSpin = v end, 3)
CreateSlider(desyncTab, "Desync Strength", 1, 30, Config.DesyncStrength, function(v) Config.DesyncStrength = v end, 4)
CreateSlider(desyncTab, "Spin Speed", 1, 50, Config.DesyncSpinSpeed, function(v) Config.DesyncSpinSpeed = v end, 5)

CreateButton(desyncTab, "Full Desync (All On)", function()
    Config.DesyncEnabled = true
    Config.DesyncHolePunch = true
    Config.DesyncSpin = true
    SetupDesync()
end, 6)

CreateButton(desyncTab, "Reset Desync (All Off)", function()
    Config.DesyncEnabled = false
    Config.DesyncHolePunch = false
    Config.DesyncSpin = false
    if DesyncVelocity then
        DesyncVelocity:Destroy()
        DesyncVelocity = nil
    end
end, 7)

-- Combat Tab
local combatTab = CreateTab("Combat", 2)
CreateToggle(combatTab, "God Mode", Config.GodModeEnabled, function(v) Config.GodModeEnabled = v end, 1)
CreateToggle(combatTab, "No Ragdoll", Config.NoRagdollEnabled, function(v)
    Config.NoRagdollEnabled = v
    if v then SetupNoRagdoll() end
end, 2)
CreateToggle(combatTab, "Auto Steal", Config.AutoStealEnabled, function(v) Config.AutoStealEnabled = v end, 3)
CreateSlider(combatTab, "Steal Range", 5, 100, Config.StealRange, function(v) Config.StealRange = v end, 4)

-- Hitbox Tab
local hitboxTab = CreateTab("Hitbox", 3)
CreateToggle(hitboxTab, "Hitbox Expander", Config.HitboxEnabled, function(v)
    Config.HitboxEnabled = v
    if not v then CleanupHitbox() end
end, 1)
CreateToggle(hitboxTab, "Hitbox ESP", Config.HitboxESP, function(v) Config.HitboxESP = v end, 2)
CreateToggle(hitboxTab, "Team Check", Config.HitboxTeamCheck, function(v) Config.HitboxTeamCheck = v end, 3)
CreateSlider(hitboxTab, "Hitbox Size", 1, 50, Config.HitboxSize, function(v) Config.HitboxSize = v end, 4)
CreateSlider(hitboxTab, "Transparency", 0, 100, Config.HitboxTransparency * 100, function(v) Config.HitboxTransparency = v / 100 end, 5)

-- ESP Tab
local espTab = CreateTab("ESP", 4)
CreateToggle(espTab, "ESP Enable", Config.EspEnabled, function(v) Config.EspEnabled = v end, 1)
CreateToggle(espTab, "Box ESP", Config.EspBox, function(v) Config.EspBox = v end, 2)
CreateToggle(espTab, "Name ESP", Config.EspName, function(v) Config.EspName = v end, 3)
CreateToggle(espTab, "Health ESP", Config.EspHealth, function(v) Config.EspHealth = v end, 4)
CreateToggle(espTab, "Distance ESP", Config.EspDistance, function(v) Config.EspDistance = v end, 5)
CreateToggle(espTab, "Tracers", Config.EspTracers, function(v) Config.EspTracers = v end, 6)
CreateToggle(espTab, "Team Check", Config.EspTeamCheck, function(v) Config.EspTeamCheck = v end, 7)

-- Aimbot Tab
local aimTab = CreateTab("Aimbot", 5)
CreateToggle(aimTab, "Aimbot Enable", Config.AimbotEnabled, function(v) Config.AimbotEnabled = v end, 1)
CreateToggle(aimTab, "Show FOV Circle", Config.AimbotShowFOV, function(v) Config.AimbotShowFOV = v end, 2)
CreateToggle(aimTab, "Team Check", Config.AimbotTeamCheck, function(v) Config.AimbotTeamCheck = v end, 3)
CreateSlider(aimTab, "FOV Size", 20, 500, Config.AimbotFOV, function(v) Config.AimbotFOV = v end, 4)
CreateSlider(aimTab, "Smoothness", 0, 100, Config.AimbotSmoothness * 100, function(v) Config.AimbotSmoothness = v / 100 end, 5)

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

-- Toggle GUI with End key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.End then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- ═══════════════════════════════════════════════════════════════════
--  INPUT HANDLING
-- ═══════════════════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Config.AimbotKey then
        IsAimbotHeld = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Config.AimbotKey then
        IsAimbotHeld = false
    end
end)

-- ═══════════════════════════════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════════════════════════════

-- Cleanup ESP on player leave
Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    if HitboxHighlights[player] then
        HitboxHighlights[player]:Destroy()
        HitboxHighlights[player] = nil
    end
    OriginalHitboxSizes[player] = nil
end)

-- Character added handler for no ragdoll
LocalPlayer.CharacterAdded:Connect(function(char)
    if Config.NoRagdollEnabled then
        char:WaitForChild("Humanoid")
        DisableRagdollForCharacter(char)
    end
end)

RunService.RenderStepped:Connect(function()
    pcall(UpdateDesync)
    pcall(UpdateGodMode)
    pcall(UpdateHitbox)
    pcall(UpdateESP)
    pcall(UpdateAimbot)
    pcall(UpdateAutoSteal)
end)

-- Select first tab
Tabs["Desync"].button.MouseButton1Click:Fire()

-- Notification
StarterGui:SetCore("SendNotification", {
    Title = "Steal a Brainrot",
    Text = "Loaded! Press End to toggle GUI.",
    Duration = 5
})
