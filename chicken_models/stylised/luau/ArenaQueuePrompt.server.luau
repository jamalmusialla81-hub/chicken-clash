--[[ ArenaQueuePrompt (server, Script). Wires the ArenaPortal's pre-existing "Coming Soon" ProximityPrompt
	(Workspace.Map.Hub.ArenaPortal.Portal.PromptHolder.ComingSoonPrompt) to real matchmaking now that
	MatchService exists. ProximityPrompt.Triggered already fires on the server for any client that
	activates it - no custom RemoteEvent needed. Re-triggering while already queued/in a match toggles the
	queue off, so the same prompt works as both "join queue" and "leave queue". ]]

local ServerScriptService = game:GetService("ServerScriptService")
local MatchService = require(ServerScriptService.Combat:WaitForChild("MatchService"))

local prompt = workspace.Map.Hub.ArenaPortal.Portal.PromptHolder.ComingSoonPrompt
prompt.ActionText = "Queue for Battle"
prompt.ObjectText = "Arena"

prompt.Triggered:Connect(function(player: Player)
	if MatchService.IsInMatch(player) then
		return -- already fighting; the prompt shouldn't pull them out mid-match
	end
	if player:GetAttribute("MatchState") == "Queued" then
		MatchService.Dequeue(player)
	else
		MatchService.Queue(player)
	end
end)
