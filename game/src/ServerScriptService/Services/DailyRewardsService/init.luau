local DailyRewardsService = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local ReplicationService = require(script.Parent.ReplicationService)
local ReplicatedUtils = ReplicatedStorage.Utils
local GlobalSignals = require(ServerScriptService.Utils.GlobalSignals)
local Configuration = ReplicatedStorage.Configuration
local Packets = require(ReplicatedUtils.Packets)
local DailyRewardsFunctions = require(script.RewardFunctions)

function DailyRewardsService:init()
	GlobalSignals.DataService.PlayerProfileLoaded:Connect(function (player:Player, profile)
		local now = os.time()
		if now - profile.LastSessionTime > 2 * 24 * 60 * 60 then
			profile.DailyRewards = {
				StartTimestamp = now,
				ClaimedRewards = {}
			}
		end
		
		ReplicationService.new(`{player.UserId}_DailyRewards`, table.clone(profile.DailyRewards), false, {player})
	end)
	
	Packets.DailyRewards.ClaimReward.OnServerEvent:Connect(function (player, index)
		local rewardFunction = DailyRewardsFunctions[index]
		if not rewardFunction then return end
		if DataService:Get(player, {"DailyRewards", "ClaimedRewards"})[index] then return end
		local totalTime = os.time() - DataService:Get(player, {"DailyRewards", "StartTimestamp"})
		if totalTime < (index - 1) * 24 * 60 * 60 then return end
		DataService:Modify(player, {"DailyRewards", "ClaimedRewards"}, function (value)
			value[index] = true
			return value
		end)
		local success, err 
		for i = 1, 5 do
			success, err = pcall(function ()
				rewardFunction(player)
			end)
			if success then
				break
			end
		end
		local entry = ReplicationService.new(`{player.UserId}_DailyRewards`)
		entry.Data = table.clone(DataService:Get(player, {"DailyRewards"}))
		entry:PushData()
		Packets.Notification.Prompt:FireClient(player, "Success", "Successfully claimed 🎉")
	end)
end

return DailyRewardsService
