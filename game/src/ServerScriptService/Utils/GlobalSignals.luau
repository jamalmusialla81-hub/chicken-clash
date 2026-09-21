local LemonSignal = require(game.ReplicatedStorage.Packages.LemonSignal)
return {
	DataService = {
		["PlayerProfileLoaded"] = LemonSignal.new() :: LemonSignal.Signal<Player, any>, -- Player, Profile.Data
		["ValueChanged"] = LemonSignal.new() :: LemonSignal.Signal<Player ,{string}, any, any>,
		["ProfileMessageProcess"] = LemonSignal.new() :: LemonSignal.Signal<Player, any>,
	},
	
	MarketplaceService = {
		["PassAcquired"] =  LemonSignal.new() :: LemonSignal.Signal<Player, string>, -- Player, PassName
	}
}