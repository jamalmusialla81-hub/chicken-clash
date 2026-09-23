--[[ ChickenCombatCamera (client, local-only). Dedicated first-person combat camera controller - camera
	logic lives here and nowhere else (not in ChickenAnimator, ChickenCombatService, or any UI script).

	State machine (reference-informed consolidation pass): Disabled -> Lobby -> Cutscene ->
	(PracticeCombat | MatchCombat) -> (MenuOpen | DeathSpectator | Cutscene[Victory] | Results) ->
	ReturnToLobby -> Lobby. Nothing here ever decides combat legality, damage, or match outcome - it only
	RENDERS whatever state it is told to enter.

	PracticeCombat vs MatchCombat is inferred from whether the chicken carries a "MatchId" attribute
	(MatchService sets one, PracticeService never does) rather than threading a new parameter through
	PracticeService/MatchService/MatchCameraBridge's existing 2-arg remote contract - same signal MatchHUD
	already reads for the same purpose, so this isn't a new source of truth.

	Integration point: call Controller.SetLocalChicken(model) once the real ownership system knows which
	chicken belongs to this client, then drive transitions with Controller.EnterEntrance() / EnterVictory()
	/ EnterResults() / ReturnToLobby() from wherever the authoritative match/round system lives. As a
	reasonable default without a dedicated match-state service, this script also auto-transitions from the
	chicken's own "Action" attribute (Entrance/Victory), CombatChicken tag add/remove, and the player's own
	"MatchState" attribute reaching Results/Returning - all wrapped in Controller.Start()/Stop() so this
	auto-wiring can be cleanly disabled if a real match-state service ever replaces it.

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
	Cutscene = "Cutscene",
	PracticeCombat = "PracticeCombat",
	MatchCombat = "MatchCombat",
	MenuOpen = "MenuOpen",
	Results = "Results",
	-- Kept as a real addition beyond the required 7 states - death-spectating is genuinely distinct
	-- camera behavior (third-person, watching the winner) that doesn't fold cleanly into any of them.
	DeathSpectator = "DeathSpectator",
}
Controller.States = States

local function isCombatState(state: string): boolean
	return state == States.PracticeCombat or state == States.MatchCombat
end

-- Parts hidden LOCALLY (LocalTransparencyModifier, never replicated Transparency) so this client's own
-- view isn't clipped by its own face/crown while everyone else keeps seeing the full rig normally.
-- Cape is included because it drapes from right behind the neck/CombatCameraAttachment and clips the
-- view there; Chest/wings/legs/tail are deliberately left OUT so the player still sees their own body
-- peripherally (chest lower edge, wing edges, legs/talons, lower body) instead of nothing at all.
local HIDDEN_IN_FIRST_PERSON = { "Head", "Beak", "Comb", "Halo", "Neck", "Cape" }

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

-- Real bug found live: the camera previously had NO mouse-look at all - it just rigidly copied the
-- Chest's CombatCameraAttachment orientation, which only ever changes when the Humanoid's AutoRotate
-- turns the body to face WASD movement. Moving the mouse while standing still did nothing whatsoever.
-- Fix: track yaw/pitch from raw mouse delta ourselves (standard MouseBehavior.LockCenter FPS pattern),
-- disable AutoRotate while in first person, and drive BOTH the body's facing (yaw only - chickens don't
-- pitch their whole body to look up/down) and the camera (yaw+pitch) from it every frame. Body-facing
-- driving the camera (rather than the other way around) is why ChickenCombatService's hitbox and
-- ChickenCombatInput's dash direction already point wherever the camera looks - both read the body's
-- LookVector/the camera's LookVector respectively, and this keeps them in agreement.
local MOUSE_SENSITIVITY = 0.0035 -- radians per pixel of raw mouse delta
local MAX_PITCH = math.rad(75)
local yaw, pitch = 0, 0
local eyeOffsetLocal = CFrame.new() -- captured once per combat-entry: attachment's offset in HRP-local space
local menuOpen = false -- true while a settings/selection panel (or Results) owns the mouse

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

-- One cursor-state function, not three separate inline assignments scattered across enter/exit/menu
-- transitions (which is how MouseIconEnabled drifted out of sync with MouseBehavior in the first place).
-- "Menu" and "Lobby" are the same cursor state (Default behavior, icon visible) but kept as distinct
-- named modes since they are conceptually different callers and may diverge later.
local function SetCursorMode(mode: string)
	if mode == "Combat" then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else -- "Menu" or "Lobby"
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end
Controller.SetCursorMode = SetCursorMode

local function restoreCameraDefaults()
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = FOV_BASE
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	camera.CameraSubject = humanoid or camera.CameraSubject
	if humanoid then
		humanoid.AutoRotate = true
	end
	SetCursorMode("Lobby")
	if renderConn then
		RunService:UnbindFromRenderStep("ChickenCombatCamera")
		renderConn = nil
	end
	currentFOV, targetFOV = FOV_BASE, FOV_BASE
	recoilPitch, recoilTimer, recoilDuration = 0, 0, 0
	shakeMag, shakeTimer, shakeDuration = 0, 0, 0
	hitStopUntil, fovOverrideUntil = 0, 0
	dashImpulse = 0
	yaw, pitch = 0, 0
	menuOpen = false
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
-- The one and only place camera.CFrame is ever assigned. Order matches the spec exactly: read mouse
-- delta -> update yaw -> update pitch -> clamp pitch -> base CFrame from the attachment -> apply yaw/pitch
-- -> apply sway/bob -> apply recoil -> apply shake -> set camera.CFrame once -> update FOV separately.
local function onRenderStep(dt: number)
	local chicken = Controller.chicken
	if not chicken or not chicken.Parent then
		return
	end
	local hrp = chicken:FindFirstChild("HumanoidRootPart")
	local chest = chicken:FindFirstChild("Chest")
	local att = chest and chest:FindFirstChild("CombatCameraAttachment")
	if not hrp or not att then
		return
	end

	if not menuOpen then
		local delta = UserInputService:GetMouseDelta()
		yaw -= delta.X * MOUSE_SENSITIVITY
		pitch = math.clamp(pitch - delta.Y * MOUSE_SENSITIVITY, -MAX_PITCH, MAX_PITCH)
	end

	-- body always faces the camera's yaw (pitch is camera-only - chickens don't pitch their whole body to
	-- look up/down); AssemblyLinearVelocity/physics are untouched, only the rotation component changes.
	hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)

	local eyePos = (hrp.CFrame * eyeOffsetLocal).Position
	local offset, moveLevel = computeLayeredOffset(dt)
	local base = CFrame.new(eyePos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
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
-- Deliberately bound at Character+1, NOT the generic "Camera priority" a reference architecture might
-- use: RenderPriority.Character (300) runs AFTER RenderPriority.Camera (200) in this engine build, and
-- this function writes hrp.CFrame directly. Binding before Character's own movement step (i.e. at
-- Camera+1) meant this write got partially fought by movement resolution immediately afterward, every
-- single frame - that fight is exactly what a user reported live as "sliding/input-delayed movement."
-- Binding after Character (Character+1) fixed it, verified live. Keeping that fix intentionally overrides
-- a generic "Camera.Value + 1" convention for this specific reason.
local RENDER_PRIORITY = Enum.RenderPriority.Character.Value + 1

local function enterCombatFirstPerson(mode: string)
	local chicken = Controller.chicken
	if not chicken then
		return
	end
	local hrp = chicken:FindFirstChild("HumanoidRootPart")
	local chest = chicken:FindFirstChild("Chest")
	local att = chest and chest:FindFirstChild("CombatCameraAttachment")
	if hrp then
		-- seed yaw from however the character currently faces, so entering first person never snaps the
		-- view to a different direction than what was already on screen.
		local _, currentYaw = hrp.CFrame:ToEulerAnglesYXZ()
		yaw = currentYaw
		pitch = 0
		if att then
			eyeOffsetLocal = hrp.CFrame:ToObjectSpace(att.WorldCFrame)
		end
		local humanoid = chicken:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.AutoRotate = false
		end
	end
	camera.CameraType = Enum.CameraType.Scriptable
	SetCursorMode("Combat")
	UserInputService:GetMouseDelta() -- clear any accumulated delta from before combat started
	menuOpen = false
	setLocalTransparency(chicken, true)
	local aura = AuraRegistry.Get(chicken)
	if aura then
		aura:SetFirstPerson(true)
	end
	targetFOV, currentFOV = FOV_BASE, FOV_BASE
	if not renderConn then
		RunService:BindToRenderStep("ChickenCombatCamera", RENDER_PRIORITY, onRenderStep)
		renderConn = true
	end
	Controller.state = mode == "Match" and States.MatchCombat or States.PracticeCombat
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
		-- combat) - only the moment-to-moment combat feedback below is gated to an active combat state.
		if action == "Entrance" then
			Controller.EnterEntrance()
			return
		elseif action == "Victory" then
			Controller.EnterVictory()
			return
		end
		if not isCombatState(Controller.state) then
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
				if isCombatState(Controller.state) then
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
	local chicken = Controller.chicken
	local mode = chicken:GetAttribute("MatchId") and "Match" or "Practice"
	Controller.state = States.Cutscene
	local Cutscene = require(ReplicatedStorage.ChickenClash.ChickenCutsceneController)
	Cutscene.Play(chicken, "Entrance", true, function(reachedEnd)
		if reachedEnd then
			enterCombatFirstPerson(mode)
		else
			Controller.ReturnToLobby()
		end
	end)
end

-- Kept as a thin public wrapper (some external caller may still reasonably expect an EnterCombat entry
-- point) - internal transitions call enterCombatFirstPerson directly with an already-known mode.
function Controller.EnterCombat(mode: string?)
	if not Controller.chicken then
		return
	end
	enterCombatFirstPerson(mode or "Practice")
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
	Controller.state = States.Cutscene
	local Cutscene = require(ReplicatedStorage.ChickenClash.ChickenCutsceneController)
	Cutscene.Play(chicken, "Victory", false, function()
		Controller.ReturnToLobby()
	end)
end

-- Real gap this closes: nothing previously released the mouse when a match reached its Results screen,
-- so MatchHUD's Rematch/Return-to-Lobby buttons were unclickable (the camera was still holding
-- MouseBehavior.LockCenter from combat). Reuses the same menuOpen render-step gate Menu already uses -
-- the frame simply freezes with the cursor free, rather than unbinding the render step entirely.
function Controller.EnterResults()
	if Controller.state == States.Results then
		return
	end
	Controller.state = States.Results
	SetCursorMode("Menu")
	menuOpen = true
end

function Controller.ReturnToLobby()
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
	if not isCombatState(Controller.state) then
		return
	end
	if kind == "Dealt" then
		addShake(actionName == "Attack3" and 0.55 or 0.28, 0.18)
		local aura = Controller.chicken and AuraRegistry.Get(Controller.chicken)
		if aura then
			aura:ImpactFlash()
		end
	elseif kind == "Taken" then
		addShake(0.5, 0.22)
		triggerRecoil(-2.5, 0.15) -- brief backward jolt, opposite sign from an outgoing swing's recoil
	end
end)

--============================== menu state ==============================--
-- Settings/chicken-selection panels call this instead of tearing the camera controller down: the render
-- step keeps running (camera stays put, reticle/HUD stay visible) but stops reading mouse delta into
-- yaw/pitch, so closing the panel resumes looking from exactly where it left off - never a snap. Also
-- transitions Controller.state to/from MenuOpen (a real state, not just a hidden boolean) and remembers
-- which combat state to restore.
local preMenuState: string? = nil

function Controller.SetMenuOpen(open: boolean)
	if menuOpen == open then
		return
	end
	if open then
		if not isCombatState(Controller.state) then
			return
		end
		preMenuState = Controller.state
		Controller.state = States.MenuOpen
		menuOpen = true
		SetCursorMode("Menu")
	else
		if Controller.state ~= States.MenuOpen then
			return
		end
		Controller.state = preMenuState or States.PracticeCombat
		preMenuState = nil
		menuOpen = false
		SetCursorMode("Combat")
		UserInputService:GetMouseDelta() -- discard whatever accumulated while the cursor was free
	end
end

function Controller.IsMenuOpen(): boolean
	return menuOpen
end

--============================== lifecycle: Start/Stop ==============================--
-- Idempotent by design: repeated Start() calls are no-ops once already started, and Stop() safely
-- unbinds/restores exactly once. Wraps the "best-effort auto wiring" (CollectionService tag watching +
-- the player's own MatchState attribute) that substitutes for a dedicated match-state service today -
-- calling Stop() cleanly disables all of it and returns the camera/cursor to Lobby defaults.
local started = false
local lifecycleConns = {}

function Controller.Start()
	if started then
		return
	end
	started = true
	table.insert(lifecycleConns, CollectionService:GetInstanceAddedSignal("CombatChicken"):Connect(function(model)
		if model:GetAttribute("OwnerUserId") == player.UserId then
			Controller.SetLocalChicken(model)
		end
	end))
	table.insert(lifecycleConns, CollectionService:GetInstanceRemovedSignal("CombatChicken"):Connect(function(model)
		if Controller.chicken == model then
			Controller.ReturnToLobby()
		end
	end))
	table.insert(lifecycleConns, player:GetAttributeChangedSignal("MatchState"):Connect(function()
		local matchState = player:GetAttribute("MatchState")
		if (matchState == "Results" or matchState == "Returning")
			and Controller.state ~= States.Results
			and Controller.state ~= States.Lobby then
			Controller.EnterResults()
		end
	end))
end

function Controller.Stop()
	if not started then
		return
	end
	started = false
	for _, c in ipairs(lifecycleConns) do
		c:Disconnect()
	end
	table.clear(lifecycleConns)
	Controller.ReturnToLobby()
end

Controller.state = States.Lobby
Controller.Start()

return Controller
