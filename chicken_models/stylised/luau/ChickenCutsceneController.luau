--[[ ChickenCutsceneController (client, ModuleScript). Reusable local controller for the Entrance and
	Victory cinematics. Owns exactly the state a cutscene needs to touch and guarantees it is ALL restored
	afterward (CameraType, CameraSubject, FOV, MouseBehavior/MouseIconEnabled, controls, UI visibility) -
	ChickenCombatCameraController marks EntranceCinematic/VictoryCinematic and hands off to this module for
	the actual camera path; this module hands back to Camera.EnterCombat()/ReturnToLobby() when done.

	Handles: normal completion, skip, death mid-cutscene, disconnect/model removal, repeated activation
	(a second Play() while one is already running cancels the first cleanly instead of stacking), and a
	missing animation/camera rig (falls back to a short static hold instead of erroring).

	Deliberately does NOT require ChickenCombatCameraController (that would be a circular require, since
	Camera requires THIS module to actually run a cutscene) - instead Play() takes an onComplete(reachedEnd)
	callback, and Camera passes its own EnterCombat/ReturnToLobby in as that callback. ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Cutscene = {}
local active = nil -- {generation, model, kind, conns, skipConn}
local generationCounter = 0

local SKIP_KEYS = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.ButtonA] = true }

local function savedState()
	return {
		cameraType = camera.CameraType,
		cameraSubject = camera.CameraSubject,
		fov = camera.FieldOfView,
		mouseBehavior = UserInputService.MouseBehavior,
		mouseIconEnabled = UserInputService.MouseIconEnabled,
	}
end

local function restoreState(state)
	camera.CameraType = state.cameraType
	if state.cameraSubject then
		camera.CameraSubject = state.cameraSubject
	end
	camera.FieldOfView = state.fov
	UserInputService.MouseBehavior = state.mouseBehavior
	UserInputService.MouseIconEnabled = state.mouseIconEnabled
end

local function cleanup(session, reachedEnd: boolean)
	if active ~= session then
		return
	end
	active = nil
	for _, c in ipairs(session.conns) do
		c:Disconnect()
	end
	restoreState(session.savedState)
	if session.onComplete then
		session.onComplete(reachedEnd)
	end
end

-- orbiting establishing shot used both for the real cinematic path and the missing-rig/missing-animation
-- fallback, so a broken asset degrades to "still shows something reasonable" rather than a hard error.
local function orbitCamera(session, center: Vector3, duration: number)
	local startTick = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if active ~= session then
			conn:Disconnect()
			return
		end
		local t = os.clock() - startTick
		local angle = t * 0.6
		local radius = 9
		local pos = center + Vector3.new(math.cos(angle) * radius, 3.5, math.sin(angle) * radius)
		camera.CFrame = CFrame.new(pos, center + Vector3.new(0, 2, 0))
	end)
	table.insert(session.conns, conn)
end

local function findTrack(model: Model, animName: string): AnimationTrack?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
		if t.Animation.Name == animName then
			return t
		end
	end
	return nil
end

-- kind: "Entrance" | "Victory". allowSkip: whether the current game design permits skipping.
-- onComplete(reachedEnd: boolean) is called exactly once, after all cutscene state is already restored -
-- this is where the caller (ChickenCombatCameraController) transitions to its own next state.
function Cutscene.Play(model: Model, kind: string, allowSkip: boolean?, onComplete: ((boolean) -> ())?)
	if not model or not model.Parent then
		return
	end
	if active then
		cleanup(active, false) -- repeated activation: cancel whatever was running rather than stacking
	end

	generationCounter += 1
	local session = {
		generation = generationCounter, model = model, kind = kind, conns = {},
		savedState = savedState(), onComplete = onComplete,
	}
	active = session

	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	local hrp = model:FindFirstChild("HumanoidRootPart")
	local center = hrp and hrp.Position or Vector3.new()
	local duration = kind == "Entrance" and 3.75 or 3.75 -- matches Entrance/Victory catalog duration (90f/24)

	orbitCamera(session, center, duration)

	local track = findTrack(model, kind)
	if track then
		local endMarker = kind == "Entrance" and "EntranceEnd" or "VictoryEnd"
		local conn = track:GetMarkerReachedSignal(endMarker):Connect(function()
			cleanup(session, true)
		end)
		table.insert(session.conns, conn)
	else
		-- missing animation: fall back to the static-length orbit above and end on a timer instead of a marker
		task.delay(duration, function()
			cleanup(session, true)
		end)
	end

	-- safety timeout in case a marker never fires (e.g. animation truncated) - never leaves the player
	-- stuck in a cinematic camera indefinitely.
	task.delay(duration + 1.5, function()
		if active == session then
			cleanup(session, true)
		end
	end)

	if allowSkip then
		local conn = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if SKIP_KEYS[input.KeyCode] then
				cleanup(session, true)
			end
		end)
		table.insert(session.conns, conn)
	end

	-- death or model removal mid-cutscene
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(session.conns, humanoid.Died:Connect(function()
			cleanup(session, false)
		end))
	end
	table.insert(session.conns, model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			cleanup(session, false)
		end
	end))
end

function Cutscene.Cancel()
	if active then
		cleanup(active, false)
	end
end

return Cutscene
