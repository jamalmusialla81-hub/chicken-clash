local MarketplaceService = require(game:GetService("ServerScriptService").Services.MarketplaceService)

return function (context, player:Player, packName:string)
	local admin = context.Executor
	if MarketplaceService:PlayerOwnsPack(player, packName) then
		return `{player.Name} already owns {packName}.`
	end
	
	local action = MarketplaceService:GivePack(player, packName)
	if action == nil then
		return `{packName} was sent to {player.Name} successfully!`
	end
	return "Something went wrong."
end