--[[
	ChickenRig - the ONE shared rig standard for every combat chicken.

	Model space: the chicken faces +X, up is +Y (this matches the Blender export axes and the existing viewers).
	Bones marked "part" are real body parts (MeshParts once imported, simple stand-ins in the test harness).
	Bones marked "attach" become Attachments (aura / trails / weapon / ultimate / finisher target).

	Assemble(model) expects a Model that already contains one BasePart per "part" bone, named exactly as the bone
	and sitting at its rest position. It builds: HumanoidRootPart (the only collider), Motor6Ds with the correct
	pivots, Attachments, a Humanoid and an Animator. Nothing in the visual parts collides or is anchored.
]]

local ChickenRig = {}

-- The mesh's rest legs are nearly straight, so the body stands this much lower than the rest pose. That keeps the knees bent
-- (room for IK to work and a more playful crouched stance) without changing where the feet plant.
ChickenRig.StandDrop = 0.3

ChickenRig.Bones = {
	{ name = "HumanoidRootPart", parent = nil, joint = Vector3.new(-0.15, 1.9, 0), kind = "root" },
	{ name = "Body", parent = "HumanoidRootPart", joint = Vector3.new(-0.15, 2.75, 0), kind = "part" },
	{ name = "Chest", parent = "Body", joint = Vector3.new(0.5, 3.4, 0), kind = "part" },
	{ name = "Neck", parent = "Chest", joint = Vector3.new(0.9, 3.9, 0), kind = "part" },
	{ name = "Head", parent = "Neck", joint = Vector3.new(1.2, 4.4, 0), kind = "part" },
	{ name = "Beak", parent = "Head", joint = Vector3.new(2.4, 4.3, 0), kind = "part" },
	{ name = "Comb", parent = "Head", joint = Vector3.new(1.25, 5.7, 0), kind = "part" },
	{ name = "LeftWingUpper", parent = "Chest", joint = Vector3.new(-0.35, 3.25, -1.55), kind = "part" },
	{ name = "LeftWingLower", parent = "LeftWingUpper", joint = Vector3.new(-0.55, 2.95, -2.15), kind = "part" },
	{ name = "RightWingUpper", parent = "Chest", joint = Vector3.new(-0.35, 3.25, 1.55), kind = "part" },
	{ name = "RightWingLower", parent = "RightWingUpper", joint = Vector3.new(-0.55, 2.95, 2.15), kind = "part" },
	{ name = "Tail", parent = "Body", joint = Vector3.new(-1.45, 3.05, 0), kind = "part" },
	{ name = "LeftUpperLeg", parent = "Body", joint = Vector3.new(0.05, 1.9, -0.85), kind = "part" },
	{ name = "LeftLowerLeg", parent = "LeftUpperLeg", joint = Vector3.new(0.3, 1.2, -0.85), kind = "part" },
	{ name = "LeftFoot", parent = "LeftLowerLeg", joint = Vector3.new(0.55, 0.45, -0.85), kind = "part" },
	{ name = "RightUpperLeg", parent = "Body", joint = Vector3.new(0.05, 1.9, 0.85), kind = "part" },
	{ name = "RightLowerLeg", parent = "RightUpperLeg", joint = Vector3.new(0.3, 1.2, 0.85), kind = "part" },
	{ name = "RightFoot", parent = "RightLowerLeg", joint = Vector3.new(0.55, 0.45, 0.85), kind = "part" },
	{ name = "Cape", parent = "Chest", joint = Vector3.new(-0.4, 4.0, 0), kind = "part" },
	{ name = "Halo", parent = "Head", joint = Vector3.new(1.25, 7.4, 0), kind = "part" },
	{ name = "AuraRoot", parent = "HumanoidRootPart", joint = Vector3.new(-0.15, 0.05, 0), kind = "attach" },
	{ name = "FootSigil", parent = "HumanoidRootPart", joint = Vector3.new(-0.0, 0.02, 0), kind = "attach" },
	{ name = "LeftWingTrail", parent = "LeftWingLower", joint = Vector3.new(-2.3, 1.5, -2.6), kind = "attach" },
	{ name = "RightWingTrail", parent = "RightWingLower", joint = Vector3.new(-2.3, 1.5, 2.6), kind = "attach" },
	{ name = "Weapon", parent = "LeftWingLower", joint = Vector3.new(0.9, 2.6, -2.3), kind = "attach" },
	{ name = "Ultimate", parent = "HumanoidRootPart", joint = Vector3.new(-0.15, 8.4, 0), kind = "attach" },
	{ name = "CrownEffect", parent = "Comb", joint = Vector3.new(1.25, 7.2, 0), kind = "attach" },
	{ name = "BackEffect", parent = "Chest", joint = Vector3.new(-1.6, 3.5, 0), kind = "attach" },
	{ name = "FinisherTarget", parent = "HumanoidRootPart", joint = Vector3.new(4.5, 2.8, 0), kind = "attach" },
}

ChickenRig.Legs = {
	Left = { Upper = "LeftUpperLeg", Lower = "LeftLowerLeg", Foot = "LeftFoot" },
	Right = { Upper = "RightUpperLeg", Lower = "RightLowerLeg", Foot = "RightFoot" },
}

ChickenRig.RequiredParts = {
	"Body", "Chest", "Neck", "Head", "Beak", "Comb", "LeftWingUpper", "LeftWingLower", "RightWingUpper", "RightWingLower", "Tail",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

ChickenRig.Attachments = { "AuraRoot", "FootSigil", "LeftWingTrail", "RightWingTrail", "Weapon", "Ultimate", "CrownEffect", "BackEffect", "FinisherTarget" }

local byName = {}
for _, b in ipairs(ChickenRig.Bones) do
	byName[b.name] = b
end
ChickenRig.ByName = byName

-- joint position of a bone in model space at rest
function ChickenRig.Joint(name: string): Vector3
	return byName[name].joint
end

local HRP_ROT = CFrame.Angles(0, -math.pi / 2, 0) -- HRP forward (-Z) == model forward (+X)

--[[ Turns a model of correctly named parts (at rest, model frame, facing +X) into a working rig.
	origin: where the model's rest frame origin should end up in the world (CFrame with no scaling). ]]
function ChickenRig.Assemble(model: Model, origin: CFrame?)
	origin = origin or CFrame.new()
	local restCF = {}
	for _, b in ipairs(ChickenRig.Bones) do
		if b.kind == "part" then
			local part = model:FindFirstChild(b.name)
			assert(part and part:IsA("BasePart"), "ChickenRig: missing part " .. b.name)
			restCF[b.name] = part.CFrame
		end
	end

	local hrpBone = byName.HumanoidRootPart
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then
		hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(1.8, 1.0, 1.8)
		hrp.Transparency = 1
		hrp.Parent = model
	end
	local hrpRest = CFrame.new(hrpBone.joint) * HRP_ROT
	hrp.CFrame = hrpRest
	hrp.CanCollide = true
	hrp.CanTouch = false
	hrp.CanQuery = false
	hrp.Anchored = false
	hrp.Massless = false

	local function jointCF(name)
		return CFrame.new(byName[name].joint)
	end
	local partCF = { HumanoidRootPart = hrpRest }
	for name, cf in pairs(restCF) do
		partCF[name] = cf
	end

	for _, b in ipairs(ChickenRig.Bones) do
		if b.kind == "part" then
			local part = model[b.name]
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			part.CastShadow = false
			local parentName = b.parent
			local m = Instance.new("Motor6D")
			m.Name = (parentName == "HumanoidRootPart") and "RootJoint" or b.name
			m.Part0 = model[parentName]
			m.Part1 = part
			local j = jointCF(b.name)
			m.C0 = partCF[parentName]:Inverse() * j
			m.C1 = partCF[b.name]:Inverse() * j
			m.Parent = part
		end
	end

	for _, b in ipairs(ChickenRig.Bones) do
		if b.kind == "attach" then
			local parentPart = model[b.parent]
			local a = Instance.new("Attachment")
			a.Name = b.name
			a.CFrame = partCF[b.parent]:Inverse() * jointCF(b.name)
			a.Parent = parentPart
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.AutoJumpEnabled = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HipHeight = math.max(hrpBone.joint.Y - hrp.Size.Y / 2 - ChickenRig.StandDrop, 0.5)
	humanoid.Parent = model
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end

	model.PrimaryPart = hrp
	model:PivotTo(origin * hrp.CFrame) -- the rest frame origin lands on `origin`
	return model
end

-- Simple stand-in parts (NOT final art): sized boxes/balls at each bone so the rig, IK and animation can be tested
-- before the imported MeshParts exist.
local PROXY = {
	Body = Vector3.new(3.0, 2.8, 3.0), Chest = Vector3.new(1.6, 1.8, 2.4), Neck = Vector3.new(0.8, 1.0, 1.4), Head = Vector3.new(2.5, 2.4, 2.6),
	Beak = Vector3.new(1.0, 0.5, 0.9), Comb = Vector3.new(0.5, 1.2, 1.6), LeftWingUpper = Vector3.new(1.0, 1.0, 1.0), LeftWingLower = Vector3.new(1.0, 2.2, 2.6),
	RightWingUpper = Vector3.new(1.0, 1.0, 1.0), RightWingLower = Vector3.new(1.0, 2.2, 2.6), Tail = Vector3.new(2.6, 1.4, 2.4),
	LeftUpperLeg = Vector3.new(0.8, 0.9, 0.8), LeftLowerLeg = Vector3.new(0.5, 0.9, 0.5), LeftFoot = Vector3.new(1.6, 0.4, 1.2),
	RightUpperLeg = Vector3.new(0.8, 0.9, 0.8), RightLowerLeg = Vector3.new(0.5, 0.9, 0.5), RightFoot = Vector3.new(1.6, 0.4, 1.2),
	Cape = Vector3.new(0.2, 2.0, 2.4), Halo = Vector3.new(2.0, 0.15, 2.0),
}
local PROXY_COLOR = {
	Body = Color3.fromRGB(255, 240, 200), Chest = Color3.fromRGB(255, 214, 90), Neck = Color3.fromRGB(255, 240, 200), Head = Color3.fromRGB(255, 240, 200),
	Beak = Color3.fromRGB(255, 160, 50), Comb = Color3.fromRGB(255, 200, 60), Tail = Color3.fromRGB(255, 190, 70), Cape = Color3.fromRGB(190, 40, 52),
	Halo = Color3.fromRGB(255, 240, 170),
}

function ChickenRig.BuildProxy(name: string?): Model
	local model = Instance.new("Model")
	model.Name = name or "ProxyChicken"
	for _, b in ipairs(ChickenRig.Bones) do
		if b.kind == "part" then
			local child
			for _, c in ipairs(ChickenRig.Bones) do
				if c.parent == b.name and c.kind == "part" then
					child = c
					break
				end
			end
			local a = b.joint
			local z = child and child.joint or (a + Vector3.new(0, 0.6, 0))
			local p = Instance.new("Part")
			p.Name = b.name
			p.Size = PROXY[b.name] or Vector3.new(1, 1, 1)
			if string.find(b.name, "Leg") or string.find(b.name, "Foot") then
				p.Color = Color3.fromRGB(255, 200, 70)
			else
				p.Color = PROXY_COLOR[b.name] or Color3.fromRGB(255, 226, 120)
			end
			p.Material = Enum.Material.SmoothPlastic
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			local centre = (b.name == "Foot" or string.find(b.name, "Foot")) and (a + Vector3.new(0.5, -0.2, 0)) or (a + z) / 2
			if b.name == "Body" then centre = a end
			if b.name == "Head" then centre = a + Vector3.new(0, 0.9, 0) end
			p.CFrame = CFrame.new(centre)
			p.Parent = model
		end
	end
	ChickenRig.Assemble(model, CFrame.new())
	return model
end

return ChickenRig
