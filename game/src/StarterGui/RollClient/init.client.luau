--==================================================
-- ROLL CLIENT
-- Original animation system from "Roll System [Slime RNG]",
-- rewired to roll CHICKENS using your existing
-- ChickenRollService / ChickenRollConfig / Luck system.
--
-- WHAT CHANGED FROM THE ORIGINAL SLIME VERSION:
-- 1. Remote: Remotes.GetRoll  ->  ChickenRollRemotes.RequestRoll
-- 2. Data source for reel filler: Configuration.Slimes -> ChickenRollConfig.Chickens
-- 3. Response shape adapter: your server returns a single
--    winning chicken (name/chance/RollDuration), not a
--    pre-built multi-entry Sequence like the old Slime server
--    did — so this script now builds that single-item Sequence
--    itself, client-side, right after the roll comes back.
-- 4. rollEntry.Type "Slime" -> "Chicken" (also affects which
--    Sound gets played, and which final-scale animation fires)
-- 5. Configuration/BaseRoll and Configuration/LuckMultipliers
--    are UNCHANGED — still tunable animation timing/scale
--    constants, not gameplay data, so nothing needed to change
--    there.
-- 6. Modules (SoundPlayer, HoverScale, TabService) are expected
--    to already exist at ReplicatedStorage.Modules — using your
--    EXISTING copies, not new ones from the package.
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local BaseRoll = require(Configuration:WaitForChild("BaseRoll"))
-- LuckMultipliers removed: it only drove a cosmetic "lucky item"
-- flourish in the reel, unrelated to your real Luck system
-- (LuckShopServer / ChickenRollService). Not needed.
local SoundPlayer = require(Modules:WaitForChild("SoundPlayer"))
local TabService = require(Modules:WaitForChild("TabService"))

--==================================================
-- CHICKEN DATA (replaces the old "Slimes" config require)
--==================================================

local ChickenRollConfig = require(ReplicatedStorage:WaitForChild("ChickenRollConfig"))

local function findChickenConfig(chickenName)

	for _, chicken in ChickenRollConfig.Chickens do

		if chicken.name == chickenName then
			return chicken
		end
	end

	return nil
end

-- Converts one ChickenRollConfig entry into the visual-entry
-- shape this animation script expects everywhere else
-- (DisplayName / OddsText / Icon / Type).

local function chickenToVisualEntry(chicken)

	return {
		Type = "Chicken",
		DisplayName = chicken.name,
		OddsText = chicken.chance,
		Icon = chicken.icon or "",
	}
end

-- Converts the actual server roll RESULT (name/chance/RollDuration)
-- into that same visual-entry shape, pulling the Icon from config
-- since the server response itself doesn't carry an icon.

local function rollResultToVisualEntry(result)

	local configEntry = findChickenConfig(result.name)

	return {
		Type = "Chicken",
		DisplayName = result.name,
		OddsText = result.chance,
		Icon = configEntry and configEntry.icon or "",
	}
end

--==================================================
-- REMOTES (replaces Remotes.GetRoll)
--==================================================

local chickenRemotes = ReplicatedStorage:WaitForChild("ChickenRollRemotes")
local requestRollRemote = chickenRemotes:WaitForChild("RequestRoll")

--==================================================
-- UI
--==================================================

local template = script:WaitForChild("Template")
local middleTemplate = script:WaitForChild("Middle")
local rollGui = playerGui:WaitForChild("RollGui")
local rollButton = rollGui:WaitForChild("RollButton")
local rollRoot = rollGui:WaitForChild("Frame")
local rollFrame = rollRoot:WaitForChild("Roll")
local hideButton = rollRoot:WaitForChild("Hide")
local hiddenRoot = rollGui:WaitForChild("HiddenFrame")
local autoRollRoot = rollRoot:WaitForChild("AutoRoll")
local autoRollButton = autoRollRoot
local autoRollStateLabel = autoRollRoot:WaitForChild("StateLabel")

local hover = require(Modules:WaitForChild("HoverScale"))
hover.Start()

local isRolling = false
local autoRollEnabled = false
local hiddenMode = false
local activeRoot = rollRoot
local activeRollFrame = rollFrame
local columns = {}
local columnReels = {}
local middleMarkers = nil
local random = Random.new()
local hideRequestId = 0
local tabService = TabService.new({
	Down = {
		rollButton,
		hideButton,
		autoRollButton,
	},
	Up = {
		hiddenRoot,
	},
})

local function setAutoRollState(enabled)
	autoRollEnabled = enabled
	autoRollStateLabel.RichText = true
	if enabled then
		autoRollStateLabel.Text = '<font color="#FFFFFF">AUTO - </font><font color="#00FF00">ON</font>'
	else
		autoRollStateLabel.Text = '<font color="#FFFFFF">AUTO - </font><font color="#FF0000">OFF</font>'
	end
end

setAutoRollState(false)

local function showDiceState()
	rollRoot.Visible = false
	hiddenRoot.Visible = false
	tabService:Apply({ rollButton }, { hideButton, autoRollButton, hiddenRoot })
end

local function showRollState()
	rollRoot.Visible = true
	hiddenRoot.Visible = false
	tabService:Apply({ hideButton, autoRollButton }, { rollButton, hiddenRoot })
end

local function showHiddenState()
	rollRoot.Visible = false
	hiddenRoot.Visible = true
	tabService:Apply({ rollButton, hiddenRoot }, { hideButton, autoRollButton })
end

local function moveRollChildren(fromParent, toParent)
	for _, child in fromParent:GetChildren() do
		child.Parent = toParent
	end
end

local function setHiddenMode(enabled)
	hiddenMode = enabled
	activeRoot = hiddenMode and hiddenRoot or rollRoot
	activeRollFrame = hiddenMode and hiddenRoot or rollFrame

	if hiddenMode then
		moveRollChildren(rollFrame, hiddenRoot)
	else
		moveRollChildren(hiddenRoot, rollFrame)
	end
end

showDiceState()

local function makeTween(instance, tweenInfo, properties)
	local tween = TweenService:Create(instance, tweenInfo, properties)
	tween:Play()
	return tween
end

local function getColumnXPositions(columnCount)
	local positions = {}
	local stepSize = BaseRoll.ColumnWidthScale + BaseRoll.ColumnGapScale
	local centerOffset = (columnCount + 1) / 2

	for index = 1, columnCount do
		positions[index] = 0.5 + ((index - centerOffset) * stepSize)
	end

	return positions
end

local function updateColumnLayout(columnCount)
	local positions = getColumnXPositions(columnCount)
	local tweenInfo = TweenInfo.new(BaseRoll.ColumnTweenTime, BaseRoll.ColumnTweenStyle, BaseRoll.ColumnTweenDirection)

	for index, column in columns do
		column.Size = UDim2.fromScale(BaseRoll.ColumnWidthScale, BaseRoll.ColumnHeightScale)
		makeTween(column, tweenInfo, {
			Position = UDim2.fromScale(positions[index], 0.5),
		})
	end

	return positions
end

local function setMarkerTransparency(marker, transparency)
	if marker:IsA("ImageLabel") or marker:IsA("ImageButton") then
		marker.ImageTransparency = transparency
	elseif marker:IsA("Frame") or marker:IsA("TextLabel") or marker:IsA("TextButton") then
		marker.BackgroundTransparency = transparency
	end
end

local function makeMarkerTween(marker, tweenInfo, properties)
	local transparency = properties.Transparency

	properties.Transparency = nil

	local tween = makeTween(marker, tweenInfo, properties)

	if transparency ~= nil then
		if marker:IsA("ImageLabel") or marker:IsA("ImageButton") then
			makeTween(marker, tweenInfo, {
				ImageTransparency = transparency,
			})
		elseif marker:IsA("Frame") or marker:IsA("TextLabel") or marker:IsA("TextButton") then
			makeTween(marker, tweenInfo, {
				BackgroundTransparency = transparency,
			})
		end
	end

	return tween
end

local function createMiddleMarkers()
	if middleMarkers ~= nil then
		return middleMarkers
	end

	local markerFolder = Instance.new("Folder")
	markerFolder.Name = "MiddleMarkers"
	markerFolder.Parent = activeRollFrame

	local leftMarker = middleTemplate:Clone()
	leftMarker.Name = "Left"
	leftMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	leftMarker.Visible = false
	leftMarker.ZIndex = 100
	setMarkerTransparency(leftMarker, 0)
	leftMarker.Parent = markerFolder

	local rightMarker = middleTemplate:Clone()
	rightMarker.Name = "Right"
	rightMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	rightMarker.Rotation = middleTemplate.Rotation + 180
	rightMarker.Visible = false
	rightMarker.ZIndex = 100
	setMarkerTransparency(rightMarker, 0)
	rightMarker.Parent = markerFolder

	middleMarkers = {
		Folder = markerFolder,
		Left = leftMarker,
		Right = rightMarker,
	}

	return middleMarkers
end

local function updateMiddleMarkers()
	local markers = createMiddleMarkers()

	if columns[1] == nil then
		return
	end

	local halfColumnWidth = BaseRoll.ColumnWidthScale / 2
	local offset = halfColumnWidth + BaseRoll.MiddlePaddingScale
	local tweenInfo = TweenInfo.new(BaseRoll.ColumnTweenTime, BaseRoll.ColumnTweenStyle, BaseRoll.ColumnTweenDirection)
	local positions = getColumnXPositions(#columns)
	local leftColumnX = positions[1]
	local rightColumnX = positions[#columns]
	local leftPosition = UDim2.fromScale(leftColumnX - offset, 0.5)
	local rightPosition = UDim2.fromScale(rightColumnX + offset, 0.5)

	markers.Left.Visible = true
	markers.Right.Visible = true
	setMarkerTransparency(markers.Left, 0)
	setMarkerTransparency(markers.Right, 0)

	makeMarkerTween(markers.Left, tweenInfo, {
		Position = leftPosition,
	})

	makeMarkerTween(markers.Right, tweenInfo, {
		Position = rightPosition,
	})
end

local function createColumn(index)
	local column = Instance.new("Frame")
	column.Name = `RollColumn{index}`
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.BackgroundTransparency = 1
	column.ClipsDescendants = false
	column.Position = UDim2.fromScale(0.5, 0.5)
	column.Parent = activeRollFrame

	columns[index] = column
	updateColumnLayout(index)

	return column
end

local function setText(instance, text)
	if instance ~= nil and (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
		instance.Text = text
		instance.Visible = text ~= ""
		instance.TextTransparency = 0
	end
end

local function setItemImage(item, image)
	if item:IsA("ImageLabel") or item:IsA("ImageButton") then
		item.Image = image
	end
end

local function setItemImageTransparency(item, transparency)
	if item:IsA("ImageLabel") or item:IsA("ImageButton") then
		item.ImageTransparency = transparency
	end

	for _, descendant in item:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			descendant.TextTransparency = transparency
		end
	end
end

local function makeRollItemTween(item, tweenInfo, properties)
	local imageTransparency = properties.ImageTransparency
	local tween = makeTween(item, tweenInfo, properties)

	if imageTransparency ~= nil then
		for _, descendant in item:GetDescendants() do
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
				makeTween(descendant, tweenInfo, {
					TextTransparency = imageTransparency,
				})
			elseif descendant:IsA("UIStroke") then
				makeTween(descendant, tweenInfo, {
					Transparency = imageTransparency,
				})
			end
		end
	end

	return tween
end

local function getChanceText(rollEntry)
	if rollEntry.OddsText ~= nil then
		return rollEntry.OddsText
	end

	if rollEntry.Multiplier ~= nil then
		return `x{rollEntry.Multiplier}`
	end

	return ""
end

local function updateRollItem(item, rollEntry)
	item.Name = rollEntry.DisplayName
	setItemImage(item, rollEntry.Icon or "")
	setText(item:FindFirstChild("Chance"), getChanceText(rollEntry))
	setText(item:FindFirstChild("Name"), rollEntry.DisplayName)
end

local function cloneVisualEntry(entry, rollType)
	return {
		Type = rollType,
		DisplayName = entry.DisplayName,
		OddsText = entry.OddsText,
		Multiplier = entry.Multiplier,
		Icon = entry.Icon,
	}
end

-- Filler pool for the spinning reel now comes from your 50
-- chickens instead of Slimes. This is what flashes past during
-- the spin before landing on the real result.

local function getRandomVisualEntry(fallbackEntry, allowedLuckEntry)
	local visualPool = {}

	for _, chicken in ChickenRollConfig.Chickens do
		table.insert(visualPool, cloneVisualEntry(chickenToVisualEntry(chicken), "Chicken"))
	end

	if allowedLuckEntry ~= nil then
		table.insert(visualPool, cloneVisualEntry(allowedLuckEntry, "Luck"))
	end

	if #visualPool == 0 then
		return fallbackEntry
	end

	return visualPool[random:NextInteger(1, #visualPool)]
end

local function createRollItem(column, rollEntry)
	local item = template:Clone()
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	setItemImageTransparency(item, 1)
	item.Position = UDim2.fromScale(0.5, 0)
	item.Size = BaseRoll.EdgeItemSize
	item.Visible = true
	item.Parent = column

	updateRollItem(item, rollEntry)

	return item
end

local function getSlotY(slotIndex)
	local visibleItems = math.max(BaseRoll.VisibleRollingItems, 2)

	return (slotIndex - 1) / (visibleItems - 1)
end

local function getMiddleSlot()
	return math.ceil(BaseRoll.VisibleRollingItems / 2)
end

local function getSlotTransparency(slotIndex)
	local middleSlot = getMiddleSlot()
	local edgeDistance = middleSlot - 1

	if edgeDistance <= 0 then
		return 0
	end

	return math.clamp(math.abs(slotIndex - middleSlot) / edgeDistance, 0, 1)
end

local function getSlotSize(slotIndex)
	local transparency = getSlotTransparency(slotIndex)
	local scale = 1 - (transparency * 0.65)

	return UDim2.fromScale(BaseRoll.CenterItemSize.X.Scale * scale, BaseRoll.CenterItemSize.Y.Scale * scale)
end

local function getSlotProperties(slotIndex)
	return {
		ImageTransparency = getSlotTransparency(slotIndex),
		Position = UDim2.fromScale(0.5, getSlotY(slotIndex)),
		Size = getSlotSize(slotIndex),
	}
end

local function setItemToSlot(item, slotIndex)
	local properties = getSlotProperties(slotIndex)

	setItemImageTransparency(item, properties.ImageTransparency)
	item.Position = properties.Position
	item.Size = properties.Size
end

local function getRollStepTimes(rollTime)
	local stepTimes = {}
	local stepWeights = {}
	local totalDurationWeight = 0
	local stepWeight = 1

	for stepIndex = 1, BaseRoll.RollSteps do
		table.insert(stepWeights, stepWeight)
		totalDurationWeight += stepWeight
		stepWeight *= BaseRoll.RollStepSlowdown
	end

	local timeScale = rollTime / totalDurationWeight

	for _, weight in stepWeights do
		table.insert(stepTimes, weight * timeScale)
	end

	return stepTimes
end

local function createReelItems(column, finalEntry, allowedLuckEntry)
	local reelItems = {}

	for slotIndex = 1, BaseRoll.VisibleRollingItems do
		local entry = getRandomVisualEntry(finalEntry, allowedLuckEntry)
		local item = createRollItem(column, entry)

		setItemToSlot(item, slotIndex)
		table.insert(reelItems, item)
	end

	columnReels[column] = reelItems

	return reelItems
end

local function hideSideReelItems(column)
	local reelItems = columnReels[column]

	if reelItems == nil then
		return
	end

	local middleSlot = getMiddleSlot()
	local tweenInfo = TweenInfo.new(BaseRoll.ColumnTweenTime, BaseRoll.ItemTweenStyle, BaseRoll.ItemTweenDirection)

	for slotIndex, item in reelItems do
		if slotIndex ~= middleSlot then
			makeRollItemTween(item, tweenInfo, {
				ImageTransparency = 1,
				Size = BaseRoll.EdgeItemSize,
			})
		end
	end
end

local function tweenReelStep(reelItems, stepTime, allowedLuckEntry)
	local tweenInfo = TweenInfo.new(stepTime, BaseRoll.ItemTweenStyle, BaseRoll.ItemTweenDirection)
	local tweens = {}

	for slotIndex, item in reelItems do
		local targetSlot = slotIndex + 1
		local targetProperties

		if targetSlot > BaseRoll.VisibleRollingItems then
			targetProperties = {
				ImageTransparency = 1,
				Position = UDim2.fromScale(0.5, 1 + getSlotY(2)),
				Size = BaseRoll.EdgeItemSize,
			}
		else
			targetProperties = getSlotProperties(targetSlot)
		end

		table.insert(tweens, makeRollItemTween(item, tweenInfo, targetProperties))
	end

	local tickTween = tweens[math.max(getMiddleSlot() - 1, 1)]
	tickTween.Completed:Wait()
	SoundPlayer.Play("Tick")

	local recycledItem = table.remove(reelItems, #reelItems)
	updateRollItem(recycledItem, getRandomVisualEntry({}, allowedLuckEntry))
	setItemToSlot(recycledItem, 1)
	table.insert(reelItems, 1, recycledItem)
end

local function settleReelHeartbeat(reelItems, settleTime, startSpeed)
	local slotDistance = getSlotY(2) - getSlotY(1)
	local maxOffset = math.max(slotDistance * BaseRoll.SettleMaxOffsetScale, 0)
	local downOffset = math.min(startSpeed * settleTime * BaseRoll.SettleDownFactor, maxOffset)
	local upOffset = -math.min(downOffset * BaseRoll.SettleUpFactor, maxOffset)
	local startTime = os.clock()

	local function hermite(p0, v0, p1, v1, t, duration)
		local s = math.clamp(t / duration, 0, 1)
		local s2 = s * s
		local s3 = s2 * s
		local h00 = 2 * s3 - 3 * s2 + 1
		local h10 = s3 - 2 * s2 + s
		local h01 = -2 * s3 + 3 * s2
		local h11 = s3 - s2
		return h00 * p0 + h10 * v0 * duration + h01 * p1 + h11 * v1 * duration
	end

	local downDistance = math.max(downOffset, 0)
	local phaseOne = math.clamp(downDistance / math.max(startSpeed, 0.001), 0.05, settleTime * 0.6)
	local remaining = math.max(settleTime - phaseOne, 0.05)
	local phaseTwo = remaining * 0.6
	local phaseThree = remaining - phaseTwo

	while true do
		local elapsed = os.clock() - startTime
		if elapsed >= settleTime then
			break
		end

		local offset
		if elapsed <= phaseOne then
			offset = hermite(0, startSpeed, downOffset, 0, elapsed, phaseOne)
		elseif elapsed <= phaseOne + phaseTwo then
			offset = hermite(downOffset, 0, upOffset, 0, elapsed - phaseOne, phaseTwo)
		else
			offset = hermite(upOffset, 0, 0, 0, elapsed - phaseOne - phaseTwo, phaseThree)
		end

		for slotIndex, item in reelItems do
			local baseY = getSlotY(slotIndex)
			item.Position = UDim2.fromScale(0.5, baseY + offset)
		end

		RunService.Heartbeat:Wait()
	end

	for slotIndex, item in reelItems do
		item.Position = UDim2.fromScale(0.5, getSlotY(slotIndex))
	end

	SoundPlayer.Play("Tick")
end

local function animateColumnRoll(column, rollEntry, rollTime, allowedLuckEntry)
	local stepTimes = getRollStepTimes(rollTime)
	local reelItems = createReelItems(column, rollEntry, allowedLuckEntry)
	local middleSlot = getMiddleSlot()

	for stepIndex, stepTime in stepTimes do
		local entryToReachMiddle = if stepIndex == #stepTimes
			then rollEntry
			else getRandomVisualEntry(rollEntry, allowedLuckEntry)
		updateRollItem(reelItems[middleSlot - 1], entryToReachMiddle)
		tweenReelStep(reelItems, stepTime, allowedLuckEntry)
	end

	local lastStepTime = stepTimes[#stepTimes] or 0.1
	local slotDistance = getSlotY(2) - getSlotY(1)
	local startSpeed = slotDistance / math.max(lastStepTime, 0.001)
	settleReelHeartbeat(reelItems, BaseRoll.SettleTime, startSpeed)

	local landedItem = reelItems[middleSlot]

	-- Plays a Sound named "Chicken" from SoundService/RollSounds,
	-- falling back to "Slime" (the package's original sound) if
	-- you haven't added/renamed one yet — so something always
	-- plays instead of nothing.
	if not SoundPlayer.Play(rollEntry.Type) then
		SoundPlayer.Play("Slime")
	end

	if rollEntry.Type == "Chicken" and landedItem ~= nil then
		hideSideReelItems(column)

		local scaledSize = UDim2.fromScale(
			BaseRoll.CenterItemSize.X.Scale * BaseRoll.FinalSlimeScale,
			BaseRoll.CenterItemSize.Y.Scale * BaseRoll.FinalSlimeScale
		)
		local scaleInfo =
			TweenInfo.new(BaseRoll.FinalSlimeScaleTime, BaseRoll.ItemTweenStyle, BaseRoll.ItemTweenDirection)

		makeTween(landedItem, scaleInfo, {
			Size = scaledSize,
		}).Completed:Wait()

		task.wait(BaseRoll.FinalSlimeHoldTime)
	end
end

local function clearColumns()
	for _, column in columns do
		columnReels[column] = nil
		column:Destroy()
	end

	table.clear(columns)
end

local function runRoll(sequence, rollTime)
	clearColumns()

	for index, rollEntry in sequence do
		if index > 1 then
			hideSideReelItems(columns[index - 1])
		end

		local column = createColumn(index)
		updateMiddleMarkers()
		local allowedLuckEntry = nil -- flourish system removed, see note above
		animateColumnRoll(column, rollEntry, rollTime, allowedLuckEntry)
	end
end

--==================================================
-- REQUEST ROLL
-- ChickenRollService.RequestRoll returns a SINGLE winning
-- chicken (result, chickenIndex) on success, or (nil, "reason")
-- on failure — not the old {Ok, Sequence, RollTime} shape. This
-- wraps that single result into a one-item Sequence so the rest
-- of the animation code (built for multi-column) works unchanged.
--==================================================

local function requestRoll()
	if isRolling then
		return
	end

	isRolling = true
	if hiddenMode then
		showHiddenState()
	else
		showRollState()
	end

	local success, result, errorOrIndex = pcall(function()
		return requestRollRemote:InvokeServer()
	end)

	if not success then

		warn("[RollClient] InvokeServer threw an error:", result)

	elseif result == nil then

		warn("[RollClient] Roll failed:", errorOrIndex or "(no reason given)")

	else

		local visualEntry = rollResultToVisualEntry(result)
		local rollTime = result.RollDuration or BaseRoll.RollTime

		runRoll({ visualEntry }, rollTime)
	end

	if autoRollEnabled then
		task.delay(BaseRoll.AutoRollDelay, requestRoll)
	elseif not hiddenMode then
		hideRequestId += 1
		local requestId = hideRequestId
		task.delay(BaseRoll.HideAfterRollDelay, function()
			if requestId == hideRequestId and not autoRollEnabled and not isRolling then
				showDiceState()
			end
		end)
	end

	isRolling = false
end

hideButton.Activated:Connect(function()
	setHiddenMode(true)
	showHiddenState()
end)

autoRollButton.Activated:Connect(function()
	setAutoRollState(not autoRollEnabled)
	if autoRollEnabled and not isRolling then
		requestRoll()
	end
end)

rollButton.Activated:Connect(function()
	if hiddenMode then
		setHiddenMode(false)
	end
	showRollState()
	requestRoll()
end)

print("[RollClient] Ready (Chicken RNG mode)")