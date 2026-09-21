local ReplicationService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerClasses = ServerScriptService.Classes
local ReplicationClass = require(ServerClasses.Replication)
local ReplicatedUtils = ReplicatedStorage.Utils
local Packets = require(ReplicatedUtils.Packets)

local ReplicationEntities = {}

function ReplicationService.new(Name:string, Data:{}, Public:boolean, AccessPlayers:{Player}?)
	if ReplicationEntities[Name] then 
		if not Data then
			return ReplicationEntities[Name] 
		end	
		ReplicationEntities[Name].Data = Data
		ReplicationEntities[Name]:PushData()
		return
	end
	local entry = ReplicationClass.new(Name, Data, Public)
	ReplicationEntities[Name] = entry
	if not Public then
		for _, player in AccessPlayers do
			entry:AddSubscriber(player)
		end
	end
	return entry
end

function ReplicationService.Destroy(Name:string)
	if not ReplicationEntities[Name] then return end
	ReplicationEntities[Name]:Destroy()
	ReplicationEntities[Name] = nil
end

function ReplicationService.init()
	Packets.Replication.Request.OnServerInvoke = function (player, name)
		local class = ReplicationEntities[name]
		if not class then return {} end
		if table.find(class.Subscribers, player) then
			return class.Data
		end
		return {}
	end
end

return ReplicationService
