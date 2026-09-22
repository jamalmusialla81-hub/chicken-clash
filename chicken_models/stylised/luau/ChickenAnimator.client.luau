--[[ ChickenAnimator (client). Only ACTIVE combat chickens (tagged "CombatChicken") get animated - stored /
	preview chickens never run IK or the state machine. The server decides what a chicken is DOING
	(attribute "Action"); the client only renders it.

	State-driven controller: each Action maps to an entry in STATES below, which prefers a real, uploaded
	Moon-Animator-authored AnimationTrack (via GoldenChickenAnimationCatalog) and falls back to the
	original code-driven ChickenPoses library for any animation Jakob hasn't uploaded yet. This means the
	game keeps working exactly as before while animations are uploaded one at a time - nothing has to
	switch over all at once. Once every catalog entry is uploaded, the fallback branch is simply dead code
	and can be deleted; until then it is the real production behaviour for whichever states aren't ready.

	Movement priority tracks (Walk/Run) are full-body, including legs, to match the authored pose
	language - so while one of them is actually playing (real asset only), ChickenLocomotion's procedural
	leg IK is switched off for that chicken (loco.enabled = false) rather than fighting the track for the
	same Motor6Ds. IK resumes the instant the track stops. Non-movement states never touch this flag.

	FIX (found during the Golden Chicken final benchmark): CollectionService tag replication and instance-
	hierarchy replication are not ordered relative to each other. A model tagged in the same server frame
	it is parented could have GetInstanceAddedSignal fire on the client BEFORE model:IsDescendantOf(workspace)
	was true yet, so the old single-shot check silently and permanently skipped it (no crest, no IK, joints
	frozen at identity). attach() retries for up to ~2 seconds instead of giving up after one synchronous
	check. This fix is unrelated to the state machine above and must be preserved as-is. ]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local folder = ReplicatedStorage:WaitForChild("ChickenClash")
local Loco = require(folder:WaitForChild("ChickenLocomotion"))
local Idle = require(folder:WaitForChild("ChickenIdle"))
local Poses = require(folder:WaitForChild("ChickenPoses"))
local Aura = require(folder:WaitForChild("ChickenAura"))
local Catalog = require(folder:WaitForChild("GoldenChickenAnimationCatalog"))
local AuraRegistry = require(folder:WaitForChild("ChickenAuraRegistry"))
local SoundKit = require(folder:WaitForChild("ChickenSoundKit"))

-- Action attribute value -> playback spec. `fallbackPose` names a ChickenPoses.Library entry to use
-- while the real asset is still "PENDING_UPLOAD"; nil means "no procedural equivalent exists" (the state
-- simply does nothing until uploaded - true for every state the brief introduced that didn't exist
-- before: JumpStart/Fall/Land/Dash/M1_2/M1_3).
local STATES = {
	Idle      = { catalog = "Idle",      fallbackPose = nil,          blendIn = 0.25, blendOut = 0.25, movementPriority = false },
	Walk      = { catalog = "Walk",      fallbackPose = nil,          blendIn = 0.20, blendOut = 0.20, movementPriority = true },
	Run       = { catalog = "Run",       fallbackPose = nil,          blendIn = 0.12, blendOut = 0.15, movementPriority = true },
	JumpStart = { catalog = "JumpStart", fallbackPose = nil,          blendIn = 0.05, blendOut = 0.10, movementPriority = false },
	Fall      = { catalog = "Fall",      fallbackPose = nil,          blendIn = 0.15, blendOut = 0.15, movementPriority = false },
	Land      = { catalog = "Land",      fallbackPose = nil,          blendIn = 0.02, blendOut = 0.15, movementPriority = false },
	Dash      = { catalog = "Dash",      fallbackPose = nil,          blendIn = 0.03, blendOut = 0.10, movementPriority = false },
	Attack1   = { catalog = "M1_1",      fallbackPose = "TestAttack", blendIn = 0.02, blendOut = 0.08, movementPriority = false },
	Attack2   = { catalog = "M1_2",      fallbackPose = "TestAttack", blendIn = 0.02, blendOut = 0.08, movementPriority = false },
	Attack3   = { catalog = "M1_3",      fallbackPose = "TestAttack", blendIn = 0.03, blendOut = 0.12, movementPriority = false },
	Entrance  = { catalog = "Entrance",  fallbackPose = "Entrance",   blendIn = 0.10, blendOut = 0.20, movementPriority = false },
	Victory   = { catalog = "Victory",   fallbackPose = "Victory",    blendIn = 0.10, blendOut = 0.20, movementPriority = false },
}
-- states whose Burst-worthy impact should trigger the aura VFX layer (matches the old TestAttack/Entrance/Victory triggers)
local AURA_BURST_STATES = { Entrance = true, Victory = true, Attack1 = true, Attack2 = true, Attack3 = true }

local active = {}
local pending = {} -- model -> true while a retry loop is in flight, so attach() is idempotent under repeated signals

-- one Animation instance + preload per catalog entry that is actually ready; built once at module load
-- and rebuilt if nothing was ready yet (Jakob uploads while the server is running).
local animationInstances = {}
local function buildAnimationInstances()
	for name, entry in pairs(Catalog.Animations) do
		if Catalog.IsReady(name) and not animationInstances[name] then
			local anim = Instance.new("Animation")
			anim.Name = name
			anim.AnimationId = "rbxassetid://" .. tostring(entry.AssetId)
			animationInstances[name] = anim
		end
	end
	local toPreload = {}
	for _, anim in pairs(animationInstances) do
		table.insert(toPreload, anim)
	end
	if #toPreload > 0 then
		task.spawn(function()
			ContentProvider:PreloadAsync(toPreload)
		end)
	end
end
buildAnimationInstances()

local function getOrLoadTrack(a, catalogName)
	if a.tracks[catalogName] then
		return a.tracks[catalogName]
	end
	local anim = animationInstances[catalogName]
	if not anim or not a.animator then
		return nil
	end
	local ok, track = pcall(function()
		return a.animator:LoadAnimation(anim)
	end)
	if not ok or not track then
		return nil
	end
	local entry = Catalog.Animations[catalogName]
	track.Priority = entry.Priority
	track.Looped = entry.Loop
	for _, markerName in ipairs(entry.Markers) do
		track:GetMarkerReachedSignal(markerName):Connect(function(value)
			a.markerEvent:Fire(catalogName, markerName, value)
		end)
	end
	a.tracks[catalogName] = track
	return track
end

local function stopCurrentTrack(a, blendOut)
	if a.currentTrack then
		a.currentTrack:Stop(blendOut)
		a.currentTrack = nil
		a.currentTrackName = nil
	end
	if a.loco.enabled == false then
		a.loco.enabled = true
	end
end

local function detach(model)
	pending[model] = nil
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
	a.markerEvent:Destroy()
	AuraRegistry.Clear(model)
	SoundKit.Cleanup(model)
end

local function doAttach(model)
	if active[model] then
		return
	end
	local idle = Idle.new(model)
	local poses = Poses.new()
	local loco = Loco.attach(model, idle)
	loco.poses = poses
	local aura = Aura.new(model)
	AuraRegistry.Set(model, aura)
	SoundKit.Preload(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local a = {
		loco = loco, aura = aura, poses = poses, conns = {},
		animator = animator, tracks = {}, currentTrack = nil, currentTrackName = nil,
		markerEvent = Instance.new("BindableEvent"),
	}
	active[model] = a

	table.insert(a.conns, RunService.Heartbeat:Connect(function(dt)
		aura:Step(dt, loco.lastIdle)
	end))

	-- marker-driven VFX + sound: same authoritative timing every observer sees (world-space, full
	-- intensity; Aura itself scales down for whichever single client has this chicken as their own
	-- first-person view). SoundKit no-ops silently until Jakob fills in real SoundIds.
	table.insert(a.conns, a.markerEvent.Event:Connect(function(catalogName, markerName)
		if markerName == "Windup" then
			SoundKit.Play(model, "AnticipationFeather")
		elseif markerName == "Impact" then
			if catalogName == "M1_1" then
				aura:AttackEffect("Attack1")
				SoundKit.Play(model, "Impact1")
			elseif catalogName == "M1_2" then
				aura:AttackEffect("Attack2")
				SoundKit.Play(model, "Impact2")
			elseif catalogName == "M1_3" then
				aura:AttackEffect("Attack3")
				SoundKit.Play(model, "ImpactHeavy")
			end
		elseif markerName == "OnSwing" then
			SoundKit.Play(model, catalogName == "M1_3" and "WhooshHeavy" or "Whoosh1")
		elseif catalogName == "Dash" and (markerName == "DashStart" or markerName == "DashEnd") then
			aura:DashEffect(markerName == "DashStart" and "Start" or "End")
			SoundKit.Play(model, markerName)
		elseif catalogName == "Entrance" and markerName == "AuraOn" then
			SoundKit.Play(model, "AuraActivate")
		elseif catalogName == "Entrance" and markerName == "EntranceStart" then
			SoundKit.Play(model, "Entrance")
		elseif catalogName == "Victory" and markerName == "VictoryStart" then
			SoundKit.Play(model, "Victory")
		end
	end))

	local function onAction()
		local action = model:GetAttribute("Action")
		local state = action and STATES[action]

		if not state then
			stopCurrentTrack(a, 0.2)
			poses:Stop()
			return
		end

		if Catalog.IsReady(state.catalog) and a.animator then
			poses:Stop()
			local track = getOrLoadTrack(a, state.catalog)
			if track and a.currentTrackName ~= state.catalog then
				stopCurrentTrack(a, state.blendOut)
				if state.movementPriority then
					a.loco.enabled = false
				end
				track:Play(state.blendIn)
				a.currentTrack = track
				a.currentTrackName = state.catalog
			end
		else
			stopCurrentTrack(a, state.blendOut)
			if state.fallbackPose then
				poses:Play(state.fallbackPose)
			else
				poses:Stop()
			end
		end

		if AURA_BURST_STATES[action] then
			aura:Burst(action)
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

-- Retries readiness checks for ~2s (20 attempts x 0.1s) instead of a single synchronous check, so a model
-- tagged the same frame it is parented (or still mid-clone) is not silently skipped forever.
local function attach(model)
	if active[model] or pending[model] then
		return
	end
	pending[model] = true
	task.spawn(function()
		for _ = 1, 20 do
			if not pending[model] then
				return -- detached or superseded while we were waiting
			end
			if model:IsDescendantOf(workspace) and model:FindFirstChild("HumanoidRootPart") and model:FindFirstChild("LeftFoot") then
				pending[model] = nil
				if CollectionService:HasTag(model, "CombatChicken") then -- could have been untagged while we waited
					doAttach(model)
				end
				return
			end
			task.wait(0.1)
		end
		pending[model] = nil -- gave up; a later re-tag (GetInstanceAddedSignal fires again) will retry
	end)
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
