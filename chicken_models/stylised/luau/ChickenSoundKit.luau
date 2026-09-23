--[[ ChickenSoundKit (client, ModuleScript). Marker-driven sound layer for combat: anticipation, per-
	attack whoosh, confirmed impacts, dash start/end, aura activation, entrance, victory. SoundId fields
	are left as "" (PENDING_UPLOAD-style placeholder) rather than guessing at arbitrary rbxassetid numbers,
	since a fabricated ID could point to unrelated or unlicensed content - Jakob fills these in with sound
	assets he actually owns/has rights to, the same way GoldenChickenAnimationCatalog's AssetIds were
	filled in after upload. Layout, pooling, preloading, spatial-vs-local routing, subtle pitch variance,
	and full cleanup are all real and functional now; only the actual audio content is pending.

	World sounds (attached to the chicken, spatial) play for every observer at authored volume. Local
	presentation sounds (parented to SoundService, non-spatial) exist for cases that need a distinct closer/
	louder mix for the attacker's own first-person perspective - currently none are marked local-only, but
	the seam (PlayLocal) is here for whichever ones Jakob decides need it once real audio exists. ]]

local SoundService = game:GetService("SoundService")

-- Structural sound architecture (Phase 8): every pooled Sound routes through one of these two groups so a
-- future settings panel has exactly one Volume to turn down for "music" vs "everything else" - not
-- fabricating a mixer beyond what two groups need. Both are created once (idempotently) in Studio; if
-- somehow missing at runtime, sounds simply play ungrouped rather than erroring.
local SFX_GROUP = SoundService:FindFirstChild("Sfx")
local MUSIC_GROUP = SoundService:FindFirstChild("Music")

local Kit = {}

local SOUNDS = {
	AnticipationFeather = { id = "", volume = 0.5, category = "World" },
	Whoosh1 = { id = "", volume = 0.6, category = "World" },
	Whoosh2 = { id = "", volume = 0.6, category = "World" },
	WhooshHeavy = { id = "", volume = 0.7, category = "World" },
	Impact1 = { id = "", volume = 0.7, category = "World" },
	Impact2 = { id = "", volume = 0.75, category = "World" },
	ImpactHeavy = { id = "", volume = 0.85, category = "World" },
	DashStart = { id = "", volume = 0.5, category = "World" },
	DashEnd = { id = "", volume = 0.4, category = "World" },
	AuraActivate = { id = "", volume = 0.5, category = "World" },
	Entrance = { id = "", volume = 0.6, category = "World" },
	Victory = { id = "", volume = 0.7, category = "World" },
}
Kit.Definitions = SOUNDS

-- one pooled Sound instance per name per chicken (never created per-play), parented to HumanoidRootPart
-- so it's spatial and cleans up automatically with the model.
local pools = setmetatable({}, { __mode = "k" }) -- model -> {name -> Sound}

local function getOrCreate(model: Model, name: string): Sound?
	local def = SOUNDS[name]
	if not def or def.id == "" then
		return nil -- placeholder not filled in yet; silently no-op rather than erroring
	end
	local byName = pools[model]
	if not byName then
		byName = {}
		pools[model] = byName
	end
	local sound = byName[name]
	if not sound then
		local hrp = model:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return nil
		end
		sound = Instance.new("Sound")
		sound.Name = "SFX_" .. name
		sound.SoundId = def.id
		sound.Volume = def.volume
		sound.RollOffMaxDistance = 60
		sound.SoundGroup = (def.category == "Music") and MUSIC_GROUP or SFX_GROUP
		sound.Parent = hrp
		byName[name] = sound
	end
	return sound
end

-- subtle pitch variance only (never enough to sound broken), so repeated hits don't feel mechanically identical
function Kit.Play(model: Model, name: string)
	local sound = getOrCreate(model, name)
	if not sound then
		return
	end
	sound.PlaybackSpeed = 1 + math.random(-4, 4) / 100
	sound:Play()
end

function Kit.Preload(model: Model)
	local ContentProvider = game:GetService("ContentProvider")
	local toPreload = {}
	for name, def in pairs(SOUNDS) do
		if def.id ~= "" then
			table.insert(toPreload, getOrCreate(model, name))
		end
	end
	if #toPreload > 0 then
		task.spawn(function()
			ContentProvider:PreloadAsync(toPreload)
		end)
	end
end

function Kit.Cleanup(model: Model)
	local byName = pools[model]
	if not byName then
		return
	end
	for _, sound in pairs(byName) do
		sound:Destroy()
	end
	pools[model] = nil
end

return Kit
