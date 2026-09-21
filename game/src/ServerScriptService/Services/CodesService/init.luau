local CodesService = {}
CodesService.__index = CodesService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedUtils = ReplicatedStorage.Utils
local GlobalFunctions = require(ReplicatedUtils.GlobalFunctions)
local DataService = require(script.Parent.DataService)
local Packets = require(ReplicatedUtils.Packets)
local Codes = require(script.Codes)
local CodesStore
pcall(function()
	CodesStore = DataStoreService:GetDataStore("Codes")
end)

local DATASTORE_RETRIES = 5
local REWARD_RETRIES = 3

local function Error(message: string)
	return {"Error", message}
end

local function Success(message: string)
	return {"Success", message}
end

local function IncrementCodeUse(code: string)
	local success, err = GlobalFunctions.Retry(function()
		CodesStore:UpdateAsync(code, function(currentValue)
			currentValue = currentValue or 0
			return currentValue + 1
		end)
	end, DATASTORE_RETRIES)

	if not success then
		warn(`Failed to increment uses for code "{code}": {err}`)
	end
end

local RedeemingPlayers = {}

function CodesService:init()
	Packets.Codes.RedeemCode.OnServerInvoke = function(player: Player, code: string)
		if RedeemingPlayers[player] then
			return Error("Please wait")
		end

		RedeemingPlayers[player] = true

		local response

		local success, err = pcall(function()
			if typeof(code) ~= "string" then
				response = Error("Invalid code")
				return
			end

			code = string.lower(code)
			local info = Codes[code]

			if not info then
				response = Error("Invalid Code")
				return
			end

			local redeemedCodes = DataService:Get(player, "RedeemedCodes")
			if table.find(redeemedCodes, code) then
				response = Error("Already Redeemed")
				return
			end

			if not info.isValid(player) then
				response = Error("Invalid Code")
				return
			end

			if info.numberOfUses > 0 then
				local datastoreSuccess, currentUses = GlobalFunctions.Retry(function()
					return CodesStore:GetAsync(code)
				end, DATASTORE_RETRIES)

				if not datastoreSuccess then
					response = Error("Something went wrong, try again later")
					return
				end

				currentUses = currentUses or 0
				if currentUses >= info.numberOfUses then
					response = Error("Code reached max amount of uses")
					return
				end
			end

			local rewarded, rewardError = GlobalFunctions.Retry(function()
				info.reward(player)
			end, REWARD_RETRIES)

			if not rewarded then
				warn(`Failed rewarding "{code}" to {player.Name}: {rewardError}`)
				response = Error("Something went wrong, try again later")
				return
			end

			table.insert(redeemedCodes, code)
			task.spawn(IncrementCodeUse, code)

			response = Success("Code Redeemed Successfully 🎊")
		end)

		RedeemingPlayers[player] = nil

		if not success then
			warn(err)
			return Error("Something went wrong")
		end

		return response
	end
	
	Players.PlayerRemoving:Connect(function(player)
		RedeemingPlayers[player] = nil
	end)
end

return CodesService