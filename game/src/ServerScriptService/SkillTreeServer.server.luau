local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local DataService = require(ServerScriptService.Services.DataService)
local GlobalSignals = require(ServerScriptService.Utils.GlobalSignals)

local config = require(ReplicatedStorage:WaitForChild("SkillTreeConfig"))
local remotes = ReplicatedStorage:WaitForChild("SkillTreeRemotes")
local requestState = remotes:WaitForChild("RequestState")
local purchaseSkill = remotes:WaitForChild("PurchaseSkill")
local stateUpdate = remotes:WaitForChild("StateUpdate")

-- Progression now lives in the player's DataService profile (Data.SkillTree.Owned) and
-- cash is the single leaderstats.Cash owned by LeaderstatsService. This old store is only
-- READ, once per player, to copy previous progression across. It is never written or deleted.
local legacySkillStore = DataStoreService:GetDataStore("SkillTreeProgression_v1")

local nodeById = {}
for _, node in ipairs(config.Nodes) do
	nodeById[node.id] = node
end

-- player -> the profile's own SkillTree.Owned table, so changes are saved with the profile
local ownedByPlayer = {}
local loadingByPlayer = {}

local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Cash")
end

local function copyOwned(owned)
	local result = {}
	for id, value in pairs(owned or {}) do
		if value == true and nodeById[id] then
			result[id] = true
		end
	end
	return result
end

local function sendState(player, message, success)
	local cash = getCash(player)
	stateUpdate:FireClient(player, copyOwned(ownedByPlayer[player]), message, success, cash and cash.Value or 0)
end

local function loadPlayer(player, profileData)
	if ownedByPlayer[player] or loadingByPlayer[player] then return end
	loadingByPlayer[player] = true

	local skillTree = profileData.SkillTree
	if type(skillTree) ~= "table" then
		skillTree = { Owned = {}, Migrated = false }
		profileData.SkillTree = skillTree
	end
	if type(skillTree.Owned) ~= "table" then
		skillTree.Owned = {}
	end

	if not skillTree.Migrated then
		local success, data = pcall(function()
			return legacySkillStore:GetAsync("Player_" .. player.UserId)
		end)
		if success then
			if type(data) == "table" then
				for id in pairs(copyOwned(data.owned)) do
					skillTree.Owned[id] = true
				end
			end
			skillTree.Migrated = true
		else
			-- Leave Migrated false so it is retried next time (e.g. Studio without API access).
			warn("[SkillTreeServer] Could not read legacy skill data for " .. player.Name)
		end
	end

	if player.Parent ~= Players then
		loadingByPlayer[player] = nil
		return
	end
	ownedByPlayer[player] = skillTree.Owned
	loadingByPlayer[player] = nil
	sendState(player, "", true)
end

local function canPurchase(player, id)
	if loadingByPlayer[player] then return false, "Your skill data is still loading." end
	if typeof(id) ~= "string" then return false, "Invalid skill." end
	local node = nodeById[id]
	local owned = ownedByPlayer[player]
	if not node or not owned then return false, "Skill data is not ready." end
	if node.isMystery then return false, "This skill is still undiscovered." end
	if owned[id] then return false, "You already own this skill." end
	if node.prerequisite and not owned[node.prerequisite] then return false, "Unlock the previous skill first." end
	if not node.prerequisite and not node.entryPoint then return false, "This skill has no available entry path." end
	local cash = getCash(player)
	if not cash then return false, "Your data is still loading." end
	if cash.Value < node.cost then return false, "You need " .. tostring(node.cost) .. " Cash." end
	return true, node, cash
end

GlobalSignals.DataService.PlayerProfileLoaded:Connect(function(player, profileData)
	task.spawn(loadPlayer, player, profileData)
end)

-- Cover a profile that finished loading before this script connected.
for _, player in ipairs(Players:GetPlayers()) do
	if DataService:IsProfileLoaded(player) then
		task.spawn(loadPlayer, player, DataService:GetData(player))
	end
end

Players.PlayerRemoving:Connect(function(player)
	ownedByPlayer[player] = nil
	loadingByPlayer[player] = nil
end)

requestState.OnServerEvent:Connect(function(player)
	if ownedByPlayer[player] then sendState(player, "", true) end
end)

purchaseSkill.OnServerEvent:Connect(function(player, id)
	local allowed, nodeOrMessage, cash = canPurchase(player, id)
	if not allowed then
		sendState(player, nodeOrMessage, false)
		return
	end
	DataService:Increment(player, "Cash", -nodeOrMessage.cost)
	ownedByPlayer[player][nodeOrMessage.id] = true
	sendState(player, "Unlocked " .. nodeOrMessage.title .. "!", true)
end)
