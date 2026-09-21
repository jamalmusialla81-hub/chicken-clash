local DataService = require(script.Parent.Parent.DataService)
return {
	[1] = function (player:Player)
		DataService:Increment(player, "Cash", 100)
	end,
	[2] = function (player:Player)
		DataService:Increment(player, "Cash", 1000)
	end,
	[3] = function (player:Player)
		DataService:Increment(player, "Cash", 10000)
	end,
	[4] = function (player:Player)
		DataService:Increment(player, "Cash", 100000)
	end,
	[5] = function (player:Player)
		DataService:Increment(player, "Cash", 150000)
	end,
}