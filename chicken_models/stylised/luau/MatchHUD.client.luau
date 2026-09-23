--[[ MatchHUD (client, LocalScript). Phase 4: the player-facing battle interface a real match needs
	beyond ChickenCombatHUD's reticle/local-health/dash-cooldown (which already covers both practice and
	real matches). This script is the REAL-MATCH-ONLY layer on top: pre-fight opponent card, opponent
	health bar, round-win pips, countdown, round timer, combo feedback, and the victory/defeat results
	panel with rematch/return-to-lobby. Everything here only DISPLAYS server-authored Player attributes
	(MatchState/MatchOpponentName/MatchChickenName/MatchRoundWins/etc, all set exclusively by MatchService)
	or reads Health/ComboStep attributes directly off the real chicken models - never computes anything
	authoritative itself, matching ChickenCombatHUD's own rule.

	Anchored/scale-based positioning throughout (no fixed pixel layouts), sized to stay clear of screen
	centre so the opponent's silhouette is never obstructed - this is the one hard rule everything here is
	built around. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Controller = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenCombatCameraController"))
local Theme = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("Theme"))
local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local rematchRemote = combatFolder:WaitForChild("RematchRequest")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Theme.Colors.Gold
local PANEL = Theme.Colors.Panel
local RED = Theme.Colors.Danger

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MatchHUD"
screenGui.ResetOnSpawn = false
-- Must respect CoreGui's safe insets (was true) - see the same fix in ChickenCombatHUD/PracticeHUD.
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 48
screenGui.Parent = playerGui

local function panelCorner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = inst
	return c
end

local function panelStroke(inst, transparency)
	local s = Instance.new("UIStroke")
	s.Color = GOLD
	s.Thickness = 1.5
	s.Transparency = transparency or 0.4
	s.Parent = inst
	return s
end

--============================== opponent resolution ==============================--
-- No remote carries "the opponent model" directly - both fighters in a match share the same MatchId
-- attribute (set by MatchService), so the opponent is just the other CombatChicken-tagged model with the
-- same MatchId. Cheap and correct: MatchId is unique per match and only ever two fighters share one.
local function findOpponent(): Model?
	local mine = Controller.chicken
	if not mine then
		return nil
	end
	local matchId = mine:GetAttribute("MatchId")
	if not matchId then
		return nil
	end
	for _, model in ipairs(CollectionService:GetTagged("CombatChicken")) do
		if model ~= mine and model:GetAttribute("MatchId") == matchId then
			return model
		end
	end
	return nil
end

--============================== pre-fight opponent card ==============================--
local preFightCard = Instance.new("Frame")
preFightCard.Name = "PreFightCard"
preFightCard.AnchorPoint = Vector2.new(0.5, 0.15)
preFightCard.Position = UDim2.new(0.5, 0, 0.15, 0)
preFightCard.Size = UDim2.fromOffset(420, 90)
preFightCard.BackgroundColor3 = PANEL
preFightCard.BackgroundTransparency = 0.2
preFightCard.Visible = false
preFightCard.Parent = screenGui
panelCorner(preFightCard, 10)
panelStroke(preFightCard)

local function cardLabel(xScale, text, size, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(xScale, 0, 0, 8)
	l.Size = UDim2.fromOffset(190, 74)
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = text
	l.Parent = preFightCard
	return l
end

local myCardLabel = cardLabel(0.25, "You\nGolden Chicken\nRare", 16, Theme.Colors.Text)
local vsLabel = Instance.new("TextLabel")
vsLabel.BackgroundTransparency = 1
vsLabel.AnchorPoint = Vector2.new(0.5, 0.5)
vsLabel.Position = UDim2.fromScale(0.5, 0.5)
vsLabel.Size = UDim2.fromOffset(40, 30)
vsLabel.Font = Enum.Font.GothamBlack
vsLabel.TextSize = 18
vsLabel.TextColor3 = GOLD
vsLabel.Text = "VS"
vsLabel.Parent = preFightCard
local oppCardLabel = cardLabel(0.75, "Opponent\nGolden Chicken\nRare", 16, Theme.Colors.Text)

--============================== top status bar: opponent name/chicken/health + round-wins + timer ==============================--
-- Spec: "opponent name, chicken, health and round wins at the top; match timer near the top centre." All
-- of it lives in one cluster now instead of being split (health used to sit at bottom-left, doubling up
-- with the player's own health there) - the opponent's status is always read from the top during Active,
-- never competing with the player's own lower-left health for the same corner.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 12)
topBar.Size = UDim2.fromOffset(280, 64)
topBar.BackgroundTransparency = 1
topBar.Visible = false
topBar.Parent = screenGui

local function pipRow(xScale)
	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(xScale, 0)
	row.Size = UDim2.fromOffset(60, 16)
	row.BackgroundTransparency = 1
	row.Parent = topBar
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.Parent = row
	local pips = {}
	for i = 1, 2 do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(14, 14)
		pip.BackgroundColor3 = PANEL
		pip.BackgroundTransparency = 0.2
		pip.Parent = row
		panelCorner(pip, 7)
		panelStroke(pip, 0.3)
		table.insert(pips, pip)
	end
	return row, pips
end

local myPipRow, myPips = pipRow(0)
myPipRow.Position = UDim2.new(0, 0, 0, 0)
local oppPipRow, oppPips = pipRow(1)
oppPipRow.AnchorPoint = Vector2.new(1, 0)
oppPipRow.Position = UDim2.new(1, 0, 0, 0)

local timerLabel = Instance.new("TextLabel")
timerLabel.AnchorPoint = Vector2.new(0.5, 0)
timerLabel.Position = UDim2.new(0.5, 0, 0, 0)
timerLabel.Size = UDim2.fromOffset(60, 20)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextSize = 16
timerLabel.TextColor3 = Theme.Colors.Text
timerLabel.Text = "0:60"
timerLabel.Parent = topBar

-- opponent name/chicken, small and centered directly under the timer - persists through Active, not just
-- the Entrance pre-fight card, so "opponent name and chicken" stays visible at the top the whole match.
local opponentInfoLabel = Instance.new("TextLabel")
opponentInfoLabel.AnchorPoint = Vector2.new(0.5, 0)
opponentInfoLabel.Position = UDim2.new(0.5, 0, 0, 22)
opponentInfoLabel.Size = UDim2.fromOffset(240, 16)
opponentInfoLabel.BackgroundTransparency = 1
opponentInfoLabel.Font = Enum.Font.GothamMedium
opponentInfoLabel.TextSize = 12
opponentInfoLabel.TextColor3 = Theme.Colors.TextMuted
opponentInfoLabel.Text = "Opponent"
opponentInfoLabel.Parent = topBar

-- opponent health bar, centered under the name - grouped with round-wins/timer at the top instead of
-- doubling up with the player's own health bar in the lower-left corner.
local opponentHealthBar = Instance.new("Frame")
opponentHealthBar.Name = "OpponentHealthBar"
opponentHealthBar.AnchorPoint = Vector2.new(0.5, 0)
opponentHealthBar.Position = UDim2.new(0.5, 0, 0, 42)
opponentHealthBar.Size = UDim2.fromOffset(160, 8)
opponentHealthBar.BackgroundColor3 = Color3.fromRGB(20, 16, 10)
opponentHealthBar.BorderSizePixel = 0
opponentHealthBar.Parent = topBar
panelCorner(opponentHealthBar, 4)
local opponentHealthFill = Instance.new("Frame")
opponentHealthFill.Name = "Fill"
opponentHealthFill.BackgroundColor3 = RED
opponentHealthFill.BorderSizePixel = 0
opponentHealthFill.Size = UDim2.fromScale(1, 1)
opponentHealthFill.Parent = opponentHealthBar
panelCorner(opponentHealthFill, 4)
local opponentHealthGradient = Instance.new("UIGradient")
opponentHealthGradient.Color = ColorSequence.new(Color3.fromRGB(255, 140, 120), RED)
opponentHealthGradient.Rotation = 90
opponentHealthGradient.Parent = opponentHealthFill

--============================== countdown (centre, but only during Countdown - never during Active) ==============================--
local countdownLabel = Instance.new("TextLabel")
countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
countdownLabel.Position = UDim2.fromScale(0.5, 0.38) -- above centre, never over the opponent's silhouette
countdownLabel.Size = UDim2.fromOffset(160, 80)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Font = Enum.Font.GothamBlack
countdownLabel.TextSize = 48
countdownLabel.TextColor3 = GOLD
countdownLabel.TextStrokeTransparency = 0.5
countdownLabel.Text = ""
countdownLabel.Visible = false
countdownLabel.Parent = screenGui

--============================== combo feedback (small, above the reticle, never covering it) ==============================--
local comboLabel = Instance.new("TextLabel")
comboLabel.AnchorPoint = Vector2.new(0.5, 1)
comboLabel.Position = UDim2.new(0.5, 0, 0.5, -40)
comboLabel.Size = UDim2.fromOffset(140, 24)
comboLabel.BackgroundTransparency = 1
comboLabel.Font = Enum.Font.GothamBold
comboLabel.TextSize = 18
comboLabel.TextColor3 = GOLD
comboLabel.TextTransparency = 1
comboLabel.Text = ""
comboLabel.Parent = screenGui
local comboFade = 0

--============================== results panel ==============================--
local resultsPanel = Instance.new("Frame")
resultsPanel.Name = "ResultsPanel"
resultsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
resultsPanel.Position = UDim2.fromScale(0.5, 0.5)
resultsPanel.Size = UDim2.fromOffset(360, 260)
resultsPanel.BackgroundColor3 = PANEL
resultsPanel.BackgroundTransparency = 0.1
resultsPanel.Visible = false
resultsPanel.Parent = screenGui
panelCorner(resultsPanel, 12)
panelStroke(resultsPanel, 0.25)

local resultTitle = Instance.new("TextLabel")
resultTitle.AnchorPoint = Vector2.new(0.5, 0)
resultTitle.Position = UDim2.new(0.5, 0, 0, 20)
resultTitle.Size = UDim2.fromOffset(300, 44)
resultTitle.BackgroundTransparency = 1
resultTitle.Font = Enum.Font.GothamBlack
resultTitle.TextSize = 30
resultTitle.TextColor3 = GOLD
resultTitle.Text = "VICTORY"
resultTitle.Parent = resultsPanel

local resultScore = Instance.new("TextLabel")
resultScore.AnchorPoint = Vector2.new(0.5, 0)
resultScore.Position = UDim2.new(0.5, 0, 0, 68)
resultScore.Size = UDim2.fromOffset(300, 24)
resultScore.BackgroundTransparency = 1
resultScore.Font = Enum.Font.GothamMedium
resultScore.TextSize = 16
resultScore.TextColor3 = Theme.Colors.Text
resultScore.Text = "Rounds: 2 - 0"
resultScore.Parent = resultsPanel

local rewardLabel = Instance.new("TextLabel")
rewardLabel.AnchorPoint = Vector2.new(0.5, 0)
rewardLabel.Position = UDim2.new(0.5, 0, 0, 100)
rewardLabel.Size = UDim2.fromOffset(300, 40)
rewardLabel.BackgroundTransparency = 1
rewardLabel.Font = Enum.Font.Gotham
rewardLabel.TextSize = 13
rewardLabel.TextColor3 = Theme.Colors.TextMuted
rewardLabel.TextWrapped = true
-- honest placeholder: reward integration is a later phase of this brief and does not exist yet - never
-- fabricate a currency amount the server did not actually grant.
rewardLabel.Text = "Rewards: coming soon"
rewardLabel.Parent = resultsPanel

local buttonRow = Instance.new("Frame")
buttonRow.Name = "ButtonRow"
buttonRow.AnchorPoint = Vector2.new(0.5, 1)
buttonRow.Position = UDim2.new(0.5, 0, 1, -20)
buttonRow.Size = UDim2.fromOffset(340, 56)
buttonRow.BackgroundTransparency = 1
buttonRow.Parent = resultsPanel
local buttonRowLayout = Instance.new("UIListLayout")
buttonRowLayout.FillDirection = Enum.FillDirection.Horizontal
buttonRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
buttonRowLayout.Padding = UDim.new(0, 16)
buttonRowLayout.Parent = buttonRow

local rematchButtonApi = Theme.Button(buttonRow, {
	name = "Rematch",
	text = "Rematch",
	size = UDim2.fromOffset(150, 48),
	topColor = Theme.Colors.Gold,
	bottomColor = Theme.Colors.GoldDim,
})
local lobbyButtonApi = Theme.Button(buttonRow, {
	name = "ReturnToLobby",
	text = "Return to Lobby",
	size = UDim2.fromOffset(160, 48),
	topColor = Theme.Colors.PanelRaised,
	bottomColor = Theme.Colors.Panel,
})

rematchButtonApi.face.MouseButton1Click:Connect(function()
	rematchRemote:FireServer()
	resultsPanel.Visible = false
end)
lobbyButtonApi.face.MouseButton1Click:Connect(function()
	-- purely a local dismissal - MatchService already tears the match down and calls LoadCharacter on its
	-- own RETURN_DELAY timer regardless of this button; this just lets an impatient player stop looking at
	-- the results screen early instead of actually forcing an early server-side return.
	resultsPanel.Visible = false
end)

--============================== drive everything off MatchState + the published attributes ==============================--
local shownForResultsThisMatch = false

local function updateOpponentCard()
	local myName = player:GetAttribute("MatchChickenName") or "Golden Chicken"
	local myRarity = player:GetAttribute("MatchChickenRarity") or "Rare"
	local oppChickenName = player:GetAttribute("MatchOpponentChickenName") or "Golden Chicken"
	local oppRarity = player:GetAttribute("MatchOpponentChickenRarity") or "Rare"
	local oppPlayerName = player:GetAttribute("MatchOpponentName") or "Opponent"
	myCardLabel.Text = ("You\n%s\n%s"):format(myName, myRarity)
	oppCardLabel.Text = ("%s\n%s\n%s"):format(oppPlayerName, oppChickenName, oppRarity)
	-- top-bar summary, kept up through Active too (the pre-fight card only shows during Entrance)
	opponentInfoLabel.Text = ("%s - %s"):format(oppPlayerName, oppChickenName)
end

local function updatePips()
	local myWins = player:GetAttribute("MatchRoundWins") or 0
	local oppWins = player:GetAttribute("MatchOpponentRoundWins") or 0
	for i, pip in ipairs(myPips) do
		pip.BackgroundColor3 = i <= myWins and GOLD or PANEL
	end
	for i, pip in ipairs(oppPips) do
		pip.BackgroundColor3 = i <= oppWins and RED or PANEL
	end
end

player:GetAttributeChangedSignal("MatchRoundWins"):Connect(updatePips)
player:GetAttributeChangedSignal("MatchOpponentRoundWins"):Connect(updatePips)
player:GetAttributeChangedSignal("MatchChickenName"):Connect(updateOpponentCard)
player:GetAttributeChangedSignal("MatchOpponentName"):Connect(updateOpponentCard)

RunService.RenderStepped:Connect(function(dt)
	local state = player:GetAttribute("MatchState")
	local inRealMatch = state == "Preparing" or state == "Entrance" or state == "Countdown"
		or state == "Active" or state == "RoundEnd" or state == "Results"

	preFightCard.Visible = state == "Entrance"
	topBar.Visible = inRealMatch and state ~= "Results"
	countdownLabel.Visible = state == "Countdown"
	opponentHealthBar.Visible = state == "Active" or state == "RoundEnd"

	if state == "Entrance" or state == "Preparing" then
		updateOpponentCard()
	end

	if state == "Countdown" then
		local endsAt = player:GetAttribute("MatchCountdownEndsAt")
		if endsAt then
			local remaining = endsAt - workspace:GetServerTimeNow()
			if remaining > 0.05 then
				countdownLabel.Text = tostring(math.ceil(remaining))
			else
				countdownLabel.Text = "FIGHT!"
			end
		end
	end

	if inRealMatch then
		updatePips()
		local roundEndsAt = player:GetAttribute("MatchRoundEndsAt")
		if roundEndsAt and state == "Active" then
			local remaining = math.max(roundEndsAt - workspace:GetServerTimeNow(), 0)
			timerLabel.Text = ("%d:%02d"):format(remaining // 60, remaining % 60)
		end
	end

	if opponentHealthBar.Visible then
		local opponent = findOpponent()
		local health = opponent and opponent:GetAttribute("Health")
		local maxHealth = opponent and opponent:GetAttribute("MaxHealth")
		local frac = 1
		if health and maxHealth and maxHealth > 0 then
			frac = math.clamp(health / maxHealth, 0, 1)
		end
		opponentHealthFill.Size = UDim2.fromScale(frac, 1)
	end

	-- combo feedback: reads the LOCAL fighter's own ComboStep attribute (set by ChickenCombatService)
	local mine = Controller.chicken
	local comboStep = mine and mine:GetAttribute("ComboStep") or 0
	if comboStep and comboStep > 1 then
		comboLabel.Text = comboStep .. " HIT COMBO"
		comboFade = 1
	end
	if comboFade > 0 then
		comboFade = math.max(comboFade - dt * 0.8, 0)
		comboLabel.TextTransparency = 1 - comboFade
	end

	if state == "Results" or state == "Returning" then
		if not shownForResultsThisMatch then
			shownForResultsThisMatch = true
			local result = player:GetAttribute("MatchResult")
			resultTitle.Text = result == "Victory" and "VICTORY" or "DEFEAT"
			resultTitle.TextColor3 = result == "Victory" and GOLD or RED
			resultScore.Text = ("Rounds: %d - %d"):format(
				player:GetAttribute("MatchRoundWins") or 0, player:GetAttribute("MatchOpponentRoundWins") or 0)
			resultsPanel.Visible = true
		end
	else
		if shownForResultsThisMatch then
			shownForResultsThisMatch = false
			resultsPanel.Visible = false
		end
	end
end)
