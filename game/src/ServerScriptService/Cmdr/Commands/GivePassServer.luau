local MarketplaceService = require(game:GetService("ServerScriptService").Services.MarketplaceService)

return function (context, player:Player, passName:string)
	local admin = context.Executor
	local action = MarketplaceService:GivePass(player.UserId, passName, true, admin.UserId)
	if action == nil then
		return `{passName} was sent to {player.Name} successfully!`
	end
	local checkOwned = MarketplaceService:PlayerOwnsPass(player.UserId, passName)
	if checkOwned then
		return `{player.Name} already owns {passName}.`
	end
	warn(`Couldnt give pass err: {action}`)
	return "Something went wrong."
end