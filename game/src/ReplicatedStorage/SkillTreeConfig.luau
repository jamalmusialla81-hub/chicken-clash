local SkillTreeConfig = {}

SkillTreeConfig.CurrencyNames = { "Cash", "Coins" }
SkillTreeConfig.DefaultCash = 1000
SkillTreeConfig.Nodes = {
	{ id = "player_open", x = 0.50, y = 0.56, grad = "yellow", title = "Player Open", icon = "rbxassetid://99097554161865", cost = 250, prerequisite = nil, entryPoint = true },
	{ id = "backpack", x = 0.50, y = 0.42, grad = "orange", title = "Backpack", icon = "rbxassetid://118915534669949", cost = 500, prerequisite = "player_open" },
	{ id = "auto_roll", x = 0.50, y = 0.28, grad = "blue", title = "Auto Roll", icon = "rbxassetid://125278872428987", cost = 1000, prerequisite = "backpack" },
	{ id = "loot_open", x = 0.50, y = 0.14, grad = "yellow", title = "Loot Open", icon = "rbxassetid://71202349341308", cost = 1500, prerequisite = "auto_roll" },
	{ id = "slime_1", x = 0.41, y = 0.08, grad = "orange", title = "2 Slime Slots", icon = "rbxassetid://88750231673471", cost = 750, prerequisite = "loot_open" },
	{ id = "slime_2", x = 0.32, y = 0.04, grad = "orange", title = "4 Slime Slots", icon = "rbxassetid://88750231673471", cost = 1250, prerequisite = "slime_1" },
	{ id = "slime_3", x = 0.23, y = 0.08, grad = "orange", title = "6 Slime Slots", icon = "rbxassetid://88750231673471", cost = 2000, prerequisite = "slime_2" },
	{ id = "slime_myst", x = 0.14, y = 0.04, grad = "dark", title = "", icon = "", cost = 0, prerequisite = "slime_3", isMystery = true },
	{ id = "enemy_1", x = 0.59, y = 0.08, grad = "purple", title = "2 Enemies", icon = "rbxassetid://111585498610164", cost = 750, prerequisite = "loot_open" },
	{ id = "enemy_2", x = 0.68, y = 0.04, grad = "purple", title = "3 Enemies", icon = "rbxassetid://111585498610164", cost = 1250, prerequisite = "enemy_1" },
	{ id = "enemy_3", x = 0.77, y = 0.08, grad = "purple", title = "4 Enemies", icon = "rbxassetid://111585498610164", cost = 1500, prerequisite = "enemy_2" },
	{ id = "enemy_myst", x = 0.86, y = 0.04, grad = "dark", title = "", icon = "", cost = 0, prerequisite = "enemy_3", isMystery = true },
	{ id = "luck_1", x = 0.39, y = 0.36, grad = "blue", title = "Luck I", icon = "rbxassetid://133633878118883", cost = 500, prerequisite = "backpack" },
	{ id = "luck_2", x = 0.29, y = 0.42, grad = "blue", title = "Luck II", icon = "rbxassetid://133633878118883", cost = 1000, prerequisite = "luck_1" },
	{ id = "luck_3", x = 0.20, y = 0.36, grad = "blue", title = "Luck III", icon = "rbxassetid://133633878118883", cost = 1500, prerequisite = "luck_2" },
	{ id = "super_luck", x = 0.11, y = 0.42, grad = "green", title = "Super Luck I", icon = "rbxassetid://133633878118883", cost = 2000, prerequisite = "luck_3" },
	{ id = "luck_myst", x = 0.04, y = 0.36, grad = "dark", title = "", icon = "", cost = 0, prerequisite = "super_luck", isMystery = true },
	{ id = "clovers_1", x = 0.61, y = 0.36, grad = "blue", title = "More Clovers I", icon = "rbxassetid://133633878118883", cost = 500, prerequisite = "backpack" },
	{ id = "clovers_2", x = 0.71, y = 0.42, grad = "purple", title = "More Clovers II", icon = "rbxassetid://133633878118883", cost = 1000, prerequisite = "clovers_1" },
	{ id = "clovers_3", x = 0.80, y = 0.36, grad = "purple", title = "More Clovers III", icon = "rbxassetid://133633878118883", cost = 15000, prerequisite = "clovers_2" },
	{ id = "clover_myst", x = 0.89, y = 0.42, grad = "dark", title = "", icon = "", cost = 0, prerequisite = "clovers_3", isMystery = true },
	{ id = "roll_spd", x = 0.61, y = 0.52, grad = "blue", title = "Roll Speed", icon = "rbxassetid://125278872428987", cost = 500, prerequisite = "player_open" },
	{ id = "faster_rolls", x = 0.70, y = 0.58, grad = "blue", title = "Faster Rolls", icon = "rbxassetid://125278872428987", cost = 1000, prerequisite = "roll_spd" },
	{ id = "rapid_rolls", x = 0.79, y = 0.64, grad = "blue", title = "Rapid Rolls", icon = "rbxassetid://125278872428987", cost = 2500, prerequisite = "faster_rolls" },
	{ id = "quick_rolls", x = 0.88, y = 0.70, grad = "blue", title = "Quick Rolls", icon = "rbxassetid://125278872428987", cost = 10000, prerequisite = "rapid_rolls" },
	{ id = "roll_myst", x = 0.96, y = 0.64, grad = "dark", title = "", icon = "", cost = 0, prerequisite = "quick_rolls", isMystery = true },
	{ id = "bonus_chance", x = 0.56, y = 0.67, grad = "yellow", title = "Bonus Chance", icon = "rbxassetid://112684829478873", cost = 500, prerequisite = "player_open" },
	{ id = "bonus_frenzy", x = 0.56, y = 0.81, grad = "blue", title = "Bonus Frenzy", icon = "rbxassetid://112684829478873", cost = 1000, prerequisite = "bonus_chance" },
	{ id = "bonus_chains", x = 0.50, y = 0.92, grad = "blue", title = "Bonus Chains", icon = "rbxassetid://112684829478873", cost = 2500, prerequisite = "bonus_frenzy" },
	{ id = "golden_rolls", x = 0.41, y = 0.67, grad = "blue", title = "Golden Rolls", icon = "rbxassetid://125278872428987", cost = 500, prerequisite = "player_open" },
	{ id = "ultra_gold", x = 0.32, y = 0.73, grad = "blue", title = "Ultra Golden", icon = "rbxassetid://125278872428987", cost = 1000, prerequisite = "golden_rolls" },
	{ id = "diamond_rolls", x = 0.32, y = 0.86, grad = "blue", title = "Diamond Rolls", icon = "rbxassetid://75581768563141", cost = 2500, prerequisite = "ultra_gold" },
	{ id = "ultra_diamond", x = 0.23, y = 0.93, grad = "blue", title = "Ultra Diamond", icon = "rbxassetid://75581768563141", cost = 50000, prerequisite = "diamond_rolls" },
}

SkillTreeConfig.Connections = {
	{ "player_open", "backpack" }, { "backpack", "auto_roll" }, { "auto_roll", "loot_open" },
	{ "loot_open", "slime_1" }, { "slime_1", "slime_2" }, { "slime_2", "slime_3" }, { "slime_3", "slime_myst" },
	{ "loot_open", "enemy_1" }, { "enemy_1", "enemy_2" }, { "enemy_2", "enemy_3" }, { "enemy_3", "enemy_myst" },
	{ "backpack", "luck_1" }, { "luck_1", "luck_2" }, { "luck_2", "luck_3" }, { "luck_3", "super_luck" }, { "super_luck", "luck_myst" },
	{ "backpack", "clovers_1" }, { "clovers_1", "clovers_2" }, { "clovers_2", "clovers_3" }, { "clovers_3", "clover_myst" },
	{ "player_open", "roll_spd" }, { "roll_spd", "faster_rolls" }, { "faster_rolls", "rapid_rolls" }, { "rapid_rolls", "quick_rolls" }, { "quick_rolls", "roll_myst" },
	{ "player_open", "bonus_chance" }, { "bonus_chance", "bonus_frenzy" }, { "bonus_frenzy", "bonus_chains" },
	{ "player_open", "golden_rolls" }, { "golden_rolls", "ultra_gold" }, { "ultra_gold", "diamond_rolls" }, { "diamond_rolls", "ultra_diamond" },
}

return SkillTreeConfig
