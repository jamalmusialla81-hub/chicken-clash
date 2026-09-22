--[[ Server side. The SERVER owns what an active chicken is doing. Clients only read the replicated "Action" attribute
	and render it; they cannot change it (client-side attribute writes do not replicate) and no combat number lives here. ]]
local CollectionService = game:GetService("CollectionService")

local ChickenStateService = {}
local ALLOWED = {
	Idle = true, Walk = true, Run = true, JumpStart = true, Fall = true, Land = true, Dash = true,
	Attack1 = true, Attack2 = true, Attack3 = true, Entrance = true, Victory = true,
}

function ChickenStateService.Activate(model: Model)
	CollectionService:AddTag(model, "CombatChicken")
end

function ChickenStateService.Deactivate(model: Model)
	CollectionService:RemoveTag(model, "CombatChicken")
	model:SetAttribute("Action", nil)
end

function ChickenStateService.SetAction(model: Model, action: string?)
	if action ~= nil and not ALLOWED[action] then
		return false
	end
	model:SetAttribute("Action", action)
	return true
end

return ChickenStateService
