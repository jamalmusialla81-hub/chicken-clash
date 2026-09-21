local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ChickenRollConfig = require(ReplicatedStorage:WaitForChild("ChickenRollConfig"))
local DataService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("DataService"))
local remotes = ReplicatedStorage:WaitForChild("ChickenRollRemotes")
local requestRoll = remotes:WaitForChild("RequestRoll")
local setRollMode = remotes:WaitForChild("SetRollMode")
local rollResultNotify = remotes:WaitForChild("RollResultNotify")

local random = Random.new()
local playerState = {}
local baseCooldown = 0.75

local function parseChance(chance)
	if type(chance) ~= "string" then
		return nil
	end
	local denominator = chance:match("1%s*in%s*([%d,]+)") or chance:match("1%s*/%s*([%d,]+)")
	if not denominator then
		return nil
	end
	return tonumber((denominator:gsub(",", "")))
end

local function chooseChicken(player)
	local entries = {}
	local totalWeight = 0

	for _, chicken in ipairs(ChickenRollConfig.Chickens) do
		local denominator = parseChance(chicken.chance)
		if denominator and denominator > 0 then
			local weight = 1 / denominator
			totalWeight += weight
			entries[#entries + 1] = {chicken = chicken, weight = weight}
		end
	end

	if totalWeight <= 0 then
		return nil
	end

	local target = random:NextNumber(0, totalWeight)
	local accumulated = 0
	for _, entry in ipairs(entries) do
		accumulated += entry.weight
		if target <= accumulated then
			return entry.chicken
		end
	end
	return entries[#entries].chicken
end

local function getOrCreateInventory(player)
	local inventory = player:FindFirstChild("Chickens")
	if inventory then
		return inventory
	end
	inventory = Instance.new("Folder")
	inventory.Name = "Chickens"
	inventory.Parent = player
	return inventory
end

local function syncInventory(player, savedInventory)
	local inventory = getOrCreateInventory(player)
	for name, owned in pairs(savedInventory) do
		if owned == true or (type(owned) == "number" and owned > 0) then
			local value = inventory:FindFirstChild(name)
			if not value then
				value = Instance.new("IntValue")
				value.Name = name
				value.Parent = inventory
			end
			value.Value = 1
		end
	end
end

local function saveInventory(player, inventory)
	local saved = {}
	for _, child in ipairs(inventory:GetChildren()) do
		if child:IsA("IntValue") and child.Value > 0 then
			saved[child.Name] = 1
		end
	end
	DataService:Set(player, "Chickens", saved)
end

local function addChicken(player, chicken)
	local inventory = getOrCreateInventory(player)
	local owned = inventory:FindFirstChild(chicken.name)
	if not owned then
		owned = Instance.new("IntValue")
		owned.Name = chicken.name
		owned.Parent = inventory
	end
	owned.Value = 1
	saveInventory(player, inventory)
end

local function copyChicken(chicken)
	local result = {}
	for key, value in pairs(chicken) do
		result[key] = value
	end
	return result
end

local function getState(player)
	local state = playerState[player]
	if not state then
		state = {nextRollAt = 0, fastRoll = false}
		playerState[player] = state
	end
	return state
end

local function syncPlayerInventory(player)
	local deadline = os.clock() + 15
	while player.Parent == Players and not DataService:IsProfileLoaded(player) and os.clock() < deadline do
		task.wait(0.2)
	end

	if player.Parent ~= Players or not DataService:IsProfileLoaded(player) then
		return
	end

	local savedInventory = DataService:Get(player, "Chickens")
	syncInventory(player, type(savedInventory) == "table" and savedInventory or {})
end

local globalSignals = require(ServerScriptService:WaitForChild("Utils"):WaitForChild("GlobalSignals"))
globalSignals.DataService.PlayerProfileLoaded:Connect(function(player, data)
	syncInventory(player, type(data.Chickens) == "table" and data.Chickens or {})
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(syncPlayerInventory, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(syncPlayerInventory, player)
end

requestRoll.OnServerInvoke = function(player)
	if not DataService:IsProfileLoaded(player) then
		return nil
	end

	local state = getState(player)
	local now = os.clock()
	if now < state.nextRollAt then
		return nil
	end

	local chicken = chooseChicken(player)
	if not chicken then
		return nil
	end

	state.nextRollAt = now + baseCooldown
	addChicken(player, chicken)

	local result = copyChicken(chicken)
	result.RollDuration = state.fastRoll and ChickenRollConfig.RollSpeed.Fast or ChickenRollConfig.RollSpeed.Normal
	rollResultNotify:FireClient(player, result)
	return result
end

setRollMode.OnServerEvent:Connect(function(player, mode, enabled)
	local state = getState(player)
	if mode == "FastRoll" then
		state.fastRoll = enabled == true
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerState[player] = nil
end)