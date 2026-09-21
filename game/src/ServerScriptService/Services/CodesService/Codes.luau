local DataService = require(script.Parent.Parent.DataService)

-- TestCode1, TestCode2 and Hey were removed: they rewarded nothing and only used up
-- a player's one redemption. Cash100 is kept as it was.
local Codes = {
	["Cash100"] = {
		isValid = function(player: Player)
			return true
		end,
		numberOfUses = 999,
		reward = function(player: Player)
			DataService:Increment(player, "Cash", 100)
		end,
	},
} :: {
	[string]: {
		isValid: (Player) -> boolean,
		numberOfUses: number,
		reward: (Player) -> ()
	}
}

local lowerCaseCodes = {}
for codeName, codeData in pairs(Codes) do
	lowerCaseCodes[codeName:lower()] = codeData
end
table.clear(Codes)

return lowerCaseCodes
