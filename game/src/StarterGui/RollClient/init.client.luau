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
local Workspace = game:GetService("Workspace")
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
-- PRESENTATION HELPERS (visual only)
-- Everything in this section only changes how a roll is DRAWN. Roll odds, rewards,
-- data and remotes are untouched.
--==================================================

local WINNER_SCALE = 1.18 -- restrained scale-up for the centred winner (BaseRoll.FinalSlimeScale was 1.4)
local WINNER_SPIN_DEGREES_PER_SECOND = 40
local MIN_LEGIBLE_LABEL_HEIGHT = 8 -- px; below this the name / odds are skipped rather than drawn unreadably
local VIEWPORT_FIELD_OF_VIEW = 30
local GENERIC_CHICKEN_NAME = "White Chicken" -- shape used (tinted) when a chicken has no model and no icon

local chickenRankByName = {}

for rank, chicken in ChickenRollConfig.Chickens do
	chickenRankByName[chicken.name] = rank
end

local RARITY_TIERS = {
	{ maxRank = 4, color = Color3.fromRGB(205, 205, 205) },
	{ maxRank = 8, color = Color3.fromRGB(95, 205, 95) },
	{ maxRank = 13, color = Color3.fromRGB(70, 145, 255) },
	{ maxRank = 19, color = Color3.fromRGB(170, 95, 255) },
	{ maxRank = 26, color = Color3.fromRGB(255, 95, 200) },
	{ maxRank = 33, color = Color3.fromRGB(255, 150, 55) },
	{ maxRank = 41, color = Color3.fromRGB(255, 75, 75) },
	{ maxRank = math.huge, color = Color3.fromRGB(255, 215, 65) },
}

local function getRarityColor(chickenName)
	local rank = chickenRankByName[chickenName] or 1

	for _, tier in RARITY_TIERS do
		if rank <= tier.maxRank then
			return tier.color
		end
	end

	return RARITY_TIERS[#RARITY_TIERS].color
end

-- "1 in 250,000,000" -> "1/250M"  (K / M / B / T)
local ODDS_UNITS = {
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
	{ 1e3, "K" },
}

local function compactNumber(value)
	for _, unit in ODDS_UNITS do
		if value >= unit[1] then
			local scaled = value / unit[1]
			local text = if scaled >= 100 or scaled % 1 == 0
				then string.format("%d", math.floor(scaled + 0.5))
				else string.format("%.1f", scaled)

			return text:gsub("%.0$", "") .. unit[2]
		end
	end

	return string.format("%d", math.floor(value + 0.5))
end

local function formatOdds(oddsText)
	if type(oddsText) ~= "string" then
		return ""
	end

	local denominator = oddsText:match("1%s*in%s*([%d,]+)") or oddsText:match("1%s*/%s*([%d,]+)")
	local value = denominator and tonumber((denominator:gsub(",", "")))

	if not value then
		return oddsText
	end

	return "1/" .. compactNumber(value)
end

-- "1/30 (3.3%)": compact odds plus the percentage chance when it is big enough to be meaningful
local function formatPercent(value)
	local percent = 100 / value

	if percent < 0.01 then
		return nil
	end

	local text = if percent >= 1 then string.format("%.1f", percent) else string.format("%.2f", percent)

	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end

	return text .. "%"
end

local function formatChance(oddsText)
	local odds = formatOdds(oddsText)

	if type(oddsText) ~= "string" then
		return odds
	end

	local denominator = oddsText:match("1%s*in%s*([%d,]+)") or oddsText:match("1%s*/%s*([%d,]+)")
	local value = denominator and tonumber((denominator:gsub(",", "")))
	local percent = value and value > 0 and formatPercent(value)

	if percent then
		return `{odds} ({percent})`
	end

	return odds
end

-- Real chicken models come from Workspace/Chicken (kept always-streamed so they exist on
-- every client). Names are matched ignoring case; if several models share a name the one
-- with the most parts wins (some copies are empty shells).
local function countBaseParts(model)
	local count = 0

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end

	return count
end

local function findChickenModel(chickenName)
	local folder = Workspace:FindFirstChild("Chicken")

	if not folder then
		return nil
	end

	local wanted = string.lower(chickenName)
	local best, bestParts = nil, 0

	for _, child in folder:GetChildren() do
		if child:IsA("Model") and string.lower(child.Name) == wanted then
			local parts = countBaseParts(child)

			if parts > bestParts then
				best, bestParts = child, parts
			end
		end
	end

	return best
end

local function shouldStrip(instance)
	return instance:IsA("LuaSourceContainer")
		or instance:IsA("Sound")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Beam")
		or instance:IsA("Trail")
		or instance:IsA("Light")
		or instance:IsA("Humanoid")
		or instance:IsA("Animator")
		or instance:IsA("Constraint")
		or instance:IsA("WeldConstraint")
		or instance:IsA("JointInstance")
		or instance:IsA("ProximityPrompt")
		or instance:IsA("ClickDetector")
		or instance:IsA("BillboardGui")
		or instance:IsA("SurfaceGui")
		or instance:IsA("Highlight")
end

-- Clone once, strip everything that is not geometry, anchor it, centre it on the origin.
local function buildDisplayTemplate(source)
	local cloned, clone = pcall(function()
		return source:Clone()
	end)

	if not cloned or not clone then
		return nil
	end

	for _, descendant in clone:GetDescendants() do
		if shouldStrip(descendant) then
			descendant:Destroy()
		end
	end

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end

	if countBaseParts(clone) == 0 then
		clone:Destroy()
		return nil
	end

	local boundsCFrame, boundsSize = clone:GetBoundingBox()
	clone.WorldPivot = boundsCFrame
	clone:PivotTo(CFrame.new())

	return { model = clone, size = boundsSize }
end

local displayTemplates = {}

local function getDisplayTemplate(chickenName)
	local key = string.lower(chickenName)
	local cached = displayTemplates[key]

	if cached then
		return cached
	end

	local source = findChickenModel(chickenName)

	if not source then
		return nil
	end

	local template = buildDisplayTemplate(source)

	if template then
		displayTemplates[key] = template
	end

	return template
end

-- The chicken models face +X in their own frame (beak and eyes sit on the +X side), so the
-- camera looks at them from the front, slightly above and to the side (three-quarter view).
local CAMERA_DIRECTION = Vector3.new(1, 0.28, 0.65).Unit

-- Closest camera distance at which the model (allowing for its slow spin) still fits the frame.
local function getFitDistance(size, direction, fieldOfView, aspect)
	local footprint = math.max(size.X, size.Z) * 1.2
	local box = Vector3.new(footprint, size.Y, footprint)
	local look = CFrame.lookAt(direction, Vector3.zero)
	local tanHalf = math.tan(math.rad(fieldOfView / 2))
	local distance = 0

	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local corner = Vector3.new(x * box.X, y * box.Y, z * box.Z) / 2
				local along = corner:Dot(look.LookVector)
				local needUp = math.abs(corner:Dot(look.UpVector)) / tanHalf - along
				local needRight = math.abs(corner:Dot(look.RightVector)) / (tanHalf * aspect) - along

				distance = math.max(distance, needUp, needRight)
			end
		end
	end

	return distance * 1.05
end

local function clearVisual(item)
	local viewport = item:FindFirstChild("Viewport")

	if viewport then
		local old = viewport:FindFirstChild("ChickenModel")

		if old then
			old:Destroy()
		end

		viewport.Visible = false
	end

	local fallback = item:FindFirstChild("Fallback")

	if fallback then
		fallback.Visible = false
	end

	if item:IsA("ImageLabel") then
		item.Image = ""
	end
end

local function showModelInViewport(viewport, template, tint)
	local model = template.model:Clone()
	model.Name = "ChickenModel"

	if tint then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Color = descendant.Color:Lerp(tint, 0.65)
			end
		end
	end

	local camera = viewport.CurrentCamera

	if not camera then
		camera = Instance.new("Camera")
		camera.FieldOfView = VIEWPORT_FIELD_OF_VIEW
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end

	local aspect = if viewport.AbsoluteSize.Y > 0 then viewport.AbsoluteSize.X / viewport.AbsoluteSize.Y else 1.5
	local distance = getFitDistance(template.size, CAMERA_DIRECTION, camera.FieldOfView, aspect)
	camera.CFrame = CFrame.lookAt(CAMERA_DIRECTION * distance, Vector3.zero)

	model.Parent = viewport
	viewport.Visible = true
end

-- Order: real model -> icon (if one is set) -> generic chicken tinted by rarity -> emoji.
-- An item is never left blank.
local function applyChickenVisual(item, entry)
	clearVisual(item)

	local viewport = item:FindFirstChild("Viewport")
	local template = getDisplayTemplate(entry.DisplayName)

	if template and viewport then
		showModelInViewport(viewport, template, nil)
		return
	end

	if type(entry.Icon) == "string" and entry.Icon ~= "" then
		item.Image = entry.Icon
		return
	end

	local generic = getDisplayTemplate(GENERIC_CHICKEN_NAME)

	if generic and viewport then
		showModelInViewport(viewport, generic, getRarityColor(entry.DisplayName))
		return
	end

	local fallback = item:FindFirstChild("Fallback")

	if fallback then
		fallback.TextColor3 = getRarityColor(entry.DisplayName)
		fallback.Visible = true
	end
end

-- Name, odds badge and glow belong to the centred winner only.
local function hideDetails(item)
	for _, childName in { "Name", "Badge", "Glow" } do
		local child = item:FindFirstChild(childName)

		if child then
			child.Visible = false
		end
	end
end

local winnerSpinConnection = nil

local function stopWinnerSpin()
	if winnerSpinConnection then
		winnerSpinConnection:Disconnect()
		winnerSpinConnection = nil
	end
end

local function revealWinner(item, entry)
	local color = getRarityColor(entry.DisplayName)
	local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local finalItemHeight = item.AbsoluteSize.Y * WINNER_SCALE

	local function fadeText(label)
		label.TextTransparency = 1
		TweenService:Create(label, info, { TextTransparency = 0 }):Play()

		local stroke = label:FindFirstChildOfClass("UIStroke")

		if stroke then
			stroke.Transparency = 1
			TweenService:Create(stroke, info, { Transparency = 0 }):Play()
		end
	end

	local nameLabel = item:FindFirstChild("Name")

	if nameLabel and finalItemHeight * nameLabel.Size.Y.Scale >= MIN_LEGIBLE_LABEL_HEIGHT then
		nameLabel.Text = entry.DisplayName
		nameLabel.Visible = true
		fadeText(nameLabel)
	end

	local badge = item:FindFirstChild("Badge")

	if badge and finalItemHeight * badge.Size.Y.Scale >= MIN_LEGIBLE_LABEL_HEIGHT then
		local chanceLabel = badge:FindFirstChild("Chance")

		if chanceLabel then
			chanceLabel.Text = formatChance(entry.OddsText)
			fadeText(chanceLabel)
		end

		local badgeStroke = badge:FindFirstChildOfClass("UIStroke")

		if badgeStroke then
			badgeStroke.Color = color
			badgeStroke.Transparency = 1
			TweenService:Create(badgeStroke, info, { Transparency = 0.1 }):Play()
		end

		badge.BackgroundTransparency = 1
		badge.Visible = true
		TweenService:Create(badge, info, { BackgroundTransparency = 0.2 }):Play()
	end

	local glow = item:FindFirstChild("Glow")

	if glow then
		glow.BackgroundColor3 = color
		glow.BackgroundTransparency = 1
		glow.Visible = true
		TweenService:Create(glow, info, { BackgroundTransparency = 0.82 }):Play()

		local glowStroke = glow:FindFirstChildOfClass("UIStroke")

		if glowStroke then
			glowStroke.Color = color
			glowStroke.Transparency = 1
			TweenService:Create(glowStroke, info, { Transparency = 0.4 }):Play()
		end
	end

	-- Slow rotation of the real model (icons and fallbacks have nothing to rotate)
	stopWinnerSpin()

	local viewport = item:FindFirstChild("Viewport")
	local model = viewport and viewport:FindFirstChild("ChickenModel")

	if model then
		local angle = 0

		winnerSpinConnection = RunService.RenderStepped:Connect(function(deltaTime)
			if not model.Parent then
				stopWinnerSpin()
				return
			end

			angle = (angle + WINNER_SPIN_DEGREES_PER_SECOND * deltaTime) % 360
			model:PivotTo(CFrame.Angles(0, math.rad(angle), 0))
		end)
	end
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

	local viewport = item:FindFirstChild("Viewport")

	if viewport then
		viewport.ImageTransparency = transparency
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
		local viewport = item:FindFirstChild("Viewport")

		if viewport then
			makeTween(viewport, tweenInfo, {
				ImageTransparency = imageTransparency,
			})
		end

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
	applyChickenVisual(item, rollEntry)
	hideDetails(item)
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
			BaseRoll.CenterItemSize.X.Scale * WINNER_SCALE,
			BaseRoll.CenterItemSize.Y.Scale * WINNER_SCALE
		)
		local scaleInfo = TweenInfo.new(
			math.max(BaseRoll.FinalSlimeScaleTime, 0.25),
			BaseRoll.ItemTweenStyle,
			BaseRoll.ItemTweenDirection
		)

		revealWinner(landedItem, rollEntry)

		makeTween(landedItem, scaleInfo, {
			Size = scaledSize,
		}).Completed:Wait()

		task.wait(BaseRoll.FinalSlimeHoldTime)
	end
end

local function clearColumns()
	stopWinnerSpin()

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