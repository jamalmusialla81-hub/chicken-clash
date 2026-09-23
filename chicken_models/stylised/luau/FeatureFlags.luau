--[[ FeatureFlags (shared, ReplicatedStorage.ChickenClash). The single, central place any feature that
	isn't ready for normal players yet gets gated through - starting with Ranked, which has an island,
	bridge, and signpost already built in the hub but no actual matchmaking/rating logic behind it yet.

	Flip a flag here and restart the server to change behavior; nothing else in the codebase should ever
	hardcode a feature-availability check that belongs here instead. ]]

local FeatureFlags = {}

-- Ranked has no queue/rating logic at all yet (confirmed via a full grep of every script: zero remotes,
-- zero prompts wired to it - the hub island is a pure "coming soon" visual). Disabling it here hides the
-- island/bridge/signpost from normal players (see RankedFeatureGate) without deleting any of it, so
-- turning it back on later is just flipping this back to true and restarting the server.
FeatureFlags.RankedEnabled = false

return FeatureFlags
