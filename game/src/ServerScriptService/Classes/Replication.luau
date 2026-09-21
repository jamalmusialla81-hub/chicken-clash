local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local ServerUtils = ServerScriptService.Utils
local ReplicatedUtils = ReplicatedStorage.Utils
local ReplicatedPackages = ReplicatedStorage.Packages
local Classe = require(ReplicatedPackages.Classe)
local GlobalSignals = require(ServerUtils.GlobalSignals)
local Packets = require(ReplicatedUtils.Packets)

local Replication =Classe.meta({} :: {
	Name:string,
	Subscribers:{Player},
	Data:{},
	Public:boolean,
	playerJoinConn:RBXScriptConnection,
	playerLeaveConn:RBXScriptConnection,
	_destroyed:boolean
}, {})

type Self = Classe.Self<typeof(Replication)>
type ISelf = Classe.ISelf<typeof(Replication)>

function Replication.PushData(self:Self, Player:Player?)
	if self._destroyed then return end
	if Player then
		Packets.Replication.Push:FireClient(Player, self.Name, self.Data)
	else
		for _, player in self.Subscribers do
			Packets.Replication.Push:FireClient(player, self.Name, self.Data)
		end
	end
end

function Replication.AddSubscriber(self:Self, Player:Player)
	if self._destroyed then return end
	if not table.find(self.Subscribers, Player) then
		table.insert(self.Subscribers, Player)
		self:PushData(Player)
	end
end

function Replication.Destroy(self:Self)
	if self._destroyed then return end
	self._destroyed = true
	if self.playerJoinConn then
		self.playerJoinConn:Disconnect()
	end
	if self.playerLeaveConn then
		self.playerLeaveConn:Disconnect()
	end
	for _, player in self.Subscribers do
		Packets.Replication.Destroy:FireClient(player, self.Name)
	end
	table.clear(self.Data)
	table.clear(self.Subscribers)
	self.Name = nil
	self.Public = nil
end

function Replication.init(self:Self)
	if self.Public then
		for _, player in Players:GetPlayers() do
			self:AddSubscriber(player)
		end
		self.playerJoinConn = Players.PlayerAdded:Connect(function (player)
			self:AddSubscriber(player)
		end)
		self.playerLeaveConn = Players.PlayerRemoving:Connect(function (player)
			local i = table.find(self.Subscribers, player)
			if i then table.remove(self.Subscribers, i) end
		end)
	end
end

function Replication.construct(self:ISelf, Name:string, Data:{}, Public:boolean)
	self.Name = Name
	self._destroyed = false
	self.Subscribers = {}
	self.Data = Data or {}
	self.Public = Public
end

return Classe.build(Replication)
