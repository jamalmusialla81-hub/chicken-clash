--==================================================
-- CHICKEN ROLL SERVICE
-- (Consolidated replacement for the wiped ChickenRollService
--  AND the separate ChickenRollBackend script. Delete/disable
--  ChickenRollBackend after installing this — only ONE script
--  may set RequestRoll.OnServerInvoke.)
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

--==================================================
-- DATA SERVICE
--==================================================

local dataServiceModule = ServerScriptService:FindFirstChild("DataService", true)

assert(
	dataServiceModule and dataServiceModule:IsA("ModuleScript"),
	"DataService ModuleScript could not be found anywhere inside ServerScriptService"
)

local DataService = require(dataServiceModule)

--==================================================
-- DUPLICATE-INSTANCE GUARD
--==================================================

if _G.ChickenRollServiceActive then

	warn(
		"[ChickenRollService] ANOTHER COPY OF THIS SCRIPT IS ALREADY RUNNING. "
			.. "Find and delete the duplicate in ServerScriptService "
			.. "(check for ChickenRollBackend or a second ChickenRollService) "
			.. "— this instance is shutting down to prevent duplicated inventory."
	)

	return
end

_G.ChickenRollServiceActive = true

--==================================================
-- CONFIG / REMOTES
--==================================================

local config = require(
	ReplicatedStorage:WaitForChild("ChickenRollConfig")
)

local remotes = ReplicatedStorage:WaitForChild("ChickenRollRemotes")

local requestRoll = remotes:WaitForChild("RequestRoll")
local setRollMode = remotes:WaitForChild("SetRollMode")
local rollResultNotify = remotes:WaitForChild("RollResultNotify")

local sellChicken = remotes:WaitForChild("SellChicken")
local sellAll = remotes:WaitForChild("SellAll")
local equipChicken = remotes:WaitForChild("EquipChicken")

local chickenModels = Workspace:WaitForChild("Chicken")
local plotsFolder = Workspace:WaitForChild("Plots")


--==================================================
-- SELL PRICE (PLACEHOLDER)
--==================================================

local SELL_PRICE_MULTIPLIER = 1

local function parseChanceDenominator(chance)

	if type(chance) ~= "string" then
		return nil
	end

	local denominator =
		chance:match("1%s*in%s*([%d,]+)")
		or chance:match("1%s*/%s*([%d,]+)")

	if not denominator then
		return nil
	end

	return tonumber((denominator:gsub(",", "")))
end

local function getSellPrice(configEntry)

	local denominator = parseChanceDenominator(configEntry and configEntry.chance)

	if not denominator then
		return 0
	end

	return math.floor(denominator * SELL_PRICE_MULTIPLIER)
end


--==================================================
-- NEST UTILS (needed early for equipped-chicken protection
-- during inventory cap enforcement, see below)
--==================================================

local NestUtils = require(ServerScriptService:FindFirstChild("NestUtils", true))

--==================================================
-- CONFIG LOOKUP
--==================================================

local function findConfigEntry(chickenName)

	for _, chicken in ipairs(config.Chickens) do

		if chicken.name == chickenName then

			return chicken
		end
	end

	return nil
end


--==================================================
-- RESOLVE BASE CHICKEN NAME
--==================================================

local function resolveBaseChickenName(candidateName)

	if type(candidateName) ~= "string" then
		return candidateName
	end

	if findConfigEntry(candidateName) then
		return candidateName
	end

	local stripped = candidateName:match("^(.*%D)%d+$")

	if stripped and findConfigEntry(stripped) then
		return stripped
	end

	return candidateName
end


--==================================================
-- LUCK VALUES
--==================================================

local luckValues = {
	1,
	5,
	20,
	50,
	200,
	1000,
	5000,
	20000,
	100000,
	500000,

	2000000,
	10000000,
	50000000,
	200000000,
	1000000000,
	5000000000,
	20000000000,
	100000000000,
	500000000000,
}


--==================================================
-- LUCK TIER
--==================================================

local function getLuckTier(luck)

	for index, multiplier in ipairs(luckValues) do

		if multiplier == luck then
			return index
		end

	end

	return 1
end


--==================================================
-- GET EQUIPPED LUCK
--==================================================
-- THE FIX: previously this ONLY accepted a real Lua number and
-- silently fell back to 1x for anything else — including a
-- string like "20000" (which happens if the shop item's Luck
-- attribute was ever typed as String in Explorer instead of
-- Number). That fallback had ZERO error output, so it was
-- invisible. This is almost certainly why 20,000x Luck was
-- still rolling Chicken #1-5.
--
-- Now: it prints exactly what it read every single roll, and it
-- will still work correctly even if Luck got saved as a string.
--==================================================

local function getLuckMultiplier(player)

	local equipped = DataService:Get(player, { "Luck", "Equipped" })

	print(
		"[ChickenRollService] Raw Luck.Equipped for",
		player.Name,
		"=",
		equipped,
		"| type:",
		typeof(equipped)
	)

	if type(equipped) == "number" then
		return equipped
	end

	if type(equipped) == "string" then

		local cleaned = equipped:gsub(",", "")
		local numeric = tonumber(cleaned)

		if numeric then

			warn(
				"[ChickenRollService] Luck.Equipped was stored as a STRING ('"
					.. equipped
					.. "') instead of a number for "
					.. player.Name
					.. ". Using it anyway — but fix the 'Luck' attribute type on "
					.. "the shop item in Explorer (should be Number, not String)."
			)

			return numeric
		end
	end

	warn(
		"[ChickenRollService] No usable Luck.Equipped found for",
		player.Name,
		"- defaulting to 1x. (Have they purchased/equipped anything yet?)"
	)

	return 1
end


--==================================================
-- GET CHICKEN WINDOW
--==================================================

local function getChickenWindow(player)

	local luck = getLuckMultiplier(player)
	local luckTier = getLuckTier(luck)

	if luckTier == 1 then
		return 1, 5
	end

	if luckTier == 2 then
		return 3, 10
	end

	if luckTier == 3 then
		return 8, 14
	end

	local startIndex = 8 + ((luckTier - 3) * 3)
	local endIndex = 14 + ((luckTier - 3) * 3)

	return startIndex, endIndex
end


--==================================================
-- PICK RANDOM CHICKEN
--==================================================

local function pickRandomChicken(player)

	local startIndex, endIndex =
		getChickenWindow(player)

	startIndex = math.max(1, startIndex)
	endIndex = math.min(endIndex, #config.Chickens)

	if startIndex > #config.Chickens then

		warn("[ChickenRollService] Luck is beyond available chickens.")

		return config.Chickens[#config.Chickens], #config.Chickens
	end

	if endIndex < startIndex then

		warn(
			"[ChickenRollService] Invalid chicken window:",
			startIndex,
			endIndex
		)

		return config.Chickens[startIndex], startIndex
	end

	local chickenIndex = math.random(startIndex, endIndex)
	local chicken = config.Chickens[chickenIndex]

	print(
		"[ChickenRollService] ROLL WINDOW:",
		startIndex,
		"-",
		endIndex
	)

	print(
		"[ChickenRollService] ROLLED:",
		chicken.name,
		"| Chicken #",
		chickenIndex,
		"| Display Chance:",
		chicken.chance
	)

	return chicken, chickenIndex
end


--==================================================
-- UNIQUE CHICKEN NAME
--==================================================

local function getUniqueChickenName(chickenFolder, baseName)

	local name = baseName
	local number = 1

	while chickenFolder:FindFirstChild(name) do

		name = baseName .. tostring(number)
		number += 1
	end

	return name
end


--==================================================
-- CHICKEN FOLDER
--==================================================

local function getChickenFolder(player)

	local chickenFolder = player:FindFirstChild("Chickens")

	if not chickenFolder then

		chickenFolder = Instance.new("Folder")
		chickenFolder.Name = "Chickens"
		chickenFolder.Parent = player

		print(
			"[ChickenRollService] Created Chickens folder for:",
			player.Name
		)
	end

	return chickenFolder
end


--==================================================
-- PERSISTENCE (counts per base chicken name)
--==================================================

local playersAlreadyLoaded = {}

local function saveChickenCounts(player)

	local chickenFolder = getChickenFolder(player)
	local counts = {}

	for _, value in ipairs(chickenFolder:GetChildren()) do

		if value:IsA("IntValue") and value.Value > 0 then

			local baseName = resolveBaseChickenName(
				value:GetAttribute("ChickenName") or value.Name
			)

			counts[baseName] = (counts[baseName] or 0) + 1
		end
	end

	DataService:Set(player, "Chickens", counts)
end

local function loadChickenCounts(player)

	if playersAlreadyLoaded[player] then
		return
	end

	playersAlreadyLoaded[player] = true

	local deadline = os.clock() + 15

	while player.Parent == Players
		and not DataService:IsProfileLoaded(player)
		and os.clock() < deadline do

		task.wait(0.2)
	end

	if player.Parent ~= Players or not DataService:IsProfileLoaded(player) then
		return
	end

	local rawCounts = DataService:Get(player, "Chickens")

	if type(rawCounts) ~= "table" then
		return
	end

	local normalizedCounts = {}
	local healedAnything = false

	for baseName, count in pairs(rawCounts) do

		if type(count) == "number" then

			local resolvedName = resolveBaseChickenName(baseName)

			if resolvedName ~= baseName then
				healedAnything = true
			end

			normalizedCounts[resolvedName] =
				(normalizedCounts[resolvedName] or 0) + count
		end
	end

	local chickenFolder = getChickenFolder(player)

	for baseName, count in pairs(normalizedCounts) do

		for _ = 1, count do

			local uniqueName =
				getUniqueChickenName(chickenFolder, baseName)

			local chickenValue = Instance.new("IntValue")
			chickenValue.Name = uniqueName
			chickenValue.Value = 1
			chickenValue:SetAttribute("ChickenName", baseName)
			chickenValue.Parent = chickenFolder
		end
	end

	if healedAnything then

		saveChickenCounts(player)

		print(
			"[ChickenRollService] Healed corrupted chicken names for:",
			player.Name
		)
	end

	print(
		"[ChickenRollService] Loaded saved chickens for:",
		player.Name
	)
end


--==================================================
-- RARITY RANK LOOKUP
-- Built once from ChickenRollConfig's order (index 1 = weakest).
-- Used to find the "worst" chicken for inventory cap enforcement.
--==================================================

local chickenRankByName = {}

for index, chicken in ipairs(config.Chickens) do
	chickenRankByName[chicken.name] = index
end

--==================================================
-- INVENTORY CAP
-- Keeps saved data from growing unbounded over long AFK
-- sessions. Above MaxInventorySize, deletes the single worst
-- (lowest rarity rank) chicken — but NEVER one that's currently
-- equipped in a nest, since the player clearly wants that one.
--==================================================

local function getEquippedUniqueNames(player)

	local equipped = {}

	local plot = NestUtils.FindPlayerPlot(player)

	if not plot then
		return equipped
	end

	local display = plot:FindFirstChild("ChickenDisplay")

	if not display then
		return equipped
	end

	for _, model in ipairs(display:GetChildren()) do

		if model:IsA("Model") then

			local invName = model:GetAttribute("InventoryName")

			if invName then
				equipped[invName] = true
			end
		end
	end

	return equipped
end

--==================================================
-- UNEQUIP IF EQUIPPED
-- Used before selling a chicken, so selling an equipped chicken
-- can never leave an orphaned display model standing in a nest
-- with no backing inventory data. Safe to call on a chicken that
-- isn't equipped — it's just a no-op in that case.
--==================================================

local function unequipIfEquipped(player, chickenName)

	local plot = NestUtils.FindPlayerPlot(player)

	if not plot then
		return
	end

	local display = plot:FindFirstChild("ChickenDisplay")

	if not display then
		return
	end

	for _, model in ipairs(display:GetChildren()) do

		if model:IsA("Model") and model:GetAttribute("InventoryName") == chickenName then

			print(
				"[ChickenRollService] Auto-unequipping "
					.. chickenName
					.. " for "
					.. player.Name
					.. " before selling it."
			)

			model:Destroy()
			return
		end
	end
end

--==================================================
-- FIND WORST NON-EQUIPPED CHICKEN
-- Returns the IntValue with the lowest rarity rank among owned,
-- non-equipped chickens, and that rank. Equipped chickens are
-- never returned — they are never eligible for deletion.
--==================================================

local function findWorstNonEquipped(owned, equippedNames)

	local worstValue = nil
	local worstRank = math.huge

	for _, value in ipairs(owned) do

		if not equippedNames[value.Name] then

			local baseName = resolveBaseChickenName(
				value:GetAttribute("ChickenName") or value.Name
			)

			local rank = chickenRankByName[baseName] or math.huge

			if rank < worstRank then
				worstRank = rank
				worstValue = value
			end
		end
	end

	return worstValue, worstRank
end

--==================================================
-- TRY ADD CHICKEN TO INVENTORY
-- This is the core of the 30-chicken cap behavior:
--
--   - Below the cap: always add normally.
--   - At/above the cap: only add if the new chicken is STRICTLY
--     better (higher rarity rank) than the worst non-equipped
--     chicken currently owned. If so, delete that worst one and
--     add the new one. If the new chicken is worse than or equal
--     to the worst non-equipped chicken, it is discarded — not
--     added, nothing deleted.
--   - Equipped chickens are NEVER counted as "worst" and NEVER
--     deleted, no matter what.
--   - If every owned chicken is currently equipped (no eligible
--     chicken to replace), the new roll is discarded, since
--     there is nothing safe to remove to make room.
--
-- Returns: added (bool), uniqueName (string, only if added),
--          replacedName (string or nil, the chicken that got
--          removed to make room, if any)
--==================================================

local function tryAddChickenToInventory(player, wonChicken, chickenIndex)

	local chickenFolder = getChickenFolder(player)
	local maxSize = config.MaxInventorySize

	local owned = {}

	for _, value in ipairs(chickenFolder:GetChildren()) do

		if value:IsA("IntValue") and value.Value > 0 then
			table.insert(owned, value)
		end
	end

	local replacedName = nil

	if type(maxSize) == "number" and #owned >= maxSize then

		local equippedNames = getEquippedUniqueNames(player)
		local worstValue, worstRank = findWorstNonEquipped(owned, equippedNames)

		if not worstValue then

			warn(
				"[ChickenRollService] "
					.. player.Name
					.. " is at the inventory cap ("
					.. #owned
					.. "/"
					.. maxSize
					.. ") and every owned chicken is equipped — new roll ("
					.. wonChicken.name
					.. ") discarded, nothing to replace."
			)

			return false, nil, nil
		end

		local newRank = chickenRankByName[wonChicken.name] or 0

		if newRank <= worstRank then

			print(
				"[ChickenRollService] "
					.. player.Name
					.. " rolled "
					.. wonChicken.name
					.. " but it's not better than the worst kept chicken ("
					.. worstValue.Name
					.. ") — discarded, inventory stays at "
					.. #owned
					.. "/"
					.. maxSize
			)

			return false, nil, nil
		end

		print(
			"[ChickenRollService] "
				.. player.Name
				.. " rolled "
				.. wonChicken.name
				.. " which beats worst kept chicken ("
				.. worstValue.Name
				.. ") — replacing it."
		)

		replacedName = worstValue.Name
		worstValue:Destroy()
	end

	local uniqueName = getUniqueChickenName(chickenFolder, wonChicken.name)

	local chickenValue = Instance.new("IntValue")
	chickenValue.Name = uniqueName
	chickenValue.Value = 1

	chickenValue:SetAttribute("ChickenName", wonChicken.name)
	chickenValue:SetAttribute("ChickenIndex", chickenIndex)
	chickenValue:SetAttribute("DisplayedChance", wonChicken.chance)

	chickenValue.Parent = chickenFolder

	saveChickenCounts(player)

	return true, uniqueName, replacedName
end


--==================================================
-- ROLL
--==================================================

local playerRollCooldowns = {}

requestRoll.OnServerInvoke = function(player)

	local now = os.clock()
	local lastRoll = playerRollCooldowns[player] or 0

	local isFast = player:GetAttribute("FastRollEnabled") == true
	local minCooldown = isFast and 0.5 or 1.2

	if now - lastRoll < minCooldown then
		return nil, "Rolling too fast"
	end

	playerRollCooldowns[player] = now


	local wonChicken, chickenIndex = pickRandomChicken(player)

	if not wonChicken then
		return nil, "No chicken available"
	end


	--==================================================
	-- LEADERSTATS
	--==================================================

	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then

		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local rollsStat = leaderstats:FindFirstChild("Rolls")

	if not rollsStat then

		rollsStat = Instance.new("IntValue")
		rollsStat.Name = "Rolls"
		rollsStat.Value = 0
		rollsStat.Parent = leaderstats
	end

	rollsStat.Value += 1


	--==================================================
	-- ADD TO INVENTORY
	-- (may be discarded entirely if inventory is full and this
	-- roll isn't better than the worst non-equipped chicken —
	-- see tryAddChickenToInventory above)
	--==================================================

	local added, uniqueName, replacedName = tryAddChickenToInventory(player, wonChicken, chickenIndex)

	if added then

		print(
			"[ChickenRollService] "
				.. player.Name
				.. " obtained "
				.. uniqueName
				.. " | Chicken #"
				.. chickenIndex
				.. " | Display Chance: "
				.. wonChicken.chance
				.. (replacedName and (" | Replaced: " .. replacedName) or "")
		)
	end


	--==================================================
	-- NOTIFY CLIENT
	-- The roll animation/result always shows what was rolled,
	-- regardless of whether it was actually kept — matches how
	-- most gacha games handle "auto-discarded" pulls. `kept` lets
	-- the client optionally show something different for a
	-- discarded roll if it wants to.
	--==================================================

	local result = {
		name = wonChicken.name,
		chance = wonChicken.chance,
		kept = added,
		RollDuration = isFast
			and (config.RollSpeed and config.RollSpeed.Fast or 0.8)
			or (config.RollSpeed and config.RollSpeed.Normal or 3.2),
	}

	rollResultNotify:FireClient(player, result, rollsStat.Value)

	return result, chickenIndex
end


--==================================================
-- SELL ONE
--==================================================

sellChicken.OnServerInvoke = function(player, chickenName)

	if type(chickenName) ~= "string" then
		return false, "Invalid chicken"
	end

	local chickenFolder = player:FindFirstChild("Chickens")

	if not chickenFolder then
		return false, "You don't own this chicken"
	end

	local chickenValue = chickenFolder:FindFirstChild(chickenName)

	if not chickenValue
		or not chickenValue:IsA("IntValue")
		or chickenValue.Value <= 0 then

		return false, "You don't own this chicken"
	end

	local actualChickenName = resolveBaseChickenName(
		chickenValue:GetAttribute("ChickenName") or chickenValue.Name
	)

	local configEntry = findConfigEntry(actualChickenName)

	if not configEntry then
		return false, "Unknown chicken"
	end

	local sellPrice = getSellPrice(configEntry)

	unequipIfEquipped(player, chickenName)

	chickenValue:Destroy()
	saveChickenCounts(player)

	local leaderstats = player:FindFirstChild("leaderstats")

	local coins =
		leaderstats
		and (
			leaderstats:FindFirstChild("Coins")
			or leaderstats:FindFirstChild("Cash")
		)

	if not coins then

		leaderstats = leaderstats or Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = 0
		coins.Parent = leaderstats
	end

	coins.Value += sellPrice

	return true, sellPrice
end


--==================================================
-- SELL ALL
--==================================================

sellAll.OnServerInvoke = function(player)

	local chickenFolder = player:FindFirstChild("Chickens")

	if not chickenFolder then
		return false, 0, 0
	end

	local leaderstats = player:FindFirstChild("leaderstats")

	local coins =
		leaderstats
		and (
			leaderstats:FindFirstChild("Coins")
			or leaderstats:FindFirstChild("Cash")
		)

	if not coins then

		leaderstats = leaderstats or Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = 0
		coins.Parent = leaderstats
	end

	local total = 0
	local sold = 0
	local skippedEquipped = 0

	local equippedNames = getEquippedUniqueNames(player)

	for _, chickenValue in ipairs(chickenFolder:GetChildren()) do

		if chickenValue:IsA("IntValue") and chickenValue.Value > 0 then

			if equippedNames[chickenValue.Name] then

				-- Sell All intentionally skips equipped chickens —
				-- a bulk "clean up my junk" action shouldn't also
				-- sell away chickens you deliberately placed and
				-- possibly leveled up. Use single Sell for that.
				skippedEquipped += 1

			else

				local actualChickenName = resolveBaseChickenName(
					chickenValue:GetAttribute("ChickenName") or chickenValue.Name
				)

				local configEntry = findConfigEntry(actualChickenName)

				if configEntry then

					total += getSellPrice(configEntry)
					sold += 1

					chickenValue:Destroy()
				end
			end
		end
	end

	if skippedEquipped > 0 then

		print(
			"[ChickenRollService] Sell All for "
				.. player.Name
				.. " skipped "
				.. skippedEquipped
				.. " equipped chicken(s)."
		)
	end

	coins.Value += total
	saveChickenCounts(player)

	return true, total, sold
end


--==================================================
-- ROLL MODES
--==================================================

setRollMode.OnServerEvent:Connect(function(player, modeType, state)

	if modeType == "AutoRoll" then

		player:SetAttribute("AutoRollEnabled", state == true)

	elseif modeType == "FastRoll" then

		player:SetAttribute("FastRollEnabled", state == true)
	end
end)


--==================================================
-- EQUIP SYSTEM
-- (Nest/plot detection now lives in NestUtils, shared with
-- ChickenLevelServer, so both always agree on which nest is
-- which. Required near the top of this file now.)
--==================================================

local function getNestSlots(plot)
	return NestUtils.GetNestSlots(plot)
end

local function findPlayerPlot(player)
	return NestUtils.FindPlayerPlot(player)
end

local function getDisplayFolder(plot)
	return NestUtils.GetDisplayFolder(plot)
end


--==================================================
-- RESOLVE MODEL (with fallback since ChickenRollConfig
-- has no modelName field yet)
--==================================================

local function resolveChickenModel(configEntry, actualChickenName)

	local candidateName = configEntry.modelName or actualChickenName

	local model = chickenModels:FindFirstChild(candidateName)

	if model then
		return model
	end

	-- FUZZY FALLBACK: case-insensitive / whitespace-insensitive match.
	-- This exists because chicken names have already drifted between
	-- systems in this game multiple times (casing, spacing). Rather
	-- than fail outright, try to find the closest real match first.

	local normalizedTarget = candidateName:lower():gsub("%s+", "")

	for _, child in ipairs(chickenModels:GetChildren()) do

		local normalizedChild = child.Name:lower():gsub("%s+", "")

		if normalizedChild == normalizedTarget then

			warn(
				"[ChickenRollService] Matched '"
					.. candidateName
					.. "' to existing model '"
					.. child.Name
					.. "' via fuzzy match (different casing/spacing). "
					.. "Consider renaming for consistency."
			)

			return child
		end
	end

	-- SELF-DIAGNOSING FAILURE: list what's actually there, so this is
	-- debuggable directly from the Output window without needing to
	-- ask anyone what's inside Workspace.Chicken.

	local availableNames = {}

	for _, child in ipairs(chickenModels:GetChildren()) do
		table.insert(availableNames, child.Name)
	end

	warn(
		"[ChickenRollService] No model found for '"
			.. tostring(candidateName)
			.. "'. Add a 'modelName' field to ChickenRollConfig for this chicken, "
			.. "or make sure a model with this exact name exists under Workspace.Chicken. "
			.. "Models currently found in Workspace.Chicken ("
			.. #availableNames
			.. "): "
			.. table.concat(availableNames, ", ")
	)

	return nil
end


equipChicken.OnServerInvoke = function(player, chickenName)

	if type(chickenName) ~= "string" then
		return false, "Invalid chicken"
	end

	local chickenFolder = player:FindFirstChild("Chickens")

	if not chickenFolder then
		return false, "You don't own this chicken"
	end

	local chickenValue = chickenFolder:FindFirstChild(chickenName)

	if not chickenValue
		or not chickenValue:IsA("IntValue")
		or chickenValue.Value <= 0 then

		return false, "You don't own this chicken"
	end

	local actualChickenName = resolveBaseChickenName(
		chickenValue:GetAttribute("ChickenName") or chickenValue.Name
	)

	local configEntry = findConfigEntry(actualChickenName)

	if not configEntry then
		return false, "Unknown chicken"
	end

	local plot = findPlayerPlot(player)

	if not plot then
		return false, "You don't have a plot"
	end

	local display = getDisplayFolder(plot)
	local nestSlots = getNestSlots(plot)

	--==================================================
	-- UNEQUIP
	--==================================================

	for _, model in ipairs(display:GetChildren()) do

		if model:IsA("Model")
			and model:GetAttribute("InventoryName") == chickenName then

			model:Destroy()
			chickenValue:SetAttribute("Equipped", false)
			return true, "unequipped"
		end
	end

	--==================================================
	-- FIND FREE SLOT
	--==================================================

	local occupied = {}

	for _, model in ipairs(display:GetChildren()) do

		if model:IsA("Model") then

			local nestIndex = model:GetAttribute("NestIndex")

			if nestIndex then
				occupied[nestIndex] = true
			end
		end
	end

	local slotIndex

	for i = 1, #nestSlots do

		if not occupied[i] then
			slotIndex = i
			break
		end
	end

	if not slotIndex then
		return false, "All nests are full (" .. #nestSlots .. ")"
	end

	--==================================================
	-- FIND MODEL (with fallback)
	--==================================================

	local sourceModel = resolveChickenModel(configEntry, actualChickenName)

	if not sourceModel then
		return false, "Missing model for: " .. tostring(actualChickenName)
	end

	--==================================================
	-- CLONE + PLACE
	--==================================================

	local model = sourceModel:Clone()

	model.Name = chickenName .. "_" .. player.Name .. "_" .. tostring(os.clock())

	model:SetAttribute("ChickenName", actualChickenName)
	model:SetAttribute("InventoryName", chickenName)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("NestIndex", slotIndex)

	for _, part in ipairs(model:GetDescendants()) do

		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	local slotCf = nestSlots[slotIndex].cf
	local halfHeight = model:GetExtentsSize().Y * 0.5
	local rearOffset = slotCf.LookVector * -1.2

	model:PivotTo(
		(slotCf + rearOffset) + Vector3.new(0, halfHeight + 0.1, 0)
	)

	model.Parent = display

	chickenValue:SetAttribute("Equipped", true)

	return true, "equipped"
end


--==================================================
-- PLAYER LIFECYCLE
--==================================================

Players.PlayerAdded:Connect(function(player)

	getChickenFolder(player)
	task.spawn(loadChickenCounts, player)

	print("[ChickenRollService] Inventory ready for:", player.Name)
end)

for _, player in ipairs(Players:GetPlayers()) do

	getChickenFolder(player)
	task.spawn(loadChickenCounts, player)
end

Players.PlayerRemoving:Connect(function(player)

	saveChickenCounts(player)
	playerRollCooldowns[player] = nil
	playersAlreadyLoaded[player] = nil
end)


--==================================================
-- START
--==================================================

print("==================================================")
print("[ChickenRollService] READY")
print("==================================================")