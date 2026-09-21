local WheelSpinService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local WheelSpinConfig = require(ReplicatedStorage.Configuration.WheelSpin)
local RewardFunctions = require(script.RewardFunctions)
local ReplicatedUtils = ReplicatedStorage.Utils
local ReplicationService = require(script.Parent.ReplicationService)
local Packets = require(ReplicatedUtils.Packets)
local GlobalFunctions = require(ReplicatedUtils.GlobalFunctions)
local GlobalSignals = require(script.Parent.Parent.Utils.GlobalSignals)
local DataService = require(script.Parent.DataService)

local RandomObject = Random.new()
local function GetRandomRewardIndex()
	local totalChance = 0

	for _, reward in pairs(WheelSpinConfig.Rewards) do
		totalChance += reward.Chance
	end

	local roll = RandomObject:NextNumber(0, totalChance)

	local current = 0
	for index, reward in pairs(WheelSpinConfig.Rewards) do
		current += reward.Chance

		if roll <= current then
			return index
		end
	end

	return 1
end

local function GetTS(player)
	local playTime = DataService:Get(player, "Playtime")
	local interval = WheelSpinConfig.FreeSpinInterval

	local passedInCurrentInterval = playTime % interval
	local secondsUntilNextSpin = interval - passedInCurrentInterval

	local nextFreeSpinUnix = os.time() + secondsUntilNextSpin
	return nextFreeSpinUnix
end

function WheelSpinService:AddSpins(player: Player, amount: number)
	local num = DataService:Increment(player, "Spins", amount)

	ReplicationService.new(`{player.UserId}_Spins`, {
		Spins = num,
		NextFreeSpin = GetTS(player)
	})
end

local PlayerSpins = {}
function WheelSpinService:init()
	GlobalSignals.DataService.PlayerProfileLoaded:Connect(function (player:Player, profile)
		ReplicationService.new(`{player.UserId}_Spins`, {Spins = profile.Spins, NextFreeSpin = GetTS(player)}, false, {player})

		local FreeSpinInterval = WheelSpinConfig.FreeSpinInterval

		local lastInterval = math.floor(profile.Playtime / FreeSpinInterval)

		while player.Parent do
			task.wait(1)

			local playTime = DataService:Get(player, "Playtime")
			if not playTime then
				continue
			end

			local currentInterval = math.floor(playTime / FreeSpinInterval)

			if currentInterval > lastInterval then
				local spinsToGive = currentInterval - lastInterval
				lastInterval = currentInterval

				WheelSpinService:AddSpins(player, spinsToGive)

				Packets.Notification.Prompt:FireClient(
					player,
					"Success",
					`You received {spinsToGive} free spin!`
				)
			end
		end
	end)
	Packets.WheelSpin.Spin.OnServerInvoke = function (player)
		if table.find(PlayerSpins, player.UserId) then return 0 end
		table.insert(PlayerSpins, player.UserId)
		local success, data = pcall(function ()
			local playerSpins = DataService:Get(player, "Spins")
			if playerSpins <= 0 then Packets.Notification.Prompt:FireClient(player, "Error", "You dont have spins") return 0 end
			local amount = DataService:Decrement(player, "Spins", 1)
			ReplicationService.new(`{player.UserId}_Spins`, {Spins = amount, NextFreeSpin = GetTS(player)})

			local spinRes = GetRandomRewardIndex()
			task.delay(WheelSpinConfig.FullSpinDuration, function()
				GlobalFunctions.Retry(function () RewardFunctions[spinRes](player) end, 3)
				Packets.Notification.Prompt:FireClient(player, "Success", `You won {WheelSpinConfig.Rewards[spinRes].Text} 🎊`)
				table.remove(PlayerSpins, table.find(PlayerSpins, player.UserId))
			end)
			return spinRes
		end)
		if data == 0 then
			table.remove(PlayerSpins, table.find(PlayerSpins, player.UserId))
		end
		return data
	end

	Players.PlayerRemoving:Connect(function (player)
		ReplicationService.Destroy(`{player.UserId}_Spins`)
	end)
end

return WheelSpinService
