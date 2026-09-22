--[[ PracticeHUD (client, LocalScript). Phase 3 practice-mode overlay: damage numbers, combo counter,
	hits/sec, total damage, dummy mode buttons (Stationary/Strafing/Attacking), infinite-health toggle,
	and a reset button. Shown only while this client's MatchState attribute reads "Practice" - the
	existing ChickenCombatHUD already covers reticle/health/dash-cooldown/reduced-motion for BOTH real
	matches and practice (it keys off the camera controller's CombatFirstPerson state, which practice also
	enters), so this script only adds what practice specifically needs on top, in the same visual language
	(dark warm panels, gold accents) rather than a second competing HUD style. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Controller = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenCombatCameraController"))
local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local statsRemote = combatFolder:WaitForChild("PracticeStats")
local modeRemote = combatFolder:WaitForChild("PracticeModeRequest")
local infiniteHealthRemote = combatFolder:WaitForChild("PracticeInfiniteHealthRequest")
local resetRemote = combatFolder:WaitForChild("PracticeResetRequest")

local GOLD = Color3.fromRGB(255, 214, 96)
local PANEL = Color3.fromRGB(20, 16, 10)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PracticeHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 49
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "StatsPanel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.new(0, 16, 0, 16)
panel.Size = UDim2.fromOffset(210, 96)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.25
panel.Parent = screenGui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = GOLD
panelStroke.Thickness = 1.25
panelStroke.Transparency = 0.4
panelStroke.Parent = panel

local function statLabel(order, prefix)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -16, 0, 20)
	l.Position = UDim2.new(0, 8, 0, 6 + (order - 1) * 21)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = Color3.fromRGB(235, 230, 220)
	l.Text = prefix .. "0"
	l.Parent = panel
	return l
end

local comboLabel = statLabel(1, "Combo: ")
local lastHitLabel = statLabel(2, "Last Hit: ")
local totalLabel = statLabel(3, "Total Damage: ")
local hpsLabel = statLabel(4, "Hits/sec: ")

statsRemote.OnClientEvent:Connect(function(data)
	if not screenGui.Enabled then
		return
	end
	comboLabel.Text = ("Combo: %dx"):format(data.combo or 0)
	local showNumbers = Controller.damageNumbersEnabled ~= false
	lastHitLabel.Text = showNumbers and ("Last Hit: %d (%s)"):format(data.lastHit or 0, tostring(data.actionName or "-")) or "Last Hit: (hidden)"
	totalLabel.Text = showNumbers and ("Total Damage: %d"):format(data.totalDamage or 0) or "Total Damage: (hidden)"
	hpsLabel.Text = ("Hits/sec: %.1f"):format(data.hitsPerSecond or 0)
end)

-- controls row: mode buttons + infinite-health toggle + reset, kept small and out of the way (bottom-left)
local controls = Instance.new("Frame")
controls.Name = "Controls"
controls.AnchorPoint = Vector2.new(0, 1)
controls.Position = UDim2.new(0, 16, 1, -16)
controls.Size = UDim2.fromOffset(420, 36)
controls.BackgroundTransparency = 1
controls.Parent = screenGui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 6)
layout.Parent = controls

local function makeButton(text, width)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, 32)
	b.BackgroundColor3 = PANEL
	b.BackgroundTransparency = 0.25
	b.TextColor3 = Color3.fromRGB(230, 230, 230)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = controls
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = GOLD
	s.Transparency = 0.55
	s.Parent = b
	return b
end

local modeButtons = {}
local currentMode = "Stationary"
local function refreshModeButtons()
	for mode, btn in pairs(modeButtons) do
		btn.BackgroundTransparency = (mode == currentMode) and 0 or 0.25
	end
end
for _, mode in ipairs({ "Stationary", "Strafing", "Attacking" }) do
	local btn = makeButton(mode, 84)
	btn.MouseButton1Click:Connect(function()
		currentMode = mode
		refreshModeButtons()
		modeRemote:FireServer(mode)
	end)
	modeButtons[mode] = btn
end
refreshModeButtons()

local infiniteHealthOn = true
local infiniteBtn = makeButton("Infinite HP: On", 118)
infiniteBtn.MouseButton1Click:Connect(function()
	infiniteHealthOn = not infiniteHealthOn
	infiniteBtn.Text = "Infinite HP: " .. (infiniteHealthOn and "On" or "Off")
	infiniteHealthRemote:FireServer(infiniteHealthOn)
end)

local resetBtn = makeButton("Reset Dummy", 96)
resetBtn.MouseButton1Click:Connect(function()
	resetRemote:FireServer()
end)

player:GetAttributeChangedSignal("MatchState"):Connect(function()
	screenGui.Enabled = player:GetAttribute("MatchState") == "Practice"
end)
screenGui.Enabled = player:GetAttribute("MatchState") == "Practice"
