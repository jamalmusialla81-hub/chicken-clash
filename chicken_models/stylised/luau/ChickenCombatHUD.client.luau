--[[ ChickenCombatHUD (LocalScript, StarterPlayerScripts). First-person-safe combat HUD: a small centre
	reticle, local health bar, dash cooldown indicator, and a reduced-motion toggle. Shown only while
	ChickenCombatCameraController is in CombatFirstPerson; hidden the instant that state ends, and hides
	the collection/menu UI (StarterGui.Main, if present) during combat so nothing competes with the reticle
	for screen centre. Never trusts local values for health/cooldown/damage - it only DISPLAYS whatever the
	server has already replicated via attributes; it computes nothing authoritative itself. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Controller = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenCombatCameraController"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ChickenCombatHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 50
screenGui.Enabled = false
screenGui.Parent = playerGui

-- centre reticle: small, readable against light/dark backgrounds via a dark outline + bright core,
-- scales from a fixed offset from the CENTRE anchor point so it stays centred on any resolution/aspect
-- ratio (ultrawide included) rather than being anchored to a corner.
local reticle = Instance.new("Frame")
reticle.Name = "Reticle"
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Position = UDim2.fromScale(0.5, 0.5)
reticle.Size = UDim2.fromOffset(14, 14)
reticle.BackgroundTransparency = 1
reticle.Parent = screenGui

local function reticleDot(offsetX, offsetY, size, color, transparency)
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
	dot.Size = UDim2.fromOffset(size, size)
	dot.BackgroundColor3 = color
	dot.BackgroundTransparency = transparency
	dot.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	dot.Parent = reticle
	return dot
end

reticleDot(0, 0, 10, Color3.new(0, 0, 0), 0.55) -- dark outline halo for contrast on light backgrounds
local core = reticleDot(0, 0, 5, Color3.fromRGB(255, 226, 150), 0.15) -- warm gold core matching the identity

-- hit-confirmation: brief scale/opacity pulse, only ever played from the server-confirmed hit remote,
-- never from a local guess at whether a swing landed.
local hitConfirmedRemote = ReplicatedStorage:WaitForChild("ChickenHitConfirmed")
local pulseT = 0
hitConfirmedRemote.OnClientEvent:Connect(function(kind: string)
	if kind == "Dealt" and screenGui.Enabled and Controller.hitMarkerEnabled ~= false then
		pulseT = 1
	end
end)

-- health/dash bars: kept near the edges, never large or bottom-centre, so the opponent's silhouette in
-- the middle of the screen is never competed with.
local healthBar = Instance.new("Frame")
healthBar.Name = "HealthBar"
healthBar.AnchorPoint = Vector2.new(0, 1)
healthBar.Position = UDim2.new(0, 24, 1, -24)
healthBar.Size = UDim2.fromOffset(160, 10)
healthBar.BackgroundColor3 = Color3.fromRGB(20, 16, 10)
healthBar.BorderSizePixel = 0
healthBar.Parent = screenGui
local healthFill = Instance.new("Frame")
healthFill.Name = "Fill"
healthFill.BackgroundColor3 = Color3.fromRGB(214, 60, 60)
healthFill.BorderSizePixel = 0
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.Parent = healthBar

local dashIcon = Instance.new("Frame")
dashIcon.Name = "DashCooldown"
dashIcon.AnchorPoint = Vector2.new(1, 1)
dashIcon.Position = UDim2.new(1, -24, 1, -24)
dashIcon.Size = UDim2.fromOffset(40, 40)
dashIcon.BackgroundColor3 = Color3.fromRGB(255, 214, 96)
dashIcon.BorderSizePixel = 0
dashIcon.Parent = screenGui
local dashCorner = Instance.new("UICorner")
dashCorner.CornerRadius = UDim.new(1, 0)
dashCorner.Parent = dashIcon
local dashCooldownOverlay = Instance.new("Frame")
dashCooldownOverlay.Name = "CooldownOverlay"
dashCooldownOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
dashCooldownOverlay.BackgroundTransparency = 0.35
dashCooldownOverlay.Size = UDim2.fromScale(1, 0)
dashCooldownOverlay.AnchorPoint = Vector2.new(0, 1)
dashCooldownOverlay.Position = UDim2.fromScale(0, 1)
dashCooldownOverlay.BorderSizePixel = 0
dashCooldownOverlay.Parent = dashIcon
local dashOverlayCorner = Instance.new("UICorner")
dashOverlayCorner.CornerRadius = UDim.new(1, 0)
dashOverlayCorner.Parent = dashCooldownOverlay

local reducedMotionButton = Instance.new("TextButton")
reducedMotionButton.Name = "ReducedMotionToggle"
reducedMotionButton.AnchorPoint = Vector2.new(1, 0)
reducedMotionButton.Position = UDim2.new(1, -16, 0, 16)
reducedMotionButton.Size = UDim2.fromOffset(140, 28)
reducedMotionButton.BackgroundColor3 = Color3.fromRGB(20, 16, 10)
reducedMotionButton.BackgroundTransparency = 0.3
reducedMotionButton.TextColor3 = Color3.fromRGB(230, 230, 230)
reducedMotionButton.Font = Enum.Font.GothamMedium
reducedMotionButton.TextSize = 13
reducedMotionButton.Text = "Reduced Motion: Off"
reducedMotionButton.Parent = screenGui
reducedMotionButton.MouseButton1Click:Connect(function()
	Controller.SetReducedMotion(not Controller.reducedMotion)
	reducedMotionButton.Text = "Reduced Motion: " .. (Controller.reducedMotion and "On" or "Off")
end)

-- Phase 3 combat settings: small cycle-buttons stacked under Reduced Motion, same visual language,
-- shown only during combat (this HUD's own existing show/hide already handles that) rather than a
-- separate always-on settings screen - keeps this purely additive to the working legacy Settings menu
-- (StarterGui's "old" Settings frame, opened elsewhere for music/graphics) instead of risking changes
-- to a UI this pass never needed to touch.
local function settingsButton(order, text)
	local b = reducedMotionButton:Clone()
	b.Name = "Setting_" .. order
	b.Position = UDim2.new(1, -16, 0, 16 + order * 32)
	b.Text = text
	b.Parent = screenGui
	return b
end

local SHAKE_LEVELS = { 0, 0.5, 1, 1.5, 2 }
local shakeIndex = 3
local shakeButton = settingsButton(1, "Shake: Normal")
shakeButton.MouseButton1Click:Connect(function()
	shakeIndex = (shakeIndex % #SHAKE_LEVELS) + 1
	Controller.SetShakeStrength(SHAKE_LEVELS[shakeIndex])
	local pct = math.floor(SHAKE_LEVELS[shakeIndex] * 100)
	shakeButton.Text = "Shake: " .. pct .. "%"
end)

local FOV_LEVELS = { -8, -4, 0, 4, 8 }
local fovIndex = 3
local fovButton = settingsButton(2, "FOV Adjust: 0")
fovButton.MouseButton1Click:Connect(function()
	fovIndex = (fovIndex % #FOV_LEVELS) + 1
	Controller.SetFOVAdjust(FOV_LEVELS[fovIndex])
	fovButton.Text = "FOV Adjust: " .. (FOV_LEVELS[fovIndex] >= 0 and "+" or "") .. FOV_LEVELS[fovIndex]
end)

local hitMarkerButton = settingsButton(3, "Hit Marker: On")
hitMarkerButton.MouseButton1Click:Connect(function()
	Controller.SetHitMarkerEnabled(not Controller.hitMarkerEnabled)
	hitMarkerButton.Text = "Hit Marker: " .. (Controller.hitMarkerEnabled and "On" or "Off")
end)

local damageNumbersButton = settingsButton(4, "Damage Numbers: On")
damageNumbersButton.MouseButton1Click:Connect(function()
	Controller.SetDamageNumbersEnabled(not Controller.damageNumbersEnabled)
	damageNumbersButton.Text = "Damage Numbers: " .. (Controller.damageNumbersEnabled and "On" or "Off")
end)

local CROSSHAIR_LEVELS = { 0.5, 0.75, 1, 1.5, 2 }
local crosshairIndex = 3
local crosshairButton = settingsButton(5, "Crosshair: 100%")
crosshairButton.MouseButton1Click:Connect(function()
	crosshairIndex = (crosshairIndex % #CROSSHAIR_LEVELS) + 1
	Controller.SetCrosshairScale(CROSSHAIR_LEVELS[crosshairIndex])
	crosshairButton.Text = "Crosshair: " .. math.floor(CROSSHAIR_LEVELS[crosshairIndex] * 100) .. "%"
end)

-- health reads from a "Health"/"MaxHealth" attribute on the chicken IF the real health system sets one;
-- until that system exists this simply shows full health rather than fabricating a number.
local function updateHealthBar()
	local chicken = Controller.chicken
	local health = chicken and chicken:GetAttribute("Health")
	local maxHealth = chicken and chicken:GetAttribute("MaxHealth")
	local frac = 1
	if health and maxHealth and maxHealth > 0 then
		frac = math.clamp(health / maxHealth, 0, 1)
	end
	healthFill.Size = UDim2.fromScale(frac, 1)
end

local function updateDashCooldown()
	local chicken = Controller.chicken
	local readyAt = chicken and chicken:GetAttribute("DashReadyAt")
	if not readyAt then
		dashCooldownOverlay.Size = UDim2.fromScale(1, 0)
		return
	end
	-- server and client os.clock() are NOT synchronized - GetServerTimeNow() is, and matches what the
	-- server used to compute DashReadyAt.
	local remaining = readyAt - workspace:GetServerTimeNow()
	local totalCooldown = chicken:GetAttribute("DashCooldownDuration") or 2.5
	local frac = math.clamp(remaining / totalCooldown, 0, 1)
	dashCooldownOverlay.Size = UDim2.fromScale(1, frac)
end

RunService.RenderStepped:Connect(function(dt)
	local shouldShow = Controller.state == Controller.States.CombatFirstPerson
	if screenGui.Enabled ~= shouldShow then
		screenGui.Enabled = shouldShow
		local mainUI = playerGui:FindFirstChild("Main")
		if mainUI then
			mainUI.Enabled = not shouldShow
		end
	end
	if not shouldShow then
		return
	end
	updateHealthBar()
	updateDashCooldown()
	local scale = Controller.crosshairScale or 1
	reticle.Size = UDim2.fromOffset(14 * scale, 14 * scale)
	if pulseT > 0 then
		pulseT = math.max(pulseT - dt * 4, 0)
		core.Size = UDim2.fromOffset((5 + pulseT * 6) * scale, (5 + pulseT * 6) * scale)
		core.BackgroundTransparency = 0.15 + (1 - pulseT) * 0
	else
		core.Size = UDim2.fromOffset(5 * scale, 5 * scale)
	end
end)
