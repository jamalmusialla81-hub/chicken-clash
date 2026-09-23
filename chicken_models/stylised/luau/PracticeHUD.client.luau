--[[ PracticeHUD (client, LocalScript). Phase 3 practice-mode overlay: damage numbers, combo counter,
	hits/sec, total damage, dummy mode buttons (Stationary/Strafing/Attacking/Combo), infinite-health and
	damage-number toggles, and reset/clear-stats buttons. Shown only while this client's MatchState
	attribute reads "Practice" - the existing ChickenCombatHUD already covers reticle/health/dash-cooldown
	for BOTH real matches and practice (it keys off the camera controller's PracticeCombat/MatchCombat
	states), so this script only adds what practice specifically needs on top.

	Presentation-rebuild spec: one collapsible stats panel (left) with an exact row order - Last Hit, Total
	Damage, DPS, Combo, Hits per sec, Best Combo, Session - and one grouped training-controls panel,
	bottom-centre, built entirely from Theme.Button rather than bare TextButtons. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Controller = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenCombatCameraController"))
local Theme = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("Theme"))
local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local statsRemote = combatFolder:WaitForChild("PracticeStats")
local modeRemote = combatFolder:WaitForChild("PracticeModeRequest")
local infiniteHealthRemote = combatFolder:WaitForChild("PracticeInfiniteHealthRequest")
local resetRemote = combatFolder:WaitForChild("PracticeResetRequest")
local clearStatsRemote = combatFolder:WaitForChild("PracticeClearStatsRequest")
local exitRemote = combatFolder:WaitForChild("PracticeExitRequest")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PracticeHUD"
screenGui.ResetOnSpawn = false
-- Must respect CoreGui's safe insets (was true) - true placed RETURN TO HUB/the stats panel at the
-- literal top edge of the screen, underneath Roblox's own top-bar menu/chat icons.
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 49
screenGui.Enabled = false
screenGui.Parent = playerGui

--============================== RETURN TO HUB (top-left) ==============================--
local returnButtonApi = Theme.Button(screenGui, {
	name = "ReturnToHub",
	text = "RETURN TO HUB",
	size = UDim2.fromOffset(150, 36),
	textSize = 13,
	topColor = Theme.Colors.PanelRaised,
	bottomColor = Theme.Colors.Panel,
})
returnButtonApi.root.AnchorPoint = Vector2.new(0, 0)
returnButtonApi.root.Position = UDim2.new(0, 16, 0, 16)
returnButtonApi.face.MouseButton1Click:Connect(function()
	exitRemote:FireServer()
end)

--============================== stats panel (left, below Return to Hub, collapsible) ==============================--
local HEADER_HEIGHT = 28
local ROW_HEIGHT = 21
local STAT_ROWS = { "Last Hit", "Total Damage", "DPS", "Combo", "Hits per sec", "Best Combo", "Session" }
local BODY_HEIGHT = 10 + #STAT_ROWS * ROW_HEIGHT

local panel = Instance.new("Frame")
panel.Name = "StatsPanel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.new(0, 16, 0, 64)
panel.Size = UDim2.fromOffset(220, HEADER_HEIGHT + BODY_HEIGHT)
panel.BackgroundTransparency = 1
panel.Parent = screenGui

local header = Instance.new("TextButton")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
header.BackgroundColor3 = Theme.Colors.Panel
header.BackgroundTransparency = 0.1
header.AutoButtonColor = false
header.Font = Theme.Fonts.Bold
header.TextSize = 13
header.TextColor3 = Theme.Colors.Gold
header.Text = "STATS  v"
header.Parent = panel
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 8)
headerCorner.Parent = header
local headerStroke = Instance.new("UIStroke")
headerStroke.Color = Theme.Colors.Gold
headerStroke.Thickness = 1.25
headerStroke.Transparency = 0.4
headerStroke.Parent = header

local body = Instance.new("Frame")
body.Name = "Body"
body.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT + 4)
body.Size = UDim2.fromOffset(220, BODY_HEIGHT)
body.BackgroundColor3 = Theme.Colors.Panel
body.BackgroundTransparency = 0.15
body.ClipsDescendants = true
body.Parent = panel
local bodyCorner = Instance.new("UICorner")
bodyCorner.CornerRadius = UDim.new(0, 8)
bodyCorner.Parent = body
local bodyStroke = Instance.new("UIStroke")
bodyStroke.Color = Theme.Colors.Gold
bodyStroke.Thickness = 1.25
bodyStroke.Transparency = 0.4
bodyStroke.Parent = body

local collapsed = false
header.MouseButton1Click:Connect(function()
	collapsed = not collapsed
	body.Visible = not collapsed
	header.Text = collapsed and "STATS  >" or "STATS  v"
end)

local statValueLabels = {}
for i, rowName in ipairs(STAT_ROWS) do
	local l = Instance.new("TextLabel")
	l.Name = rowName:gsub("%s", "")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -16, 0, 20)
	l.Position = UDim2.new(0, 8, 0, 6 + (i - 1) * ROW_HEIGHT)
	l.Font = Theme.Fonts.Body
	l.TextSize = 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = Theme.Colors.Text
	l.Text = rowName .. ": 0"
	l.Parent = body
	statValueLabels[rowName] = l
end

local function formatSessionTime(seconds)
	seconds = math.floor(seconds or 0)
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

statsRemote.OnClientEvent:Connect(function(data)
	if not screenGui.Enabled then
		return
	end
	local showNumbers = Controller.damageNumbersEnabled ~= false
	local totalDamage = data.totalDamage or 0
	local sessionTime = data.sessionTime or 0
	local dps = sessionTime > 0 and (totalDamage / sessionTime) or 0
	statValueLabels["Last Hit"].Text = showNumbers
		and ("Last Hit: %d (%s)"):format(data.lastHit or 0, tostring(data.actionName or "-"))
		or "Last Hit: (hidden)"
	statValueLabels["Total Damage"].Text = showNumbers and ("Total Damage: %d"):format(totalDamage) or "Total Damage: (hidden)"
	statValueLabels["DPS"].Text = ("DPS: %.1f"):format(dps)
	statValueLabels["Combo"].Text = ("Combo: %dx"):format(data.combo or 0)
	statValueLabels["Hits per sec"].Text = ("Hits per sec: %.1f"):format(data.hitsPerSecond or 0)
	statValueLabels["Best Combo"].Text = ("Best Combo: %dx"):format(data.highestCombo or 0)
	statValueLabels["Session"].Text = "Session: " .. formatSessionTime(sessionTime)
end)

--============================== training-controls panel (one grouped card, bottom-centre) ==============================--
-- Spec size: ~680-760px wide, 130-160px tall at 1080p. The previous 560px-wide panel was narrower than
-- its OWN action row's button widths summed together (140+170+130+120+3*8=584px against 536px of
-- available content width) - the row silently overflowed the panel, which is what read as "oversized,
-- crude, cramped." 720px comfortably fits both rows with room to spare.
local controlsPanel = Instance.new("Frame")
controlsPanel.Name = "TrainingControls"
controlsPanel.AnchorPoint = Vector2.new(0.5, 1)
controlsPanel.Position = UDim2.new(0.5, 0, 1, -16)
controlsPanel.Size = UDim2.fromOffset(720, 148)
controlsPanel.BackgroundColor3 = Theme.Colors.Panel
controlsPanel.BackgroundTransparency = 0.1
controlsPanel.Parent = screenGui
local controlsCorner = Instance.new("UICorner")
controlsCorner.CornerRadius = UDim.new(0, 12)
controlsCorner.Parent = controlsPanel
local controlsStroke = Instance.new("UIStroke")
controlsStroke.Color = Theme.Colors.Gold
controlsStroke.Thickness = 1.5
controlsStroke.Transparency = 0.35
controlsStroke.Parent = controlsPanel
local controlsPadding = Instance.new("UIPadding")
controlsPadding.PaddingTop = UDim.new(0, 12)
controlsPadding.PaddingLeft = UDim.new(0, 16)
controlsPadding.PaddingRight = UDim.new(0, 16)
controlsPadding.Parent = controlsPanel

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.Size = UDim2.new(1, 0, 0, 18)
titleLabel.Font = Theme.Fonts.Bold
titleLabel.TextSize = 13
titleLabel.TextColor3 = Theme.Colors.Gold
titleLabel.Text = "TRAINING CONTROLS"
titleLabel.Parent = controlsPanel

-- lane row: Stationary / Strafing / Attacking / Combo
local laneRow = Instance.new("Frame")
laneRow.Name = "LaneRow"
laneRow.Position = UDim2.new(0, 0, 0, 22)
laneRow.Size = UDim2.new(1, 0, 0, 44)
laneRow.BackgroundTransparency = 1
laneRow.Parent = controlsPanel
local laneLayout = Instance.new("UIListLayout")
laneLayout.FillDirection = Enum.FillDirection.Horizontal
laneLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
laneLayout.VerticalAlignment = Enum.VerticalAlignment.Center
laneLayout.Padding = UDim.new(0, 10)
laneLayout.Parent = laneRow

-- toggle/action row: Infinite HP, Damage Numbers, Reset Dummy, Clear Stats
local actionRow = Instance.new("Frame")
actionRow.Name = "ActionRow"
actionRow.Position = UDim2.new(0, 0, 0, 76)
actionRow.Size = UDim2.new(1, 0, 0, 44)
actionRow.BackgroundTransparency = 1
actionRow.Parent = controlsPanel
local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
actionLayout.Padding = UDim.new(0, 10)
actionLayout.Parent = actionRow

local laneButtons = {}
local currentMode = "Stationary"
local function refreshLaneButtons()
	for mode, api in pairs(laneButtons) do
		api.SetSelected(mode == currentMode)
	end
end
for _, mode in ipairs({ "Stationary", "Strafing", "Attacking", "Combo" }) do
	local api = Theme.Button(laneRow, {
		name = mode,
		text = mode,
		size = UDim2.fromOffset(120, 40),
		textSize = 13,
		topColor = Theme.Colors.PanelRaised,
		bottomColor = Theme.Colors.Panel,
	})
	api.face.MouseButton1Click:Connect(function()
		currentMode = mode
		refreshLaneButtons()
		modeRemote:FireServer(mode)
	end)
	laneButtons[mode] = api
end
refreshLaneButtons()

-- Spec: "Toggle ON uses Cyan/Green" - a distinct concept from a lane's Gold "selected mode" face, so this
-- uses SetTopColor (swaps the actual face color) rather than SetSelected (which always forces Gold).
local infiniteHealthOn = true
local infiniteApi = Theme.Button(actionRow, {
	name = "InfiniteHP",
	text = "Infinite HP: On",
	size = UDim2.fromOffset(140, 40),
	textSize = 13,
	topColor = Theme.Colors.Cyan,
	bottomColor = Theme.Colors.Panel,
})
infiniteApi.face.MouseButton1Click:Connect(function()
	infiniteHealthOn = not infiniteHealthOn
	infiniteApi.SetText("Infinite HP: " .. (infiniteHealthOn and "On" or "Off"))
	infiniteApi.SetTopColor(infiniteHealthOn and Theme.Colors.Cyan or Theme.Colors.PanelRaised)
	infiniteHealthRemote:FireServer(infiniteHealthOn)
end)

local damageNumbersApi = Theme.Button(actionRow, {
	name = "DamageNumbers",
	text = "Damage Numbers: On",
	size = UDim2.fromOffset(170, 40),
	textSize = 13,
	topColor = Controller.damageNumbersEnabled ~= false and Theme.Colors.Cyan or Theme.Colors.PanelRaised,
	bottomColor = Theme.Colors.Panel,
})
damageNumbersApi.face.MouseButton1Click:Connect(function()
	local enabled = Controller.damageNumbersEnabled == false
	Controller.SetDamageNumbersEnabled(enabled)
	damageNumbersApi.SetText("Damage Numbers: " .. (enabled and "On" or "Off"))
	damageNumbersApi.SetTopColor(enabled and Theme.Colors.Cyan or Theme.Colors.PanelRaised)
end)

local resetApi = Theme.Button(actionRow, {
	name = "ResetDummy",
	text = "Reset Dummy",
	size = UDim2.fromOffset(130, 40),
	textSize = 13,
	topColor = Theme.Colors.Orange,
	bottomColor = Theme.Colors.GoldDim,
})
resetApi.face.MouseButton1Click:Connect(function()
	resetRemote:FireServer()
end)

local clearStatsApi = Theme.Button(actionRow, {
	name = "ClearStats",
	text = "Clear Stats",
	size = UDim2.fromOffset(120, 40),
	textSize = 13,
	topColor = Theme.Colors.Coral,
	bottomColor = Theme.Colors.Panel,
})
clearStatsApi.face.MouseButton1Click:Connect(function()
	clearStatsRemote:FireServer()
end)

player:GetAttributeChangedSignal("MatchState"):Connect(function()
	screenGui.Enabled = player:GetAttribute("MatchState") == "Practice"
end)
screenGui.Enabled = player:GetAttribute("MatchState") == "Practice"

-- brief "locked" feedback when the chicken-selection station rejects a pick - never fails silently.
local lockedRemote = combatFolder:WaitForChild("PracticeChickenLocked")
local lockedLabel = Instance.new("TextLabel")
lockedLabel.AnchorPoint = Vector2.new(0.5, 0)
lockedLabel.Position = UDim2.new(0.5, 0, 0, 80)
lockedLabel.Size = UDim2.fromOffset(420, 24)
lockedLabel.BackgroundTransparency = 1
lockedLabel.Font = Theme.Fonts.Bold
lockedLabel.TextSize = 16
lockedLabel.TextColor3 = Theme.Colors.Danger
lockedLabel.TextStrokeTransparency = 0.3
lockedLabel.Text = ""
lockedLabel.Parent = screenGui
lockedRemote.OnClientEvent:Connect(function(defId, reason)
	lockedLabel.Text = tostring(defId) .. " is locked: " .. tostring(reason)
	task.delay(4, function()
		if lockedLabel.Text:sub(1, #tostring(defId)) == tostring(defId) then
			lockedLabel.Text = ""
		end
	end)
end)
