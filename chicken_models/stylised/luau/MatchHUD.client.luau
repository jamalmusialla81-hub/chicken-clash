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
local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local rematchRemote = combatFolder:WaitForChild("RematchRequest")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 214, 96)
local PANEL = Color3.fromRGB(20, 16, 10)
local RED = Color3.fromRGB(214, 60, 60)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MatchHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
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

local myCardLabel = cardLabel(0.25, "You\nGolden Chicken\nRare", 16, Color3.fromRGB(235, 230, 220))
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
local oppCardLabel = cardLabel(0.75, "Opponent\nGolden Chicken\nRare", 16, Color3.fromRGB(235, 230, 220))

--============================== round-win pips + timer (top centre, clear of the middle) ==============================--
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 12)
topBar.Size = UDim2.fromOffset(260, 40)
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
timerLabel.TextColor3 = Color3.fromRGB(235, 230, 220)
timerLabel.Text = "0:60"
timerLabel.Parent = topBar

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

--============================== opponent health bar (stacked above the local one, bottom-left) ==============================--
local opponentHealthBar = Instance.new("Frame")
opponentHealthBar.Name = "OpponentHealthBar"
opponentHealthBar.AnchorPoint = Vector2.new(0, 1)
opponentHealthBar.Position = UDim2.new(0, 24, 1, -40)
opponentHealthBar.Size = UDim2.fromOffset(160, 8)
opponentHealthBar.BackgroundColor3 = Color3.fromRGB(20, 16, 10)
opponentHealthBar.BorderSizePixel = 0
opponentHealthBar.Visible = false
opponentHealthBar.Parent = screenGui
local opponentHealthFill = Instance.new("Frame")
opponentHealthFill.Name = "Fill"
opponentHealthFill.BackgroundColor3 = RED
opponentHealthFill.BorderSizePixel = 0
opponentHealthFill.Size = UDim2.fromScale(1, 1)
opponentHealthFill.Parent = opponentHealthBar
local opponentLabel = Instance.new("TextLabel")
opponentLabel.AnchorPoint = Vector2.new(0, 1)
opponentLabel.Position = UDim2.new(0, 0, 0, -14)
opponentLabel.Size = UDim2.fromOffset(160, 12)
opponentLabel.BackgroundTransparency = 1
opponentLabel.Font = Enum.Font.GothamMedium
opponentLabel.TextSize = 11
opponentLabel.TextXAlignment = Enum.TextXAlignment.Left
opponentLabel.TextColor3 = Color3.fromRGB(200, 195, 185)
opponentLabel.Text = "Opponent"
opponentLabel.Parent = opponentHealthBar

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
resultScore.TextColor3 = Color3.fromRGB(230, 230, 230)
resultScore.Text = "Rounds: 2 - 0"
resultScore.Parent = resultsPanel

local rewardLabel = Instance.new("TextLabel")
rewardLabel.AnchorPoint = Vector2.new(0.5, 0)
rewardLabel.Position = UDim2.new(0.5, 0, 0, 100)
rewardLabel.Size = UDim2.fromOffset(300, 40)
rewardLabel.BackgroundTransparency = 1
rewardLabel.Font = Enum.Font.Gotham
rewardLabel.TextSize = 13
rewardLabel.TextColor3 = Color3.fromRGB(190, 185, 175)
rewardLabel.TextWrapped = true
-- honest placeholder: reward integration is a later phase of this brief and does not exist yet - never
-- fabricate a currency amount the server did not actually grant.
rewardLabel.Text = "Rewards: coming soon"
rewardLabel.Parent = resultsPanel

local function resultButton(text, xOffset)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(0.5, xOffset, 1, -24)
	b.Size = UDim2.fromOffset(150, 44) -- comfortably large touch target
	b.BackgroundColor3 = PANEL
	b.BackgroundTransparency = 0.1
	b.TextColor3 = Color3.fromRGB(235, 230, 220)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.AutoButtonColor = true
	b.Text = text
	b.Parent = resultsPanel
	panelCorner(b, 8)
	local stroke = panelStroke(b, 0.35)
	b.MouseEnter:Connect(function() stroke.Color = Color3.fromRGB(255, 232, 160) end)
	b.MouseLeave:Connect(function() stroke.Color = GOLD end)
	b.SelectionImageObject = nil -- gamepad focus uses the default selection box; keep default behavior
	return b
end

local rematchButton = resultButton("Rematch", -80)
local lobbyButton = resultButton("Return to Lobby", 80)
lobbyButton.Size = UDim2.fromOffset(160, 44)

rematchButton.MouseButton1Click:Connect(function()
	rematchRemote:FireServer()
	resultsPanel.Visible = false
end)
lobbyButton.MouseButton1Click:Connect(function()
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
	local oppName = player:GetAttribute("MatchChickenName") or "Golden Chicken" -- opponent's OWN chicken, not mine
	local oppRarity = player:GetAttribute("MatchOpponentChickenRarity") or "Rare"
	local oppPlayerName = player:GetAttribute("MatchOpponentName") or "Opponent"
	myCardLabel.Text = ("You\n%s\n%s"):format(myName, myRarity)
	oppCardLabel.Text = ("%s\n%s\n%s"):format(oppPlayerName, player:GetAttribute("MatchOpponentChickenName") or oppName, oppRarity)
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

	if state == "Entrance" then
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
