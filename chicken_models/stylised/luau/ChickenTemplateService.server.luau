--[[ ChickenTemplateService (server, Script). Phase 6 bootstrap: runs RigCompatibilityValidator once per
	non-master ChickenDefinitions entry against the verified Golden Chicken rig, and writes the real result
	back into the shared registry via ChickenDefinitions.SetValidationResult. A plain Script (not a
	ModuleScript some other file must remember to require) so this always runs at server start alongside
	ArenaQueuePrompt/TrainingDojoPrompt/ChickenCombatInputHandler, before any player can queue or enter
	practice and ask a definition whether it is combat-compatible. ]]

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RigCompatibilityValidator = require(script.Parent:WaitForChild("RigCompatibilityValidator"))
local ChickenDefinitions = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenDefinitions"))

local masterDef = ChickenDefinitions.Get(ChickenDefinitions.DefaultId)
local masterModel = masterDef and ServerStorage.CombatChickens:FindFirstChild(masterDef.CombatModelName)

for id, def in pairs(ChickenDefinitions.List) do
	if def.IsMasterTemplate then
		continue
	end
	local candidateModel = ServerStorage.CombatChickens:FindFirstChild(def.CombatModelName)
	if not candidateModel or not masterModel then
		ChickenDefinitions.SetValidationResult(id, false, "Combat model or master template not found in ServerStorage.CombatChickens")
		continue
	end
	local compatible, reasons = RigCompatibilityValidator.Validate(candidateModel, masterModel)
	local reasonText = #reasons > 0 and table.concat(reasons, "; ") or nil
	ChickenDefinitions.SetValidationResult(id, compatible, reasonText, compatible and "validated-shares-golden-anims" or "unrigged")
	if not compatible then
		warn(string.format("[ChickenTemplateService] %s is NOT combat-compatible: %s", def.DisplayName, reasonText or "unknown"))
	end
end

-- Client-safe replication of validation results (see ChickenDefinitions' own header comment: the client
-- must never read CombatCompatible off the module directly, since ServerStorage rigs never replicate).
-- Validation above is a one-time bootstrap that finishes before any player can join and ask, so a plain
-- RemoteFunction returning a snapshot is sufficient - no need to push updates after the fact.
local combatFolder = ReplicatedStorage:FindFirstChild("Combat") or Instance.new("Folder")
combatFolder.Name = "Combat"
combatFolder.Parent = ReplicatedStorage

local rosterFunction = combatFolder:FindFirstChild("GetChickenRoster")
if not rosterFunction then
	rosterFunction = Instance.new("RemoteFunction")
	rosterFunction.Name = "GetChickenRoster"
	rosterFunction.Parent = combatFolder
end

local roster = {}
for id, def in pairs(ChickenDefinitions.List) do
	table.insert(roster, {
		Id = id,
		DisplayName = def.DisplayName,
		CombatCompatible = def.CombatCompatible == true,
		CombatUnavailableReason = def.CombatCompatible ~= true and (def.CombatUnavailableReason or "Not combat-ready") or nil,
	})
end
rosterFunction.OnServerInvoke = function()
	return roster
end
