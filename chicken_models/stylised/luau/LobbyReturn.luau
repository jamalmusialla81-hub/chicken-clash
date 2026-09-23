--[[ LobbyReturn (server). The ONE authoritative way any server system restores a player's normal hub
	avatar - MatchService.teardownMatch and PracticeService.Exit both call this instead of each calling
	player:LoadCharacter() independently, so there is exactly one code path deciding "how does a player
	get their real body back", never two slightly-different copies that can drift or race.

	Tearing down the fighter/dummy and clearing Match/Practice-specific attributes stays the CALLER's job
	(a fighter model is owned by whichever service spawned it) - this module owns everything from "load
	the normal avatar" onward: LoadCharacter, waiting for a real Humanoid/HumanoidRootPart to actually
	exist before touching them, and a defensive fallback pivot for the rare case no SpawnLocation could be
	found (matches HubSafety's own known-safe fallback position). ]]

local LobbyReturn = {}

local HUB_SPAWN_FALLBACK = Vector3.new(0, 6, 24) -- same fallback HubSafety.returnToHub already uses

function LobbyReturn.RestoreAvatar(player: Player)
	if not player.Parent then
		return
	end
	player:LoadCharacter()
	local character = player.Character
	if not character then
		warn(("LobbyReturn: %s has no Character after LoadCharacter()"):format(player.Name))
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 5)
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if not humanoid or not hrp then
		warn(("LobbyReturn: %s's avatar never got a Humanoid/HumanoidRootPart after LoadCharacter()"):format(player.Name))
		return
	end
	-- defensive only: a real SpawnLocation should already have placed the avatar correctly. If it somehow
	-- landed far from the hub (no SpawnLocation found, or one placed outside the normal play area), pull
	-- it back to a known-safe point rather than leaving the player stranded.
	if (hrp.Position - HUB_SPAWN_FALLBACK).Magnitude > 300 then
		character:PivotTo(CFrame.new(HUB_SPAWN_FALLBACK))
	end
end

return LobbyReturn
