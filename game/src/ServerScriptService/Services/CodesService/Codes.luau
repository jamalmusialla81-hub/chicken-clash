local DataService = require(script.Parent.Parent.DataService)

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
	["TestCode1"] = {
		isValid = function(player: Player)
			return true
		end,
		numberOfUses = 999,
		reward = function(player: Player)
			print("Rewarding Player")
		end,
	},

	["TestCode2"] = {
		isValid = function(player: Player)
			return true
		end,
		numberOfUses = -1,
		reward = function(player: Player)
			print("Rewarding Player")
		end,
	},
	
	["Hey"] = {
		isValid = function() return true end,
		numberOfUses = -1,
		reward = function ()
			
		end,
	}
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
