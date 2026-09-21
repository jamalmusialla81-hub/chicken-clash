--==================================================
-- CHICKEN LEVEL SERVICE
-- Pure logic for chicken leveling: no remotes, no UI, just
-- data. ChickenLevelServer (the Script) wires this up to the
-- actual ClickDetector/SurfaceGui.
--
-- LEVEL IS PER INDIVIDUAL CHICKEN, not per chicken type — keyed
-- by the same unique inventory name ChickenRollService already
-- gives each owned chicken (e.g. "Black Chicken2"). This matches
-- the earlier decision that leveling should NOT be shared across
-- every chicken of the same type.
--
-- Saved at: DataService -> player -> "ChickenLevels" -> {[uniqueName] = level}
-- This is a NEW, separate data path — does not touch or restructure
-- the existing "Chickens" count-based inventory save at all.
--==================================================

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ServerScriptService:FindFirstChild("DataService", true))
local ChickenLevelConfig = require(ReplicatedStorage:WaitForChild("ChickenLevelConfig"))
local ChickenEggConfig = require(ReplicatedStorage:WaitForChild("ChickenEggConfig"))

local ChickenLevelService = {}

--==================================================
-- CASE-INSENSITIVE EGG PRICE LOOKUP
-- ChickenEggConfig uses lowercase "chicken" (e.g. "Black chicken")
-- while the rest of the game uses "Black Chicken". Rather than
-- force either side to change (we already tried that and reverted
-- it), this just resolves the mismatch at lookup time.
--==================================================

local lowercaseEggLookup = {}

for eggName, eggData in pairs(ChickenEggConfig) do
	lowercaseEggLookup[eggName:lower()] = eggData
end

local function getBaseEggPrice(chickenName)

	if type(chickenName) ~= "string" then
		return 0
	end

	local eggData = lowercaseEggLookup[chickenName:lower()]

	if eggData and type(eggData.price) == "number" then
		return eggData.price
	end

	return 0
end

--==================================================
-- LEVEL READ / WRITE
--==================================================

function ChickenLevelService.GetLevel(player, uniqueChickenName)

	if not player or type(uniqueChickenName) ~= "string" then
		return 1
	end

	local level = DataService:Get(player, { "ChickenLevels", uniqueChickenName })

	if type(level) == "number" and level >= 1 then
		return math.floor(level)
	end

	return 1
end

local function setLevel(player, uniqueChickenName, level)
	DataService:Set(player, { "ChickenLevels", uniqueChickenName }, level)
end

--==================================================
-- COST / VALUE FORMULAS
--==================================================

function ChickenLevelService.GetUpgradeCost(level)

	level = math.max(level or 1, 1)

	local cost = ChickenLevelConfig.BaseUpgradeCost
		* (ChickenLevelConfig.UpgradeCostGrowth ^ (level - 1))

	return math.floor(cost)
end

function ChickenLevelService.GetEggValue(chickenName, level)

	level = math.max(level or 1, 1)

	local basePrice = getBaseEggPrice(chickenName)

	-- Compounding growth (the "real" curve at higher levels)...
	local compoundedValue = basePrice * (ChickenLevelConfig.EggValueGrowth ^ (level - 1))

	-- ...but never less than a flat +$1/level floor, so cheap
	-- chickens (e.g. a $1 Brown Chicken) always visibly grow every
	-- single level instead of rounding down to the same number for
	-- several levels in a row before compounding catches up.
	local flatFloor = basePrice + (level - 1)

	local value = math.max(compoundedValue, flatFloor)

	return math.floor(value)
end

--==================================================
-- TRY UPGRADE
-- Returns: success (bool), newLevel or reason (string on fail),
--          newUpgradeCost (for the NEXT level), newEggValue
--==================================================

function ChickenLevelService.TryUpgrade(player, uniqueChickenName, chickenName)

	if not player or type(uniqueChickenName) ~= "string" then
		return false, "Invalid request"
	end

	-- Ownership check: the chicken must still actually be owned.
	local chickenFolder = player:FindFirstChild("Chickens")
	local chickenValue = chickenFolder and chickenFolder:FindFirstChild(uniqueChickenName)

	if not chickenValue or not chickenValue:IsA("IntValue") or chickenValue.Value <= 0 then
		return false, "You don't own this chicken"
	end

	local currentLevel = ChickenLevelService.GetLevel(player, uniqueChickenName)
	local cost = ChickenLevelService.GetUpgradeCost(currentLevel)

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")

	if not cash then
		return false, "Cash stat missing"
	end

	if cash.Value < cost then
		return false, "Not enough cash"
	end

	cash.Value -= cost

	local newLevel = currentLevel + 1
	setLevel(player, uniqueChickenName, newLevel)

	local newCost = ChickenLevelService.GetUpgradeCost(newLevel)
	local newEggValue = ChickenLevelService.GetEggValue(chickenName, newLevel)

	return true, newLevel, newCost, newEggValue
end

return ChickenLevelService