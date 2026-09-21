local DataService = require(game:GetService("ServerScriptService").Services.DataService)

return function (context, player:Player, amount:number)
	local action = DataService:Increment(player, "Cash", amount)

	if action then
		return `Success! {player.Name} cash is now {action}.`
	end
	
	warn(`Couldnt add cash err: {action}`)
	return `Something went wrong.`
end