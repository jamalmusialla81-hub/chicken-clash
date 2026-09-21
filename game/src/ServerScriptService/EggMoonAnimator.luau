--[[
	EggMoonAnimator
	LOCATION: ServerScriptService.EggMoonAnimator  (ModuleScript)
	Plays a Moon Animator 2 recording retargeted to the firing nest:
	    [ LAUNCH baked ] --> [ HORIZONTAL BELT ROLL ] --> [ DROP INTO BOX ] --> [ TAIL baked ]
]]

local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local EggMoonAnimator = {}

local animationCache = {}

--------------------------------------------------
-- PARSE HELPERS
--------------------------------------------------
local TRACK_NAME_CANDIDATES = { "CFrame", "Frame" }

local function findTrackFolder(objectFolder)
	for _, candidate in ipairs(TRACK_NAME_CANDIDATES) do
		local track = objectFolder:FindFirstChild(candidate)
		if track then
			return track
		end
	end
	return nil
end


local function readValueFromValuesFolder(valuesFolder)
	for _, child in ipairs(valuesFolder:GetChildren()) do
		local ok, value = pcall(function()
			return child.Value
		end)
		if ok then
			return value
		end
	end
	return nil
end

local function readCFrameKeyframes(objectFolder)
	local track = findTrackFolder(objectFolder)
	if not track then
		return nil, "no CFrame/Frame track folder found under object folder"
	end

	local keyframes = {}
	for _, child in ipairs(track:GetChildren()) do
		if child:IsA("Folder") then
			local frameNumber = tonumber(child.Name)
			if frameNumber then
				local valuesFolder = child:FindFirstChild("Values")
				if valuesFolder then
					local value = readValueFromValuesFolder(valuesFolder)
					if typeof(value) == "CFrame" then
						table.insert(keyframes, { frame = frameNumber, cframe = value })
					end
				end
			end
		end
	end

	table.sort(keyframes, function(a, b)
		return a.frame < b.frame
	end)

	if #keyframes == 0 then
		return nil, "track folder has no readable CFrame keyframes"
	end

	if keyframes[1].frame > 0 then
		local defaultValue = track:FindFirstChild("Default")
		local ok, cframe = pcall(function()
			return defaultValue and defaultValue.Value
		end)
		if ok and typeof(cframe) == "CFrame" then
			table.insert(keyframes, 1, { frame = 0, cframe = cframe })
		end
	end

	return keyframes
end

local function findEggObjectFolder(animationValue)
	local ok, metadata = pcall(function()
		return HttpService:JSONDecode(animationValue.Value)
	end)
	if ok and typeof(metadata) == "table" and typeof(metadata.Items) == "table" then
		for index, item in ipairs(metadata.Items) do
			local names = item.Path and item.Path.InstanceNames
			if names and names[#names] == "EggForAnim" then
				local folder = animationValue:FindFirstChild(tostring(index))
				if folder then
					return folder
				end
			end
		end
	end
	return animationValue:FindFirstChild("1")
end

local function findChickenObjectFolder(animationValue, eggFolder)
	for _, child in ipairs(animationValue:GetChildren()) do
		if child:IsA("Folder") and child ~= eggFolder and tonumber(child.Name) then
			return child
		end
	end
	return nil
end

--------------------------------------------------
-- LOAD
--------------------------------------------------
local function loadAnimation(animationName, config)
	if animationCache[animationName] then
		return animationCache[animationName]
	end

	local savesFolderName = config.MoonAnimatorSavesFolderName or "MoonAnimator2Saves"
	local savesFolder = ServerStorage:FindFirstChild(savesFolderName)
	if not savesFolder then
		return nil, "ServerStorage." .. savesFolderName .. " not found"
	end

	local animationValue = savesFolder:FindFirstChild(animationName)
	if not animationValue then
		return nil, "no animation named '" .. animationName .. "' found in " .. savesFolder:GetFullName()
	end

	local eggFolder = findEggObjectFolder(animationValue)
	if not eggFolder then
		return nil, "could not find the egg's object folder inside '" .. animationName .. "'"
	end

	local eggKeyframes, err = readCFrameKeyframes(eggFolder)
	if not eggKeyframes then
		return nil, err
	end

	local data = {
		eggKeyframes = eggKeyframes,
		eggLastFrame = eggKeyframes[#eggKeyframes].frame,
		chickenKeyframes = nil,
		chickenLastFrame = 0,
	}

	local chickenFolder = findChickenObjectFolder(animationValue, eggFolder)
	if chickenFolder then
		local chickenKeyframes = readCFrameKeyframes(chickenFolder)
		if chickenKeyframes then
			data.chickenKeyframes = chickenKeyframes
			data.chickenLastFrame = chickenKeyframes[#chickenKeyframes].frame
		end
	end

	animationCache[animationName] = data
	return data
end

--------------------------------------------------
-- SAMPLING + TRANSFORM
--------------------------------------------------
local function sampleCFrame(keyframes, frame)
	if frame <= keyframes[1].frame then
		return keyframes[1].cframe
	end
	local last = keyframes[#keyframes]
	if frame >= last.frame then
		return last.cframe
	end
	for i = 1, #keyframes - 1 do
		local a = keyframes[i]
		local b = keyframes[i + 1]
		if frame >= a.frame and frame <= b.frame then
			local span = b.frame - a.frame
			local alpha = span > 0 and (frame - a.frame) / span or 0
			return a.cframe:Lerp(b.cframe, alpha)
		end
	end
	return last.cframe
end

local function mirrorRotationZ(cf)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, -r20, -r21, -r22)
end

local function sampleTransformed(keyframes, frame, translation, mirror)
	local cf = sampleCFrame(keyframes, frame)
	if mirror then
		cf = mirrorRotationZ(cf)
	end
	return cf + translation
end

local UP = Vector3.new(0, 1, 0)

local function rollAxisFor(direction)
	local axis = direction:Cross(UP)
	if axis.Magnitude < 0.001 then
		return Vector3.new(1, 0, 0)
	end
	return axis.Unit
end

--------------------------------------------------
-- ALPHA TWEEN
--------------------------------------------------
local function runAlphaTween(state, duration, updateFn)
	if state.cancelled then
		return false
	end

	local alphaValue = Instance.new("NumberValue")
	alphaValue.Value = 0

	local conn = alphaValue.Changed:Connect(updateFn)

	local tween = TweenService:Create(
		alphaValue,
		TweenInfo.new(math.max(duration, 0.01), Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
		{ Value = 1 }
	)

	state.currentTween = tween
	tween:Play()
	local playbackState = tween.Completed:Wait()

	conn:Disconnect()
	alphaValue:Destroy()
	state.currentTween = nil

	if state.cancelled or playbackState == Enum.PlaybackState.Cancelled then
		return false
	end

	updateFn(1)
	return true
end

--------------------------------------------------
-- PUBLIC: Play
--------------------------------------------------
function EggMoonAnimator.Play(egg, chickenModel, animationName, context, config, onComplete)
	local data, err = loadAnimation(animationName, config)
	local state = { cancelled = false, currentTween = nil }
	local controller = {}
	local ancestryConns = {}

	local function finish(success)
		for _, conn in ipairs(ancestryConns) do
			conn:Disconnect()
		end
		ancestryConns = {}
		if onComplete then
			onComplete(success)
		end
	end

	function controller:Cancel()
		if state.cancelled then
			return
		end
		state.cancelled = true
		if state.currentTween then
			pcall(function()
				state.currentTween:Cancel()
			end)
		end
	end

	if not data then
		warn("[EggMoonAnimator] Failed to load '" .. animationName .. "': " .. tostring(err))
		task.defer(finish, false)
		return controller
	end

	if not context or not context.targetPosition or not context.boxPosition then
		warn("[EggMoonAnimator] Missing targetPosition/boxPosition in context")
		task.defer(finish, false)
		return controller
	end

	table.insert(
		ancestryConns,
		egg.AncestryChanged:Connect(function(_, parent)
			if not parent then
				controller:Cancel()
			end
		end)
	)

	--------------------------------------------------
	-- Chicken setup
	--------------------------------------------------
	local animateChicken = chickenModel ~= nil and data.chickenKeyframes ~= nil
	local chickenOriginalCFrame = nil
	if animateChicken then
		local ok, pivot = pcall(function()
			return chickenModel:GetPivot()
		end)
		if ok then
			chickenOriginalCFrame = pivot
			table.insert(
				ancestryConns,
				chickenModel.AncestryChanged:Connect(function(_, parent)
					if not parent then
						animateChicken = false
					end
				end)
			)
		else
			animateChicken = false
		end
	end

	--------------------------------------------------
	-- Mirror
	--------------------------------------------------
	local mirror = false
	if config.MoonMirrorOppositeRow and context.targetSlotNumber then
		local slotsPerRow = config.MoonSlotsPerRow or 4
		local referenceSlot = config.MoonReferenceSlot or 4
		local targetHalf = math.ceil(context.targetSlotNumber / slotsPerRow)
		local referenceHalf = math.ceil(referenceSlot / slotsPerRow)
		mirror = targetHalf ~= referenceHalf
	end

	--------------------------------------------------
	-- Frame boundaries
	--------------------------------------------------
	local firstFrame = data.eggKeyframes[1].frame
	local landingFrame = math.clamp(config.MoonLaunchLandingFrame or 91, firstFrame, data.eggLastFrame)
	local tailStartFrame = math.clamp(
		config.MoonTailStartFrame or data.eggLastFrame,
		landingFrame,
		data.eggLastFrame
	)
	local frameRate = config.MoonAnimationFrameRate or 60

	--------------------------------------------------
	-- Translations
	--------------------------------------------------
	local recordedNestPos = data.eggKeyframes[1].cframe.Position
	local launchTranslation = context.targetPosition - recordedNestPos
	local chickenTranslation = launchTranslation

	local rawTailStartPos = sampleCFrame(data.eggKeyframes, tailStartFrame).Position
	local tailTranslation = context.boxPosition - rawTailStartPos

	--------------------------------------------------
	-- Durations / speed from recording
	--------------------------------------------------
	local launchDuration = (landingFrame - firstFrame) / frameRate
	local rawLandingPos = sampleCFrame(data.eggKeyframes, landingFrame).Position
	local rawRollDistance = (rawTailStartPos - rawLandingPos).Magnitude
	local rawRollFrames = math.max(tailStartFrame - landingFrame, 1)
	local rawRollDuration = math.max(rawRollFrames / frameRate, 0.01)
	local rollSpeed = rawRollDistance > 0.001 and (rawRollDistance / rawRollDuration) or 0

	local landingPos = rawLandingPos + launchTranslation
	local boxPos = context.boxPosition
	local tailDuration = (data.eggLastFrame - tailStartFrame) / frameRate
	local eggRadius = math.max(context.eggRadius or 0.5, 0.1)

	--------------------------------------------------
	-- STAGE 1: LAUNCH (baked)
	--------------------------------------------------
	local function playLaunchStage()
		return runAlphaTween(state, launchDuration, function(alpha)
			local frame = firstFrame + (landingFrame - firstFrame) * alpha
			egg:PivotTo(sampleTransformed(data.eggKeyframes, frame, launchTranslation, mirror))
			if animateChicken then
				pcall(function()
					chickenModel:PivotTo(sampleTransformed(data.chickenKeyframes, frame, chickenTranslation, mirror))
				end)
			end
		end)
	end

	--------------------------------------------------
	-- STAGE 2: HORIZONTAL BELT ROLL + DROP INTO BOX
	--------------------------------------------------
	local function playBridgeStage()
		local dropDistance = math.max(config.MoonBridgeDropDistance or 2.5, 0.1)
		local dropTime = math.max(config.MoonBridgeDropTime or 0.35, 0.05)
		local beltYOffset = config.MoonBeltYOffset or 0.5

		local beltY = landingPos.Y + beltYOffset
		local rollStart = Vector3.new(landingPos.X, beltY, landingPos.Z)
		local aboveBox = Vector3.new(boxPos.X, beltY, boxPos.Z)

		local toBox = aboveBox - rollStart
		local totalHoriz = Vector3.new(toBox.X, 0, toBox.Z).Magnitude

		local dropStart
		if totalHoriz <= dropDistance then
			dropStart = rollStart
		else
			local flatDir = Vector3.new(toBox.X, 0, toBox.Z).Unit
			dropStart = aboveBox - flatDir * dropDistance
			dropStart = Vector3.new(dropStart.X, beltY, dropStart.Z)
		end

		-- Snap onto belt height
		egg:PivotTo(CFrame.new(rollStart) * egg:GetPivot().Rotation)

		-- Phase A: horizontal only (Y locked)
		local rollVec = dropStart - rollStart
		local rollDist = rollVec.Magnitude

		if rollDist > 0.001 then
			local direction = Vector3.new(rollVec.X, 0, rollVec.Z)
			if direction.Magnitude < 0.001 then
				direction = Vector3.new(0, 0, 1)
			else
				direction = direction.Unit
			end

			local rollDuration = rollSpeed > 0.001 and (rollDist / rollSpeed) or 0.01
			rollDuration = math.max(rollDuration, 0.05)

			local ok = runAlphaTween(state, rollDuration, function(alpha)
				local travelled = rollDist * alpha
				local pos = Vector3.new(
					rollStart.X + direction.X * travelled,
					beltY,
					rollStart.Z + direction.Z * travelled
				)
				local spin = CFrame.Angles(0, 0, travelled / eggRadius)
				egg:PivotTo(CFrame.new(pos) * spin)
			end)
			if not ok then
				return false
			end
		end

		-- Phase B: drop into box
		local dropFrom = Vector3.new(dropStart.X, beltY, dropStart.Z)
		local dropTo = boxPos
		local dropLen = (dropTo - dropFrom).Magnitude

		if dropLen < 0.001 then
			egg:PivotTo(CFrame.new(boxPos))
			return true
		end

		return runAlphaTween(state, dropTime, function(alpha)
			local t = alpha * alpha
			local pos = dropFrom:Lerp(dropTo, t)
			local spin = CFrame.Angles(0, 0, (dropLen * t) / eggRadius)
			egg:PivotTo(CFrame.new(pos) * spin)
		end)
	end
	


	--------------------------------------------------
	-- STAGE 3: TAIL / SETTLE (baked at box)
	--------------------------------------------------
	local function playTailStage()
		return runAlphaTween(state, tailDuration, function(alpha)
			local frame = tailStartFrame + (data.eggLastFrame - tailStartFrame) * alpha
			egg:PivotTo(sampleTransformed(data.eggKeyframes, frame, tailTranslation, mirror))
		end)
	end

	--------------------------------------------------
	-- Chicken restore
	--------------------------------------------------
	local function restoreChicken()
		if not (animateChicken and chickenOriginalCFrame) then
			return
		end
		pcall(function()
			local restoreValue = Instance.new("NumberValue")
			restoreValue.Value = 0
			local restoreConn = restoreValue.Changed:Connect(function(a)
				local current = chickenModel:GetPivot()
				chickenModel:PivotTo(current:Lerp(chickenOriginalCFrame, a))
			end)
			local restoreTween = TweenService:Create(
				restoreValue,
				TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Value = 1 }
			)
			restoreTween:Play()
			restoreTween.Completed:Wait()
			restoreConn:Disconnect()
			restoreValue:Destroy()
			chickenModel:PivotTo(chickenOriginalCFrame)
		end)
	end

	--------------------------------------------------
	-- Start pose + run
	--------------------------------------------------
	egg:PivotTo(sampleTransformed(data.eggKeyframes, firstFrame, launchTranslation, mirror))
	if animateChicken then
		pcall(function()
			chickenModel:PivotTo(sampleTransformed(data.chickenKeyframes, firstFrame, chickenTranslation, mirror))
		end)
	end

	task.spawn(function()
		local function runSequence()
			if not playLaunchStage() then
				return false
			end
			task.spawn(restoreChicken)
			if not playBridgeStage() then
				return false
			end
			if not playTailStage() then
				return false
			end
			return not state.cancelled
		end
		finish(runSequence())
	end)

	return controller
end

return EggMoonAnimator