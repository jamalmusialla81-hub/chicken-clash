local MarketplaceService = require(game:GetService("ServerScriptService").Services.MarketplaceService)

return function (context, player:Player, productName:string)
	local admin = context.Executor
	local action = MarketplaceService:GiveProduct(player.UserId, productName, true, admin.UserId)
	if action == nil then
		return `{productName} was sent to {player.Name} successfully!`
	end
	return "Something went wrong."
end