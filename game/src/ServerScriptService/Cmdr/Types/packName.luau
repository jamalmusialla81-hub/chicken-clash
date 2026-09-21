local Rep = game:GetService("ReplicatedStorage")
local PacksConfig = require(Rep.Configuration.Packs)
local Packs = {}

for name, _ in PacksConfig do table.insert(Packs, name) end

return function (registry)
	registry:RegisterType(script.Name, registry.Cmdr.Util.MakeEnumType(script.Name, Packs))
end