--==================================================
-- CHICKEN CONTENT AUDIT
-- Run-once diagnostic. Checks your full 50-chicken list against:
--   1. Workspace.Chicken (equip models)
--   2. ChickenEggConfig (egg prices)
--   3. ChickenRollConfig's icon field (roll animation art)
--
-- Prints a clean report to the server Output. Doesn't change
-- anything — pure read-only diagnostic. Safe to leave in the
-- game permanently (it's cheap, runs once), or delete once
-- everything's filled in.
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ChickenRollConfig = require(ReplicatedStorage:WaitForChild("ChickenRollConfig"))
local ChickenEggConfig = require(ReplicatedStorage:WaitForChild("ChickenEggConfig"))

local chickenModels = Workspace:WaitForChild("Chicken")

task.wait(5)

--==================================================
-- HELPERS
--==================================================

local function normalize(name)
	return name:lower():gsub("%s+", "")
end

local function findModelFuzzy(name)

	local exact = chickenModels:FindFirstChild(name)

	if exact then
		return exact, "exact"
	end

	local normalizedTarget = normalize(name)

	for _, child in ipairs(chickenModels:GetChildren()) do
		if normalize(child.Name) == normalizedTarget then
			return child, "fuzzy (" .. child.Name .. ")"
		end
	end

	return nil, nil
end

local lowercaseEggLookup = {}

for eggName in pairs(ChickenEggConfig) do
	lowercaseEggLookup[eggName:lower()] = true
end

local function hasEggConfig(name)
	return lowercaseEggLookup[name:lower()] == true
end

local function hasIcon(chicken)
	return type(chicken.icon) == "string" and chicken.icon ~= "" and chicken.icon ~= "rbxassetid://0"
end

--==================================================
-- RUN AUDIT
--==================================================

local missingModels = {}
local fuzzyModels = {}
local missingEggConfig = {}
local missingIcons = {}

for index, chicken in ipairs(ChickenRollConfig.Chickens) do

	local model, matchType = findModelFuzzy(chicken.name)

	if not model then
		table.insert(missingModels, string.format("#%d %s", index, chicken.name))
	elseif matchType ~= "exact" then
		table.insert(fuzzyModels, string.format("#%d %s -> matched %s", index, chicken.name, matchType))
	end

	if not hasEggConfig(chicken.name) then
		table.insert(missingEggConfig, string.format("#%d %s", index, chicken.name))
	end

	if not hasIcon(chicken) then
		table.insert(missingIcons, string.format("#%d %s", index, chicken.name))
	end
end

--==================================================
-- PRINT REPORT
--==================================================

local function printSection(title, list, emptyMessage)

	print("--------------------------------------------------")
	print(title .. " (" .. #list .. ")")
	print("--------------------------------------------------")

	if #list == 0 then
		print(emptyMessage)
	else
		for _, line in ipairs(list) do
			print("  " .. line)
		end
	end
end

print("==================================================")
print("[ChickenContentAudit] Checking " .. #ChickenRollConfig.Chickens .. " chickens...")
print("==================================================")

printSection(
	"MISSING MODELS (Workspace.Chicken) — equipping these will fail",
	missingModels,
	"None — every chicken has a model."
)

printSection(
	"FUZZY-MATCHED MODELS — working, but name mismatch worth cleaning up",
	fuzzyModels,
	"None — every model name matches exactly."
)

printSection(
	"MISSING EGG CONFIG (ChickenEggConfig) — will never lay a valued egg",
	missingEggConfig,
	"None — every chicken has an egg price."
)

printSection(
	"MISSING ICONS (ChickenRollConfig icon field) — reel will show blank art",
	missingIcons,
	"None — every chicken has an icon set."
)

print("==================================================")
print("[ChickenContentAudit] Done.")
print("==================================================")