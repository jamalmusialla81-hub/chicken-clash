local LeaderstatsService = {}

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerUtils = ServerScriptService.Utils
local GlobalSignals = require(ServerUtils.GlobalSignals)
local DataService = require(script.Parent.DataService)

-- Cash used to start every session at 1000 (SkillTreeServer's old DefaultCash) without ever
-- saving it. Existing profiles are lifted to this once so nobody ends up below what they had.
local LEGACY_STARTING_CASH = 1000

local cashValues: {[Player]: IntValue} = {}
local applyingFromData: {[Player]: boolean} = {}

local function CreateValue(type:"IntValue"|"NumberValue"|"StringValue", name:string, value:any):Instance
	local instance = Instance.new(type)
	instance.Name = name
	instance.Value = value

	return instance
end

local function SetCashValue(player:Player, value:number)
	local cash = cashValues[player]
	if not cash or cash.Value == value then return end
	applyingFromData[player] = true
	cash.Value = value
	applyingFromData[player] = nil
end

local function SetupLeaderstats(player:Player, data)
	if player.Parent ~= Players then return end

	if not data.CashMigrated then
		data.CashMigrated = true
		if (data.Cash or 0) < LEGACY_STARTING_CASH then
			data.Cash = LEGACY_STARTING_CASH
		end
	end

	-- Other scripts (e.g. ChickenRollService's Rolls stat) may already have made the folder.
	-- Reuse it so a player only ever has one leaderstats folder and one Cash value.
	local leaderstats = player:FindFirstChild("leaderstats")
	local isNewFolder = leaderstats == nil
	if isNewFolder then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
	end

	local cash = leaderstats:FindFirstChild("Cash")
	if not cash then
		cash = CreateValue("IntValue", "Cash", data.Cash)
		cash.Parent = leaderstats
	end
	cashValues[player] = cash
	SetCashValue(player, data.Cash)

	-- leaderstats.Cash is a display mirror of DataService's Cash. Game scripts must change
	-- cash with DataService:Increment(player, "Cash", amount) so it is saved.
	-- Safety net: if something still writes leaderstats.Cash directly, put the saved value
	-- back and say so, instead of letting the two silently disagree.
	cash:GetPropertyChangedSignal("Value"):Connect(function()
		if applyingFromData[player] then return end
		local saved = DataService:Get(player, "Cash")
		if saved ~= nil and cash.Value ~= saved then
			warn(`[LeaderstatsService] {player.Name}: leaderstats.Cash was written directly ({cash.Value}); restoring saved value {saved}. Use DataService:Increment(player, "Cash", amount).`)
			SetCashValue(player, saved)
		end
	end)

	if isNewFolder then
		leaderstats.Parent = player
	end

	player:SetAttribute("Floor", data.Floor)
end

function LeaderstatsService:init()
	GlobalSignals.DataService.PlayerProfileLoaded:Connect(function(player:Player, profile)
		SetupLeaderstats(player, profile)
	end)
	GlobalSignals.DataService.ValueChanged:Connect(function (player:Player, path, before, after)
		if path[1] == "Cash" then
			SetCashValue(player, after)
		elseif path[1] == "Floor" then
			player:SetAttribute("Floor", after)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		cashValues[player] = nil
		applyingFromData[player] = nil
	end)
end

return LeaderstatsService
