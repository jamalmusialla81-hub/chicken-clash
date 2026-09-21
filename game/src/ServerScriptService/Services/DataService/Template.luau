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

	-- 1000 matches the starting cash every player already effectively had (the old
	-- SkillTreeServer.DefaultCash). CashMigrated must default to false: Reconcile copies
	-- missing keys into existing profiles, and LeaderstatsService flips it to true once.
	["Cash"] = 1000,
	["CashMigrated"] = false,

	-- Skill tree progression (was its own DataStore, "SkillTreeProgression_v1").
	-- Migrated is set once SkillTreeServer has copied any old data across.
	["SkillTree"] = {
		Owned = {},
		Migrated = false,
	},

	["LastSessionTime"] = 0,

	["Playtime"] = 0,

	["Settings"] = {
		["Music"] = 0.9,
		["SFX"] = 0.9,
	}
}

return template