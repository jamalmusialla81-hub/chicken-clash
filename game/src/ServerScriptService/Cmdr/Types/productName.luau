local Rep = game:GetService("ReplicatedStorage")
local ProductsConfig = require(Rep.Configuration.Products)
local Products = {}

for name, _ in ProductsConfig do table.insert(Products, name) end

return function (registry)
	registry:RegisterType(script.Name, registry.Cmdr.Util.MakeEnumType(script.Name, Products))
end