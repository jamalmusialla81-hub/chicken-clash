--[[ TrainingDojoPrompt (server, Script). Wires the TrainingDojo's pre-existing "Coming Soon"
	ProximityPrompt to PracticeService now that a real practice mode exists. Same toggle pattern as
	ArenaQueuePrompt: trigger once to enter, trigger again to leave. ]]

local ServerScriptService = game:GetService("ServerScriptService")
local PracticeService = require(ServerScriptService.Combat:WaitForChild("PracticeService"))
local MatchService = require(ServerScriptService.Combat:WaitForChild("MatchService"))

local prompt = workspace.Map.Training.TrainingDojo.Dojo.DojoPrompt.ComingSoonPrompt
prompt.ActionText = "Enter Practice"
prompt.ObjectText = "Training Dojo"

prompt.Triggered:Connect(function(player: Player)
	if MatchService.IsInMatch(player) then
		return -- don't let someone pull themselves into practice mid real-match
	end
	if PracticeService.IsInPractice(player) then
		PracticeService.Exit(player)
	else
		PracticeService.Enter(player)
	end
end)
