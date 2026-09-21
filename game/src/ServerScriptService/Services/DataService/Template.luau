local Config = game:GetService("ReplicatedStorage").Configuration
local WheelSpinConfig = require(Config.WheelSpin)

local template = {
	["GiftedPasses"] = {},

	["Packs"] = {},

	["Luck"] = {
		Owned = {1},
		Equipped = 1,
	},

	["Chickens"] = {},

	["PlaytimeRewards"] = {
		StartTimestamp = 0,
		StartPlaytime = 0,
		ClaimedRewards = {},
		Unlocked = false
	},

	["DailyRewards"] = {
		StartTimestamp = 0,
		ClaimedRewards = {},
		Unlocked = false
	},

	["FriendsReward"] = {
		JoinedFriends = {},
		Claimed = false,
		Unlocked = false,
	},

	["GroupReward"] = false,

	["Spins"] = WheelSpinConfig.StartingSpins,

	["RedeemedCodes"] = {},

	["Cash"] = 0,

	["LastSessionTime"] = 0,

	["Playtime"] = 0,

	["Settings"] = {
		["Music"] = 0.9,
		["SFX"] = 0.9,
	}
}

return template