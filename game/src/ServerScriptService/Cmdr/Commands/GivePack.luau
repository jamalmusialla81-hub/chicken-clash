return {
	Name= "GivePack",
	Aliases = {"gpk"},
	Description = "Gives a player a specfic pack.",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "Target Player"
		},
		{
			Type = "packName",
			Name = "PackName",
			Description = "The pack which will be given"
		},
	}
}