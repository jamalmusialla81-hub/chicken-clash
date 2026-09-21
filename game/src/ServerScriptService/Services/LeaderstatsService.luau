local LeaderstatsService = {}

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerPackages = ServerScriptService.Packages
local ServerUtils = ServerScriptService.Utils
local GlobalSignals = require(ServerUtils.GlobalSignals)

local function CreateValue(type:"IntValue"|"NumberValue"|"StringValue", name:string, value:any):Instance
	local instance = Instance.new(type)
	instance.Name = name
	instance.Value = value
	
	return instance
end

local function SetupLeaderstats(player:Player, data)
	if player.Parent ~= Players then return end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	
	local Values = {}
	
	Values.cash = CreateValue("IntValue", "Cash", data.Cash)
	
	for _, v in Values do
		v.Parent = leaderstats
	end
	leaderstats.Parent = player
	
	player:SetAttribute("Floor", data.Floor)
end

function LeaderstatsService:init()
	GlobalSignals.DataService.PlayerProfileLoaded:Connect(function(player:Player, profile)
		SetupLeaderstats(player, profile)
	end)
	GlobalSignals.DataService.ValueChanged:Connect(function (player:Player, path, before, after)
		if path[1] == "Cash" then
			player.leaderstats.Cash.Value = after
		elseif path[1] == "Floor" then
			player:SetAttribute("Floor", after)
		end
	end)
end

return LeaderstatsService