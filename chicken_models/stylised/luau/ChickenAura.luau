--[[ ChickenAura - effects only (no aura baked into the mesh). Uses the rig's named attachments.
	Golden: royal crest under the feet, occasional falling gold sparkle-feather, slow clean halo turn, faint warm outline.
	Quality: 0 = off, 1 = low (crest only), 2 = full. Emitters are created once per chicken and reused (never per burst);
	the crest disc comes from a small shared pool. Everything is removed by :Destroy(). ]]
local UserGameSettings = UserSettings():GetService("UserGameSettings")

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
	self.built = false
	self:_build()
	return self
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
	for _, k in ipairs({ "feathers", "glint", "outline" }) do
		if self[k] then
			self[k]:Destroy()
			self[k] = nil
		end
	end
end

return Aura
