--[[ ChickenHealthService (server, authoritative). The missing subscriber ChickenCombatService's own
	comment asked for: "HitEvent fires ... for whatever system should own health to subscribe to". Owns
	Health/MaxHealth as replicated attributes on the combat chicken model (the HUD and camera death-
	spectator flow already read/react to these - ChickenCombatHUD reads Health/MaxHealth attributes,
	ChickenCombatCameraController reacts to Humanoid.Died), applies damage from HitEvent, clamps at 0,
	and fires Humanoid:TakeDamage so the existing Humanoid.Died signal (already wired into camera + this
	module's own KO signal) fires exactly once per combatant. Ignores hits on a target that is already
	dead or not currently tracked, so a hitbox connecting during the death animation cannot double-KO. ]]

local ChickenCombatService = require(script.Parent:WaitForChild("ChickenCombatService"))

local HealthService = {}
HealthService.KOEvent = Instance.new("BindableEvent") -- (victim: Model, attacker: Model)

local tracked = setmetatable({}, { __mode = "k" }) -- model -> true while alive and tracked

function HealthService.Init(model: Model, maxHealth: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	model:SetAttribute("MaxHealth", maxHealth)
	model:SetAttribute("Health", maxHealth)
	tracked[model] = true
end

function HealthService.Reset(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.Health = humanoid.MaxHealth
	model:SetAttribute("Health", humanoid.MaxHealth)
	tracked[model] = true
end

function HealthService.Stop(model: Model)
	tracked[model] = nil
end

function HealthService.IsAlive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return tracked[model] == true and humanoid ~= nil and humanoid.Health > 0
end

ChickenCombatService.HitEvent.Event:Connect(function(attacker: Model, victim: Model, damage: number, _actionName: string)
	if not tracked[victim] then
		return
	end
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if type(damage) ~= "number" or damage ~= damage or damage < 0 then
		return -- defensive: never apply NaN/negative damage even though ChickenCombatService's own table is trusted
	end
	humanoid:TakeDamage(damage)
	local newHealth = math.max(humanoid.Health, 0)
	victim:SetAttribute("Health", newHealth)
	if newHealth <= 0 then
		tracked[victim] = nil
		HealthService.KOEvent:Fire(victim, attacker)
	end
end)

return HealthService
