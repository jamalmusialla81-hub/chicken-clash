--[[ UIStateController (ModuleScript, ReplicatedStorage.ChickenClash). Single source of truth for which
	top-level UI mode is active - Lobby, Practice, Match, or Results. Every HUD script already reads
	MatchState/the camera controller's state independently (and mostly gated itself correctly); the one
	real gap this closes is ChickenClashUI, whose ScreenGui had NO gate at all and stayed visible during
	Practice/Match, which is exactly the "too many unrelated interfaces visible simultaneously" complaint.
	This does not replace any HUD's own internal panel logic - it just gives every script ONE place to ask
	"which top-level screen should be showing" instead of each re-deriving it independently. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Controller = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenCombatCameraController"))

local UIStateController = {}
UIStateController.Mode = "Lobby"

local listeners = {}

function UIStateController.OnModeChanged(fn)
	table.insert(listeners, fn)
	return {
		Disconnect = function()
			local i = table.find(listeners, fn)
			if i then
				table.remove(listeners, i)
			end
		end,
	}
end

function UIStateController.GetMode(): string
	return UIStateController.Mode
end

-- "Results"/"Returning" cover the post-match results panel; every other real-match MatchService state
-- (Preparing/Entrance/Countdown/Active/RoundEnd) maps to "Match". "Cutscene" now has a real signal to
-- read: ChickenCombatCameraController.state reaches Controller.States.Cutscene during the
-- Entrance/Victory cinematics (previously documented here as "no signal exists yet, not fabricated" -
-- the camera consolidation pass added the real state this reads).
local RESULT_STATES = { Results = true, Returning = true }
local MATCH_STATES = { Preparing = true, Entrance = true, Countdown = true, Active = true, RoundEnd = true }

local function computeMode(): string
	if Controller.state == Controller.States.Cutscene then
		return "Cutscene"
	end
	local matchState = player:GetAttribute("MatchState")
	if RESULT_STATES[matchState] then
		return "Results"
	elseif MATCH_STATES[matchState] then
		return "Match"
	elseif matchState == "Practice" then
		return "Practice"
	end
	return "Lobby"
end

local function refresh()
	local mode = computeMode()
	if mode ~= UIStateController.Mode then
		UIStateController.Mode = mode
		for _, fn in ipairs(listeners) do
			task.spawn(fn, mode)
		end
	end
end

player:GetAttributeChangedSignal("MatchState"):Connect(refresh)

-- The camera controller has no state-changed event (adding one would mean touching every one of its
-- ~10 internal state-assignment sites for a state - Cutscene - that only lasts ~1-2 seconds); a light
-- 10Hz poll is a fair trade against that risk since nothing here needs sub-frame precision.
task.spawn(function()
	while true do
		refresh()
		task.wait(0.1)
	end
end)

refresh()

return UIStateController

