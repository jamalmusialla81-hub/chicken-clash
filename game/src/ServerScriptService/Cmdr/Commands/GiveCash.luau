return {
	Name= "GiveCash",
	Aliases = {"gc"},
	Description = "Gives a player an amount of cash.",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "Target Player"
		},
		{
			Type = "number",
			Name = "Amount",
			Description = "Amount of cash"
		},
	}
}