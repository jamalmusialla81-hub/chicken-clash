--[[ MatchCameraBridge (client, LocalScript). Fixes a real race found during MatchService integration
	testing: ChickenCombatCameraController's own "best-effort auto-wiring" (CollectionService tag +
	Action-attribute-changed) only reacts to FUTURE attribute changes - if the server tags a chicken
	CombatChicken and sets Action="Entrance" in the same fast burst (as MatchService does), the client can
	receive both nearly together and miss the transition entirely, because GetAttributeChangedSignal never
	fires retroactively for a value that was already set before the listener connected. Confirmed live: a
	real match reached MatchState=Active with the chicken correctly auto-wired (SetLocalChicken ran) but the
	camera controller was still stuck in "Lobby" - exactly this race.

	The controller's own header comment anticipated this exact fix: "call SetLocalChicken(model) ... then
	drive transitions with EnterEntrance()/EnterVictory()/ReturnToLobby() ... from wherever the authoritative
	match/round system lives" - this script is that bridge. The pre-existing auto-wiring is left in place as
	a harmless redundant fallback (SetLocalChicken/state transitions are idempotent). ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Controller = require(ReplicatedStorage.ChickenClash.ChickenCombatCameraController)
local player = Players.LocalPlayer

local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local directive = combatFolder:FindFirstChild("MatchCameraDirective")
if not directive then
	directive = Instance.new("RemoteEvent")
	directive.Name = "MatchCameraDirective"
	directive.Parent = combatFolder
end

directive.OnClientEvent:Connect(function(action: string, model: Model?)
	if action == "SetChicken" then
		Controller.SetLocalChicken(model)
	elseif action == "EnterEntrance" then
		Controller.SetLocalChicken(model)
		Controller.EnterEntrance()
	elseif action == "EnterVictory" then
		Controller.EnterVictory()
	elseif action == "ReturnToLobby" then
		Controller.ReturnToLobby()
	end
end)
