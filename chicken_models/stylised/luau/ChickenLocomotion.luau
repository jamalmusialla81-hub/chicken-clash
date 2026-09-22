--[[
	ChickenLocomotion - original procedural locomotion for the shared chicken rig.

	* Two analytic two-bone IK legs (hip -> knee -> ankle), each with its own foot target, ground ray and pole direction.
	* Feet stay planted during stance; a step starts when the body has moved past a distance threshold (or the leg is near
	  full reach), follows a smooth arc, lands on the ground point and aligns to the ground normal.
	* The two legs never step together during ordinary walking (a leg only lifts while the other is planted or nearly landed).
	* Snap on teleport, hang in the air while falling, hard reach limit so legs never stretch.
	* Playful body motion: walk bob, weight shift, turn lean, acceleration lean, terrain tilt from averaged ground normals,
	  head stabilisation, tail + wing follow-through.

	Runs on the CLIENT for chickens the local player can see (owner or remote). It only writes Motor6D.Transform; it never
	touches gameplay state, position, damage or cooldowns - the server stays authoritative.
	Update(dt) is cheap to skip: call it every frame when close, every 2-3 frames when far.
]]

local RunService = game:GetService("RunService")
local Rig = require(script.Parent.ChickenRig)

local Loco = {}
Loco.__index = Loco

local ANKLE_H = 0.45          -- ankle joint height above the sole when the foot is flat
local RAY_UP, RAY_DOWN = 1.6, 7.0
local STEP_HEIGHT = 0.5
local STEP_TRIGGER = 1.05     -- stud drift from the ideal spot before a step is requested
local MAX_TILT = math.rad(18)
local SNAP_DISTANCE = 9

local function clampMag(v: Vector3, m: number): Vector3
	local l = v.Magnitude
	if l > m then
		return v * (m / l)
	end
	return v
end

local function easeInOut(t: number): number
	return t * t * (3 - 2 * t)
end

-- damped spring on a number
local function springStep(state, target: number, dt: number, freq: number, damping: number)
	local f = freq * 2 * math.pi
	local accel = (target - state.x) * f * f - state.v * 2 * damping * f
	state.v += accel * dt
	state.x += state.v * dt
	return state.x
end

function Loco.new(model: Model, idleLayer: any?)
	local self = setmetatable({}, Loco)
	self.model = model
	self.root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	self.humanoid = model:FindFirstChildOfClass("Humanoid")
	self.idle = idleLayer
	self.joints = {} :: { [string]: Motor6D }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 then
			self.joints[d.Part1.Name] = d
		end
	end
	self.legs = {}
	self.time = 0
	self.phase = 0
	self.lastPos = self.root.Position
	self.lastVel = Vector3.zero
	self.lastLook = self.root.CFrame.LookVector
	self.airborne = false
	self.destroyed = false
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.rayParams.FilterDescendantsInstances = { model }
	self.rayParams.RespectCanCollide = true

	-- rest geometry in model space (rest pose = identity transforms)
	local hrpJoint = Rig.Joint("HumanoidRootPart")
	self.hrpRest = CFrame.new(hrpJoint) * CFrame.Angles(0, -math.pi / 2, 0)
	for side, names in pairs(Rig.Legs) do
		local hip, knee, ankle = Rig.Joint(names.Upper), Rig.Joint(names.Lower), Rig.Joint(names.Foot)
		local leg = {
			side = side, names = names,
			restHip = hip, restKnee = knee, restAnkle = ankle,
			L1 = (knee - hip).Magnitude, L2 = (ankle - knee).Magnitude,
			hipLocal = self.hrpRest:PointToObjectSpace(hip),
			ankleLocal = self.hrpRest:PointToObjectSpace(ankle),
			planted = true, stepT = 1, stepDur = 0.25, stepFrom = Vector3.zero, stepTo = Vector3.zero,
			pos = Vector3.zero, normal = Vector3.yAxis, yaw = 0,
			restBend = Vector3.xAxis, -- knees bend toward the chicken's front
		}
		self.legs[side] = leg
	end
	self.state = {
		bob = { x = 0, v = 0 }, sway = { x = 0, v = 0 }, leanP = { x = 0, v = 0 }, leanR = { x = 0, v = 0 }, tilt = { x = 0, v = 0 },
		tiltR = { x = 0, v = 0 }, tailP = { x = 0, v = 0 }, tailY = { x = 0, v = 0 }, wingL = { x = 0, v = 0 }, wingR = { x = 0, v = 0 },
		height = { x = 0, v = 0 },
	}
	self:_snapFeet()
	return self
end

-- world CFrame of a rig part, computed purely from the root and the joint Transforms (no physics lag)
function Loco:_world(part: BasePart): CFrame
	if part == self.root then
		return self.root.CFrame
	end
	local m = self.joints[part.Name]
	return self:_world(m.Part0) * m.C0 * m.Transform * m.C1:Inverse()
end

function Loco:_groundAt(origin: Vector3)
	local hit = workspace:Raycast(origin, Vector3.new(0, -(RAY_UP + RAY_DOWN), 0), self.rayParams)
	return hit
end

function Loco:_restFootTarget(leg)
	local cf = self.root.CFrame
	local origin = cf:PointToWorldSpace(Vector3.new(leg.hipLocal.X, 0, leg.hipLocal.Z + 0.0)) + Vector3.new(0, RAY_UP, 0)
	-- step slightly ahead of the hip in the direction of travel (rest ankle sits a little forward of the hip)
	origin += cf:VectorToWorldSpace(Vector3.new(0, 0, leg.ankleLocal.Z - leg.hipLocal.Z))
	local hit = self:_groundAt(origin)
	if hit then
		local n = hit.Normal.Y > 0.55 and hit.Normal or Vector3.yAxis -- stair risers / edges are not ground to stand on
		return hit.Position + n * ANKLE_H, n, true
	end
	return origin - Vector3.new(0, RAY_UP + leg.L1 + leg.L2 * 0.85, 0), Vector3.yAxis, false
end

function Loco:_snapFeet()
	for _, leg in pairs(self.legs) do
		local p, n = self:_restFootTarget(leg)
		leg.pos, leg.normal, leg.planted, leg.stepT = p, n, true, 1
		leg.stepFrom, leg.stepTo = p, p
	end
	self.lastPos = self.root.Position
end

-- two-bone IK. Returns knee position and the reachable end position.
local function solveTwoBone(hip: Vector3, target: Vector3, L1: number, L2: number, pole: Vector3)
	local d = target - hip
	local dist = math.clamp(d.Magnitude, math.abs(L1 - L2) + 0.05, L1 + L2 - 0.02)
	local dn = d.Magnitude > 1e-4 and d.Unit or Vector3.new(0, -1, 0)
	local a = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(L1 * L1 - a * a, 0))
	local bend = pole - dn * pole:Dot(dn)
	bend = bend.Magnitude > 1e-3 and bend.Unit or dn:Cross(Vector3.xAxis).Unit
	local knee = hip + dn * a + bend * h
	return knee, hip + dn * dist, bend
end

local function rotBetween(restDir: Vector3, restUp: Vector3, dir: Vector3, up: Vector3): CFrame
	local r0 = CFrame.lookAt(Vector3.zero, restDir, restUp)
	local r1 = CFrame.lookAt(Vector3.zero, dir, up)
	return r1 * r0:Inverse()
end

-- pose one bone of a chain: rotate the child about its joint so the bone points along `dir` with knee-plane `up`
function Loco:_poseBone(childName: string, restDirModel: Vector3, dir: Vector3, up: Vector3)
	local m = self.joints[childName]
	local jointWorld = self:_world(m.Part0) * m.C0
	local rot = jointWorld.Rotation
	local restDirW = rot:VectorToWorldSpace(restDirModel)
	local restUpW = self.modelRot:VectorToWorldSpace(Vector3.xAxis) -- bend toward the chicken's front
	restUpW = restUpW - restDirW.Unit * restUpW:Dot(restDirW.Unit)
	if restUpW.Magnitude < 1e-3 then
		restUpW = self.modelRot:VectorToWorldSpace(Vector3.yAxis)
	end
	local qWorld = rotBetween(restDirW, restUpW, dir, up)
	m.Transform = rot:Inverse() * qWorld * rot
end

function Loco:_solveLeg(leg)
	local hipM = self.joints[leg.names.Upper]
	local kneeM = self.joints[leg.names.Lower]
	local ankleM = self.joints[leg.names.Foot]
	local hip = (self:_world(hipM.Part0) * hipM.C0).Position
	local pole = self.modelRot:VectorToWorldSpace(Vector3.xAxis) -- knees point toward the front
	local knee, foot, bend = solveTwoBone(hip, leg.pos, leg.L1, leg.L2, pole)
	self:_poseBone(leg.names.Upper, leg.restKnee - leg.restHip, (knee - hip).Unit, bend)
	self:_poseBone(leg.names.Lower, leg.restAnkle - leg.restKnee, (foot - knee).Unit, bend)
	-- foot: yaw follows the body, up follows the ground normal
	local ankleJoint = self:_world(ankleM.Part0) * ankleM.C0
	local fwd = self.modelRot:VectorToWorldSpace(Vector3.xAxis)
	fwd = fwd - leg.normal * fwd:Dot(leg.normal)
	if fwd.Magnitude < 1e-3 then
		fwd = self.modelRot:VectorToWorldSpace(Vector3.xAxis)
	end
	-- fromMatrix(right, up, back): X = chicken forward, Y = ground normal, Z = X cross Y
	local desired = CFrame.fromMatrix(Vector3.zero, fwd.Unit, leg.normal, fwd.Unit:Cross(leg.normal))
	ankleM.Transform = ankleJoint.Rotation:Inverse() * desired
	return foot
end

function Loco:_updateSteps(dt: number, speed: number, moveDir: Vector3, airborne: boolean)
	local left, right = self.legs.Left, self.legs.Right
	self.frame = (self.frame or 0) + 1
	local idleMode = speed < 0.6
	for name, leg in pairs(self.legs) do
		-- while standing still the ideal spot barely changes, so each leg re-checks the ground every 3rd frame
		if not idleMode or not leg.ideal or not leg.planted or (self.frame + (name == "Left" and 0 or 1)) % 3 == 0 then
			local ideal, normal, grounded = self:_restFootTarget(leg)
			leg.ideal, leg.idealNormal, leg.grounded = ideal, normal, grounded
		end
	end
	if not airborne then
		-- remote chickens do not report Freefall to this client, so also detect it from geometry:
		-- if the ground is farther below both hips than the legs can reach, the chicken is in the air
		local far = true
		for _, leg in pairs(self.legs) do
			local hipY = (self.root.CFrame * CFrame.new(leg.hipLocal)).Position.Y
			if not leg.grounded or hipY - leg.ideal.Y < (leg.L1 + leg.L2) * 1.1 then
				far = false
			end
		end
		airborne = far
	end
	self.airborne = airborne
	if airborne then
		for _, leg in pairs(self.legs) do
			leg.planted = true
			local hangTarget = leg.ideal + Vector3.new(0, 0.9, 0)
			leg.pos = hangTarget -- locked to the body: smoothing would lag far behind at fall speed
			leg.normal = leg.normal:Lerp(Vector3.yAxis, math.min(dt * 8, 1)).Unit
		end
		return
	end
	-- 1) advance any leg that is mid-step
	for _, leg in pairs(self.legs) do
		if not leg.planted then
			leg.stepT = math.min(leg.stepT + dt / leg.stepDur, 1)
			local t = easeInOut(leg.stepT)
			local base = leg.stepFrom:Lerp(leg.stepTo, t)
			local arc = math.sin(math.pi * leg.stepT) * STEP_HEIGHT * math.clamp(0.6 + speed * 0.03, 0.6, 1.4)
			leg.pos = base + Vector3.new(0, arc, 0)
			leg.normal = leg.normal:Lerp(leg.stepNormal or Vector3.yAxis, math.min(dt * 14, 1)).Unit
			if leg.stepT >= 1 then
				-- land on the freshly detected ground under the target
				local hit = workspace:Raycast(leg.stepTo + Vector3.new(0, RAY_UP, 0), Vector3.new(0, -(RAY_UP + RAY_DOWN), 0), self.rayParams)
				if hit then
					local n = hit.Normal.Y > 0.55 and hit.Normal or Vector3.yAxis
					leg.pos = hit.Position + n * ANKLE_H
					leg.normal = n
				else
					leg.pos = leg.stepTo
				end
				leg.planted = true
				leg.lastLanded = self.time
			end
		end
	end
	-- 2) at most ONE leg may start a step per frame: the planted leg that has drifted furthest, and only while the other
	--    leg is planted or almost landed (so the two feet never lift together during ordinary walking)
	local best, bestScore
	for name, leg in pairs(self.legs) do
		if leg.planted then
			local other = (name == "Left") and right or left
			-- Where is the foot relative to the hip? While moving, a step is needed when the foot has fallen behind the hip line
			-- (or drifted sideways); a foot ahead of the hip is exactly where it should be. Standing still uses plain distance.
			local hip = (self.root.CFrame * CFrame.new(leg.hipLocal)).Position
			local drift
			if speed > 1 then
				local rel = (leg.pos - hip) * Vector3.new(1, 0, 1)
				local along = rel:Dot(moveDir)
				local side = (rel - moveDir * along).Magnitude
				drift = math.max(-along, side * 1.2)
			else
				drift = ((leg.ideal - leg.pos) * Vector3.new(1, 0, 1)).Magnitude
			end
			local reach = (leg.pos - hip).Magnitude
			local trigger = (speed > 1) and 0.55 or STEP_TRIGGER
			local reachRatio = reach / (leg.L1 + leg.L2)
			local want = drift > trigger or reachRatio > 0.9
			local emergency = reachRatio > 0.95 or drift > 1.9   -- about to over-stretch: step even if the other foot is still up
			-- walking: the other foot must be planted. running (>10 studs/s): a short overlap is allowed for a bouncy gait.
			local otherOk = other.planted or (speed > 10 and other.stepT > 0.8) or emergency
			local rested = (self.time - (leg.lastLanded or -1)) > 0.05 or emergency -- a landed foot stays planted for a moment
			if want and otherOk and rested then
				local score = drift + (reach / (leg.L1 + leg.L2)) + ((self.time - (leg.lastLanded or 0)) * 0.05)
				if not bestScore or score > bestScore then
					best, bestScore = leg, score
				end
			end
		end
	end
	if best then
		best.planted = false
		best.stepT = 0
		best.stepDur = math.clamp(1.2 / math.max(speed, 4), 0.13, 0.26) -- swing no longer than the stance, so one foot is always down when walking
		best.stepFrom = best.pos
		if speed > 1 then
			-- land where the hip WILL be when the foot arrives, a little ahead of it, so the leg reaches forward
			local hipNow = (self.root.CFrame * CFrame.new(best.hipLocal)).Position
			local ahead = hipNow + moveDir * (speed * best.stepDur + 0.8)
			local hit = workspace:Raycast(Vector3.new(ahead.X, hipNow.Y + RAY_UP, ahead.Z), Vector3.new(0, -(RAY_UP + RAY_DOWN + 2), 0), self.rayParams)
			if hit then
				local n = hit.Normal.Y > 0.55 and hit.Normal or Vector3.yAxis
				best.stepTo = hit.Position + n * ANKLE_H
				best.idealNormal = n
			else
				best.stepTo = Vector3.new(ahead.X, best.ideal.Y, ahead.Z)
			end
		else
			best.stepTo = best.ideal
		end
		best.stepNormal = best.idealNormal
	end
end

function Loco:Update(dt: number)
	if self.destroyed or not self.root.Parent then
		return
	end
	if self.enabled == false then
		-- an authored movement-priority AnimationTrack owns the legs right now (ChickenAnimator toggles
		-- this off rather than letting IK and a real track fight over the same Motor6Ds).
		return
	end
	dt = math.min(dt, 0.1)
	self.time += dt
	local cf = self.root.CFrame
	self.modelRot = cf.Rotation * CFrame.Angles(0, math.pi / 2, 0)
	local vel = self.root.AssemblyLinearVelocity
	local flat = Vector3.new(vel.X, 0, vel.Z)
	local speed = flat.Magnitude
	local moveDir = speed > 0.1 and flat.Unit or Vector3.zero
	local moved = (self.root.Position - self.lastPos).Magnitude
	if moved > SNAP_DISTANCE then
		self:_snapFeet() -- teleported
	end
	local airborne = false
	if self.humanoid then
		local st = self.humanoid:GetState()
		airborne = st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Flying
	end

	self:_updateSteps(dt, speed, moveDir, airborne)

	-- terrain tilt from the averaged ground normals of both feet
	local n = ((self.legs.Left.normal + self.legs.Right.normal) * 0.5).Unit
	local nm = self.modelRot:VectorToObjectSpace(n)
	local pitchT = math.clamp(math.atan2(-nm.X, nm.Y), -MAX_TILT, MAX_TILT)
	local rollT = math.clamp(math.atan2(nm.Z, nm.Y), -MAX_TILT, MAX_TILT)
	local S = self.state

	-- accel / turn lean
	local accel = (vel - self.lastVel) / math.max(dt, 1e-3)
	local accelFwd = self.modelRot:VectorToObjectSpace(Vector3.new(accel.X, 0, accel.Z)).X
	local look = cf.LookVector
	local yawRate = self.lastLook:Cross(look).Y / math.max(dt, 1e-3)
	self.lastVel, self.lastLook, self.lastPos = vel, look, self.root.Position

	local stride = 3.6
	self.phase += (speed * dt / stride) * 2 * math.pi
	local walk = math.clamp(speed / 12, 0, 1)
	local bobT = math.abs(math.sin(self.phase)) * 0.11 * walk
	local swayT = math.sin(self.phase) * 0.10 * walk
	local leanPT = math.clamp(-accelFwd * 0.004, -0.2, 0.2) - walk * 0.08 + pitchT
	local leanRT = math.clamp(yawRate * 0.05, -0.25, 0.25) + rollT + swayT * 0.25

	-- average foot height -> gentle body height compensation on stairs / slopes
	local footY = (self.legs.Left.pos.Y + self.legs.Right.pos.Y) * 0.5 - ANKLE_H
	local expectY = cf.Position.Y - (Rig.Joint("HumanoidRootPart").Y - Rig.StandDrop)
	local heightT = math.clamp((footY - expectY) * 0.5, -0.4, 0.4)

	leanPT = math.clamp(leanPT, -MAX_TILT * 1.15, MAX_TILT * 1.15)
	leanRT = math.clamp(leanRT, -MAX_TILT * 1.15, MAX_TILT * 1.15)
	springStep(S.bob, bobT, dt, 4.5, 0.7)
	springStep(S.sway, swayT, dt, 3.5, 0.7)
	springStep(S.leanP, leanPT, dt, 3.0, 0.8)
	springStep(S.leanR, leanRT, dt, 3.0, 0.8)
	springStep(S.height, heightT, dt, 3.0, 0.9)
	springStep(S.tailP, math.clamp(accelFwd * 0.006, -0.5, 0.5) + walk * 0.12 * math.sin(self.phase * 0.5), dt, 2.2, 0.35)
	springStep(S.tailY, math.clamp(-yawRate * 0.08, -0.6, 0.6) + math.sin(self.time * 1.7) * 0.05, dt, 2.0, 0.35)
	springStep(S.wingL, walk * 0.10 + math.clamp(yawRate * 0.05, -0.3, 0.3), dt, 2.6, 0.4)
	springStep(S.wingR, walk * 0.10 - math.clamp(yawRate * 0.05, -0.3, 0.3), dt, 2.6, 0.4)

	local idle = self.idle and self.idle:Step(dt, walk) or nil
	local poses = self.poses and self.poses:Get(dt) or nil
	local id = idle or { chest = 0, headYaw = 0, headRoll = 0, headPitch = 0, tail = 0, wing = 0, breathe = 0 }
	self.lastIdle = id

	-- body
	local bodyJ = self.joints.Body
	bodyJ.Transform = CFrame.new(0, S.bob.x + S.height.x + id.breathe * 0.04, S.sway.x * 0.5)
		* CFrame.Angles(S.leanR.x, 0, S.leanP.x)
	-- chest lifts proudly when idle, settles when running
	if self.joints.Chest then
		self.joints.Chest.Transform = CFrame.Angles(0, 0, -(id.chest * (1 - walk)) - S.leanP.x * 0.25)
	end
	-- head stabilisation: cancel most of the body pitch/roll, add idle personality
	if self.joints.Neck then
		self.joints.Neck.Transform = CFrame.Angles(-S.leanR.x * 0.4, 0, -S.leanP.x * 0.35)
	end
	if self.joints.Head then
		self.joints.Head.Transform = CFrame.Angles(id.headRoll - S.leanR.x * 0.35, id.headYaw, id.headPitch - S.leanP.x * 0.3)
	end
	if self.joints.Tail then
		self.joints.Tail.Transform = CFrame.Angles(0, S.tailY.x, S.tailP.x + id.tail)
	end
	local function wing(name, val, sign)
		local j = self.joints[name]
		if j then
			j.Transform = CFrame.Angles(0, 0, 0) * CFrame.Angles(sign * (val + id.wing), 0, 0)
		end
	end
	wing("LeftWingUpper", S.wingL.x, 1)
	wing("RightWingUpper", S.wingR.x, -1)
	if self.joints.LeftWingLower then self.joints.LeftWingLower.Transform = CFrame.Angles(S.wingL.x * 0.6, 0, S.tailP.x * 0.3) end
	if self.joints.RightWingLower then self.joints.RightWingLower.Transform = CFrame.Angles(-S.wingR.x * 0.6, 0, S.tailP.x * 0.3) end
	if self.joints.Cape then
		self.joints.Cape.Transform = CFrame.Angles(0, 0, math.clamp(accelFwd * 0.006, -0.3, 0.3) + walk * 0.1)
	end

	-- authored pose layer: upper body only, so the feet stay planted
	if poses then
		for jointName, e in pairs(poses.joints) do
			local j = self.joints[jointName]
			if j then
				j.Transform = j.Transform * CFrame.Angles(e[1], e[2], e[3])
			end
		end
		if poses.body then
			bodyJ.Transform = bodyJ.Transform * CFrame.new(poses.body[1], poses.body[2], poses.body[3])
		end
	end

	-- legs last (they read the finished body transform)
	self:_solveLeg(self.legs.Left)
	self:_solveLeg(self.legs.Right)
end

function Loco:Destroy()
	self.destroyed = true
end

-- convenience: drives Update from Heartbeat and cleans itself up when the model leaves the world
function Loco.attach(model: Model, idleLayer: any?)
	local self = Loco.new(model, idleLayer)
	local acc = 0
	self.conn = RunService.Heartbeat:Connect(function(dt)
		if self.destroyed or not model.Parent then
			self.conn:Disconnect()
			return
		end
		local cam = workspace.CurrentCamera
		local dist = cam and (cam.CFrame.Position - self.root.Position).Magnitude or 0
		if cam and dist > 25 then
			local _, onScreen = cam:WorldToViewportPoint(self.root.Position)
			if not onScreen then
				return -- off screen: no IK, no cost
			end
		end
		acc += dt
		local interval = dist > 140 and math.huge or (dist > 70 and 1 / 20 or (dist > 35 and 1 / 30 or 0))
		if acc >= interval then
			self:Update(acc)
			acc = 0
		end
	end)
	model.Destroying:Connect(function()
		self.destroyed = true
		if self.conn then
			self.conn:Disconnect()
		end
	end)
	return self
end

return Loco
