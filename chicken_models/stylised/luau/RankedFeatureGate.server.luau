--[[ RankedFeatureGate (server, Script). Reads FeatureFlags.RankedEnabled once at server start and, if
	disabled, moves the Ranked hub island, its bridge, and its signpost out of Workspace into
	ServerStorage.DisabledFeatures.Ranked - fully intact, never destroyed, so re-enabling later is just
	flipping the flag back to true and restarting the server (or, if this game is ever kept running
	without a restart, reparenting them back from ServerStorage.DisabledFeatures.Ranked).

	Ranked has no remotes, no ProximityPrompt, and no server logic anywhere in this codebase (confirmed by
	grepping every script) - it is a pure "coming soon" visual with nothing a player could invoke even if
	the island were left visible. Moving it out of Workspace is still the correct fix: a signpost and
	bridge pointing at a "coming soon" island reads as an unfinished/broken corner of the hub, which is
	exactly what this pass is meant to remove from normal players' view. ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local FeatureFlags = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("FeatureFlags"))

if FeatureFlags.RankedEnabled then
	return
end

local hub = workspace.Map.Hub
local ranked = hub:FindFirstChild("Ranked")
local bridgeRanked = hub.Bridges:FindFirstChild("Bridge_Ranked")
local sign = hub.Center.Signposts:FindFirstChild("Sign_RANKED")

if not ranked and not bridgeRanked and not sign then
	return -- already disabled (e.g. a previous run of this script already moved everything)
end

local disabledFolder = ServerStorage:FindFirstChild("DisabledFeatures")
if not disabledFolder then
	disabledFolder = Instance.new("Folder")
	disabledFolder.Name = "DisabledFeatures"
	disabledFolder.Parent = ServerStorage
end
local rankedFolder = Instance.new("Folder")
rankedFolder.Name = "Ranked"
rankedFolder.Parent = disabledFolder

if ranked then ranked.Parent = rankedFolder end
if bridgeRanked then bridgeRanked.Parent = rankedFolder end
if sign then sign.Parent = rankedFolder end
