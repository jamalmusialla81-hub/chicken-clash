local PlaytimeRewardsService = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local ReplicationService = require(script.Parent.ReplicationService)
local ReplicatedUtils = ReplicatedStorage.Utils
local Configuration = ReplicatedStorage.Configuration
local Packets = require(ReplicatedUtils.Packets)
local PlaytimeConfg = require(Configuration.PlaytimeRewards)
local PlaytimeRewardsFunctions = require(script.RewardFunctions)
local GlobalSignals = require(ServerScriptService.Utils.GlobalSignals)

local PlayerJoinTimestamp = {}
local PlayerJoinPlaytime = {}

function PlaytimeRewardsService:init()
	GlobalSignals.DataService.PlayerProfileLoaded:Connect(function (player:Player, profile)
		local now = os.time()
		PlayerJoinTimestamp[player.UserId] = now
		PlayerJoinPlaytime[player.UserId] = profile.Playtime
		
		if now - profile.PlaytimeRewards.StartTimestamp >= PlaytimeConfg.Config.ResetDuration then
			profile.PlaytimeRewards.ClaimedRewards = {}
			profile.PlaytimeRewards.StartPlaytime = profile.Playtime
			profile.PlaytimeRewards.StartTimestamp = now
		end
		
		local entry = ReplicationService.new(`{player.UserId}_PlaytimeRewards`, table.clone({
			OnSendPlayTime = profile.Playtime,
			OnSendTimestamp = now,
			RewardsPlaytime = profile.PlaytimeRewards.StartPlaytime,
			ClaimedRewards = profile.PlaytimeRewards.ClaimedRewards,
			ResetTimestamp = profile.PlaytimeRewards.StartTimestamp + PlaytimeConfg.Config.ResetDuration
		}), false, {player})
	end)
	
	Players.PlayerRemoving:Connect(function (player)
		PlayerJoinTimestamp[player.UserId] = nil
		PlayerJoinPlaytime[player.UserId] = nil
		ReplicationService.Destroy(`{player.UserId}_PlaytimeRewards`)
	end)
	
	Packets.PlaytimeRewards.ClaimReward.OnServerEvent:Connect(function (player, rewardIndex)
		if not PlaytimeConfg.Rewards[rewardIndex] then return end
		local playerPlaytime = DataService:Get(player, "Playtime")
		local playerPlaytimeRewardsData = DataService:Get(player, "PlaytimeRewards")
		
		local playerRewardsPlaytime = playerPlaytime - playerPlaytimeRewardsData.StartPlaytime
		if PlaytimeConfg.Rewards[rewardIndex].Duration > playerRewardsPlaytime then return end
		if DataService:Get(player, {"PlaytimeRewards", "ClaimedRewards"})[rewardIndex] then return end
		local rewardFunction = PlaytimeRewardsFunctions[rewardIndex]
		if not rewardFunction then warn(`Reward number:{rewardIndex} doesnt have a reward function`) return end
		DataService:Modify(player, {"PlaytimeRewards", "ClaimedRewards"}, function (value)
			value[rewardIndex] = true
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
		local entry = ReplicationService.new(`{player.UserId}_PlaytimeRewards`)
		entry.Data.ClaimedRewards[rewardIndex] = true
		entry:PushData()
		Packets.Notification.Prompt:FireClient(player, "Success", "Successfully claimed 🎉")
	end)
	
	task.spawn(function ()
		while task.wait(1) do
			for _, player:Player in Players:GetPlayers() do
				if not DataService:IsProfileLoaded(player) or not PlayerJoinPlaytime[player.UserId] or not PlayerJoinTimestamp[player.UserId] then continue end
				local playtime = PlayerJoinPlaytime[player.UserId] + (os.time() - PlayerJoinTimestamp[player.UserId])
				DataService:Set(player, "Playtime", playtime)
				
				if os.time() - DataService:Get(player, {"PlaytimeRewards", "StartTimestamp"}) > PlaytimeConfg.Config.ResetDuration then
					DataService:Set(player, "PlaytimeRewards", {
						StartTimestamp = os.time(),
						StartPlaytime = playtime,
						ClaimedRewards = {},
					})
					local entry = ReplicationService.new(`{player.UserId}_PlaytimeRewards`)
					entry.Data = table.clone({
						OnSendPlayTime = playtime,
						OnSendTimestamp = os.time(),
						RewardsPlaytime = playtime,
						ClaimedRewards = {},
						ResetTimestamp = os.time() + PlaytimeConfg.Config.ResetDuration
					})
					entry:PushData()
				end
			end
		end
	end)
end

return PlaytimeRewardsService
