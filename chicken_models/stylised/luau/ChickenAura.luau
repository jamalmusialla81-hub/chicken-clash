--[[ ChickenAura - effects only (no aura baked into the mesh). Uses the rig's named attachments.
	Golden: royal crest under the feet, occasional falling gold sparkle-feather, slow clean halo turn, faint warm outline.
	Quality: 0 = off, 1 = low (crest only), 2 = full. Emitters are created once per chicken and reused (never per burst);
	the crest disc comes from a small shared pool. Everything is removed by :Destroy(). ]]
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local Debris = game:GetService("Debris")

local Aura = {}
Aura.__index = Aura

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds" -- built-in engine texture, no upload needed
local GOLD = Color3.fromRGB(255, 214, 96)

local crestPool: { Part } = {}

local function takeCrest(): Part
	local p = table.remove(crestPool)
	if p then
		return p
	end
	p = Instance.new("Part")
	p.Name = "RoyalCrest"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.12, 5.4, 5.4)
	p.Anchored = false
	p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.CastShadow = false, false, false, true, false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Transparency = 0.72
	return p
end

function Aura.defaultQuality(): number
	local q = UserGameSettings.SavedQualityLevel.Value
	if q == 0 then
		-- "Automatic": full effects on desktop, reduced on touch devices
		return game:GetService("UserInputService").TouchEnabled and 1 or 2
	elseif q <= 2 then
		return 0
	elseif q <= 5 then
		return 1
	end
	return 2
end

function Aura.new(model: Model, quality: number?)
	local self = setmetatable({}, Aura)
	self.model = model
	self.quality = quality or Aura.defaultQuality()
	self.haloAngle = 0
	self.firstPerson = false
	self.built = false
	self:_build()
	self:_buildAttackEmitters()
	return self
end

-- Two-context VFX: called by ChickenCombatCameraController when this chicken becomes (or stops being)
-- the local player's own first-person view. Idle aura (crest/feathers/glint/outline) gets greatly reduced
-- or hidden since it sits right in front of the camera; attack/dash effects stay - they read as short
-- peripheral motion, not a static obstruction, and section 9 only asks the IDLE aura to be reduced.
function Aura:SetFirstPerson(isFirstPerson: boolean)
	if self.firstPerson == isFirstPerson then
		return
	end
	self.firstPerson = isFirstPerson
	local idleAlpha = isFirstPerson and 0.15 or 1
	if self.crest then
		self.crest.LocalTransparencyModifier = isFirstPerson and 0.9 or 0
	end
	if self.feathers then
		self.feathers.Rate = 1.2 * idleAlpha
	end
	if self.outline then
		self.outline.Enabled = not isFirstPerson
	end
end

function Aura:_build()
	local m = self.model
	local sigilA = m:FindFirstChild("FootSigil", true)
	local backA = m:FindFirstChild("BackEffect", true)
	local crownA = m:FindFirstChild("CrownEffect", true)
	local aura = m:FindFirstChild("AuraRoot", true)
	self.parts = {}
	if self.quality >= 1 and aura and aura:IsA("Attachment") and sigilA then
		local crest = takeCrest()
		crest.CFrame = aura.WorldCFrame * CFrame.Angles(0, 0, math.pi / 2) * CFrame.new(0, 0, 0)
		crest.Parent = m
		local w = Instance.new("Weld")
		w.Part0 = sigilA.Parent
		w.Part1 = crest
		w.C0 = sigilA.CFrame * CFrame.Angles(0, 0, math.pi / 2)
		w.Parent = crest
		self.crest = crest
	end
	if self.quality >= 2 then
		if backA then
			local e = Instance.new("ParticleEmitter")
			e.Name = "FallingFeathers"
			e.Texture = SPARKLE
			e.Color = ColorSequence.new(GOLD)
			e.LightEmission = 0.7
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.05) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			e.Lifetime = NumberRange.new(2.0, 3.2)
			e.Rate = 1.2 -- "occasional"
			e.Speed = NumberRange.new(0.2, 0.6)
			e.Acceleration = Vector3.new(0, -2.2, 0)
			e.SpreadAngle = Vector2.new(60, 60)
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-60, 60)
			e.Parent = backA
			self.feathers = e
		end
		if crownA then
			local e = Instance.new("ParticleEmitter")
			e.Name = "CrownGlint"
			e.Texture = SPARKLE
			e.Color = ColorSequence.new(Color3.fromRGB(255, 244, 190))
			e.LightEmission = 1
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
			e.Lifetime = NumberRange.new(0.5, 0.8)
			e.Rate = 0
			e.Speed = NumberRange.new(0, 0.5)
			e.Parent = crownA
			self.glint = e
		end
		local h = Instance.new("Highlight")
		h.Name = "IdleOutline"
		h.FillTransparency = 1
		h.OutlineColor = Color3.fromRGB(255, 196, 96)
		h.OutlineTransparency = 0.65
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = m
		self.outline = h
	end
	self.built = true
end

-- Built once alongside the idle aura (not per-burst) - M1_1/M1_2/M1_3 wing arcs, dash streaks, and a
-- shared impact-spark emitter. Deep red is kept restrained (accent only, on the impact ring) so the
-- overall identity stays royal-gold/warm-yellow per the brief's colour language.
local DEEP_RED = Color3.fromRGB(150, 40, 40)

function Aura:_buildAttackEmitters()
	local m = self.model
	local leftWingTrailA = m:FindFirstChild("LeftWingTrail", true)
	local rightWingTrailA = m:FindFirstChild("RightWingTrail", true)
	local finisherA = m:FindFirstChild("FinisherTarget", true)

	local function makeArcEmitter(attachment: Attachment?, name: string)
		if not attachment then
			return nil
		end
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		e.Texture = SPARKLE
		e.Color = ColorSequence.new(GOLD)
		e.LightEmission = 0.85
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.18, 0.28)
		e.Rate = 0
		e.Speed = NumberRange.new(4, 7)
		e.SpreadAngle = Vector2.new(20, 20)
		e.Parent = attachment
		return e
	end

	self.leftArc = makeArcEmitter(leftWingTrailA, "AttackArcLeft")
	self.rightArc = makeArcEmitter(rightWingTrailA, "AttackArcRight")

	if finisherA then
		local impact = Instance.new("ParticleEmitter")
		impact.Name = "ImpactRing"
		impact.Texture = SPARKLE
		impact.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 200)),
			ColorSequenceKeypoint.new(0.4, GOLD),
			ColorSequenceKeypoint.new(1, DEEP_RED),
		})
		impact.LightEmission = 1
		impact.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.4) })
		impact.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
		impact.Lifetime = NumberRange.new(0.2, 0.32)
		impact.Rate = 0
		impact.Speed = NumberRange.new(6, 10)
		impact.SpreadAngle = Vector2.new(180, 180)
		impact.Parent = finisherA
		self.impactRing = impact
	end

	if leftWingTrailA then
		local t = Instance.new("Trail")
		t.Name = "DashStreakLeft"
		t.Attachment0 = leftWingTrailA
		t.Attachment1 = leftWingTrailA
		t.Color = ColorSequence.new(GOLD)
		t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		t.Lifetime = 0.25
		t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		t.Enabled = false
		t.Parent = leftWingTrailA.Parent
		self.dashTrailLeft = t
	end
	if rightWingTrailA then
		local t = Instance.new("Trail")
		t.Name = "DashStreakRight"
		t.Attachment0 = rightWingTrailA
		t.Attachment1 = rightWingTrailA
		t.Color = ColorSequence.new(GOLD)
		t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		t.Lifetime = 0.25
		t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		t.Enabled = false
		t.Parent = rightWingTrailA.Parent
		self.dashTrailRight = t
	end
end

--============================== beam slash rig (pooled) ==============================--
-- Real gap this closes: the only "slash" feedback before this was small particle bursts at the wing
-- attachments - never an actual claw-mark arc crossing the view, which the VFX rebuild spec calls for
-- explicitly. Three curved Beam attachments, alternating direction per attack in the combo, pooled and
-- returned after each play rather than created/destroyed per swing.
local SLASH_RIG_POOL: { Model } = {}
local SLASH_DIRECTIONS = {
	Attack1 = 1, -- left-to-right
	Attack2 = -1, -- right-to-left
	Attack3 = 1, -- left-to-right, wider/brighter (finisher)
}

local function buildSlashArc(rig: Model, index: number, radius: number)
	local a0 = Instance.new("Attachment")
	a0.Name = "A0_" .. index
	a0.Position = Vector3.new(-radius, (index - 2) * 0.35, 0)
	a0.Parent = rig.PrimaryPart

	local a1 = Instance.new("Attachment")
	a1.Name = "A1_" .. index
	a1.Position = Vector3.new(radius, (index - 2) * 0.35, 0)
	a1.Parent = rig.PrimaryPart

	local beam = Instance.new("Beam")
	beam.Name = "SlashBeam" .. index
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = true
	beam.Segments = 16
	beam.CurveSize0 = radius * 0.9
	beam.CurveSize1 = -radius * 0.9
	beam.Width0 = 0
	beam.Width1 = 0
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 235)), -- narrow bright cream core
		ColorSequenceKeypoint.new(0.5, GOLD),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(233, 130, 50)), -- wider orange/gold outer edge
	})
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.1),
		NumberSequenceKeypoint.new(0.85, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.TextureSpeed = 3
	beam.TextureLength = 1
	beam.LightEmission = 0.9
	beam.Parent = rig.PrimaryPart
	return beam
end

local function newSlashRig(): Model
	local rig = Instance.new("Model")
	rig.Name = "SlashRig"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide, root.CanTouch, root.CanQuery, root.CastShadow = false, false, false, false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Parent = rig
	rig.PrimaryPart = root
	local beams = {}
	for i = 1, 3 do
		table.insert(beams, buildSlashArc(rig, i, 3 + i * 0.4))
	end
	rig:SetAttribute("BeamCount", #beams)
	rig.Parent = workspace
	return rig
end

local function takeSlashRig(): Model
	local rig = table.remove(SLASH_RIG_POOL)
	return rig or newSlashRig()
end

local function returnSlashRig(rig: Model)
	rig.Parent = nil
	table.insert(SLASH_RIG_POOL, rig)
end

-- Plays the three-arc slash in front of the given attachment, oriented along `direction` (1 or -1), and
-- animates width 0 -> peak -> 0 over the swing plus a quick rotation sweep (the "tween the parent's
-- rotation to create rapid slash motion" step). Returns the rig to the pool when done.
local function playSlashRig(anchor: Attachment, direction: number, scale: number)
	local rig = takeSlashRig()
	local root = rig.PrimaryPart
	local baseCFrame = anchor.WorldCFrame * CFrame.Angles(0, direction > 0 and 0 or math.pi, 0)
	root.CFrame = baseCFrame
	root.Parent = rig

	local beams = {}
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("Beam") then
			table.insert(beams, child)
		end
	end

	local DURATION = 0.16
	task.spawn(function()
		local startTime = os.clock()
		local sweepStart = baseCFrame * CFrame.Angles(0, math.rad(-35), 0)
		local sweepEnd = baseCFrame * CFrame.Angles(0, math.rad(35), 0)
		while true do
			local elapsed = os.clock() - startTime
			local alpha = math.clamp(elapsed / DURATION, 0, 1)
			-- width envelope: 0 -> peak -> 0
			local widthAlpha = alpha < 0.5 and (alpha * 2) or (1 - (alpha - 0.5) * 2)
			for _, beam in ipairs(beams) do
				beam.Width0 = widthAlpha * 0.15 * scale
				beam.Width1 = widthAlpha * 1.1 * scale
			end
			root.CFrame = sweepStart:Lerp(sweepEnd, alpha)
			if alpha >= 1 then
				break
			end
			task.wait()
		end
		for _, beam in ipairs(beams) do
			beam.Width0, beam.Width1 = 0, 0
		end
		returnSlashRig(rig)
	end)
end

-- name: "Attack1"|"Attack2"|"Attack3". Compact arcs for the first two hits, a heavier impact ring
-- (with the finisher's restrained deep-red accent) for the third, matching the brief's per-hit VFX spec.
-- Also plays the beam slash rig, alternating arc direction per attack in the combo (M1_1/M1_2/M1_3 each
-- read as a distinct slash, not the same animation replayed three times).
function Aura:AttackEffect(name: string)
	if self.quality < 1 then
		return
	end
	local anchor = self.model:FindFirstChild("FinisherTarget", true) or self.model:FindFirstChild("Chest", true)
	local direction = SLASH_DIRECTIONS[name] or 1
	if anchor then
		if anchor:IsA("BasePart") then
			-- FinisherTarget/Chest may be a Part rather than an Attachment - use its centre as an anchor
			local temp = Instance.new("Attachment")
			temp.WorldCFrame = anchor.CFrame
			playSlashRig(temp, direction, name == "Attack3" and 1.4 or 1)
			temp:Destroy()
		else
			playSlashRig(anchor, direction, name == "Attack3" and 1.4 or 1)
		end
	end
	if name == "Attack1" and self.leftArc then
		self.leftArc:Emit(self.firstPerson and 4 or 10)
	elseif name == "Attack2" and self.rightArc then
		self.rightArc:Emit(self.firstPerson and 5 or 14)
	elseif name == "Attack3" and self.impactRing then
		self.impactRing:Emit(self.firstPerson and 8 or 20)
	end
end

-- Real gap this closes: confirmed-hit feedback (shake/recoil/hitmarker/damage numbers) existed, but
-- nothing produced the "tiny PointLight flash" the impact-feel spec calls for. One-shot, pooled-by-reuse
-- (a single light per chicken, just re-triggered) rather than spawning a new instance per hit.
function Aura:ImpactFlash()
	if self.quality < 1 then
		return
	end
	local anchor = self.model:FindFirstChild("FinisherTarget", true) or self.model.PrimaryPart
	if not anchor then
		return
	end
	if not self.impactLight then
		local light = Instance.new("PointLight")
		light.Name = "ImpactFlash"
		light.Color = Color3.fromRGB(255, 232, 160)
		light.Range = 10
		light.Brightness = 0
		light.Parent = anchor:IsA("Attachment") and anchor or anchor
		self.impactLight = light
	end
	self.impactLight.Brightness = 4
	task.delay(0.12, function()
		if self.impactLight then
			self.impactLight.Brightness = 0
		end
	end)
end

-- Real gap this closes: dash had a streak Trail but nothing marked WHERE it ended - the "completion dust"/
-- "ground debris" step. Raycasts straight down from the chicken so the dust genuinely reacts to whatever
-- surface it lands on (Practice Range floor, arena ground, portal disc, etc.) instead of a fixed color;
-- reuses the same SPARKLE texture already proven elsewhere in this file rather than an unverified new asset.
local function spawnDashDust(model: Model)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local result = workspace:Raycast(hrp.Position, Vector3.new(0, -8, 0), params)
	if not result then
		return
	end
	local groundColor = (result.Instance :: BasePart).Color or Color3.fromRGB(200, 200, 190)

	local anchor = Instance.new("Part")
	anchor.Name = "DashDustAnchor"
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.CastShadow = false, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(result.Position)
	anchor.Parent = workspace

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = SPARKLE
	dust.Color = ColorSequence.new(groundColor:Lerp(Color3.new(1, 1, 1), 0.35))
	dust.LightEmission = 0
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.6) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.35, 0.6)
	dust.Rate = 0
	dust.Speed = NumberRange.new(3, 6)
	dust.SpreadAngle = Vector2.new(50, 15)
	dust.Acceleration = Vector3.new(0, -6, 0)
	dust.Parent = anchor
	dust:Emit(10)

	Debris:AddItem(anchor, 1)
end

function Aura:DashEffect(startOrEnd: string)
	if self.quality < 1 then
		return
	end
	local enable = startOrEnd == "Start"
	if self.dashTrailLeft then
		self.dashTrailLeft.Enabled = enable
	end
	if self.dashTrailRight then
		self.dashTrailRight.Enabled = enable
	end
	if startOrEnd == "End" then
		spawnDashDust(self.model)
	end
end

-- called each frame by the animator with the idle layer output; drives the halo turn + crown reaction
function Aura:Step(dt: number, idle: any?)
	local halo = self.model:FindFirstChild("Halo")
	local j = halo and halo:FindFirstChildOfClass("Motor6D")
	if j then
		self.haloAngle = (self.haloAngle + dt * 0.6) % (math.pi * 2)
		j.Transform = CFrame.Angles(0, self.haloAngle, 0)
	end
	if idle and idle.crown and idle.crown > 0.8 and self.glint and not self.glintFired then
		self.glintFired = true
		self.glint:Emit(6)
	elseif idle and idle.crown and idle.crown < 0.1 then
		self.glintFired = false
	end
end

-- stronger effects only on abilities / ultimate / reveal
function Aura:Burst(kind: string)
	if self.quality < 2 then
		return
	end
	if self.feathers then
		self.feathers:Emit(kind == "Ultimate" and 24 or 10)
	end
	if self.glint then
		self.glint:Emit(kind == "Ultimate" and 20 or 8)
	end
	if self.outline then
		self.outline.OutlineTransparency = 0.1
		task.delay(0.7, function()
			if self.outline and self.outline.Parent then
				self.outline.OutlineTransparency = 0.65
			end
		end)
	end
end

function Aura:SetQuality(q: number)
	if q == self.quality then
		return
	end
	self:Destroy(true)
	self.quality = q
	self:_build()
	self:_buildAttackEmitters()
end

function Aura:Destroy(keepModel: boolean?)
	if self.crest then
		local w = self.crest:FindFirstChildOfClass("Weld")
		if w then
			w:Destroy()
		end
		self.crest.Parent = nil
		table.insert(crestPool, self.crest)
		self.crest = nil
	end
	for _, k in ipairs({ "feathers", "glint", "outline", "leftArc", "rightArc", "impactRing", "dashTrailLeft", "dashTrailRight", "impactLight" }) do
		if self[k] then
			self[k]:Destroy()
			self[k] = nil
		end
	end
end

return Aura
