local Rep = game:GetService("ReplicatedStorage")
local PassesConfig = require(Rep.Configuration.Passes)
local Passes = {}

for name, _ in PassesConfig do table.insert(Passes, name) end

return function (registry)
	registry:RegisterType(script.Name, registry.Cmdr.Util.MakeEnumType(script.Name, Passes))
end