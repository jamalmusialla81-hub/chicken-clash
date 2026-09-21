local SettingsService = {}

local DataService = require(script.Parent.DataService)
local Utils = script.Parent.Parent.Utils
local GlobalSignals = require(Utils.GlobalSignals)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedUtils = ReplicatedStorage.Utils
local Packets = require(ReplicatedUtils.Packets)
local ReplicationService = require(script.Parent.ReplicationService)

function SettingsService:init()
	GlobalSignals.DataService.PlayerProfileLoaded:Connect(function (player:Player, profile)
		local entry = ReplicationService.new(`{player.UserId}_Settings`, table.clone(profile.Settings), false, {player})
	end)
	
	Packets.Settings.UpdateSetting.OnServerEvent:Connect(function (player:Player, settingName, value)
		local plrSettings = DataService:Get(player, "Settings")
		if not plrSettings then return end
		
		if plrSettings[settingName] == nil then return end
		if typeof(plrSettings[settingName]) ~= typeof(value) then return end
		
		DataService:Set(player, {"Settings", settingName}, value)
	end)
end

return SettingsService
