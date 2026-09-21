local FriendService = {}

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Utils.Packets)
local DataService = require(script.Parent.DataService)
local ReplicattionService = require(script.Parent.ReplicationService)
local Config = ReplicatedStorage.Configuration
local GeneralConfig = require(Config.General)
local GlobalSignal = require(ServerScriptService.Utils.GlobalSignals)
local ReplicatedFunctions = require(ReplicatedStorage.Utils.GlobalFunctions)

local function ClaimFunction(player:Player)
	print("Reward")
end

local function PushData(player:Player)
	ReplicattionService.new(`{player}_Friends`, table.clone(DataService:Get(player, "FriendsReward")), false, {player})
end

local function RegisterFriends(p1:Player, p2:Player)
	DataService:ArrayInsert(p1, {"FriendsReward", "JoinedFriends"}, p2.UserId)
	DataService:ArrayInsert(p2, {"FriendsReward", "JoinedFriends"}, p1.UserId)
	
	PushData(p1)
	PushData(p2)
end

function FriendService:init()
	GlobalSignal.DataService.PlayerProfileLoaded:Connect(function (player:Player, profile)
		local friends
		local success, err = pcall(function ()
			friends = player:GetFriendsWhoPlayedAsync()
		end)
		if not success or not friends then return end
		local playerRegisteredFriends = DataService:Get(player, {"FriendsReward", "JoinedFriends"})
		for _, plr:Player in Players:GetPlayers() do
			if not table.find(friends, plr.UserId) then continue end
			if table.find(playerRegisteredFriends, plr.UserId) then continue end
			RegisterFriends(player, plr)
		end
		PushData(player)
	end)
	
	Packets.FriendReward.ClaimReward.OnServerEvent:Connect(function (player:Player)
		if DataService:Get(player, {"FriendsReward", "Claimed"}) then return end
		if GeneralConfig.InviteRewardRequiredFriends > #DataService:Get(player, {"FriendsReward", "JoinedFriends"}) then return end
		DataService:Set(player, {"FriendsReward", "Claimed"}, true)
		ReplicatedFunctions.Retry(function ()
			ClaimFunction(player)
		end, 5)
		Packets.Notification.Prompt:Fire("Success", "Claimed Reward 🎉")
		PushData(player)
	end)
end

return FriendService
