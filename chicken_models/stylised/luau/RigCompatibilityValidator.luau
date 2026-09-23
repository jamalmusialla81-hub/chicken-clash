--[[ RigCompatibilityValidator (server, ServerScriptService.Combat). Phase 6: the real gate deciding
	whether a candidate combat chicken's rig can safely share Golden Chicken's animations and hit timing.
	Every check inspects real Instance properties on both rigs at server start - nothing here is guessed
	or hardcoded per chicken name, and a candidate fails outright (with the actual reason recorded) rather
	than being nudged into a "probably fine" pass. Golden Chicken remains the only automatically-trusted
	rig until a candidate genuinely passes every check below AND live testing (done separately, by hand)
	confirms no detachment/clipping/bad foot placement/broken hit alignment.

	Checks performed (per the Phase 6 brief): Motor6D hierarchy + joint names (exact topology), required
	attachments, forward-axis convention, proportions, PrimaryPart, collision-part convention. Animations
	are authored as per-joint Motor6D.Transform deltas relative to each joint's own rest C0/C1, so exact
	joint NAME/topology equality (not exact C0/C1 equality) is what actually determines whether a track
	retargets correctly - two rigs with the same joint graph but different limb lengths can still share an
	animation, just with more risk of clipping/foot-sliding at extreme proportion differences, which is why
	proportions is its own check rather than folded into topology. ]]

local RigCompatibilityValidator = {}

local function motor6dSignature(model: Model)
	local joints = {}
	local count = 0
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("Motor6D") and obj.Part0 and obj.Part1 then
			joints[obj.Name] = { part0 = obj.Part0.Name, part1 = obj.Part1.Name }
			count += 1
		end
	end
	return joints, count
end

local function attachmentSignature(model: Model)
	local set = {}
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("Attachment") and obj.Parent then
			set[obj.Parent.Name .. "/" .. obj.Name] = true
		end
	end
	return set
end

local function collideSignature(model: Model)
	local set = {}
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") and obj.CanCollide then
			set[obj.Name] = true
		end
	end
	return set
end

-- Forward axis: the rest-pose offset of Head relative to HumanoidRootPart, expressed in the HRP's own
-- local space - comparing the LOCAL-space direction (not world-space) means two rigs built facing
-- different world directions in their storage folder still compare correctly; only the relative
-- "which local axis is forward" convention has to match for animations authored in joint-local space to
-- look right on both.
local function forwardAxisSample(model: Model)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	if not hrp or not head then
		return nil
	end
	local localOffset = hrp.CFrame:PointToObjectSpace(head.Position)
	if localOffset.Magnitude < 0.001 then
		return nil
	end
	return localOffset.Unit
end

-- candidate/reference are Models (e.g. ServerStorage.CombatChickens["Red Chicken"] vs ["Golden Chicken"]).
-- Returns (compatible: boolean, reasons: {string}, checks: {[string]: boolean}) - reasons is empty when
-- compatible is true; checks always has one entry per check performed, for callers that want the detail.
function RigCompatibilityValidator.Validate(candidate: Model, reference: Model)
	local reasons = {}
	local checks = {}

	-- 1. PrimaryPart
	local candidatePrimary = candidate.PrimaryPart and candidate.PrimaryPart.Name
	local referencePrimary = reference.PrimaryPart and reference.PrimaryPart.Name
	checks.primaryPart = candidatePrimary ~= nil and candidatePrimary == referencePrimary
	if not checks.primaryPart then
		table.insert(reasons, string.format(
			"PrimaryPart mismatch: candidate=%s reference=%s", tostring(candidatePrimary), tostring(referencePrimary)))
	end

	-- 2. Humanoid / rig presence
	local candidateHumanoid = candidate:FindFirstChildOfClass("Humanoid")
	checks.hasHumanoid = candidateHumanoid ~= nil
	if not checks.hasHumanoid then
		table.insert(reasons, "No Humanoid instance - candidate is not a skeletal/animatable rig")
	end

	-- 3. Motor6D hierarchy + joint names (exact topology match required)
	local candidateJoints, candidateJointCount = motor6dSignature(candidate)
	local referenceJoints, referenceJointCount = motor6dSignature(reference)
	local topologyMatches = candidateJointCount > 0 and candidateJointCount == referenceJointCount
	if topologyMatches then
		for name, ref in pairs(referenceJoints) do
			local cand = candidateJoints[name]
			if not cand or cand.part0 ~= ref.part0 or cand.part1 ~= ref.part1 then
				topologyMatches = false
				break
			end
		end
	end
	checks.motor6dTopology = topologyMatches
	if not topologyMatches then
		if candidateJointCount == 0 then
			table.insert(reasons, "Candidate has zero Motor6D joints - it is a static/decorative model with no skeleton, not a rig")
		else
			table.insert(reasons, string.format(
				"Motor6D joint hierarchy does not match reference: candidate has %d joint(s), reference has %d, and/or joint names or Part0/Part1 topology differ",
				candidateJointCount, referenceJointCount))
		end
	end

	-- 4. Attachments required for existing combat/camera systems to function on this rig
	local requiredAttachments = { "Chest/CombatCameraAttachment" }
	local candidateAttachments = attachmentSignature(candidate)
	local missingAttachments = {}
	for _, req in ipairs(requiredAttachments) do
		if not candidateAttachments[req] then
			table.insert(missingAttachments, req)
		end
	end
	checks.attachments = #missingAttachments == 0
	if not checks.attachments then
		table.insert(reasons, "Missing required attachment(s): " .. table.concat(missingAttachments, ", "))
	end

	-- 5. Forward-axis convention
	local candidateForward = forwardAxisSample(candidate)
	local referenceForward = forwardAxisSample(reference)
	if candidateForward and referenceForward then
		local dot = candidateForward:Dot(referenceForward)
		checks.forwardAxis = dot > 0.85
		if not checks.forwardAxis then
			table.insert(reasons, string.format(
				"Forward-axis convention differs from reference (Head-vs-root local alignment dot=%.2f)", dot))
		end
	else
		checks.forwardAxis = false
		table.insert(reasons, "Could not sample forward axis - missing HumanoidRootPart and/or Head")
	end

	-- 6. Proportions: overall bounding-box axis ratios must scale roughly uniformly relative to the
	-- reference, or a shared animation will clip/foot-slide even with matching joint topology.
	local candOk, _candCF, candSize = pcall(function() return candidate:GetBoundingBox() end)
	local refOk, _refCF, refSize = pcall(function() return reference:GetBoundingBox() end)
	if candOk and refOk then
		local rx = candSize.X / math.max(refSize.X, 0.001)
		local ry = candSize.Y / math.max(refSize.Y, 0.001)
		local rz = candSize.Z / math.max(refSize.Z, 0.001)
		local minR, maxR = math.min(rx, ry, rz), math.max(rx, ry, rz)
		checks.proportions = (maxR / math.max(minR, 0.001)) < 1.35
		if not checks.proportions then
			table.insert(reasons, string.format(
				"Proportions differ too much between axes to share animation without clipping (bounding-box ratios X=%.2f Y=%.2f Z=%.2f)",
				rx, ry, rz))
		end
	else
		checks.proportions = false
		table.insert(reasons, "Could not compute bounding box for proportions check")
	end

	-- 7. Collisions: same convention as the reference (today: only HumanoidRootPart collides)
	local candidateCollide = collideSignature(candidate)
	local referenceCollide = collideSignature(reference)
	local collideMatches = true
	for name in pairs(referenceCollide) do
		if not candidateCollide[name] then collideMatches = false end
	end
	for name in pairs(candidateCollide) do
		if not referenceCollide[name] then collideMatches = false end
	end
	checks.collisions = collideMatches
	if not collideMatches then
		table.insert(reasons, "CanCollide part set differs from reference convention")
	end

	local compatible = true
	for _, passed in pairs(checks) do
		if not passed then
			compatible = false
			break
		end
	end

	return compatible, reasons, checks
end

return RigCompatibilityValidator
