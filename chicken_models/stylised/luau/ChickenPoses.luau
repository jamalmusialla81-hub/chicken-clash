--[[ ChickenPoses - code-driven pose layers for the Golden benchmark (Roblox AnimationTracks need uploaded Animation
	assets, so these are data-defined keyframe poses instead). Upper body only: the legs are never touched, so procedural
	feet stay planted while a pose plays. Each key holds per-joint Euler offsets (radians, joint frame: X roll, Y yaw, Z pitch). ]]
local Poses = {}
Poses.__index = Poses

Poses.Library = {
	CombatIdle = { length = 2.0, loop = true, keys = {
		{ t = 0.0, Chest = { 0, 0, 0.10 }, Head = { 0, 0, -0.10 }, LeftWingUpper = { 0.18, 0, 0 }, RightWingUpper = { -0.18, 0, 0 }, Tail = { 0, 0, 0.14 }, Body = { 0.10, -0.12, 0 } },
		{ t = 1.0, Chest = { 0, 0, 0.14 }, Head = { 0, 0.05, -0.14 }, LeftWingUpper = { 0.26, 0, 0 }, RightWingUpper = { -0.26, 0, 0 }, Tail = { 0, 0, 0.20 }, Body = { 0.10, -0.15, 0 } },
		{ t = 2.0, Chest = { 0, 0, 0.10 }, Head = { 0, 0, -0.10 }, LeftWingUpper = { 0.18, 0, 0 }, RightWingUpper = { -0.18, 0, 0 }, Tail = { 0, 0, 0.14 }, Body = { 0.10, -0.12, 0 } } } },
	Entrance = { length = 1.4, loop = false, keys = {
		{ t = 0.0, Chest = { 0, 0, -0.30 }, Head = { 0, 0, 0.30 }, LeftWingUpper = { 0.7, 0, 0 }, RightWingUpper = { -0.7, 0, 0 }, Tail = { 0, 0, -0.3 }, Body = { 0, -0.55, 0 } },
		{ t = 0.6, Chest = { 0, 0, 0.30 }, Head = { 0, 0, -0.25 }, LeftWingUpper = { -0.45, 0, 0 }, RightWingUpper = { 0.45, 0, 0 }, Tail = { 0, 0, 0.35 }, Body = { 0, 0.18, 0 } },
		{ t = 1.4, Chest = { 0, 0, 0.12 }, Head = { 0, 0, -0.08 }, LeftWingUpper = { 0.06, 0, 0 }, RightWingUpper = { -0.06, 0, 0 }, Tail = { 0, 0, 0.1 }, Body = { 0, 0, 0 } } } },
	Victory = { length = 2.2, loop = true, keys = {
		{ t = 0.0, Chest = { 0, 0, 0.28 }, Head = { 0, 0.20, -0.30 }, LeftWingUpper = { -0.75, 0, 0 }, RightWingUpper = { 0.75, 0, 0 }, Tail = { 0, 0.15, 0.45 }, Body = { 0, 0.16, 0 } },
		{ t = 1.1, Chest = { 0, 0, 0.32 }, Head = { 0, -0.20, -0.34 }, LeftWingUpper = { -0.95, 0, 0 }, RightWingUpper = { 0.95, 0, 0 }, Tail = { 0, -0.15, 0.5 }, Body = { 0, 0.22, 0 } },
		{ t = 2.2, Chest = { 0, 0, 0.28 }, Head = { 0, 0.20, -0.30 }, LeftWingUpper = { -0.75, 0, 0 }, RightWingUpper = { 0.75, 0, 0 }, Tail = { 0, 0.15, 0.45 }, Body = { 0, 0.16, 0 } } } },
	TestAttack = { length = 0.7, loop = false, keys = {
		{ t = 0.00, Chest = { 0, 0, 0 }, Head = { 0, 0, 0 }, Body = { 0, 0, 0 } },
		{ t = 0.22, Chest = { 0, 0, 0.30 }, Head = { 0, 0, -0.55 }, LeftWingUpper = { -0.5, 0, 0 }, RightWingUpper = { 0.5, 0, 0 }, Tail = { 0, 0, 0.4 }, Body = { -0.35, 0, 0 } },
		{ t = 0.36, Chest = { 0, 0, -0.35 }, Head = { 0, 0, 0.85 }, LeftWingUpper = { 0.4, 0, 0 }, RightWingUpper = { -0.4, 0, 0 }, Tail = { 0, 0, -0.3 }, Body = { 0.9, -0.1, 0 } },
		{ t = 0.70, Chest = { 0, 0, 0 }, Head = { 0, 0, 0 }, Body = { 0, 0, 0 } } } },
}

local JOINTS = { "Chest", "Neck", "Head", "Beak", "Comb", "LeftWingUpper", "LeftWingLower", "RightWingUpper", "RightWingLower", "Tail", "Cape" }

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

function Poses.new()
	return setmetatable({ current = nil, t = 0, weight = 0, target = 0 }, Poses)
end

function Poses:Play(name: string, fade: number?)
	local def = Poses.Library[name]
	assert(def, "unknown pose " .. tostring(name))
	self.current, self.t, self.target, self.fade = def, 0, 1, fade or 0.12
	self.name = name
end

function Poses:Stop(fade: number?)
	self.target, self.fade = 0, fade or 0.15
end

function Poses:Get(dt: number)
	local def = self.current
	if not def then
		return nil
	end
	self.t += dt
	local dur = def.length
	if self.t > dur then
		if def.loop then
			self.t %= dur
		else
			self.target = 0
			self.t = dur
		end
	end
	local k = dt / math.max(self.fade or 0.12, 1e-3)
	self.weight += math.clamp(self.target - self.weight, -k, k)
	if self.weight <= 0.001 and self.target == 0 then
		self.current = nil
		return nil
	end
	local keys = def.keys
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if self.t >= keys[i].t and self.t <= keys[i + 1].t then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local f = (b.t > a.t) and smooth(math.clamp((self.t - a.t) / (b.t - a.t), 0, 1)) or 0
	local w = smooth(self.weight)
	local out = { joints = {} }
	for _, j in ipairs(JOINTS) do
		local va, vb = a[j], b[j]
		if va or vb then
			va, vb = va or { 0, 0, 0 }, vb or { 0, 0, 0 }
			out.joints[j] = { (va[1] + (vb[1] - va[1]) * f) * w, (va[2] + (vb[2] - va[2]) * f) * w, (va[3] + (vb[3] - va[3]) * f) * w }
		end
	end
	local ba, bb = a.Body, b.Body
	if ba or bb then
		ba, bb = ba or { 0, 0, 0 }, bb or { 0, 0, 0 }
		out.body = { (ba[1] + (bb[1] - ba[1]) * f) * w, (ba[2] + (bb[2] - ba[2]) * f) * w, (ba[3] + (bb[3] - ba[3]) * f) * w }
	end
	return out
end

return Poses
