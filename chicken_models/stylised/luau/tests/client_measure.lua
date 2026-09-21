-- Run in the CLIENT runtime. Attaches the locomotion controller and records planted-foot movement, leg stretch, IK target error,
-- body tilt and per-frame cost. Read _G.S afterwards.
local RS, RunService = game:GetService("ReplicatedStorage"), game:GetService("RunService")
local model = workspace.ProxyChicken
local Loco = require(RS.ChickenClash.ChickenLocomotion)
local Idle = require(RS.ChickenClash.ChickenIdle)
local Poses = require(RS.ChickenClash.ChickenPoses)
local loco = Loco.new(model, Idle.new(model, 7)); loco.poses = Poses.new(); _G.loco = loco
local S = { frames = 0, slip = 0, slipFrames = 0, maxStretch = 0, maxErr = 0, ftimes = {}, steps = { Left = 0, Right = 0 }, overlap = 0, maxTilt = 0, minFootClear = 9e9 }
_G.S = S
local prev = {}
_G.conn = RunService.Heartbeat:Connect(function(dt)
	local t0 = os.clock(); loco:Update(dt); S.ftimes[#S.ftimes + 1] = (os.clock() - t0) * 1000; S.frames += 1
	local both = true
	for side, leg in pairs(loco.legs) do
		local hipM = loco.joints[leg.names.Upper]; local hip = (hipM.Part0.CFrame * hipM.C0).Position
		local fm = loco.joints[leg.names.Foot]; local ank = (fm.Part1.CFrame * fm.C1).Position
		S.maxStretch = math.max(S.maxStretch, (ank - hip).Magnitude / (leg.L1 + leg.L2)); S.maxErr = math.max(S.maxErr, (ank - leg.pos).Magnitude)
		local p = prev[side]
		if p then
			if p.planted and leg.planted then local d = (leg.pos - p.pos).Magnitude; S.slip = math.max(S.slip, d); if d > 0.02 then S.slipFrames += 1 end end
			if p.planted and not leg.planted then S.steps[side] += 1 end
		end
		if leg.planted then both = false end
		prev[side] = { pos = leg.pos, planted = leg.planted }
	end
	if both then S.overlap += 1 end   -- both feet in the air at once (only expected while airborne)
	local body = loco.joints.Body.Transform; local x, y, z = body:ToEulerAnglesXYZ(); S.maxTilt = math.max(S.maxTilt, math.abs(x), math.abs(z))
end)
