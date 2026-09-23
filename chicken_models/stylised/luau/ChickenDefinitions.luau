--[[ ChickenDefinitions (shared, ReplicatedStorage.ChickenClash). Phase 6: the single source of truth for
	which chickens exist as combat characters, replacing every hardcoded "Golden Chicken" string that used
	to live directly in MatchService/PracticeService/ChickenCombatService/ChickenAnimator. Every one of
	those systems now resolves display name, combat model, preview model, animation catalog, stats, and
	combat-availability through a definition looked up here (by Id, replicated on each fighter model as the
	"ChickenDefId" attribute), instead of a string literal.

	CombatCompatible/CombatUnavailableReason for anything other than the master template is NOT hardcoded
	as a guess - it starts as nil ("not yet validated") and is only ever set by
	ChickenTemplateService/RigCompatibilityValidator actually inspecting the real ServerStorage rig at
	server start. The client never runs that validator (ServerStorage doesn't replicate), so on the client
	a non-master entry's fields reflect whatever value the last server->client attribute/remote sync gave
	it - today, Phase 6 does not yet replicate validation results to clients (no chicken-selection UI exists
	yet; that is a later pass), so this module is authoritative on the server only. Do not read
	CombatCompatible client-side and treat it as ground truth until that replication exists. ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ccFolder = script.Parent
local visuals = ReplicatedStorage:WaitForChild("ChickenVisuals")

local GoldenCatalog = require(ccFolder:WaitForChild("GoldenChickenAnimationCatalog"))

local ChickenDefinitions = {}

-- Id -> definition. CombatModelName/PreviewModel resolve by NAME into ServerStorage.CombatChickens /
-- ReplicatedStorage.ChickenVisuals rather than storing a direct ServerStorage instance reference, since
-- ServerStorage does not replicate and this module is required on both client and server.
ChickenDefinitions.List = {
	Golden = {
		Id = "Golden",
		DisplayName = "Golden Chicken",
		CombatModelName = "Golden Chicken",
		PreviewModel = visuals:FindFirstChild("Golden Chicken"),
		AnimationCatalog = GoldenCatalog,
		AnimationSourceId = "Golden", -- whose catalog/marker timings this definition's combat actually plays
		Stats = {
			MaxHealth = 100,
			AttackDamage = { Attack1 = 8, Attack2 = 10, Attack3 = 18 },
			DashCooldown = 2.5,
			DashDistance = 24,
		},
		-- small data-driven adjustments (Phase 6 step 7) - neutral defaults, real code paths (see
		-- ChickenCombatService/ChickenAnimator), not decorative fields.
		HitboxScale = 1.0,
		PlaybackSpeedMultiplier = 1.0,
		-- reserved for future per-chicken camera/VFX/pose tuning once a second combat-compatible chicken
		-- actually exists to verify them against live - deliberately NOT wired into the camera controller
		-- or Aura yet, so as not to claim tested behavior that was never run.
		CameraFOVOffset = 0,
		VFXTheme = "Golden",
		RigVersion = "master-v1-verified",
		IsMasterTemplate = true,
		-- the one hand-verified, live-tested rig; never runtime-validated against itself.
		CombatCompatible = true,
		CombatUnavailableReason = nil,
	},

	Red = {
		Id = "Red",
		DisplayName = "Red Chicken",
		CombatModelName = "Red Chicken",
		PreviewModel = visuals:FindFirstChild("Red Chicken"),
		-- only actually used if RigCompatibilityValidator proves the rig can safely play it - see
		-- ChickenTemplateService, which runs the real check at server start.
		AnimationCatalog = GoldenCatalog,
		AnimationSourceId = "Golden",
		Stats = {
			MaxHealth = 100,
			AttackDamage = { Attack1 = 8, Attack2 = 10, Attack3 = 18 },
			DashCooldown = 2.5,
			DashDistance = 24,
		},
		HitboxScale = 1.0,
		PlaybackSpeedMultiplier = 1.0,
		CameraFOVOffset = 0,
		VFXTheme = "Golden",
		RigVersion = "unvalidated",
		IsMasterTemplate = false,
		-- filled in by ChickenTemplateService/RigCompatibilityValidator at server start; nil until then.
		CombatCompatible = nil,
		CombatUnavailableReason = nil,
	},
}

function ChickenDefinitions.Get(id: string)
	return ChickenDefinitions.List[id]
end

-- Server-only: RigCompatibilityValidator's bootstrap calls this once per non-master definition.
function ChickenDefinitions.SetValidationResult(id: string, compatible: boolean, reason: string?, rigVersion: string?)
	local def = ChickenDefinitions.List[id]
	if not def then
		return
	end
	def.CombatCompatible = compatible
	def.CombatUnavailableReason = reason
	if rigVersion then
		def.RigVersion = rigVersion
	end
end

ChickenDefinitions.DefaultId = "Golden"

-- Placeholder for a real per-player equipped-chicken lookup - no chicken-selection UI/data exists yet
-- (that is a later pass, per the portal-practice-range chicken-selection station). Always returns the
-- default (master) definition's Id today; written as its own function rather than inlined so every
-- caller (MatchService, PracticeService) already goes through one seam that a real selection system can
-- replace later without touching those callers again.
function ChickenDefinitions.ResolveForPlayer(_player: Player?): string
	return ChickenDefinitions.DefaultId
end

return ChickenDefinitions
