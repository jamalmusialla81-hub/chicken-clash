local Packet = require(game:GetService("ReplicatedStorage").Packages.Packet)
return {
	Replication = {
		["Request"] = Packet("RequestSubscribe", Packet.String):Response(Packet.Any),
		["Push"] = Packet("ReplicationPush", Packet.String, Packet.Any),
		["Destroy"] = Packet("ReplicationDestroy", Packet.String)
	},
	
	Marketplace = {
		["CheckPassOwned"] = Packet("CheckPassOwned", Packet.NumberF64, Packet.String):Response(Packet.Boolean8),
		["StartGifting"] = Packet("StartGifting", Packet.NumberF64, Packet.String, Packet.String),
		["PromptStart"] = Packet("PromptStart")
	},
	
	Notification = {
		["Prompt"] = Packet("Prompt", Packet.String, Packet.String) -- Type, Message
	}, 
	
	Conffeti = {
		["Emit"] = Packet("Emit")
	},
	
	PlaytimeRewards = {
		["ClaimReward"] = Packet("ClaimRewardTime", Packet.NumberU8)
	},
	
	DailyRewards = {
		["ClaimReward"] = Packet("ClaimRewardDaily", Packet.NumberU8)
	},
	
	FriendReward = {
		["ClaimReward"] = Packet("ClaimRewardFriend")
	},
	
	GroupReward = {
		["ClaimReward"] = Packet("ClaimRewardGroup"):Response(Packet.Boolean8)
	},
	
	WheelSpin = {
		["Spin"] = Packet("Spin"):Response(Packet.NumberU8)
	},
	
	Codes = {
		["RedeemCode"] = Packet("RedeemCode", Packet.String):Response({Packet.String, Packet.String})
	},
	
	Settings = {
		["UpdateSetting"] = Packet("UpdateSetting", Packet.String, Packet.Any)
	}
}