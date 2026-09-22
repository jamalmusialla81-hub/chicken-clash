--[[ ChickenCombatInput (client, LocalScript). The missing input path: previously nothing fired the
	combat RemoteEvents at all (every attack/dash in this project's history was triggered by a script
	directly calling the server module). This is intentionally a thin, central input abstraction per the
	"one central input abstraction rather than scattering raw key checks" rule - mouse/keyboard and a first
	gamepad pass live here; it never runs any combat logic itself, it only requests.

	Dash direction is the camera's flat look vector (first-person combat camera already faces the fight),
	sanitized again server-side regardless. Requests are only SENT while this client's own MatchState
	attribute reads "Active" (cheap local gate for responsiveness/UI feedback only - the server enforces the
	real gate independently via MatchService.CanPlayerFight, so a spoofed local attribute cannot bypass
	anything, it can only make requests that the server will just as cleanly reject). ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local attackRemote = combatFolder:WaitForChild("AttackRequest")
local dashRemote = combatFolder:WaitForChild("DashRequest")

local function isActive(): boolean
	local state = player:GetAttribute("MatchState")
	return state == "Active" or state == "Practice"
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

-- mouse/keyboard
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		requestAttack()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		requestDash()
	elseif input.UserInputType == Enum.UserInputType.Touch then
		requestAttack() -- bare-minimum touch fallback until Phase 5 adds dedicated mobile buttons
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		requestAttack()
	elseif input.KeyCode == Enum.KeyCode.ButtonX then
		requestDash()
	end
end)
