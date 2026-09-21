local ProfileService = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerPackages = ServerScriptService.Packages
local ReplicatedPackages = ReplicatedStorage.Packages
local ServerUtils = ServerScriptService.Utils
local SafePlayerAdded = require(ServerUtils.SafePlayerAdded)
local GlobalSignals = require(ServerUtils.GlobalSignals)

local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
local PROFILE_TEMPLATE = require(script.Template)

local PlayerStore
if RunService:IsStudio() then
	PlayerStore = ProfileStore.New("PlayerStoreStudio12", PROFILE_TEMPLATE)
else
	PlayerStore = ProfileStore.New("PlayerStore", PROFILE_TEMPLATE)	
end

local Profiles: {[Player]: typeof(PlayerStore:StartSessionAsync())} = {}

-- Players that are in the process of leaving. Their profile session is already
-- ending, so services calling Get/Set during teardown should not warn.
local LeavingPlayers: {[Player]: boolean} = {}

local function GetProfile(player: Player)
	return Profiles[player]
end

local function ValidatePath(path: {string} | string): {string}
	if type(path) == "string" then
		return {path}
	elseif type(path) == "table" then
		return path
	else
		error("Invalid path type. Expected string or array of strings.")
	end
end

local function GetNestedValue(data, path: {string})
	local current = data
	for i, key in ipairs(path) do
		if current == nil then
			return nil
		end
		if i == #path then
			return current[key]
		else
			current = current[key]
		end
	end
	return current
end

local function SetNestedValue(player ,data, path: {string}, value)
	local current = data
	for i = 1, #path - 1 do
		local key = path[i]
		if current[key] == nil then
			current[key] = {}
		end
		current = current[key]
	end
	if #path == 1 then
		GlobalSignals.DataService.ValueChanged:Fire(player ,path, current, value)
	end
	current[path[#path]] = value
end

local function PlayerAdded(player:Player)
	local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile ~= nil then
		profile:AddUserId(player.UserId) 
		profile:Reconcile()
		profile.OnSessionEnd:Connect(function()
			Profiles[player].Data.LastSessionTime = os.time()
			print(Profiles[player].Data)
			Profiles[player] = nil
			player:Kick(`Profile session end - Please rejoin`)
		end)
		if player.Parent == Players then
			Profiles[player] = profile
			GlobalSignals.DataService.PlayerProfileLoaded:Fire(player, profile.Data)
			task.wait()
			profile:MessageHandler(function (message, processed)
				GlobalSignals.DataService.ProfileMessageProcess:Fire(player, message)
				processed()
			end)
		else
			profile:EndSession()
		end
	else
		player:Kick(`Profile load fail - Please rejoin`)
	end
end

function ProfileService:start()
	SafePlayerAdded(PlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		LeavingPlayers[player] = true
		task.delay(10, function()
			LeavingPlayers[player] = nil
		end)
		local profile = Profiles[player]
		if profile ~= nil then
			profile:EndSession()
		end
	end)
end

function ProfileService:GetProfile(player: Player)
	return GetProfile(player)
end

function ProfileService:IsProfileLoaded(player: Player): boolean
	return Profiles[player] ~= nil
end

function ProfileService:MessagePlayer(playerID:number, message:{}, messageType:string)
	message.MessageType = messageType
	PlayerStore:MessageAsync(tostring(playerID), message)
end

function ProfileService:OfflineProfileRead(playerID:number)
	local success, data = pcall(function ()
		return PlayerStore:GetAsync(tostring(playerID))
	end)
	if success then
		return data
	end
end

function ProfileService:Get(player: Player, path: {string} | string)
	local profile = GetProfile(player)
	if not profile then
 		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return nil
	end

	local validPath = ValidatePath(path)
	return GetNestedValue(profile.Data, validPath)
end

function ProfileService:Set(player: Player, path: {string} | string, value: any)
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return false
	end

	local validPath = ValidatePath(path)
	SetNestedValue(player,profile.Data, validPath, value)
	return true
end

function ProfileService:Increment(player: Player, path: {string} | string, amount: number?)
	amount = amount or 1
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return nil
	end

	local validPath = ValidatePath(path)
	local currentValue = GetNestedValue(profile.Data, validPath)

	if type(currentValue) ~= "number" then
		warn(`Cannot increment non-numeric value at path {table.concat(validPath, ".")}`)
		return nil
	end

	local newValue = currentValue + amount
	SetNestedValue(player,profile.Data, validPath, newValue)
	return newValue
end

function ProfileService:Decrement(player: Player, path: {string} | string, amount: number?)
	return ProfileService:Increment(player, path, -(amount or 1))
end

function ProfileService:Multiply(player: Player, path: {string} | string, multiplier: number)
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return nil
	end

	local validPath = ValidatePath(path)
	local currentValue = GetNestedValue(profile.Data, validPath)

	if type(currentValue) ~= "number" then
		warn(`Cannot multiply non-numeric value at path {table.concat(validPath, ".")}`)
		return nil
	end

	local newValue = currentValue * multiplier
	SetNestedValue(player,profile.Data, validPath, newValue)
	return newValue
end

function ProfileService:Toggle(player: Player, path: {string} | string)
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return nil
	end

	local validPath = ValidatePath(path)
	local currentValue = GetNestedValue(profile.Data, validPath)

	if type(currentValue) ~= "boolean" then
		warn(`Cannot toggle non-boolean value at path {table.concat(validPath, ".")}`)
		return nil
	end

	local newValue = not currentValue
	SetNestedValue(player,profile.Data, validPath, newValue)
	return newValue
end

function ProfileService:ArrayInsert(player: Player, path: {string} | string, value: any, index: number?)
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return false
	end

	local validPath = ValidatePath(path)
	local array = GetNestedValue(profile.Data, validPath)

	if type(array) ~= "table" then
		warn(`Cannot insert into non-array at path {table.concat(validPath, ".")}`)
		return false
	end

	if index then
		table.insert(array, index, value)
	else
		table.insert(array, value)
	end

	return true
end

function ProfileService:ArrayRemove(player: Player, path: {string} | string, index: number)
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return nil
	end

	local validPath = ValidatePath(path)
	local array = GetNestedValue(profile.Data, validPath)

	if type(array) ~= "table" then
		warn(`Cannot remove from non-array at path {table.concat(validPath, ".")}`)
		return nil
	end

	return table.remove(array, index)
end

function ProfileService:ArrayRemoveValue(player: Player, path: {string} | string, value: any)
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return false
	end

	local validPath = ValidatePath(path)
	local array = GetNestedValue(profile.Data, validPath)

	if type(array) ~= "table" then
		warn(`Cannot remove from non-array at path {table.concat(validPath, ".")}`)
		return false
	end

	for i, v in ipairs(array) do
		if v == value then
			table.remove(array, i)
			return true
		end
	end

	return false
end

function ProfileService:ArrayClear(player: Player, path: {string} | string)
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return false
	end

	local validPath = ValidatePath(path)
	SetNestedValue(player,profile.Data, validPath, {})
	return true
end

function ProfileService:ArrayLength(player: Player, path: {string} | string): number?
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return nil
	end

	local validPath = ValidatePath(path)
	local array = GetNestedValue(profile.Data, validPath)

	if type(array) ~= "table" then
		warn(`Cannot get length of non-array at path {table.concat(validPath, ".")}`)
		return nil
	end

	return #array
end

function ProfileService:Update(player: Player, path: {string} | string, updates: {[any]: any})
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return false
	end

	local validPath = ValidatePath(path)
	local currentTable = GetNestedValue(profile.Data, validPath)

	if type(currentTable) ~= "table" then
		warn(`Cannot update non-table value at path {table.concat(validPath, ".")}`)
		return false
	end

	for key, value in pairs(updates) do
		currentTable[key] = value
	end

	return true
end

function ProfileService:Modify(player: Player, path: {string} | string, callback: (currentValue: any) -> any)
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return nil
	end

	local validPath = ValidatePath(path)
	local currentValue = GetNestedValue(profile.Data, validPath)
	local newValue = callback(currentValue)

	SetNestedValue(player,profile.Data, validPath, newValue)
	return newValue
end

function ProfileService:Reset(player: Player, path: {string} | string)
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return false
	end
	
	local validPath = ValidatePath(path)
	local templateValue = GetNestedValue(PROFILE_TEMPLATE, validPath)

	if templateValue == nil then
		warn(`No template value found for path {table.concat(validPath, ".")}`)
		return false
	end

	local function deepCopy(original)
		if type(original) ~= "table" then
			return original
		end
		local copy = {}
		for k, v in pairs(original) do
			copy[k] = deepCopy(v)
		end
		return copy
	end

	SetNestedValue(player,profile.Data, validPath, deepCopy(templateValue))
	return true
end

function ProfileService:Exists(player: Player, path: {string} | string): boolean
	local profile = GetProfile(player)
	if not profile then
		return false
	end

	local validPath = ValidatePath(path)
	return GetNestedValue(profile.Data, validPath) ~= nil
end

function ProfileService:GetData(player: Player)
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return nil
	end

	return profile.Data
end

function ProfileService:Batch(player: Player, operations: {{type: string, path: any, value: any?}})
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return false
	end

	for _, operation in ipairs(operations) do
		local opType = operation.type
		local path = operation.path
		local value = operation.value

		if opType == "Set" then
			ProfileService:Set(player, path, value)
		elseif opType == "Increment" then
			ProfileService:Increment(player, path, value)
		elseif opType == "Decrement" then
			ProfileService:Decrement(player, path, value)
		elseif opType == "Toggle" then
			ProfileService:Toggle(player, path)
		elseif opType == "ArrayInsert" then
			ProfileService:ArrayInsert(player, path, value)
		else
			warn(`Unknown batch operation type: {opType}`)
		end
	end

	return true
end

function ProfileService:ForceSave(player: Player)
	local profile = GetProfile(player)
	if not profile then
		if not LeavingPlayers[player] then warn(`Profile not loaded for player {player.Name}`) end
		return false
	end
	
	profile:Save()
	return true
end

return ProfileService