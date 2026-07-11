local repo = 'https://raw.githubusercontent.com/deividcomsono/Obsidian/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

Library.ShowToggleFrameInKeybinds = true
Library.ShowCustomCursor = true
Library.NotifySide = "Right"

local Window = Library:CreateWindow({
    Title = ' 流浪生存 | NOLSAKEN',
    Footer = "NOLSAKEN Team",
    Center = true,
    AutoShow = true,
    Resizable = true,
    ShowCustomCursor = true,
    NotifySide = "Right",
    TabPadding = 8,
    MenuFadeTime = 0
})

local Tabs = {
    Main = Window:AddTab('杀戮','house'),
    Esp = Window:AddTab('绘制','eye'),
    ["UI Settings"] = Window:AddTab('UI 调试', 'settings')
}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DebrisService = game:GetService("Debris")

local GunEvent = RepStorage:WaitForChild("Events"):WaitForChild("EventsReplication"):WaitForChild("CommunicateGun")

getgenv().RageSettings = {
    MasterSwitch = false,
    Interval = 0.01,
    TargetBone = "Head",
    Silent = true,
    IgnoreTeam = true,
    Prediction = 0.13,
    WallCheck = true
}

local RageSettings = getgenv().RageSettings
local VelCache = {}
local lastShot = 0
local reloaded = false

local function doReload()
    pcall(function()
        GunEvent:FireServer("Reload")
        reloaded = true
    end)
end

local function createTrail(origin, targetPos)
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.2, 0.2, 0.2)
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.CFrame = CFrame.new(origin)
    part.Parent = Workspace

    local att0 = Instance.new("Attachment", part)
    local att1 = Instance.new("Attachment", Workspace.Terrain)
    att1.WorldPosition = targetPos

    local beam = Instance.new("Beam", part)
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    beam.Color = ColorSequence.new(Color3.fromRGB(0, 170, 255))
    beam.Width0 = 0.3
    beam.Width1 = 0.3
    beam.FaceCamera = true
    beam.LightEmission = 1

    DebrisService:AddItem(part, 0.2)
end

local function playFireSound()
    local snd = Instance.new("Sound")
    snd.SoundId = "rbxassetid://9116483270"
    snd.Volume = 1
    snd.Parent = Workspace
    snd.PlayOnRemove = true
    snd:Destroy()
end

local function getPredictedPos(plr, bonePart)
    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not bonePart or not root then return nil end

    local vel = root.Velocity
    local prevVel = VelCache[plr]
    VelCache[plr] = vel

    if prevVel then
        local accel = (vel - prevVel) / 0.01
        return bonePart.Position + vel * RageSettings.Prediction + accel * (RageSettings.Prediction ^ 2) / 2
    else
        return bonePart.Position + vel * RageSettings.Prediction
    end
end

local function getClosestTarget()
    local myChar = LocalPlayer.Character
    if not myChar then return nil, nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil, nil end
    local myPos = myRoot.Position

    local closestPlr, closestBone, closestDist = nil, nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local hum = char:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        if RageSettings.IgnoreTeam and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
            continue
        end

        local bone = char:FindFirstChild(RageSettings.TargetBone) or char:FindFirstChild("HumanoidRootPart")
        if not bone then continue end

        local dist = (bone.Position - myPos).Magnitude
        if dist < closestDist then
            closestDist = dist
            closestPlr = plr
            closestBone = bone
        end
    end
    return closestPlr, closestBone
end

local function isWallBetween(origin, targetPos, ignoreList)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = ignoreList or {}
    local direction = (targetPos - origin).Unit * (targetPos - origin).Magnitude
    local result = Workspace:Raycast(origin, direction, rayParams)
    return result ~= nil
end

local function doShot(plr, hitPos, hitPart)
    if not reloaded then
        doReload()
        return
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local fireOrigin = root.Position + Vector3.new(0, 1.5, 0)

    if RageSettings.WallCheck then
        local ignoreList = {char, plr.Character}
        if isWallBetween(fireOrigin, hitPos, ignoreList) then
            return
        end
    end

    local dir = (hitPos - fireOrigin).Unit
    local oldCFrame = RageSettings.Silent and root.CFrame or nil

    if RageSettings.Silent then
        root.CFrame = CFrame.new(root.Position, hitPos)
    end

    local bulletId = tostring(tick()) .. "|1"
    local stackTrace = "ReplicatedStorage.Modules.Client.Behaviours.BehaviourGunClient:27\n"
    local hitStackTrace = "ReplicatedStorage.Modules.Client.Behaviours.BehaviourGunClient.ProjectileEnvConstructors.Projectile:27\n"

    pcall(function()
        GunEvent:FireServer("Fired",
            fireOrigin,
            dir,
            hitPos,
            {{bulletId, dir}},
            stackTrace
        )

        if not hitPart then
            hitPart = plr.Character and (plr.Character:FindFirstChild(RageSettings.TargetBone) or plr.Character:FindFirstChild("Head"))
        end

        if hitPart then
            GunEvent:FireServer("Hit",
                bulletId,
                hitPart,
                hitPos,
                hitStackTrace,
                {sz = hitPart.Size}
            )
        end

        reloaded = false
    end)

    if oldCFrame then
        root.CFrame = oldCFrame
    end

    createTrail(fireOrigin, hitPos)
    playFireSound()
end

RunService.Heartbeat:Connect(function()
    if not RageSettings.MasterSwitch then return end

    local now = tick()
    if now - lastShot < RageSettings.Interval then return end

    local targetPlr, targetBone = getClosestTarget()
    if not targetPlr or not targetBone then return end

    local predPos = getPredictedPos(targetPlr, targetBone)
    if predPos then
        doShot(targetPlr, predPos, targetBone)
        lastShot = now
    end
end)

getgenv().ESPSettings = {
    Enabled = false,
    Box = true,
    Name = true,
    HealthBar = true,
    Distance = true,
    Tracer = true,
    TracerR = 255, TracerG = 255, TracerB = 255,
    Transparency = 0.7,
    Thickness = 2
}

local ESP_Players = {}

local function clearESP(esp)
    if esp.Box then esp.Box:Remove() end
    if esp.Name then esp.Name:Remove() end
    if esp.HealthBar then esp.HealthBar:Remove() end
    if esp.Distance then esp.Distance:Remove() end
    if esp.Tracer then esp.Tracer:Remove() end
end

local function UpdateESP()
    for _, esp in pairs(ESP_Players) do clearESP(esp) end
    table.clear(ESP_Players)
    if not getgenv().ESPSettings.Enabled then return end

    local settings = getgenv().ESPSettings
    local function createESP(player)
        local esp = {}
        if settings.Box then
            esp.Box = Drawing.new("Square")
            esp.Box.Color = Color3.fromRGB(255,0,0)
            esp.Box.Thickness = settings.Thickness
            esp.Box.Filled = false
            esp.Box.Transparency = 1 - settings.Transparency
        end
        if settings.Name then
            esp.Name = Drawing.new("Text")
            esp.Name.Color = Color3.fromRGB(settings.TracerR, settings.TracerG, settings.TracerB)
            esp.Name.Size = 14; esp.Name.Center = true; esp.Name.Outline = true
            esp.Name.Transparency = 1 - settings.Transparency
        end
        if settings.HealthBar then
            esp.HealthBar = Drawing.new("Line")
            esp.HealthBar.Color = Color3.fromRGB(0,255,0)
            esp.HealthBar.Thickness = 2
            esp.HealthBar.Transparency = 1 - settings.Transparency
        end
        if settings.Distance then
            esp.Distance = Drawing.new("Text")
            esp.Distance.Color = Color3.fromRGB(settings.TracerR, settings.TracerG, settings.TracerB)
            esp.Distance.Size = 13; esp.Distance.Center = true; esp.Distance.Outline = true
            esp.Distance.Transparency = 1 - settings.Transparency
        end
        if settings.Tracer then
            esp.Tracer = Drawing.new("Line")
            esp.Tracer.Color = Color3.fromRGB(settings.TracerR, settings.TracerG, settings.TracerB)
            esp.Tracer.Thickness = settings.Thickness
            esp.Tracer.Transparency = 1 - settings.Transparency
        end
        return esp
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            ESP_Players[plr] = createESP(plr)
        end
    end
    Players.PlayerAdded:Connect(function(plr)
        if plr ~= LocalPlayer and not ESP_Players[plr] then
            ESP_Players[plr] = createESP(plr)
        end
    end)
    Players.PlayerRemoving:Connect(function(plr)
        local esp = ESP_Players[plr]
        if esp then clearESP(esp); ESP_Players[plr] = nil end
    end)
end

RunService.RenderStepped:Connect(function()
    local settings = getgenv().ESPSettings
    if not settings.Enabled then return end
    local camera = Camera
    local screenSize = camera.ViewportSize
    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")

    for plr, esp in pairs(ESP_Players) do
        local char = plr.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
            local root = char.HumanoidRootPart
            local head = char:FindFirstChild("Head")
            if not head then
                if esp.Box then esp.Box.Visible = false end
                if esp.Name then esp.Name.Visible = false end
                if esp.HealthBar then esp.HealthBar.Visible = false end
                if esp.Distance then esp.Distance.Visible = false end
                if esp.Tracer then esp.Tracer.Visible = false end
                continue
            end

            local humanoid = char:FindFirstChildOfClass("Humanoid")
            local topWorldPos = head.Position + Vector3.new(0, 0.5, 0)
            local bottomWorldPos
            if humanoid then
                bottomWorldPos = root.Position - Vector3.new(0, humanoid.HipHeight, 0)
            else
                bottomWorldPos = root.Position - Vector3.new(0, 3, 0)
            end

            local topScreenPos, topOnScreen = camera:WorldToScreenPoint(topWorldPos)
            local bottomScreenPos, bottomOnScreen = camera:WorldToScreenPoint(bottomWorldPos)
            local rootScreenPos, rootOnScreen = camera:WorldToScreenPoint(root.Position)

            if not topOnScreen and not bottomOnScreen and not rootOnScreen then
                if esp.Box then esp.Box.Visible = false end
                if esp.Name then esp.Name.Visible = false end
                if esp.HealthBar then esp.HealthBar.Visible = false end
                if esp.Distance then esp.Distance.Visible = false end
                if esp.Tracer then esp.Tracer.Visible = false end
                continue
            end

            local topY = topScreenPos.Y
            local bottomY = bottomScreenPos.Y
            local rootX = rootScreenPos.X

            if topY > bottomY then
                topY, bottomY = bottomY, topY
            end

            local height = bottomY - topY
            local width = height * 0.5
            if width < 10 then width = 10 end

            if esp.Box then
                esp.Box.Visible = true
                esp.Box.Position = Vector2.new(rootX - width/2, topY)
                esp.Box.Size = Vector2.new(width, height)
            end

            if esp.Name then
                esp.Name.Visible = true
                esp.Name.Text = plr.Name
                esp.Name.Position = Vector2.new(rootX, topY - 15)
            end

            if esp.HealthBar and humanoid then
                esp.HealthBar.Visible = true
                local healthPercent = humanoid.Health / humanoid.MaxHealth
                local barX = rootX - width/2 - 8
                local barTop = topY + height * (1 - healthPercent)
                esp.HealthBar.From = Vector2.new(barX, topY + height)
                esp.HealthBar.To = Vector2.new(barX, barTop)
                esp.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
            end

            if esp.Distance and localRoot then
                esp.Distance.Visible = true
                local dist = (root.Position - localRoot.Position).Magnitude
                esp.Distance.Text = math.floor(dist) .. "m"
                esp.Distance.Position = Vector2.new(rootX, bottomY + 5)
            end

            if esp.Tracer then
                esp.Tracer.Visible = true
                esp.Tracer.From = Vector2.new(screenSize.X / 2, screenSize.Y)
                esp.Tracer.To = Vector2.new(rootX, bottomY)
            end
        else
            if esp.Box then esp.Box.Visible = false end
            if esp.Name then esp.Name.Visible = false end
            if esp.HealthBar then esp.HealthBar.Visible = false end
            if esp.Distance then esp.Distance.Visible = false end
            if esp.Tracer then esp.Tracer.Visible = false end
        end
    end
end)

UpdateESP()

local RagebotLeft = Tabs.Main:AddLeftGroupbox("Ragebot ")
RagebotLeft:AddToggle("MasterSwitch", {
    Text = "启用 Ragebot",
    Default = false,
    Callback = function(val) RageSettings.MasterSwitch = val end
})
RagebotLeft:AddSlider("Interval", {
    Text = "射击间隔 ",
    Min = 0.001, Max = 1, Default = 0.01, Rounding = 3,
    Callback = function(v) RageSettings.Interval = v end
})
RagebotLeft:AddDropdown("TargetBone", {
    Text = "瞄准部位",
    Values = {"Head", "HumanoidRootPart", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"},
    Default = "Head",
    Callback = function(v) RageSettings.TargetBone = v end
})
RagebotLeft:AddToggle("Silent", {
    Text = "静默自瞄",
    Default = true,
    Callback = function(v) RageSettings.Silent = v end
})
RagebotLeft:AddToggle("IgnoreTeam", {
    Text = "忽略同队",
    Default = true,
    Callback = function(v) RageSettings.IgnoreTeam = v end
})
RagebotLeft:AddSlider("Prediction", {
    Text = "预判系数",
    Min = 0, Max = 0.5, Default = 0.13, Rounding = 2,
    Callback = function(v) RageSettings.Prediction = v end
})
RagebotLeft:AddToggle("WallCheck", {
    Text = "墙壁检测",
    Default = true,
    Callback = function(v) RageSettings.WallCheck = v end
})

local EspLeft = Tabs.Esp:AddLeftGroupbox("玩家 ESP")
local EspRight = Tabs.Esp:AddRightGroupbox("追踪线设置")

EspLeft:AddToggle("ESP_Enabled", {
    Text = "启用 ESP",
    Default = false,
    Callback = function(v) getgenv().ESPSettings.Enabled = v; UpdateESP() end
})
EspLeft:AddToggle("ESP_Box", {
    Text = "方框",
    Default = true,
    Callback = function(v) getgenv().ESPSettings.Box = v; UpdateESP() end
})
EspLeft:AddToggle("ESP_Name", {
    Text = "名字",
    Default = true,
    Callback = function(v) getgenv().ESPSettings.Name = v; UpdateESP() end
})
EspLeft:AddToggle("ESP_HealthBar", {
    Text = "血量条",
    Default = true,
    Callback = function(v) getgenv().ESPSettings.HealthBar = v; UpdateESP() end
})
EspLeft:AddToggle("ESP_Distance", {
    Text = "距离",
    Default = true,
    Callback = function(v) getgenv().ESPSettings.Distance = v; UpdateESP() end
})
EspLeft:AddToggle("ESP_Tracer", {
    Text = "追踪线",
    Default = true,
    Callback = function(v) getgenv().ESPSettings.Tracer = v; UpdateESP() end
})

EspRight:AddLabel("颜色 (R/G/B)")
EspRight:AddSlider("TracerR", {
    Text = "红",
    Min = 0, Max = 255, Default = 255, Rounding = 0,
    Callback = function(v) getgenv().ESPSettings.TracerR = v; UpdateESP() end
})
EspRight:AddSlider("TracerG", {
    Text = "绿",
    Min = 0, Max = 255, Default = 255, Rounding = 0,
    Callback = function(v) getgenv().ESPSettings.TracerG = v; UpdateESP() end
})
EspRight:AddSlider("TracerB", {
    Text = "蓝",
    Min = 0, Max = 255, Default = 255, Rounding = 0,
    Callback = function(v) getgenv().ESPSettings.TracerB = v; UpdateESP() end
})
EspRight:AddSlider("TracerTransparency", {
    Text = "透明度",
    Min = 0, Max = 1, Default = 0.7, Rounding = 1,
    Callback = function(v) getgenv().ESPSettings.Transparency = v; UpdateESP() end
})
EspRight:AddSlider("TracerThickness", {
    Text = "线条粗细",
    Min = 1, Max = 10, Default = 2, Rounding = 0,
    Callback = function(v) getgenv().ESPSettings.Thickness = v; UpdateESP() end
})

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Debug")
MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = Library.KeybindFrame.Visible,
    Text = "快捷菜单",
    Callback = function(v) Library.KeybindFrame.Visible = v end
})
MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "自定义光标",
    Default = true,
    Callback = function(v) Library.ShowCustomCursor = v end
})
MenuGroup:AddDropdown("NotificationSide", {
    Values = {"Left","Right"},
    Default = "Right",
    Text = "通知位置",
    Callback = function(v) Library:SetNotifySide(v) end
})
MenuGroup:AddDropdown("DPIDropdown", {
    Values = {"25%","50%","75%","100%","125%","150%","175%","200%"},
    Default = "100%",
    Text = "UI 大小",
    Callback = function(v)
        v = v:gsub("%%","")
        Library:SetDPIScale(tonumber(v))
    end
})
MenuGroup:AddDivider()
MenuGroup:AddLabel("菜单快捷键"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "菜单键位"
})
MenuGroup:AddButton("销毁 UI", function() Library:Unload() end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetFolder("MyScriptHub")
SaveManager:SetFolder("MyScriptHub/specific-game")
SaveManager:SetSubFolder("specific-place")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()

doReload()
