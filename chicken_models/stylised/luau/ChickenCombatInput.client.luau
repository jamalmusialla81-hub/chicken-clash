--[[ ChickenCombatInput (client, LocalScript). The central input abstraction for combat - one place that
	turns a raw device event into an attack/dash REQUEST, never combat logic itself. Originally (Phase 1)
	this only had to prove a real input path existed at all (nothing fired the combat remotes before this
	pass); Phase 5 fills it out to cover mouse/keyboard, gamepad, and dedicated mobile touch buttons, plus
	a device-switch-aware on-screen hint, instead of scattering per-device key checks across other scripts.

	Dash direction is the camera's flat look vector (first-person combat camera already faces the fight),
	sanitized again server-side regardless. Requests are only SENT while this client's own MatchState
	attribute reads "Active" or "Practice" (cheap local gate for responsiveness/UI feedback only - the
	server enforces the real gate independently via MatchService/PracticeService.CanPlayerFight, so a
	spoofed local attribute cannot bypass anything, it can only make requests the server will just as
	cleanly reject).

	Mobile buttons are positioned bottom-right, well above Roblox's own default jump button and this
	project's DashCooldown HUD icon (also bottom-right, see ChickenCombatHUD) - never over the bottom-left
	movement thumbstick. Block/parry has no binding on any device: Phase 3 left block/parry unbuilt, so
	there is nothing to bind it to yet; a binding will be added here alongside the mechanic itself, not
	before.

	Hardware note: only Studio's device emulation was available to verify this - real touch responsiveness,
	controller haptics, and exact thumb ergonomics on physical hardware were NOT tested and are not claimed
	here (see PHASE5 notes in the final report). ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local attackRemote = combatFolder:WaitForChild("AttackRequest")
local dashRemote = combatFolder:WaitForChild("DashRequest")
local Controller = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenCombatCameraController"))

local function isActive(): boolean
	local state = player:GetAttribute("MatchState")
	if state ~= "Active" and state ~= "Practice" then
		return false
	end
	-- a settings/selection panel owns the mouse right now - attacks/dashes must not fire while a player is
	-- trying to click a UI button, per the menu-state contract in ChickenCombatCameraController.
	return not Controller.IsMenuOpen()
end

local function requestAttack()
	if isActive() then
		attackRemote:FireServer()
	end
end

local function requestDash()
	if not isActive() then
		return
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	dashRemote:FireServer(flat.Magnitude > 0.01 and flat.Unit or nil)
end

--============================== mouse/keyboard + gamepad ==============================--
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		requestAttack()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		requestDash()
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		requestAttack()
	elseif input.KeyCode == Enum.KeyCode.ButtonX then
		requestDash()
	end
	-- Menu/cancel: deliberately NOT intercepted here. Escape/ButtonStart already open Roblox's own native
	-- menu on every device without any code in this script, and combat has no separate pause state of its
	-- own to cancel into - overriding it would only risk breaking that default, working behavior.
end)

--============================== mobile: dedicated touch buttons ==============================--
-- Replaces an earlier "any touch = attack" fallback (Phase 1) that made moving the camera on a touch
-- screen accidentally throw punches - a real, separate, clearly-labelled button per action is the correct
-- fix, not a broader touch listener.
local touchGui = Instance.new("ScreenGui")
touchGui.Name = "CombatTouchControls"
touchGui.ResetOnSpawn = false
touchGui.IgnoreGuiInset = true
touchGui.Enabled = UserInputService.TouchEnabled
touchGui.Parent = playerGui

local function touchButton(text, xOffset, yOffset, callback)
	local b = Instance.new("TextButton")
	b.Name = "Touch_" .. text
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, xOffset, 1, yOffset)
	b.Size = UDim2.fromOffset(76, 76) -- comfortably large touch target, well above WCAG/mobile minimums
	b.BackgroundColor3 = Color3.fromRGB(20, 16, 10)
	b.BackgroundTransparency = 0.25
	b.TextColor3 = Color3.fromRGB(255, 214, 96)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = touchGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 214, 96)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.4
	stroke.Parent = b
	-- press feedback: same idea as desktop hover/press states, just touch-driven
	b.MouseButton1Down:Connect(function() b.BackgroundTransparency = 0 end)
	b.MouseButton1Up:Connect(function() b.BackgroundTransparency = 0.25 end)
	b.MouseButton1Click:Connect(callback)
	return b
end

-- stacked bottom-right, clear of the bottom-left movement thumbstick and well above the default jump
-- button / this project's DashCooldown HUD icon (both also bottom-right, but much closer to the corner).
touchButton("ATTACK", -20, -220, requestAttack)
touchButton("DASH", -110, -220, requestDash)

--============================== adaptive input hint (device-switch aware) ==============================--
-- Small, unobtrusive label near the reticle showing the CURRENT device's attack bind - never trusted for
-- anything, purely a readability aid, and updates live if the player switches input device mid-session
-- (e.g. picks up a controller while playing on desktop).
local hintGui = Instance.new("ScreenGui")
hintGui.Name = "InputHint"
hintGui.ResetOnSpawn = false
hintGui.IgnoreGuiInset = true
hintGui.DisplayOrder = 47
hintGui.Parent = playerGui

local hintLabel = Instance.new("TextLabel")
hintLabel.AnchorPoint = Vector2.new(0.5, 0)
hintLabel.Position = UDim2.new(0.5, 0, 0.5, 40)
hintLabel.Size = UDim2.fromOffset(220, 18)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 12
hintLabel.TextColor3 = Color3.fromRGB(210, 205, 195)
hintLabel.TextTransparency = 0.3
hintLabel.Text = ""
hintLabel.Parent = hintGui

local function updateHint()
	local lastType = UserInputService:GetLastInputType()
	local isGamepad = lastType and lastType.Name:find("Gamepad") ~= nil
	local isTouch = lastType == Enum.UserInputType.Touch or UserInputService.TouchEnabled
	touchGui.Enabled = isTouch
	if isTouch then
		hintLabel.Text = "Tap ATTACK / DASH"
	elseif isGamepad then
		hintLabel.Text = "R2 Attack   •   X Dash"
	else
		hintLabel.Text = "Click Attack   •   Shift Dash"
	end
end

-- Two independent triggers for "handle device switching during a session": LastInputTypeChanged fires on
-- any real input event (mouse click, gamepad button, a real touch) and covers the common case; the
-- TouchEnabled property-changed signal is the correct, direct fix for hybrid hardware whose touch
-- capability itself can change after this script has already loaded (found while testing with Studio's
-- device simulator, which flips this same capability flag without firing a synthetic input event first).
UserInputService.LastInputTypeChanged:Connect(updateHint)
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(updateHint)
updateHint()
