local DataService = require(script.Parent.Parent.DataService)
local WheelSpinService = require(script.Parent.Parent.WheelSpinService)
return {
	["1K Cash"] = function (player:Player)
		DataService:Increment(player, "Cash", 1000)
	end,
	
	["100K Cash"] = function (player:Player)
		DataService:Increment(player, "Cash", 100000)
	end,
	
	["1M Cash"] = function (player:Player)
		DataService:Increment(player, "Cash", 1000000)
	end,
	
	["10M Cash"] = function (player:Player)
		DataService:Increment(player, "Cash", 10000000)
	end,
	
	["x2 Spins"] = function (player:Player)
		WheelSpinService:AddSpins(player, 2)
	end,
	
	["x5 Spins"] = function (player:Player)
		WheelSpinService:AddSpins(player, 5)
	end,
	
	["x10 Spins"] = function (player:Player)
		WheelSpinService:AddSpins(player, 10)
	end,
}