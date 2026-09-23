--[[ ChickenCombatHUD (LocalScript, StarterPlayerScripts). First-person-safe combat HUD: a proper
	crosshair reticle, a health card (bottom-left), a dash card (bottom-right), and a settings gear/panel.
	Shown only while ChickenCombatCameraController is in CombatFirstPerson; hidden the instant that state
	ends, and hides the collection/menu UI (StarterGui.Main, if present) during combat so nothing competes
	with the reticle for screen centre. Never trusts local values for health/cooldown/damage - it only
	DISPLAYS whatever the server has already replicated via attributes; it computes nothing authoritative
	itself.

	Gate 3 rebuild: the previous reticle was a single translucent dot (read as "a muddy brown pixel" at
	low contrast) and the health/dash indicators were a bare 10px line and a plain circle with no card,
	label or context - which read as "unexplained UI artifacts" rather than intentional HUD elements. Both
	are rebuilt here as the spec's actual cross/ring reticle and framed cards. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Controller = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenCombatCameraController"))
local Theme = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("Theme"))
local ChickenDefinitions = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenDefinitions"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ChickenCombatHUD"
screenGui.ResetOnSpawn = false
-- Must respect CoreGui's safe insets (was true) - true placed the settings gear underneath Roblox's own
-- top-bar menu/chat icons.
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 50
screenGui.Enabled = false
screenGui.Parent = playerGui

--============================== centre reticle: cross + tiny gold dot ==============================--
-- Four short cream tick marks (a gap in the middle, not a solid cross) plus a thin dark outline on each
-- for contrast against any background, and a tiny gold centre dot. Never a single translucent blob.
local reticle = Instance.new("Frame")
reticle.Name = "Reticle"
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Position = UDim2.fromScale(0.5, 0.5)
reticle.Size = UDim2.fromOffset(24, 24)
reticle.BackgroundTransparency = 1
reticle.Parent = screenGui

local tickFrames = {}
local function reticleTick(dx, dy, w, h)
	local tick = Instance.new("Frame")
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.new(0.5, dx, 0.5, dy)
	tick.Size = UDim2.fromOffset(w, h)
	tick.BackgroundColor3 = Theme.Colors.Text
	tick.BorderSizePixel = 0
	tick.ZIndex = 2
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Outline
	stroke.Thickness = 1
	stroke.Transparency = 0.2
	stroke.Parent = tick
	tick.Parent = reticle
	table.insert(tickFrames, { frame = tick, dx = dx, dy = dy, w = w, h = h })
	return tick
end

-- top, bottom, left, right ticks with a small central gap
reticleTick(0, -9, 2, 6)
reticleTick(0, 9, 2, 6)
reticleTick(-9, 0, 6, 2)
reticleTick(9, 0, 6, 2)

local centerDot = Instance.new("Frame")
centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
centerDot.Position = UDim2.fromScale(0.5, 0.5)
centerDot.Size = UDim2.fromOffset(4, 4)
centerDot.BackgroundColor3 = Theme.Colors.Gold
centerDot.BorderSizePixel = 0
centerDot.ZIndex = 2
local centerDotCorner = Instance.new("UICorner")
centerDotCorner.CornerRadius = UDim.new(1, 0)
centerDotCorner.Parent = centerDot
centerDot.Parent = reticle

-- hit-confirmation: brief outward pulse of the ticks, only ever played from the server-confirmed hit
-- remote, never from a local guess at whether a swing landed.
local hitConfirmedRemote = ReplicatedStorage:WaitForChild("ChickenHitConfirmed")
local pulseT = 0

-- floating damage numbers: Controller.damageNumbersEnabled/SetDamageNumbersEnabled already existed as a
-- toggle (settings panel + PracticeHUD action row) but nothing ever actually spawned a number - the
-- toggle did nothing visible. This is the real renderer for it: a small TextLabel near the reticle,
-- upward drift + fade, gold for damage dealt, red for damage taken. Server-confirmed only, same as the
-- hit-marker pulse above.
local damageNumberLayer = Instance.new("Frame")
damageNumberLayer.Name = "DamageNumbers"
damageNumberLayer.AnchorPoint = Vector2.new(0.5, 0.5)
damageNumberLayer.Position = UDim2.fromScale(0.5, 0.5)
damageNumberLayer.Size = UDim2.fromOffset(1, 1)
damageNumberLayer.BackgroundTransparency = 1
damageNumberLayer.Parent = screenGui

local activeDamageNumbers = {}
local function spawnDamageNumber(amount: number, dealt: boolean)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(math.random(-30, 30), -40)
	label.Size = UDim2.fromOffset(80, 30)
	label.Font = Theme.Fonts.Bold
	label.TextSize = dealt and 22 or 18
	label.TextColor3 = dealt and Theme.Colors.Gold or Theme.Colors.Danger
	label.TextStrokeTransparency = 0.3
	label.Text = (dealt and "-" or "") .. tostring(math.floor(amount))
	label.Parent = damageNumberLayer
	table.insert(activeDamageNumbers, { label = label, t = 0, startY = label.Position.Y.Offset })
end

hitConfirmedRemote.OnClientEvent:Connect(function(kind: string, actionName: string, damage: number)
	if not screenGui.Enabled then
		return
	end
	if kind == "Dealt" then
		if Controller.hitMarkerEnabled ~= false then
			pulseT = 1
		end
		if Controller.damageNumbersEnabled ~= false and damage then
			spawnDamageNumber(damage, true)
		end
	elseif kind == "Taken" and Controller.damageNumbersEnabled ~= false and damage then
		spawnDamageNumber(damage, false)
	end
end)

--============================== health card (bottom-left) ==============================--
local healthCard = Instance.new("Frame")
healthCard.Name = "HealthCard"
healthCard.AnchorPoint = Vector2.new(0, 1)
healthCard.Position = UDim2.new(0, 20, 1, -20)
healthCard.Size = UDim2.fromOffset(190, 60)
healthCard.BackgroundColor3 = Theme.Colors.Panel
healthCard.BackgroundTransparency = 0.05
healthCard.Parent = screenGui
local healthCardCorner = Instance.new("UICorner")
healthCardCorner.CornerRadius = UDim.new(0, 10)
healthCardCorner.Parent = healthCard
local healthCardStroke = Instance.new("UIStroke")
healthCardStroke.Color = Theme.Colors.Gold
healthCardStroke.Thickness = 1.5
healthCardStroke.Transparency = 0.35
healthCardStroke.Parent = healthCard

local healthIcon = Instance.new("Frame")
healthIcon.AnchorPoint = Vector2.new(0, 0.5)
healthIcon.Position = UDim2.new(0, 8, 0.5, 0)
healthIcon.Size = UDim2.fromOffset(30, 30)
healthIcon.BackgroundColor3 = Theme.Colors.Gold
healthIcon.Parent = healthCard
local healthIconCorner = Instance.new("UICorner")
healthIconCorner.CornerRadius = UDim.new(1, 0)
healthIconCorner.Parent = healthIcon

local healthNameLabel = Instance.new("TextLabel")
healthNameLabel.BackgroundTransparency = 1
healthNameLabel.Position = UDim2.new(0, 46, 0, 6)
healthNameLabel.Size = UDim2.new(1, -78, 0, 16)
healthNameLabel.Font = Theme.Fonts.Bold
healthNameLabel.TextSize = 12
healthNameLabel.TextXAlignment = Enum.TextXAlignment.Left
healthNameLabel.TextColor3 = Theme.Colors.Text
healthNameLabel.Text = "Chicken"
healthNameLabel.Parent = healthCard

local healthNumberLabel = Instance.new("TextLabel")
healthNumberLabel.BackgroundTransparency = 1
healthNumberLabel.AnchorPoint = Vector2.new(1, 0)
healthNumberLabel.Position = UDim2.new(1, -8, 0, 6)
healthNumberLabel.Size = UDim2.fromOffset(50, 16)
healthNumberLabel.Font = Theme.Fonts.Bold
healthNumberLabel.TextSize = 12
healthNumberLabel.TextXAlignment = Enum.TextXAlignment.Right
healthNumberLabel.TextColor3 = Theme.Colors.Text
healthNumberLabel.Text = "100/100"
healthNumberLabel.Parent = healthCard

local healthBarFrame = Instance.new("Frame")
healthBarFrame.Position = UDim2.new(0, 46, 0, 30)
healthBarFrame.Size = UDim2.new(1, -58, 0, 14)
healthBarFrame.BackgroundColor3 = Theme.Colors.Outline
healthBarFrame.BorderSizePixel = 0
healthBarFrame.Parent = healthCard
local healthBarFrameCorner = Instance.new("UICorner")
healthBarFrameCorner.CornerRadius = UDim.new(0, 5)
healthBarFrameCorner.Parent = healthBarFrame
local healthFill = Instance.new("Frame")
healthFill.Name = "Fill"
healthFill.BackgroundColor3 = Theme.Colors.Danger
healthFill.BorderSizePixel = 0
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.Parent = healthBarFrame
local healthFillCorner = Instance.new("UICorner")
healthFillCorner.CornerRadius = UDim.new(0, 5)
healthFillCorner.Parent = healthFill
local healthGradient = Instance.new("UIGradient")
healthGradient.Color = ColorSequence.new(Color3.fromRGB(255, 140, 120), Theme.Colors.Danger)
healthGradient.Rotation = 90
healthGradient.Parent = healthFill

--============================== dash card (bottom-right) ==============================--
local dashCard = Instance.new("Frame")
dashCard.Name = "DashCard"
dashCard.AnchorPoint = Vector2.new(1, 1)
dashCard.Position = UDim2.new(1, -20, 1, -20)
dashCard.Size = UDim2.fromOffset(140, 60)
dashCard.BackgroundColor3 = Theme.Colors.Panel
dashCard.BackgroundTransparency = 0.05
dashCard.Parent = screenGui
local dashCardCorner = Instance.new("UICorner")
dashCardCorner.CornerRadius = UDim.new(0, 10)
dashCardCorner.Parent = dashCard
local dashCardStroke = Instance.new("UIStroke")
dashCardStroke.Color = Theme.Colors.Gold
dashCardStroke.Thickness = 1.5
dashCardStroke.Transparency = 0.35
dashCardStroke.Parent = dashCard

local dashIconFrame = Instance.new("Frame")
dashIconFrame.AnchorPoint = Vector2.new(0, 0.5)
dashIconFrame.Position = UDim2.new(0, 8, 0.5, 0)
dashIconFrame.Size = UDim2.fromOffset(30, 30)
dashIconFrame.BackgroundColor3 = Theme.Colors.Cyan
dashIconFrame.Parent = dashCard
local dashIconCorner = Instance.new("UICorner")
dashIconCorner.CornerRadius = UDim.new(1, 0)
dashIconCorner.Parent = dashIconFrame
local dashIconLabel = Instance.new("TextLabel")
dashIconLabel.BackgroundTransparency = 1
dashIconLabel.Size = UDim2.fromScale(1, 1)
dashIconLabel.Font = Theme.Fonts.Bold
dashIconLabel.TextSize = 14
dashIconLabel.TextColor3 = Theme.Colors.Outline
dashIconLabel.Text = "SHIFT"
dashIconLabel.TextScaled = true
local dashIconPadding = Instance.new("UIPadding")
dashIconPadding.PaddingTop = UDim.new(0, 6)
dashIconPadding.PaddingBottom = UDim.new(0, 6)
dashIconPadding.Parent = dashIconLabel
dashIconLabel.Parent = dashIconFrame

local dashNameLabel = Instance.new("TextLabel")
dashNameLabel.BackgroundTransparency = 1
dashNameLabel.Position = UDim2.new(0, 46, 0, 6)
dashNameLabel.Size = UDim2.new(1, -54, 0, 16)
dashNameLabel.Font = Theme.Fonts.Bold
dashNameLabel.TextSize = 12
dashNameLabel.TextXAlignment = Enum.TextXAlignment.Left
dashNameLabel.TextColor3 = Theme.Colors.Text
dashNameLabel.Text = "DASH"
dashNameLabel.Parent = dashCard

local dashBarFrame = Instance.new("Frame")
dashBarFrame.Position = UDim2.new(0, 46, 0, 30)
dashBarFrame.Size = UDim2.new(1, -54, 0, 14)
dashBarFrame.BackgroundColor3 = Theme.Colors.Outline
dashBarFrame.BorderSizePixel = 0
dashBarFrame.Parent = dashCard
local dashBarFrameCorner = Instance.new("UICorner")
dashBarFrameCorner.CornerRadius = UDim.new(0, 5)
dashBarFrameCorner.Parent = dashBarFrame
local dashFill = Instance.new("Frame")
dashFill.Name = "Fill"
dashFill.BackgroundColor3 = Theme.Colors.Cyan
dashFill.BorderSizePixel = 0
dashFill.Size = UDim2.fromScale(1, 1)
dashFill.Parent = dashBarFrame
local dashFillCorner = Instance.new("UICorner")
dashFillCorner.CornerRadius = UDim.new(0, 5)
dashFillCorner.Parent = dashFill

--============================== settings: one gear, one panel ==============================--
-- Spec: "One gear opens one panel. Do not show six individual buttons permanently." Previously Reduced
-- Motion + 5 cycle-buttons were ALL always visible during combat, competing with the opponent/reticle for
-- attention - replaced with a single small gear icon; the panel it opens releases the mouse via
-- Controller.SetMenuOpen so the player can actually click its controls (a locked-center cursor otherwise
-- can't reach anything off-center), and closing it re-locks/relocks first-person without a snap.
local gearButton = Instance.new("TextButton")
gearButton.Name = "SettingsGear"
gearButton.AnchorPoint = Vector2.new(1, 0)
gearButton.Position = UDim2.new(1, -16, 0, 16)
gearButton.Size = UDim2.fromOffset(44, 44)
gearButton.BackgroundColor3 = Theme.Colors.Panel
gearButton.BackgroundTransparency = 0.15
gearButton.Text = "\u{2699}" -- gear glyph
gearButton.TextColor3 = Theme.Colors.Text
gearButton.Font = Theme.Fonts.Bold
gearButton.TextSize = 20
gearButton.AutoButtonColor = false
gearButton.Parent = screenGui
local gearCorner = Instance.new("UICorner")
gearCorner.CornerRadius = UDim.new(1, 0)
gearCorner.Parent = gearButton
local gearStroke = Instance.new("UIStroke")
gearStroke.Color = Theme.Colors.Gold
gearStroke.Thickness = 1.5
gearStroke.Transparency = 0.3
gearStroke.Parent = gearButton

local settingsPanel = Instance.new("Frame")
settingsPanel.Name = "SettingsPanel"
settingsPanel.AnchorPoint = Vector2.new(1, 0)
settingsPanel.Position = UDim2.new(1, -16, 0, 68)
settingsPanel.Size = UDim2.fromOffset(220, 234)
settingsPanel.BackgroundColor3 = Theme.Colors.Panel
settingsPanel.BackgroundTransparency = 0.05
settingsPanel.Visible = false
settingsPanel.Parent = screenGui
local settingsPanelCorner = Instance.new("UICorner")
settingsPanelCorner.CornerRadius = UDim.new(0, 10)
settingsPanelCorner.Parent = settingsPanel
local settingsPanelStroke = Instance.new("UIStroke")
settingsPanelStroke.Color = Theme.Colors.Gold
settingsPanelStroke.Thickness = 1.5
settingsPanelStroke.Transparency = 0.35
settingsPanelStroke.Parent = settingsPanel
local settingsLayout = Instance.new("UIListLayout")
settingsLayout.Padding = UDim.new(0, 6)
settingsLayout.Parent = settingsPanel
local settingsPadding = Instance.new("UIPadding")
settingsPadding.PaddingTop = UDim.new(0, 10)
settingsPadding.PaddingLeft = UDim.new(0, 10)
settingsPadding.PaddingRight = UDim.new(0, 10)
settingsPadding.Parent = settingsPanel

local function settingsRow(text)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 32)
	b.BackgroundColor3 = Theme.Colors.PanelRaised
	b.TextColor3 = Theme.Colors.Text
	b.Font = Theme.Fonts.Body
	b.TextSize = 13
	b.Text = text
	b.AutoButtonColor = false
	b.Parent = settingsPanel
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = b
	return b
end

local reducedMotionButton = settingsRow("Reduced Motion: Off")
reducedMotionButton.MouseButton1Click:Connect(function()
	Controller.SetReducedMotion(not Controller.reducedMotion)
	reducedMotionButton.Text = "Reduced Motion: " .. (Controller.reducedMotion and "On" or "Off")
end)

local SHAKE_LEVELS = { 0, 0.5, 1, 1.5, 2 }
local shakeIndex = 3
local shakeButton = settingsRow("Shake: Normal")
shakeButton.MouseButton1Click:Connect(function()
	shakeIndex = (shakeIndex % #SHAKE_LEVELS) + 1
	Controller.SetShakeStrength(SHAKE_LEVELS[shakeIndex])
	local pct = math.floor(SHAKE_LEVELS[shakeIndex] * 100)
	shakeButton.Text = "Shake: " .. pct .. "%"
end)

local FOV_LEVELS = { -8, -4, 0, 4, 8 }
local fovIndex = 3
local fovButton = settingsRow("FOV Adjust: 0")
fovButton.MouseButton1Click:Connect(function()
	fovIndex = (fovIndex % #FOV_LEVELS) + 1
	Controller.SetFOVAdjust(FOV_LEVELS[fovIndex])
	fovButton.Text = "FOV Adjust: " .. (FOV_LEVELS[fovIndex] >= 0 and "+" or "") .. FOV_LEVELS[fovIndex]
end)

local hitMarkerButton = settingsRow("Hit Marker: On")
hitMarkerButton.MouseButton1Click:Connect(function()
	Controller.SetHitMarkerEnabled(not Controller.hitMarkerEnabled)
	hitMarkerButton.Text = "Hit Marker: " .. (Controller.hitMarkerEnabled and "On" or "Off")
end)

local damageNumbersButton = settingsRow("Damage Numbers: On")
damageNumbersButton.MouseButton1Click:Connect(function()
	Controller.SetDamageNumbersEnabled(not Controller.damageNumbersEnabled)
	damageNumbersButton.Text = "Damage Numbers: " .. (Controller.damageNumbersEnabled and "On" or "Off")
end)

local CROSSHAIR_LEVELS = { 0.5, 0.75, 1, 1.5, 2 }
local crosshairIndex = 3
local crosshairButton = settingsRow("Crosshair: 100%")
crosshairButton.MouseButton1Click:Connect(function()
	crosshairIndex = (crosshairIndex % #CROSSHAIR_LEVELS) + 1
	Controller.SetCrosshairScale(CROSSHAIR_LEVELS[crosshairIndex])
	crosshairButton.Text = "Crosshair: " .. math.floor(CROSSHAIR_LEVELS[crosshairIndex] * 100) .. "%"
end)

local settingsOpen = false
gearButton.MouseButton1Click:Connect(function()
	settingsOpen = not settingsOpen
	settingsPanel.Visible = settingsOpen
	Controller.SetMenuOpen(settingsOpen)
end)

-- health reads from a "Health"/"MaxHealth" attribute on the chicken IF the real health system sets one;
-- until that system exists this simply shows full health rather than fabricating a number.
local function updateHealthCard()
	local chicken = Controller.chicken
	local health = chicken and chicken:GetAttribute("Health")
	local maxHealth = chicken and chicken:GetAttribute("MaxHealth")
	local frac = 1
	if health and maxHealth and maxHealth > 0 then
		frac = math.clamp(health / maxHealth, 0, 1)
	end
	healthFill.Size = UDim2.fromScale(frac, 1)
	healthNumberLabel.Text = ("%d/%d"):format(math.floor(health or maxHealth or 100), math.floor(maxHealth or 100))
	local defId = chicken and chicken:GetAttribute("ChickenDefId")
	local def = defId and ChickenDefinitions.Get(defId)
	healthNameLabel.Text = (def and def.DisplayName) or "Chicken"
end

local function updateDashCard()
	local chicken = Controller.chicken
	local readyAt = chicken and chicken:GetAttribute("DashReadyAt")
	if not readyAt then
		dashFill.Size = UDim2.fromScale(1, 1)
		return
	end
	-- server and client os.clock() are NOT synchronized - GetServerTimeNow() is, and matches what the
	-- server used to compute DashReadyAt.
	local remaining = readyAt - workspace:GetServerTimeNow()
	local totalCooldown = chicken:GetAttribute("DashCooldownDuration") or 2.5
	local frac = 1 - math.clamp(remaining / totalCooldown, 0, 1)
	dashFill.Size = UDim2.fromScale(math.max(frac, 0.02), 1)
end

RunService.RenderStepped:Connect(function(dt)
	local shouldShow = Controller.state == Controller.States.PracticeCombat or Controller.state == Controller.States.MatchCombat
	if screenGui.Enabled ~= shouldShow then
		screenGui.Enabled = shouldShow
		local mainUI = playerGui:FindFirstChild("Main")
		if mainUI then
			mainUI.Enabled = not shouldShow
		end
		if not shouldShow and settingsOpen then
			-- combat ended with the settings panel still open - close it so it can't linger into the
			-- next session, and don't leave the camera controller thinking a menu still owns the mouse.
			settingsOpen = false
			settingsPanel.Visible = false
			Controller.SetMenuOpen(false)
		end
	end
	if not shouldShow then
		return
	end
	updateHealthCard()
	updateDashCard()
	local scale = Controller.crosshairScale or 1
	local pulse = 1 + (pulseT > 0 and pulseT * 0.6 or 0)
	for _, t in ipairs(tickFrames) do
		t.frame.Position = UDim2.new(0.5, t.dx * scale * pulse, 0.5, t.dy * scale * pulse)
		t.frame.Size = UDim2.fromOffset(t.w * scale, t.h * scale)
	end
	centerDot.Size = UDim2.fromOffset(4 * scale, 4 * scale)
	if pulseT > 0 then
		pulseT = math.max(pulseT - dt * 4, 0)
	end

	-- drift damage numbers upward and fade them out over ~0.9s, then clean up
	for i = #activeDamageNumbers, 1, -1 do
		local entry = activeDamageNumbers[i]
		entry.t += dt
		local alpha = math.clamp(entry.t / 0.9, 0, 1)
		entry.label.Position = UDim2.fromOffset(entry.label.Position.X.Offset, entry.startY - alpha * 36)
		entry.label.TextTransparency = alpha
		entry.label.TextStrokeTransparency = 0.3 + alpha * 0.7
		if alpha >= 1 then
			entry.label:Destroy()
			table.remove(activeDamageNumbers, i)
		end
	end
end)
