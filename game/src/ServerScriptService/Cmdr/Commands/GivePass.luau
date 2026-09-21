return {
	Name= "GivePass",
	Aliases = {"gps"},
	Description = "Gives a player a specfic gamepass.",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "Target Player"
		},
		{
			Type = "passName",
			Name = "PassName",
			Description = "The gamepass which will be given"
		},
	}
}