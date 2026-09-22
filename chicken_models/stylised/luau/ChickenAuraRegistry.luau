--[[ ChickenAuraRegistry (client-only, shared). ChickenAnimator is a self-contained LocalScript with no
	exported API; this tiny registry is the one deliberate seam other local scripts (currently just
	ChickenCombatCameraController, for the two-context idle-aura reduction) can use to reach a chicken's
	live Aura instance without ChickenAnimator itself needing to become a full module. ]]

local Registry = {}
local byModel = setmetatable({}, { __mode = "k" })

function Registry.Set(model: Model, aura)
	byModel[model] = aura
end

function Registry.Clear(model: Model)
	byModel[model] = nil
end

function Registry.Get(model: Model)
	return byModel[model]
end

return Registry
