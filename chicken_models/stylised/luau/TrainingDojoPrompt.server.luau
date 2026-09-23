--[[ TrainingDojoPrompt (server, Script). Wires the hub-side Training Dojo's pre-existing ProximityPrompt
	to PracticeService. This is now a PORTAL: PracticeService.Enter spawns the player's fighter at the
	large, dedicated Practice Range (workspace.Map.PracticeRange, far from the hub/arenas), not on this
	small island - the dojo itself stays as hub flavor/backdrop (its bamboo/lanterns/targets are just
	decoration; they were never wired to a live dummy). Same toggle pattern as ArenaQueuePrompt: trigger
	once to enter (teleports to the range), trigger again to leave (only relevant if triggered again from
	here, which can't normally happen since the player is no longer standing on this island once in
	practice - real day-to-day exit happens via the range's own return gate, see
	PracticeRangePrompts). ]]

local ServerScriptService = game:GetService("ServerScriptService")
local PracticeService = require(ServerScriptService.Combat:WaitForChild("PracticeService"))
local MatchService = require(ServerScriptService.Combat:WaitForChild("MatchService"))

local prompt = workspace.Map.Training.TrainingDojo.Dojo.DojoPrompt.ComingSoonPrompt
prompt.ActionText = "Enter Practice Range"
prompt.ObjectText = "Practice Portal"

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
