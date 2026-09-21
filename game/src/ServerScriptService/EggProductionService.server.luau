--[[
	EggProductionService
	Moon egg laying + Eggbox pickup
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")									

local plotsFolder = Workspace:WaitForChild("Plots")
local ChickenFolder = ReplicatedStorage:WaitForChild("Chicken")
local EggTemplates = ChickenFolder:WaitForChild("Eggs")
local TOOL_TEMPLATE = ReplicatedStorage:WaitForChild("EggboxToolTemplate")
local ChickenEggConfig = require(ReplicatedStorage:WaitForChild("ChickenEggConfig"))
local EggAnimationConfig = require(ServerScriptService:WaitForChild("EggAnimationConfig"))
local EggMoonAnimator = require(ServerScriptService:WaitForChild("EggMoonAnimator"))
local ActiveEventState = require(ServerScriptService:WaitForChild("ActiveEventState"))
local MutationConfig = require(ReplicatedStorage:WaitForChild("MutationConfig"))
local Packets = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("Packets"))

local LAY_INTERVAL = 6
local MAX_EGGS_PER_PLOT = 20
local STAGGER_MIN = 0.4
local STAGGER_MAX = 2.2
local MAX_BOX_STAGE = 6
local MAX_DISPLAY_EGGS = 6

local BOX_SLOT_POSITIONS = {
	Vector3.new(239.063, 67.183, 352.176),
	Vector3.new(239.063, 67.183, 354.5),
	Vector3.new(239.063, 67.183, 349.863),
	Vector3.new(241.177, 67.183, 354.5),
	Vector3.new(241.172, 67.183, 352.176),
	Vector3.new(241.172, 67.183, 349.863),
}

local cachedEggRadius
local plotStages = {}
local plotEggContents = {}
local plotDisplayEggs = {}
local promptConnections = {}
local eggCountConnections = {}
local applyMutationVisuals

local function getEggRollRadius(eggTemplate)
	if EggAnimationConfig.EggRollRadius then
		return EggAnimationConfig.EggRollRadius
	end
	if not cachedEggRadius then
		local size = eggTemplate:GetExtentsSize()
		cachedEggRadius = math.max(size.X, size.Z) / 2
	end
	return cachedEggRadius
end

local function getChickenEggData(chickenModel)
	local baseName = chickenModel.Name:match("^[^_]+") or chickenModel.Name
	baseName = baseName:gsub("%s*%d+$", "")
	for chickenName, data in pairs(ChickenEggConfig) do
		if string.lower(chickenName) == string.lower(baseName) then
			return data
		end
	end
	return nil
end

local function makeEgg(eggModelName)
	local template = EggTemplates:FindFirstChild(eggModelName)
	if not template or not template:IsA("Model") then
		warn("[EggProductionService] Missing egg model: " .. tostring(eggModelName))
		return nil
	end
	local egg = template:Clone()
	local root = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		warn("[EggProductionService] Egg model has no BasePart: " .. eggModelName)
		egg:Destroy()
		return nil
	end
	egg.PrimaryPart = root
	for _, part in ipairs(egg:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
		end
	end
	return egg
end

local function getChickenModels(plot)
	local display = plot:FindFirstChild("ChickenDisplay")
	if not display then
		return {}
	end
	local chickens = {}
	for _, object in ipairs(display:GetChildren()) do
		if object:IsA("Model") then
			table.insert(chickens, object)
		end
	end
	return chickens
end

local function getSlotNumberFromChicken(chicken)
	local current = chicken
	for _ = 1, 6 do
		if not current then
			break
		end
		local n = tonumber(current.Name:match("%d+"))
		if n then
			return n
		end
		current = current.Parent
	end
	local display = chicken.Parent
	if display then
		local models = {}
		for _, obj in ipairs(display:GetChildren()) do
			if obj:IsA("Model") then
				table.insert(models, obj)
			end
		end
		table.sort(models, function(a, b) return a.Name < b.Name end)
		for i, model in ipairs(models) do
			if model == chicken then
				return i
			end
		end
	end
	return nil
end

local function resolveMoonAnimationName(slotNumber)
	if slotNumber and EggAnimationConfig.SlotAnimations[slotNumber] then
		return EggAnimationConfig.SlotAnimations[slotNumber]
	end
	if EggAnimationConfig.DefaultMoonAnimation then
		return EggAnimationConfig.DefaultMoonAnimation
	end
	for _, name in pairs(EggAnimationConfig.SlotAnimations) do
		return name
	end
	return nil
end

local function setModelVisible(model, visible)
	if not model then
		return
	end
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Transparency = visible and 0 or 1
			desc.CanCollide = visible
			desc.CanQuery = visible
			desc.CanTouch = visible
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = visible and 0 or 1
		elseif desc:IsA("ProximityPrompt") then
			desc.Enabled = visible
		end
	end
	if model:IsA("BasePart") then
		model.Transparency = visible and 0 or 1
		model.CanCollide = visible
		model.CanQuery = visible
		model.CanTouch = visible
	end
end

local function getEggboxModel(plot)
	return plot:FindFirstChild("Eggbox")
end

local function updateEggboxDisplay(plot, eggCount)
	local eggbox = getEggboxModel(plot)
	if not eggbox then
		return
	end

	eggCount = math.max(0, math.floor(tonumber(eggCount) or 0))
	eggbox:SetAttribute("EggCount", eggCount)

	local textLabel = eggbox:FindFirstChild("TextLabel", true)
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = string.format("%d egg%s", eggCount, eggCount == 1 and "" or "s")
	end

	local displayEggs = {}
	for _, object in ipairs(plot:GetChildren()) do
		if object:IsA("Model") and object.Name:match("^EggboxEgg_%d+$") then
			table.insert(displayEggs, object)
		end
	end

	table.sort(displayEggs, function(a, b)
		return (tonumber(a.Name:match("%d+$")) or 0) < (tonumber(b.Name:match("%d+$")) or 0)
	end)

	for index, eggModel in ipairs(displayEggs) do
		setModelVisible(eggModel, index <= MAX_DISPLAY_EGGS and index <= eggCount)
	end
end

local function computeBoxValue(contents)
	local total = 0

	for _, entry in ipairs(contents) do
		local price = tonumber(entry.price) or 0
		local multiplier = 1

		if typeof(entry.mutations) == "table" and MutationConfig.GetMultiplier then
			for _, mutationName in ipairs(entry.mutations) do
				multiplier *= MutationConfig.GetMultiplier(mutationName)
			end
		end

		total += math.floor(price * multiplier)
	end

	return total
end

local function applyBoxStage(plot, stageIndex)
	plotStages[plot] = math.clamp(stageIndex, 0, MAX_BOX_STAGE)
	setModelVisible(getEggboxModel(plot), true)
end

local function clearDisplayEggs(plot)
	for _, egg in ipairs(plotDisplayEggs[plot] or {}) do
		if egg.Parent then
			egg:Destroy()
		end
	end
	plotDisplayEggs[plot] = {}
end

local function prepareEggModel(egg)
	local root = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		egg:Destroy()
		return nil
	end
	egg.PrimaryPart = root
	local sourceTemplate = EggTemplates:FindFirstChild("Egg")
	local sourceSize = sourceTemplate and sourceTemplate:GetExtentsSize()
	local eggSize = egg:GetExtentsSize()
	local sourceDiameter = sourceSize and math.max(sourceSize.X, sourceSize.Z) or 2
	local eggDiameter = math.max(eggSize.X, eggSize.Z)
	if eggDiameter > 0 then
		egg:ScaleTo(0.848)
	end
	for _, part in ipairs(egg:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	return egg
end

local function addDisplayEgg(plot, eggModelName, eggIndex, mutations)
	local template = EggTemplates:FindFirstChild(eggModelName)
	local position = BOX_SLOT_POSITIONS[eggIndex]
	if not template or not position then
		warn("[EggProductionService] Cannot display missing egg model " .. tostring(eggModelName))
		return false
	end
	local egg = template:Clone()
	egg.Name = "EggboxEgg_" .. tostring(eggIndex)
	if not prepareEggModel(egg) then
		return false
	end
	egg.Parent = plot
	egg:PivotTo(CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)))
	applyMutationVisuals(egg, mutations)
	table.insert(plotDisplayEggs[plot], egg)
	return true
end

local MUTATION_VISUALS = {
	Candy = {color = Color3.fromRGB(255, 105, 180), material = Enum.Material.Neon},
	Neon = {color = Color3.fromRGB(57, 255, 20), material = Enum.Material.Neon},
	Golden = {color = Color3.fromRGB(255, 205, 45), material = Enum.Material.Neon},
	Diamond = {color = Color3.fromRGB(80, 220, 255), material = Enum.Material.Glass},
	Shiny = {color = Color3.fromRGB(255, 255, 255), material = Enum.Material.Neon},
	Rainbow = {color = Color3.fromRGB(255, 80, 220), material = Enum.Material.Neon, sequence = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 255, 100)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 210, 255)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(130, 90, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 190)),
	})},
	Space = {color = Color3.fromRGB(145, 75, 255), material = Enum.Material.Neon},
	Lava = {color = Color3.fromRGB(255, 75, 20), material = Enum.Material.Neon},
	Radioactive = {color = Color3.fromRGB(80, 255, 40), material = Enum.Material.Neon},
	Disco = {color = Color3.fromRGB(255, 70, 230), material = Enum.Material.Neon, sequence = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 40, 80)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(70, 220, 255)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 230, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 70, 255)),
	})},
	Void = {color = Color3.fromRGB(35, 10, 55), material = Enum.Material.Neon},
	Tsunami = {color = Color3.fromRGB(45, 150, 255), material = Enum.Material.Glass},
}

applyMutationVisuals = function(model, mutations)
	if not model or not mutations or #mutations == 0 then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return
	end
	local visuals = model:FindFirstChild("MutationVisuals")
	if visuals then
		visuals:Destroy()
	end
	visuals = Instance.new("Folder")
	visuals.Name = "MutationVisuals"
	visuals.Parent = model
	local attachment = Instance.new("Attachment")
	attachment.Name = "MutationAttachment"
	attachment.Parent = root
	for _, mutationName in ipairs(mutations) do
		local visual = MUTATION_VISUALS[mutationName]
		if visual then
			local highlight = Instance.new("Highlight")
			highlight.Name = mutationName .. "Highlight"
			highlight.Adornee = model
			highlight.FillColor = visual.color
			highlight.OutlineColor = visual.color
			highlight.FillTransparency = 0.72
			highlight.OutlineTransparency = 0.08
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Parent = visuals

			local light = Instance.new("PointLight")
			light.Name = mutationName .. "Glow"
			light.Color = visual.color
			light.Brightness = 1.2
			light.Range = 5
			light.Parent = attachment

			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = mutationName .. "Particles"
			emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			emitter.Color = visual.sequence or ColorSequence.new(visual.color)
			emitter.LightEmission = 0.8
			emitter.Rate = 5
			emitter.Lifetime = NumberRange.new(0.7, 1.3)
			emitter.Speed = NumberRange.new(0.3, 0.8)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.16),
				NumberSequenceKeypoint.new(0.5, 0.28),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.Parent = attachment
		end
	end
end

local function addMutation(mutations, mutationName)
	if not mutationName or table.find(mutations, mutationName) then
		return
	end
	table.insert(mutations, mutationName)
end

local function rollEggMutations()
	local mutations = {}
	local activeEventId = ActiveEventState.Get()
	local eventMutation = activeEventId and MutationConfig.GetEventMutation(activeEventId)

	if eventMutation and math.random() <= MutationConfig.EventChance then
		addMutation(mutations, eventMutation.name)
	end

	if math.random() <= MutationConfig.NormalChance then
		local normalNames = {}
		for mutationName in pairs(MutationConfig.NormalMutations) do
			table.insert(normalNames, mutationName)
		end
		if #normalNames > 0 then
			addMutation(mutations, normalNames[math.random(1, #normalNames)])
		end
	end

	return mutations
end

local function advanceBoxStage(plot, eggModelName, price)
	local contents = plotEggContents[plot] or {}

	local mutations = rollEggMutations()

	local entry = {
		eggModelName = eggModelName,
		price = price,
		mutations = mutations,
	}

	if #mutations > 0 then
		local mutationText = table.concat(mutations, " + ")

		print(string.format(
			"[Mutation] Egg %q received mutations: %s",
			eggModelName,
			table.concat(mutations, ", ")
			))

		local ownerUserId = plot:GetAttribute("Owner")
		local owner = ownerUserId and Players:GetPlayerByUserId(ownerUserId)

		if owner
			and Packets
			and Packets.Notification
			and Packets.Notification.Prompt then

			Packets.Notification.Prompt:FireClient(
				owner,
				"Success",
				string.format(
					"Your %s was mutated with %s!",
					eggModelName,
					mutationText
				)
			)
		end
	end

	table.insert(contents, entry)
	plotEggContents[plot] = contents

	local eggCount = #contents
	if eggCount <= MAX_DISPLAY_EGGS then
		if not addDisplayEgg(plot, eggModelName, eggCount, mutations) then
			table.remove(contents)
			return false
		end
	end

	applyBoxStage(plot, math.min(eggCount, MAX_BOX_STAGE))
	updateEggboxDisplay(plot, eggCount)

	print(
		"[EggProductionService] Box now contains",
		#contents,
		"eggs. Added",
		eggModelName,
		"worth $",
		computeBoxValue(contents)
	)

	return true
end

local function getEggDataByModelName(eggModelName)
	for _, data in pairs(ChickenEggConfig) do
		if data.eggModelName == eggModelName then
			return data
		end
	end
	return nil
end

local function giveBoxToolToPlayer(player, plot, stageIndex)
	local contents = plotEggContents[plot] or {}
	if #contents == 0 then
		return
	end
	local firstData = getEggDataByModelName(contents[1].eggModelName)
	if not firstData then
		warn("[EggProductionService] Cannot validate egg type for box pickup")
		return
	end
	local tool = TOOL_TEMPLATE:Clone()
	local eggCount = #contents
	tool.Name = eggCount == 1 and "Eggbox" or ("Eggbox x" .. tostring(eggCount))
	tool:SetAttribute("EggStage", math.min(eggCount, MAX_BOX_STAGE))
	tool:SetAttribute("EggCount", eggCount)
	tool:SetAttribute("EggModelName", firstData.eggModelName)
	tool:SetAttribute("EggPrice", firstData.price)
	tool:SetAttribute("EggContents", HttpService:JSONEncode(contents))

	local boxValue = computeBoxValue(contents)

	tool:SetAttribute("BoxValue", boxValue)
	local handle = tool:FindFirstChild("Handle")
	if not handle then
		warn("[EggProductionService] EggboxToolTemplate is missing Handle")
		tool:Destroy()
		return
	end

	local boxScale = 0.5
	local heldEggOffsets = {
		Vector3.new(-0.666522, -0.807539,  0.092352),
		Vector3.new(-0.666522, -0.807539,  2.416352),
		Vector3.new(-0.666522, -0.807539, -2.220648),
		Vector3.new( 1.447477, -0.807539,  2.416352),
		Vector3.new( 1.442477, -0.807539,  0.092352),
		Vector3.new( 1.442477, -0.807539, -2.220648),
	}

	local sourceBox = getEggboxModel(plot)
	if sourceBox then
		local body = sourceBox:Clone()
		body.Name = "HeldEggboxBody"
		for _, desc in ipairs(body:GetDescendants()) do
			if desc:IsA("ProximityPrompt") or desc:IsA("Attachment") then
				desc:Destroy()
			end
		end
		body.Parent = tool
		body:ScaleTo(boxScale)
		body:PivotTo(handle.CFrame)
		for _, part in ipairs(body:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = handle
			end
		end
	end



	for index, entry in ipairs(contents) do
		if index > MAX_BOX_STAGE then
			break
		end
		local eggTemplate = EggTemplates:FindFirstChild(entry.eggModelName)
		if not eggTemplate or not eggTemplate:IsA("Model") then
			warn("[EggProductionService] Missing tool egg model " .. tostring(entry.eggModelName))
			continue
		end
		local visual = eggTemplate:Clone()
		visual.Name = "EggVisual_" .. tostring(index) .. "_" .. entry.eggModelName
		local visualRoot = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart", true)
		if not visualRoot then
			visual:Destroy()
			continue
		end
		visual.PrimaryPart = visualRoot
		local eggScale = eggTemplate:GetScale() * boxScale
		visual:ScaleTo(eggScale)
		local slotOffset = CFrame.Angles(0, math.rad(90), 0):VectorToWorldSpace(
			heldEggOffsets[index] * boxScale
		)
		visual:PivotTo(
			handle.CFrame
				* CFrame.new(slotOffset)
				* CFrame.Angles(0, 0, math.rad(90))
		)
		applyMutationVisuals(visual, entry.mutations or {})
		for _, part in ipairs(visual:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.Massless = true
				part.CanQuery = false
				part.CanTouch = false
			elseif part:IsA("ProximityPrompt") then
				part:Destroy()
			end
		end
		visual.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = visualRoot
		weld.Parent = handle
		for _, part in ipairs(visual:GetDescendants()) do
			if part:IsA("BasePart") and part ~= visualRoot then
				local partWeld = Instance.new("WeldConstraint")
				partWeld.Part0 = visualRoot
				partWeld.Part1 = part
				partWeld.Parent = visualRoot
			end
		end
	end
	for _, desc in ipairs(tool:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			desc:Destroy()
		end
	end
	local backpack = player:FindFirstChild("Backpack")
	tool.Parent = backpack or player.Character
	print("[EggProductionService] Gave", player.Name, "an eggbox containing", #contents, "eggs worth $", boxValue)
end

-- FIX: Restored from the old version.
local function resetBoxStage(plot, player)
	local current = plotStages[plot] or 0
	if player and current > 0 then
		giveBoxToolToPlayer(player, plot, current)
	end
	plotEggContents[plot] = {}
	clearDisplayEggs(plot)
	applyBoxStage(plot, 0)
	updateEggboxDisplay(plot, 0)
end

local function setupBoxPrompts(plot)
	if promptConnections[plot] then
		return
	end
	promptConnections[plot] = true
	local model = getEggboxModel(plot)
	if not model then
		return
	end
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			if (plotStages[plot] or 0) > 0 then
				resetBoxStage(plot, player)
			end
		end)
	end
end

local function initPlotBox(plot)
	plotEggContents[plot] = {}
	clearDisplayEggs(plot)
	applyBoxStage(plot, 0)

	local eggbox = getEggboxModel(plot)
	if eggCountConnections[plot] then
		eggCountConnections[plot]:Disconnect()
		eggCountConnections[plot] = nil
	end
	if eggbox then
		local currentCount = eggbox:GetAttribute("EggCount")
		updateEggboxDisplay(plot, currentCount or 0)
		eggCountConnections[plot] = eggbox:GetAttributeChangedSignal("EggCount"):Connect(function()
			updateEggboxDisplay(plot, eggbox:GetAttribute("EggCount"))
		end)
	end

	setupBoxPrompts(plot)
end
local function spawnMoonEgg(plot, chickenModel)
	local holder = plot:FindFirstChild("EggBeltEggs")
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "EggBeltEggs"
		holder.Parent = plot
	end
	if #holder:GetChildren() >= MAX_EGGS_PER_PLOT then
		return
	end
	local eggData = getChickenEggData(chickenModel)
	if not eggData then
		warn("[EggProductionService] No egg configuration for " .. chickenModel.Name)
		return
	end

	-- LEVELING HOOK: if this chicken has been leveled up via
	-- ChickenLevelServer, it will have an "EggValue" attribute set
	-- directly on this model — use that instead of the flat base
	-- price. Un-leveled chickens (no attribute set) just fall back
	-- to the normal ChickenEggConfig price, unchanged from before.
	local eggPrice = chickenModel:GetAttribute("EggValue") or eggData.price

	local egg = makeEgg(eggData.eggModelName)
	if not egg then
		return
	end
	egg.Parent = holder
	local function onAnimationComplete(success)
		if egg and egg.Parent then
			egg:Destroy()
		end
		if success then
			advanceBoxStage(plot, eggData.eggModelName, eggPrice)
		end
	end
	local slotNumber = getSlotNumberFromChicken(chickenModel)
	local moonAnimationName = resolveMoonAnimationName(slotNumber)
	if not moonAnimationName then
		warn("[EggProductionService] No Moon animation configured")
		egg:Destroy()
		return
	end
	local eggbox = plot:FindFirstChild("Eggbox")
	local boxPosition
	if eggbox then
		boxPosition = eggbox:GetPivot().Position
	else
		boxPosition = chickenModel:GetPivot().Position + Vector3.new(0, -2, 8)
	end
	local context = {
		targetPosition = chickenModel:GetPivot().Position,
		targetSlotNumber = slotNumber,
		boxPosition = boxPosition,
		eggRadius = getEggRollRadius(EggTemplates:FindFirstChild(eggData.eggModelName)),
	}
	EggMoonAnimator.Play(egg, chickenModel, moonAnimationName, context, EggAnimationConfig, onAnimationComplete)
end

for _, plot in ipairs(plotsFolder:GetChildren()) do
	if plot:IsA("Model") then
		initPlotBox(plot)
	end
end

plotsFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		task.defer(initPlotBox, child)
	end
end)

local function startLoop()
	while true do
		task.wait(LAY_INTERVAL)
		for _, plot in ipairs(plotsFolder:GetChildren()) do
			if not plot:IsA("Model") then
				continue
			end
			if plotStages[plot] == nil then
				initPlotBox(plot)
			end
			local chickens = getChickenModels(plot)
			if #chickens == 0 then
				continue
			end
			for i, chicken in ipairs(chickens) do
				local delayTime = (i - 1) * STAGGER_MIN + math.random() * (STAGGER_MAX - STAGGER_MIN)
				task.spawn(function()
					task.wait(delayTime)
					spawnMoonEgg(plot, chicken)
				end)
			end
		end
	end
end

task.spawn(startLoop)
print("[EggProductionService] Egg laying + box pickup initialized")