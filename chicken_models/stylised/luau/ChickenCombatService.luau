--[[ ChickenCombatService (server, authoritative). Owns attack legality, the 3-hit M1 combo buffer,
	cooldowns, hitboxes and damage dispatch, and a modern (non-BodyVelocity) validated dash. Timing for
	windup/active/combo windows comes from GoldenChickenAnimationCatalog.MarkerFrames, computed as
	frame/FPS - this makes combat timing correct and testable even before an animation is uploaded, since
	the server never plays AnimationTracks itself; it only sets the replicated "Action" attribute that
	ChickenAnimator renders on each client.

	Integration point: call RequestAttack(model) / RequestDash(model, direction) from whatever RemoteEvent
	handler validates the calling player owns `model` (not built here - this module only assumes `model`
	is a real, currently-tagged CombatChicken; it does not resolve player ownership itself).

	Damage is intentionally NOT applied directly to a Health property here, since the project's real
	health/damage system was not identified in this pass - HitEvent fires with (attacker, victim, damage)
	for whatever system should own health to subscribe to, rather than guessing at a Humanoid.Health or
	custom Health attribute convention and getting it wrong. ]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("ChickenClash")
local Catalog = require(folder:WaitForChild("GoldenChickenAnimationCatalog"))
local ChickenStateService = require(script.Parent:WaitForChild("ChickenStateService"))

local ChickenCombatService = {}
ChickenCombatService.HitEvent = Instance.new("BindableEvent") -- (attacker: Model, victim: Model, damage: number, attackName: string)

local ATTACK_CHAIN = { "Attack1", "Attack2", "Attack3" }
local ATTACK_CATALOG = { Attack1 = "M1_1", Attack2 = "M1_2", Attack3 = "M1_3" }
local ATTACK_DAMAGE = { Attack1 = 8, Attack2 = 10, Attack3 = 18 }
local HITBOX_RANGE = 7 -- studs, in front of HumanoidRootPart
local HITBOX_HALF_WIDTH = 4
local DASH_COOLDOWN = 2.5
local DASH_DISTANCE = 24

local combos = setmetatable({}, { __mode = "k" }) -- model -> state, weak so a destroyed model's state is GC'd

local function getState(model: Model)
	local s = combos[model]
	if not s then
		s = { comboStep = 0, comboWindowOpen = false, busy = false, dashReadyAt = 0, generation = 0 }
		combos[model] = s
	end
	return s
end

-- swept, multi-sample spatial query (not .Touched) so a fast-moving swing can't skip a target between
-- frames: samples the hitbox region at the start AND end of the active window, unions the hit sets.
local function queryHitbox(model: Model)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return {}
	end
	local forward = hrp.CFrame.LookVector
	local center = hrp.Position + forward * (HITBOX_RANGE * 0.5)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local size = Vector3.new(HITBOX_HALF_WIDTH * 2, 6, HITBOX_RANGE)
	local cf = CFrame.new(center, center + forward)
	local parts = workspace:GetPartBoundsInBox(cf, size, params)
	local targets = {}
	for _, part in ipairs(parts) do
		local targetModel = part:FindFirstAncestorOfClass("Model")
		if targetModel and targetModel ~= model and CollectionService:HasTag(targetModel, "CombatChicken") then
			targets[targetModel] = true
		end
	end
	return targets
end

local function runActiveWindow(model: Model, actionName: string, catalogName: string, generation: number)
	local s = getState(model)
	local activeStart = Catalog.MarkerTime(catalogName, "ActiveStart")
	local activeEnd = Catalog.MarkerTime(catalogName, "ActiveEnd")
	if not activeStart or not activeEnd then
		return
	end
	local hitThisSwing = {}
	local elapsed = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if s.generation ~= generation or not model.Parent then
			conn:Disconnect()
			return
		end
		elapsed += dt
		if elapsed < activeStart then
			return
		end
		if elapsed > activeEnd then
			conn:Disconnect()
			return
		end
		for target in pairs(queryHitbox(model)) do
			if not hitThisSwing[target] then
				hitThisSwing[target] = true
				ChickenCombatService.HitEvent:Fire(model, target, ATTACK_DAMAGE[actionName] or 0, actionName)
			end
		end
	end)
end

-- Rejects: not tagged, dead/disabled (no attribute hook exists yet for that - a future "Dead" attribute
-- check goes here), spam (busy with no open combo window), NaN/garbage input never reaches this function
-- since it takes no external numeric input at all (direction for dash is sanitized separately below).
function ChickenCombatService.RequestAttack(model: Model): boolean
	if not model or not model.Parent or not CollectionService:HasTag(model, "CombatChicken") then
		return false
	end
	local s = getState(model)
	if s.busy and not s.comboWindowOpen then
		return false
	end
	local nextStep = s.comboWindowOpen and math.min(s.comboStep + 1, 3) or 1
	local actionName = ATTACK_CHAIN[nextStep]
	local catalogName = ATTACK_CATALOG[actionName]
	local entry = Catalog.Animations[catalogName]
	if not ChickenStateService.SetAction(model, actionName) then
		return false
	end

	s.comboStep = nextStep
	s.comboWindowOpen = false
	s.busy = true
	s.generation += 1
	local generation = s.generation

	runActiveWindow(model, actionName, catalogName, generation)

	local comboOpenT = Catalog.MarkerTime(catalogName, "ComboOpen")
	local comboCloseT = Catalog.MarkerTime(catalogName, "ComboClose")
	if comboOpenT then
		task.delay(comboOpenT, function()
			if s.generation == generation then
				s.comboWindowOpen = true
			end
		end)
	end
	if comboCloseT then
		task.delay(comboCloseT, function()
			if s.generation == generation then
				s.comboWindowOpen = false
			end
		end)
	end
	task.delay(entry.Duration, function()
		if s.generation == generation then
			s.busy = false
			s.comboStep = 0
			s.comboWindowOpen = false
			if model.Parent then
				ChickenStateService.SetAction(model, "Idle")
			end
		end
	end)
	return true
end

-- direction is sanitized (NaN/inf/zero all fall back to facing) before ever reaching movement code.
local function sanitizeDirection(model: Model, direction: Vector3?): Vector3
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local fallback = hrp and hrp.CFrame.LookVector or Vector3.new(0, 0, -1)
	if typeof(direction) ~= "Vector3" then
		return fallback
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude ~= flat.Magnitude or flat.Magnitude < 0.01 or flat.Magnitude == math.huge then
		return fallback
	end
	return flat.Unit
end

function ChickenCombatService.RequestDash(model: Model, direction: Vector3?): boolean
	if not model or not model.Parent or not CollectionService:HasTag(model, "CombatChicken") then
		return false
	end
	local s = getState(model)
	if s.busy then
		return false
	end
	if os.clock() < s.dashReadyAt then
		return false
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	if not ChickenStateService.SetAction(model, "Dash") then
		return false
	end

	s.busy = true
	s.generation += 1
	local generation = s.generation
	local dir = sanitizeDirection(model, direction)
	local entry = Catalog.Animations.Dash
	local dashStartT = Catalog.MarkerTime("Dash", "DashStart") or 0.2
	local dashEndT = Catalog.MarkerTime("Dash", "DashEnd") or (entry.Duration - 0.15)

	task.delay(dashStartT, function()
		if s.generation ~= generation or not hrp.Parent then
			return
		end
		local dur = math.max(dashEndT - dashStartT, 0.05)
		local elapsed = 0
		local traveled = 0
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			if s.generation ~= generation or not hrp.Parent then
				if conn then conn:Disconnect() end
				return
			end
			elapsed += dt
			if elapsed >= dur then
				conn:Disconnect()
				return
			end
			local alpha = math.clamp(elapsed / dur, 0, 1)
			local eased = 1 - (1 - alpha) ^ 2 -- ease-out, matches the animation's braking follow-through
			local targetTraveled = DASH_DISTANCE * eased
			local step = targetTraveled - traveled
			if step > 0 then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { model }
				local result = workspace:Raycast(hrp.Position, dir * (step + 1), params)
				local movable = result and math.max(result.Distance - 1, 0) or step
				hrp.CFrame = CFrame.new(hrp.Position + dir * movable, hrp.Position + dir * movable + dir)
				traveled += movable
				if result then
					conn:Disconnect() -- hit a wall - stop the dash early instead of tunneling/jittering into it
				end
			end
		end)
	end)

	task.delay(entry.Duration, function()
		if s.generation == generation then
			s.busy = false
			s.dashReadyAt = os.clock() + DASH_COOLDOWN
			if model.Parent then
				ChickenStateService.SetAction(model, "Idle")
			end
		end
	end)
	return true
end

function ChickenCombatService.IsBusy(model: Model): boolean
	return getState(model).busy
end

return ChickenCombatService
