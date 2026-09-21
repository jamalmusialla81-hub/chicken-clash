--[[ ChickenIdle - randomised personality layer. Returns small additive offsets; never touches feet or position.
	Timers are randomised inside sensible ranges so the idle never loops robotically. ]]
local Idle = {}
Idle.__index = Idle

local function env(t: number, len: number): number -- 0..1..0 bell over `len` seconds
	if t < 0 or t > len then
		return 0
	end
	local x = t / len
	return math.sin(math.pi * x) ^ 2
end

function Idle.new(model: Model?, seed: number?)
	local self = setmetatable({}, Idle)
	self.model = model
	self.rng = Random.new(seed or math.random(1, 1e6))
	self.t = 0
	self.head = { roll = 0, yaw = 0, pitch = 0, tRoll = 0, tYaw = 0, tPitch = 0, nextAt = 1.5 }
	self.nextChest, self.chestT = self.rng:NextNumber(3, 6), -10
	self.nextWing, self.wingT = self.rng:NextNumber(5, 9), -10
	self.nextBlink, self.blinkT = self.rng:NextNumber(2, 4), -10
	self.nextCrown, self.crownT = self.rng:NextNumber(12, 24), -10
	self.enabled = true
	return self
end

function Idle:Step(dt: number, walk: number)
	self.t += dt
	local t, rng, h = self.t, self.rng, self.head
	local calm = 1 - math.clamp(walk * 1.5, 0, 1)
	if t >= h.nextAt then
		h.tRoll, h.tYaw, h.tPitch = rng:NextNumber(-0.14, 0.14), rng:NextNumber(-0.16, 0.16), rng:NextNumber(-0.05, 0.08)
		h.nextAt = t + rng:NextNumber(2.2, 5)
	end
	local k = math.min(dt * 2.2, 1)
	h.roll += (h.tRoll - h.roll) * k
	h.yaw += (h.tYaw - h.yaw) * k
	h.pitch += (h.tPitch - h.pitch) * k
	if t >= self.nextChest then self.chestT, self.nextChest = t, t + rng:NextNumber(5, 10) end
	if t >= self.nextWing then self.wingT, self.nextWing = t, t + rng:NextNumber(6, 12) end
	if t >= self.nextBlink then self.blinkT, self.nextBlink = t, t + rng:NextNumber(2.5, 6) end
	if t >= self.nextCrown then self.crownT, self.nextCrown = t, t + rng:NextNumber(15, 30) end
	local blink = env(t - self.blinkT, 0.16)
	local crown = env(t - self.crownT, 1.2)
	if self.model then
		-- read by the aura (crown/halo reaction) and by any separate Eyes/Eyelids part an imported model provides
		self.model:SetAttribute("Blink", blink > 0.5)
		self.model:SetAttribute("CrownPulse", crown)
	end
	return {
		breathe = math.sin(t * 1.9) * 0.5 * (0.6 + 0.4 * calm),
		chest = (0.10 * env(t - self.chestT, 1.3) + 0.03) * calm,
		headRoll = h.roll * calm, headYaw = h.yaw * calm, headPitch = h.pitch * calm - 0.04 * crown,
		tail = (math.sin(t * 1.3) * 0.05 + math.sin(t * 0.47) * 0.03) * calm,
		wing = 0.13 * env(t - self.wingT, 0.7) * calm,
		blink = blink, crown = crown,
	}
end

return Idle
