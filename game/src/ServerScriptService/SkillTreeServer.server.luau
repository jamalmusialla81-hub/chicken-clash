local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local config = require(ReplicatedStorage:WaitForChild("SkillTreeConfig"))
local remotes = ReplicatedStorage:WaitForChild("SkillTreeRemotes")
local requestState = remotes:WaitForChild("RequestState")
local purchaseSkill = remotes:WaitForChild("PurchaseSkill")
local stateUpdate = remotes:WaitForChild("StateUpdate")
local skillStore = DataStoreService:GetDataStore("SkillTreeProgression_v1")

local nodeById = {}
for _, node in ipairs(config.Nodes) do
	nodeById[node.id] = node
end

local ownedByPlayer = {}
local loadingByPlayer = {}
local currencySyncing = {}

local function getCurrency(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local cash = leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Coins")
	if not cash then
		cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = config.DefaultCash
		cash.Parent = leaderstats
	end
	if cash.Name == "Coins" then
		local alias = leaderstats:FindFirstChild("Cash")
		if not alias then
			alias = Instance.new("IntValue")
			alias.Name = "Cash"
			alias.Value = cash.Value
			alias.Parent = leaderstats
		end
		if not currencySyncing[player] then
			currencySyncing[player] = true
			cash:GetPropertyChangedSignal("Value"):Connect(function() if alias.Value ~= cash.Value then alias.Value = cash.Value end end)
			alias:GetPropertyChangedSignal("Value"):Connect(function() if cash.Value ~= alias.Value then cash.Value = alias.Value end end)
			currencySyncing[player] = nil
		end
		cash = alias
	end
	return cash
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
	stateUpdate:FireClient(player, copyOwned(ownedByPlayer[player]), message, success, getCurrency(player).Value)
end

local function loadPlayer(player)
	loadingByPlayer[player] = true
	local owned = {}
	local success, data = pcall(function()
		return skillStore:GetAsync("Player_" .. player.UserId)
	end)
	if success and type(data) == "table" then
		owned = copyOwned(data.owned)
	elseif not success then
		warn("[SkillTreeServer] Could not load data for " .. player.Name)
	end
	ownedByPlayer[player] = owned
	loadingByPlayer[player] = nil
	sendState(player, "", true)
end

local function savePlayer(player)
	local owned = ownedByPlayer[player]
	if not owned then return end
	local success, err = pcall(function()
		skillStore:UpdateAsync("Player_" .. player.UserId, function()
			return { owned = copyOwned(owned) }
		end)
	end)
	if not success then
		warn("[SkillTreeServer] Could not save data for " .. player.Name .. ": " .. tostring(err))
	end
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
	local cash = getCurrency(player)
	if cash.Value < node.cost then return false, "You need " .. tostring(node.cost) .. " Cash." end
	return true, node, cash
end

Players.PlayerAdded:Connect(function(player)
	getCurrency(player)
	task.spawn(loadPlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	ownedByPlayer[player] = nil
	loadingByPlayer[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end
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
	cash.Value -= nodeOrMessage.cost
	ownedByPlayer[player][nodeOrMessage.id] = true
	sendState(player, "Unlocked " .. nodeOrMessage.title .. "!", true)
	task.spawn(savePlayer, player)
end)
