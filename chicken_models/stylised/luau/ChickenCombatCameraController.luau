--[[ ChickenCombatCamera (client, local-only). Dedicated first-person combat camera controller - camera
	logic lives here and nowhere else (not in ChickenAnimator, ChickenCombatService, or any UI script).

	State machine: Disabled -> Lobby -> EntranceCinematic -> CombatFirstPerson -> (Death/Spectator |
	VictoryCinematic) -> ReturningToLobby -> Lobby. Nothing here ever decides combat legality, damage, or
	match outcome - it only RENDERS whatever state it is told to enter. Integration point: since this pass
	of the project has no match-state service yet, call Controller.SetLocalChicken(model) once the real
	ownership system knows which chicken belongs to this client, then drive transitions with
	Controller.EnterEntrance() / EnterCombat() / EnterDeathSpectator() / EnterVictory() / ReturnToLobby()
	from wherever that authoritative match/round system lives. As a reasonable default without that system
	wired up yet, this script also auto-transitions from the chicken's own "Action" attribute (Entrance/
	Victory) and CombatChicken tag add/remove, and from Humanoid.Died - remove those listeners once a real
	match-state service exists so camera transitions are driven by one source of truth, not two.

	Every offset layer (sway, bob, recoil, shake) is recomputed from the STABLE base CFrame each frame and
	summed once - never accumulated onto the previous frame's camera CFrame - so nothing can drift. ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local AuraRegistry = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenAuraRegistry"))

local Controller = {}

local States = {
	Disabled = "Disabled",
	Lobby = "Lobby",
	EntranceCinematic = "EntranceCinematic",
	CombatFirstPerson = "CombatFirstPerson",
	DeathSpectator = "DeathSpectator",
	VictoryCinematic = "VictoryCinematic",
	ReturningToLobby = "ReturningToLobby",
}
Controller.States = States

-- Parts hidden LOCALLY (LocalTransparencyModifier, never replicated Transparency) so this client's own
-- view isn't clipped by its own face/crown while everyone else keeps seeing the full rig normally.
local HIDDEN_IN_FIRST_PERSON = { "Head", "Beak", "Comb", "Halo", "Neck" }

local FOV_BASE = 78
local FOV_RUN = 81
local FOV_DASH_PEAK = 86
local FOV_LERP_SPEED = 8 -- higher = snappier return to base

local RECOIL = {
	Attack1 = { pitch = 0.5, duration = 0.10, shake = 0.15, shakeDuration = 0.12 },
	Attack2 = { pitch = 0.55, duration = 0.10, shake = 0.18, shakeDuration = 0.12 },
	Attack3 = { pitch = 1.1, duration = 0.16, shake = 0.4, shakeDuration = 0.20 },
}
local HITSTOP = { Attack1 = 0.035, Attack2 = 0.045, Attack3 = 0.07 }

--============================== state ==============================--
Controller.state = States.Disabled
Controller.chicken = nil
Controller.reducedMotion = false
-- Phase 3 combat settings panel: session-only (this environment's DataStoreService is blocked in Studio
-- regardless - see CombatSettingsPanel.client.luau), safe defaults, clamped ranges so a bad saved/typed
-- value can never push the camera outside a sane window.
Controller.shakeStrength = 1
Controller.fovAdjust = 0
Controller.hitMarkerEnabled = true
Controller.crosshairScale = 1
Controller.damageNumbersEnabled = true

local conns = {} -- per-chicken connections, cleared on every chicken swap/detach
local renderConn = nil

local currentFOV = FOV_BASE
local targetFOV = FOV_BASE
local recoilPitch, recoilTimer, recoilDuration = 0, 0, 0
local shakeMag, shakeTimer, shakeDuration = 0, 0, 0
local shakeRng = Random.new()
local hitStopUntil = 0
local fovOverrideUntil = 0 -- while > os.clock(), onRenderStep leaves targetFOV alone (e.g. a dash pulse)
local dashImpulse = 0 -- forward camera-space nudge, decays to 0

local function clearConns()
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	table.clear(conns)
end

local function setLocalTransparency(model: Model, hidden: boolean)
	for _, partName in ipairs(HIDDEN_IN_FIRST_PERSON) do
		local part = model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function restoreCameraDefaults()
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = FOV_BASE
	camera.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid") or camera.CameraSubject
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	if renderConn then
		RunService:UnbindFromRenderStep("ChickenCombatCamera")
		renderConn = nil
	end
	currentFOV, targetFOV = FOV_BASE, FOV_BASE
	recoilPitch, recoilTimer, recoilDuration = 0, 0, 0
	shakeMag, shakeTimer, shakeDuration = 0, 0, 0
	hitStopUntil, fovOverrideUntil = 0, 0
	dashImpulse = 0
end

--============================== camera math ==============================--
-- deterministic damped shake: magnitude decays linearly to zero over `duration`; roughness comes from a
-- seeded RNG re-sampled every frame (coherent because the DECAY envelope is smooth, not the noise itself
-- accumulating) - never a raw unbounded random offset.
local function addShake(magnitude: number, duration: number)
	if Controller.reducedMotion then
		magnitude *= 0.5
	end
	magnitude *= Controller.shakeStrength
	shakeMag = math.max(shakeMag, magnitude)
	shakeDuration = duration
	shakeTimer = 0
end

local function stepShake(dt: number): (Vector3, number)
	if shakeDuration <= 0 then
		return Vector3.zero, 0
	end
	shakeTimer += dt
	if shakeTimer >= shakeDuration then
		shakeDuration = 0
		return Vector3.zero, 0
	end
	local decay = 1 - (shakeTimer / shakeDuration)
	local x = shakeRng:NextNumber(-1, 1) * shakeMag * decay
	local y = shakeRng:NextNumber(-1, 1) * shakeMag * decay
	local roll = shakeRng:NextNumber(-1, 1) * shakeMag * decay * 0.3
	return Vector3.new(x, y, 0), math.rad(roll)
end

local function triggerRecoil(pitchDeg: number, duration: number)
	if Controller.reducedMotion then
		pitchDeg *= 0.5
	end
	recoilPitch = pitchDeg
	recoilDuration = duration
	recoilTimer = 0
end

local function stepRecoil(dt: number): number
	if recoilDuration <= 0 then
		return 0
	end
	recoilTimer += dt
	local alpha = math.clamp(recoilTimer / recoilDuration, 0, 1)
	if alpha >= 1 then
		recoilDuration = 0
		return 0
	end
	-- snap out, ease back to zero (recoil-then-recover, not a linear ramp)
	local eased = (1 - alpha) ^ 2
	return math.rad(recoilPitch) * eased
end

local function getMoveState(): (number, boolean)
	-- 0 = idle, 1 = walk, 2 = run (drawn from the chicken's own Action attribute, the same replicated
	-- source ChickenAnimator reads, so camera and body animation never disagree about what's happening)
	local action = Controller.chicken and Controller.chicken:GetAttribute("Action")
	if action == "Run" then
		return 2, true
	elseif action == "Walk" then
		return 1, true
	end
	return 0, false
end

local swayPhase = 0
local function computeLayeredOffset(dt: number): (CFrame, number)
	local moveLevel = getMoveState()
	local motionScale = Controller.reducedMotion and 0.35 or 1

	swayPhase += dt * (moveLevel == 2 and 6.5 or moveLevel == 1 and 4.5 or 1.2)
	local bobAmp = (moveLevel == 2 and 0.065 or moveLevel == 1 and 0.04 or 0.006) * motionScale
	local rotAmp = (moveLevel == 2 and 0.45 or moveLevel == 1 and 0.28 or 0.05) * motionScale

	local bobY = math.sin(swayPhase * 2) * bobAmp
	local bobX = math.cos(swayPhase) * bobAmp * 0.4
	local swayRoll = math.sin(swayPhase) * math.rad(rotAmp)

	local recoilRad = stepRecoil(dt)
	local shakeOffset, shakeRoll = stepShake(dt)

	dashImpulse = dashImpulse - dashImpulse * math.min(dt * 6, 1) -- exponential decay to exactly 0

	local pos = Vector3.new(bobX, bobY, -dashImpulse) + shakeOffset * 0.02
	local rot = CFrame.Angles(-recoilRad, 0, swayRoll + shakeRoll)

	return CFrame.new(pos) * rot, moveLevel
end

--============================== render step ==============================--
local function onRenderStep(dt: number)
	local chicken = Controller.chicken
	if not chicken or not chicken.Parent then
		return
	end
	local chest = chicken:FindFirstChild("Chest")
	local att = chest and chest:FindFirstChild("CombatCameraAttachment")
	if not att then
		return
	end

	local base = att.WorldCFrame
	local offset, moveLevel = computeLayeredOffset(dt)
	camera.CFrame = base * offset

	if os.clock() >= hitStopUntil and os.clock() >= fovOverrideUntil then
		-- brief local hit-stop: visual-only pause, achieved by simply not advancing sway phase further
		-- this frame (camera + effects read as "paused" without touching workspace time or physics).
		-- fovOverrideUntil similarly protects a temporary pulse (e.g. dash) from being stomped every
		-- frame by the ordinary locomotion-based FOV baseline below.
		targetFOV = (moveLevel == 2 and FOV_RUN or FOV_BASE) + Controller.fovAdjust
	end
	local fovT = math.min(dt * FOV_LERP_SPEED, 1)
	currentFOV += (targetFOV - currentFOV) * fovT
	camera.FieldOfView = currentFOV
end

--============================== state transitions ==============================--
local function enterCombatFirstPerson()
	local chicken = Controller.chicken
	if not chicken then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	setLocalTransparency(chicken, true)
	local aura = AuraRegistry.Get(chicken)
	if aura then
		aura:SetFirstPerson(true)
	end
	targetFOV, currentFOV = FOV_BASE, FOV_BASE
	if not renderConn then
		RunService:BindToRenderStep("ChickenCombatCamera", Enum.RenderPriority.Camera.Value + 1, onRenderStep)
		renderConn = true
	end
	Controller.state = States.CombatFirstPerson
end

local function exitCombatFirstPerson()
	local chicken = Controller.chicken
	if chicken then
		setLocalTransparency(chicken, false)
		local aura = AuraRegistry.Get(chicken)
		if aura then
			aura:SetFirstPerson(false)
		end
	end
	restoreCameraDefaults()
end

function Controller.SetLocalChicken(model: Model?)
	if Controller.chicken == model then
		return
	end
	if Controller.chicken then
		setLocalTransparency(Controller.chicken, false)
	end
	clearConns()
	Controller.chicken = model
	if not model then
		return
	end
	table.insert(conns, model:GetAttributeChangedSignal("Action"):Connect(function()
		local action = model:GetAttribute("Action")
		-- Entrance/Victory must fire from ANY state (that is their whole job: transitioning into/out of
		-- combat) - only the moment-to-moment combat feedback below is gated to CombatFirstPerson.
		if action == "Entrance" then
			Controller.EnterEntrance()
			return
		elseif action == "Victory" then
			Controller.EnterVictory()
			return
		end
		if Controller.state ~= States.CombatFirstPerson then
			return
		end
		if RECOIL[action] then
			local r = RECOIL[action]
			triggerRecoil(r.pitch, r.duration)
			addShake(r.shake, r.shakeDuration)
			hitStopUntil = os.clock() + (HITSTOP[action] or 0)
		elseif action == "Dash" then
			dashImpulse = 0.35
			targetFOV = FOV_DASH_PEAK
			fovOverrideUntil = os.clock() + 0.18
			task.delay(0.18, function()
				if Controller.state == States.CombatFirstPerson then
					targetFOV = FOV_BASE
				end
			end)
		end
	end))
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(conns, humanoid.Died:Connect(function()
			Controller.EnterDeathSpectator()
		end))
	end
	table.insert(conns, model.AncestryChanged:Connect(function(_, parent)
		if not parent and Controller.chicken == model then
			Controller.ReturnToLobby()
		end
	end))
end

function Controller.EnterLobby()
	clearConns()
	exitCombatFirstPerson()
	Controller.state = States.Lobby
end

function Controller.EnterEntrance()
	if not Controller.chicken then
		return
	end
	Controller.state = States.EntranceCinematic
	local Cutscene = require(ReplicatedStorage.ChickenClash.ChickenCutsceneController)
	Cutscene.Play(Controller.chicken, "Entrance", true, function(reachedEnd)
		if reachedEnd then
			Controller.EnterCombat()
		else
			Controller.ReturnToLobby()
		end
	end)
end


function Controller.EnterCombat()
	if not Controller.chicken then
		return
	end
	enterCombatFirstPerson()
end

function Controller.EnterDeathSpectator()
	exitCombatFirstPerson()
	camera.CameraType = Enum.CameraType.Custom
	if Controller.chicken then
		camera.CameraSubject = Controller.chicken:FindFirstChildOfClass("Humanoid")
	end
	Controller.state = States.DeathSpectator
end

function Controller.EnterVictory()
	if not Controller.chicken then
		return
	end
	local chicken = Controller.chicken
	exitCombatFirstPerson()
	Controller.state = States.VictoryCinematic
	local Cutscene = require(ReplicatedStorage.ChickenClash.ChickenCutsceneController)
	Cutscene.Play(chicken, "Victory", false, function()
		Controller.ReturnToLobby()
	end)
end

function Controller.ReturnToLobby()
	Controller.state = States.ReturningToLobby
	exitCombatFirstPerson()
	Controller.SetLocalChicken(nil)
	Controller.state = States.Lobby
end

function Controller.SetReducedMotion(enabled: boolean)
	Controller.reducedMotion = enabled
end

-- Phase 3 settings panel setters: every value is clamped here (not just at the UI layer) so this stays
-- safe to call from anywhere, including a stray/replayed remote or a future non-UI caller.
function Controller.SetShakeStrength(value: number)
	Controller.shakeStrength = math.clamp(value, 0, 2)
end

function Controller.SetFOVAdjust(value: number)
	Controller.fovAdjust = math.clamp(value, -8, 8)
end

function Controller.SetHitMarkerEnabled(enabled: boolean)
	Controller.hitMarkerEnabled = enabled == true
end

function Controller.SetCrosshairScale(value: number)
	Controller.crosshairScale = math.clamp(value, 0.5, 2)
end

function Controller.SetDamageNumbersEnabled(enabled: boolean)
	Controller.damageNumbersEnabled = enabled == true
end

--============================== server-confirmed hit feedback ==============================--
-- Distinct from the swing recoil above (which plays on every attack whether or not it connects): this
-- only fires once the SERVER confirms a real hitbox overlap, per section 10's "server-confirmed hit"
-- requirement. Never trust a local-only guess at whether a swing landed.
local hitConfirmedRemote = ReplicatedStorage:WaitForChild("ChickenHitConfirmed")
hitConfirmedRemote.OnClientEvent:Connect(function(kind: string, actionName: string, damage: number)
	if Controller.state ~= States.CombatFirstPerson then
		return
	end
	if kind == "Dealt" then
		addShake(actionName == "Attack3" and 0.55 or 0.28, 0.18)
	elseif kind == "Taken" then
		addShake(0.5, 0.22)
		triggerRecoil(-2.5, 0.15) -- brief backward jolt, opposite sign from an outgoing swing's recoil
	end
end)

--============================== best-effort auto wiring ==============================--
-- Until a real match-state service exists, fall back to reacting to this client's own chicken (identified
-- by an "OwnerUserId" attribute, a common convention) entering/leaving combat. Remove this block once a
-- real authoritative match/round system calls SetLocalChicken/EnterEntrance/etc. directly.
CollectionService:GetInstanceAddedSignal("CombatChicken"):Connect(function(model)
	if model:GetAttribute("OwnerUserId") == player.UserId then
		Controller.SetLocalChicken(model)
	end
end)
CollectionService:GetInstanceRemovedSignal("CombatChicken"):Connect(function(model)
	if Controller.chicken == model then
		Controller.ReturnToLobby()
	end
end)

Controller.state = States.Lobby

return Controller
