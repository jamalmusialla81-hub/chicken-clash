--[[ ChickenAnimator (client). Only ACTIVE combat chickens (tagged "CombatChicken") get procedural animation - stored /
	preview chickens never run IK. Everything is torn down when the model leaves the world (no leaked connections).
	The server decides what a chicken is DOING (attribute "Action"); the client only renders it. ]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("ChickenClash")
local Loco = require(folder:WaitForChild("ChickenLocomotion"))
local Idle = require(folder:WaitForChild("ChickenIdle"))
local Poses = require(folder:WaitForChild("ChickenPoses"))
local Aura = require(folder:WaitForChild("ChickenAura"))

local active = {}

local function detach(model)
	local a = active[model]
	if not a then
		return
	end
	active[model] = nil
	for _, c in ipairs(a.conns) do
		c:Disconnect()
	end
	a.loco:Destroy()
	if a.loco.conn then
		a.loco.conn:Disconnect()
	end
	a.aura:Destroy()
end

local function attach(model)
	if active[model] or not model:IsDescendantOf(workspace) then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not model:FindFirstChild("LeftFoot") then
		return
	end
	local idle = Idle.new(model)
	local poses = Poses.new()
	local loco = Loco.attach(model, idle)
	loco.poses = poses
	local aura = Aura.new(model)
	local a = { loco = loco, aura = aura, poses = poses, conns = {} }
	active[model] = a
	table.insert(a.conns, RunService.Heartbeat:Connect(function(dt)
		aura:Step(dt, loco.lastIdle)
	end))
	local function onAction()
		local action = model:GetAttribute("Action")
		if action and Poses.Library[action] then
			poses:Play(action)
			if action == "Entrance" or action == "Victory" or action == "TestAttack" then
				aura:Burst(action)
			end
		else
			poses:Stop()
		end
	end
	table.insert(a.conns, model:GetAttributeChangedSignal("Action"):Connect(onAction))
	table.insert(a.conns, model.Destroying:Connect(function() detach(model) end))
	table.insert(a.conns, model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			detach(model)
		end
	end))
	onAction()
end

CollectionService:GetInstanceAddedSignal("CombatChicken"):Connect(attach)
CollectionService:GetInstanceRemovedSignal("CombatChicken"):Connect(detach)
for _, m in ipairs(CollectionService:GetTagged("CombatChicken")) do
	attach(m)
end

-- follow graphics-quality changes (reduced-effects path)
local ugs = UserSettings():GetService("UserGameSettings")
ugs:GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
	local q = Aura.defaultQuality()
	for _, a in pairs(active) do
		a.aura:SetQuality(q)
	end
end)
