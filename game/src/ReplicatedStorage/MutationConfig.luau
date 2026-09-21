local MutationConfig = {}

MutationConfig.EventChance = 0.5
MutationConfig.NormalChance = 0.01

MutationConfig.NormalMutations = {
	Neon = {displayName = "Neon", multiplier = 1.5, eventOnly = false},
	Golden = {displayName = "Golden", multiplier = 2, eventOnly = false},
	Diamond = {displayName = "Diamond", multiplier = 3, eventOnly = false},
	Shiny = {displayName = "Shiny", multiplier = 1.75, eventOnly = false},
	Rainbow = {displayName = "Rainbow", multiplier = 4, eventOnly = false},
}

MutationConfig.EventMutations = {
	CandySpawn = {name = "Candy", displayName = "Candy", multiplier = 2, eventOnly = true, eventId = "CandySpawn"},
	SpaceEvent = {name = "Space", displayName = "Space", multiplier = 3, eventOnly = true, eventId = "SpaceEvent"},
	MagmaSpawn = {name = "Lava", displayName = "Lava", multiplier = 2, eventOnly = true, eventId = "MagmaSpawn"},
	RadioactiveSpawn = {name = "Radioactive", displayName = "Radioactive", multiplier = 3, eventOnly = true, eventId = "RadioactiveSpawn"},
	DiscoEvent = {name = "Disco", displayName = "Disco", multiplier = 2, eventOnly = true, eventId = "DiscoEvent"},
}

MutationConfig.ByName = {}
for name, definition in pairs(MutationConfig.NormalMutations) do
	MutationConfig.ByName[name] = definition
end
for _, definition in pairs(MutationConfig.EventMutations) do
	MutationConfig.ByName[definition.name] = definition
end

function MutationConfig.GetEventMutation(eventId)
	return MutationConfig.EventMutations[eventId]
end

function MutationConfig.GetMultiplier(mutationName)
	local definition = MutationConfig.ByName[mutationName]
	return definition and definition.multiplier or 1
end

return MutationConfig