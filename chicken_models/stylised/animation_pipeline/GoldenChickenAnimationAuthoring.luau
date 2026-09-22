--[[ GoldenChickenAnimationAuthoring (editor-only)
	Generates real KeyframeSequence/Keyframe/Pose/marker data for the Golden Chicken combat rig from
	declarative specs, so Moon Animator is used for real authorship/refinement/export rather than being
	bypassed. This module never plays animations and never runs at runtime - it is a content-generation
	tool invoked from the command bar / a build script, producing instances that get imported into Moon.

	Conversion layer: every Motor6D's C0/C1 on this rig shares an identical baked 90-degree conjugation
	(R_fix, part of the -Z-forward convention baked into ChickenRig). Motor6D.Transform (== Pose.CFrame)
	sits between C0 and C1^-1, so Transform's own local axes get conjugated by R_fix before they appear as
	world-visual rotation. Local(pitch,yaw,roll) below is the derived+calibrated fix for that (see
	animation_pipeline/calibration_report.json) - author every pose through it instead of raw
	CFrame.Angles so a future rig/rebuild only needs correcting in one place. ]]

local Authoring = {}

-- child joint (Motor6D.Name == Part1.Name) -> parent joint name in the pose tree.
-- Root of the tree is HumanoidRootPart itself (not a Motor6D).
Authoring.Hierarchy = {
	Body = "HumanoidRootPart",
	Chest = "Body",
	Neck = "Chest",
	Head = "Neck",
	Beak = "Head",
	Comb = "Head",
	Halo = "Head",
	Tail = "Body",
	LeftWingUpper = "Chest",
	LeftWingLower = "LeftWingUpper",
	RightWingUpper = "Chest",
	RightWingLower = "RightWingUpper",
	LeftUpperLeg = "Body",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
	RightUpperLeg = "Body",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
	Cape = "Chest",
}

Authoring.MirrorPairs = {
	LeftUpperLeg = "RightUpperLeg",
	LeftLowerLeg = "RightLowerLeg",
	LeftFoot = "RightFoot",
	LeftWingUpper = "RightWingUpper",
	LeftWingLower = "RightWingLower",
}

-- pitchDeg = nod around world/mesh +X, yawDeg = turn around +Y, rollDeg = bank around +Z.
-- Valid for every joint on this rig because R_fix is identical across all of them.
function Authoring.Local(pitchDeg: number?, yawDeg: number?, rollDeg: number?): CFrame
	return CFrame.Angles(math.rad(-(rollDeg or 0)), math.rad(yawDeg or 0), math.rad(pitchDeg or 0))
end

-- Mirrors a LEFT-authored pitch/yaw/roll onto the RIGHT side (or vice versa): turning and banking are
-- handed (negate), nod/extension is not (keep). Use this instead of negating a raw CFrame's Euler angles.
function Authoring.MirrorLocal(pitchDeg: number?, yawDeg: number?, rollDeg: number?): CFrame
	return Authoring.Local(pitchDeg or 0, -(yawDeg or 0), -(rollDeg or 0))
end

local function getOrCreatePose(poseByJoint, jointName, easingStyle, easingDirection)
	if poseByJoint[jointName] then
		return poseByJoint[jointName]
	end
	local parentJoint = Authoring.Hierarchy[jointName]
	assert(parentJoint, "GoldenChickenAnimationAuthoring: unknown joint '" .. tostring(jointName) .. "'")
	local parentPose = getOrCreatePose(poseByJoint, parentJoint, easingStyle, easingDirection)
	local pose = Instance.new("Pose")
	pose.Name = jointName
	pose.CFrame = CFrame.new()
	pose.Weight = 1
	pose.EasingStyle = easingStyle or Enum.PoseEasingStyle.Linear
	pose.EasingDirection = easingDirection or Enum.PoseEasingDirection.InOut
	pose.Parent = parentPose
	poseByJoint[jointName] = pose
	return pose
end

--[[ spec = {
	Name = string, FPS = number, Frames = number, Loop = boolean, Priority = Enum.AnimationPriority,
	Keys = { [frameNumber] = {
		EasingStyle = Enum.PoseEasingStyle?, EasingDirection = Enum.PoseEasingDirection?,
		Joints = { [jointName] = CFrame },   -- from Authoring.Local/MirrorLocal, or CFrame.new() to hold neutral
		Markers = { {Name = string, Value = any?} },
	} },
} ]]
function Authoring.Build(spec)
	assert(type(spec.Name) == "string" and #spec.Name > 0, "spec.Name required")
	assert(type(spec.Keys) == "table" and next(spec.Keys), "spec.Keys required (non-empty)")
	local fps = spec.FPS or 24

	local seq = Instance.new("KeyframeSequence")
	seq.Name = spec.Name
	seq.Loop = spec.Loop or false
	seq.Priority = spec.Priority or Enum.AnimationPriority.Action

	local frameNumbers = {}
	for frameNum in pairs(spec.Keys) do
		table.insert(frameNumbers, frameNum)
	end
	table.sort(frameNumbers)

	for _, frameNum in ipairs(frameNumbers) do
		local keyData = spec.Keys[frameNum]
		local kf = Instance.new("Keyframe")
		kf.Name = tostring(frameNum)
		kf.Time = frameNum / fps

		local poseByJoint = {}
		local rootPose = Instance.new("Pose")
		rootPose.Name = "HumanoidRootPart"
		rootPose.CFrame = CFrame.new()
		rootPose.Weight = 1
		poseByJoint.HumanoidRootPart = rootPose

		if keyData.Joints then
			for jointName, cf in pairs(keyData.Joints) do
				local pose = getOrCreatePose(poseByJoint, jointName, keyData.EasingStyle, keyData.EasingDirection)
				pose.CFrame = cf
			end
		end

		kf:AddPose(rootPose)

		if keyData.Markers then
			for _, m in ipairs(keyData.Markers) do
				local marker = Instance.new("KeyframeMarker")
				marker.Name = m.Name
				marker.Value = m.Value or m.Name
				kf:AddMarker(marker)
			end
		end

		seq:AddKeyframe(kf)
	end

	return seq
end

-- Deterministic validation + human-readable report (frame/pose/marker counts, joint coverage).
function Authoring.Validate(seq: KeyframeSequence)
	local report = {name = seq.Name, loop = seq.Loop, priority = seq.Priority.Name, keyframes = {}}
	local ok = true
	local keyframes = seq:GetKeyframes()
	table.sort(keyframes, function(a, b) return a.Time < b.Time end)
	for _, kf in ipairs(keyframes) do
		local jointsPosed = {}
		local function walk(pose)
			for _, sub in ipairs(pose:GetSubPoses()) do
				table.insert(jointsPosed, sub.Name)
				walk(sub)
			end
		end
		local poses = kf:GetPoses()
		for _, root in ipairs(poses) do
			walk(root)
		end
		local markers = kf:GetMarkers()
		table.insert(report.keyframes, {
			time = kf.Time,
			jointsPosed = jointsPosed,
			markerCount = #markers,
			markerNames = (function()
				local n = {}
				for _, m in ipairs(markers) do table.insert(n, m.Name) end
				return n
			end)(),
		})
	end
	if #keyframes == 0 then
		ok = false
	end
	return ok, report
end

return Authoring
