return {
	Name= "GiveProduct",
	Aliases = {"gpd"},
	Description = "Gives a player a specfic product.",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "Target Player"
		},
		{
			Type = "productName",
			Name = "ProductName",
			Description = "The product which will be given"
		},
	}
}