--[[ ArenaQueuePrompt (server, Script). Wires the ArenaPortal's pre-existing "Coming Soon" ProximityPrompt
	(Workspace.Map.Hub.ArenaPortal.Portal.PromptHolder.ComingSoonPrompt) to real matchmaking now that
	MatchService exists. ProximityPrompt.Triggered already fires on the server for any client that
	activates it - no custom RemoteEvent needed for the physical portal. The presentation-rebuild's Lobby
	UI also needs a "Quick Match" button that does the exact same toggle without walking to the portal, so
	a QuickMatchRequest RemoteEvent shares the same toggleQueue function - one authoritative queue/dequeue
	path for both entry points, never two competing implementations. ]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchService = require(ServerScriptService.Combat:WaitForChild("MatchService"))

local prompt = workspace.Map.Hub.ArenaPortal.Portal.PromptHolder.ComingSoonPrompt
prompt.ActionText = "Queue for Battle"
prompt.ObjectText = "Quick Match"

local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local quickMatchRemote = combatFolder:FindFirstChild("QuickMatchRequest")
if not quickMatchRemote then
	quickMatchRemote = Instance.new("RemoteEvent")
	quickMatchRemote.Name = "QuickMatchRequest"
	quickMatchRemote.Parent = combatFolder
end

-- Re-triggering while already queued/in a match toggles the queue off, so both entry points work as
-- "join queue" and "leave queue".
local function toggleQueue(player: Player)
	if MatchService.IsInMatch(player) then
		return -- already fighting; neither entry point should pull them out mid-match
	end
	if player:GetAttribute("MatchState") == "Queued" then
		MatchService.Dequeue(player)
	else
		MatchService.Queue(player)
	end
end

prompt.Triggered:Connect(toggleQueue)
quickMatchRemote.OnServerEvent:Connect(function(player: Player)
	toggleQueue(player)
end)
