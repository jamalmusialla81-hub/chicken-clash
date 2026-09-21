--==================================================
-- LUCK SHOP SERVER
--==================================================

print("==================================================")
print("[LuckShopServer] STARTING")
print("==================================================")


--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")


--==================================================
-- MODULES
--==================================================

local ProfileService = require(
	ServerScriptService.Utils.ProfileService
)


--==================================================
-- REMOTES
--==================================================

local remotes = ReplicatedStorage:WaitForChild("LuckShopRemotes")

local GetLuckData = remotes:WaitForChild("GetLuckData")
local PurchaseLuck = remotes:WaitForChild("PurchaseLuck")
local EquipLuck = remotes:WaitForChild("EquipLuck")


print("[LuckShopServer] Remotes loaded")


--==================================================
-- LUCK VALUES
--==================================================

local luckValues = {
	1,
	5,
	20,
	50,
	200,
	1000,
	5000,
	20000,
	100000,
	500000,

	2000000,
	10000000,
	50000000,
	200000000,
	1000000000,
	5000000000,
	20000000000,
	100000000000,
	500000000000,
}


--==================================================
-- PRICES
--==================================================

local prices = {
	[1] = 0,

	[5] = 1000,
	[20] = 5000,
	[50] = 25000,
	[200] = 150000,
	[1000] = 1000000,
	[5000] = 7500000,
	[20000] = 50000000,
	[100000] = 500000000,
	[500000] = 5000000000,

	[2000000] = 50000000000,
	[10000000] = 500000000000,
	[50000000] = 5000000000000,
	[200000000] = 50000000000000,
	[1000000000] = 500000000000000,
	[5000000000] = 5000000000000000,
	[20000000000] = 50000000000000000,
	[100000000000] = 500000000000000000,
	[500000000000] = 5000000000000000000,
}


--==================================================
-- VALID LUCK CHECK
--==================================================

local validLuck = {}

for _, multiplier in ipairs(luckValues) do
	validLuck[multiplier] = true
end


--==================================================
-- HELPERS
--==================================================

local function getLuckData(player)
	local luckData = ProfileService:Get(player, "Luck")

	if not luckData then
		warn(
			"[LuckShopServer] Luck data missing for:",
			player.Name
		)

		return nil
	end

	if type(luckData.Owned) ~= "table" then
		warn(
			"[LuckShopServer] Owned wasn't a table. Repairing."
		)

		luckData.Owned = {1}
	end

	if type(luckData.Equipped) ~= "number" then
		warn(
			"[LuckShopServer] Equipped wasn't a number. Repairing."
		)

		luckData.Equipped = 1
	end

	return luckData
end


local function ownsLuck(luckData, multiplier)
	return table.find(luckData.Owned, multiplier) ~= nil
end


local function getCash(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		warn(
			"[LuckShopServer] leaderstats missing:",
			player.Name
		)

		return nil
	end

	local cash = leaderstats:FindFirstChild("Cash")

	if not cash then
		warn(
			"[LuckShopServer] Cash missing:",
			player.Name
		)

		return nil
	end

	return cash
end


--==================================================
-- GET LUCK DATA
--==================================================

GetLuckData.OnServerInvoke = function(player)

	print("--------------------------------------------------")
	print(
		"[LuckShopServer] GetLuckData called:",
		player.Name
	)

	local luckData = getLuckData(player)

	if not luckData then

		warn(
			"[LuckShopServer] Could not get luck data."
		)

		return {
			Owned = {1},
			Equipped = 1,
		}
	end


	print(
		"[LuckShopServer] Equipped:",
		luckData.Equipped
	)

	print(
		"[LuckShopServer] Owned count:",
		#luckData.Owned
	)

	for _, multiplier in ipairs(luckData.Owned) do
		print(
			"[LuckShopServer] Owned:",
			multiplier
		)
	end


	return {
		Owned = table.clone(luckData.Owned),
		Equipped = luckData.Equipped,
	}
end


--==================================================
-- PURCHASE LUCK
--==================================================

PurchaseLuck.OnServerInvoke = function(player, multiplier)

	print("--------------------------------------------------")
	print(
		"[LuckShopServer] PURCHASE REQUEST:",
		player.Name,
		multiplier
	)


	-- Validate number
	if type(multiplier) ~= "number" then

		warn(
			"[LuckShopServer] Invalid multiplier type:",
			typeof(multiplier)
		)

		return false
	end


	-- Validate luck exists
	if not validLuck[multiplier] then

		warn(
			"[LuckShopServer] Invalid luck multiplier:",
			multiplier
		)

		return false
	end


	-- Get profile
	local luckData = getLuckData(player)

	if not luckData then
		return false
	end


	-- Already owned
	if ownsLuck(luckData, multiplier) then

		warn(
			"[LuckShopServer] Player already owns:",
			multiplier
		)

		return false
	end


	-- Get price
	local price = prices[multiplier]

	if not price then

		warn(
			"[LuckShopServer] No price for:",
			multiplier
		)

		return false
	end


	-- Get cash
	local cash = getCash(player)

	if not cash then
		return false
	end


	print(
		"[LuckShopServer] Cash:",
		cash.Value
	)

	print(
		"[LuckShopServer] Price:",
		price
	)


	-- Not enough cash
	if cash.Value < price then

		warn(
			"[LuckShopServer] NOT ENOUGH CASH"
		)

		return false
	end


	-- Take cash
	cash.Value -= price


	-- Add ownership
	table.insert(
		luckData.Owned,
		multiplier
	)


	-- Save through profile
	ProfileService:Set(
		player,
		{"Luck", "Owned"},
		luckData.Owned
	)


	print(
		"[LuckShopServer] PURCHASE SUCCESS:",
		multiplier
	)

	print(
		"[LuckShopServer] Remaining Cash:",
		cash.Value
	)


	return true
end


--==================================================
-- EQUIP LUCK
--==================================================

EquipLuck.OnServerInvoke = function(player, multiplier)

	print("--------------------------------------------------")
	print(
		"[LuckShopServer] EQUIP REQUEST:",
		player.Name,
		multiplier
	)


	-- Validate number
	if type(multiplier) ~= "number" then

		warn(
			"[LuckShopServer] Invalid multiplier type."
		)

		return false
	end


	-- Validate luck
	if not validLuck[multiplier] then

		warn(
			"[LuckShopServer] Invalid luck:",
			multiplier
		)

		return false
	end


	-- Get profile
	local luckData = getLuckData(player)

	if not luckData then
		return false
	end


	-- Must own it
	if not ownsLuck(luckData, multiplier) then

		warn(
			"[LuckShopServer] Player doesn't own:",
			multiplier
		)

		return false
	end


	-- Equip
	luckData.Equipped = multiplier


	ProfileService:Set(
		player,
		{"Luck", "Equipped"},
		multiplier
	)


	print(
		"[LuckShopServer] EQUIP SUCCESS:",
		multiplier
	)


	return true
end


--==================================================
-- PLAYER CHECK
--==================================================

Players.PlayerAdded:Connect(function(player)

	task.spawn(function()

		-- Wait for profile
		while player.Parent and not ProfileService:IsProfileLoaded(player) do
			task.wait(0.1)
		end


		if not player.Parent then
			return
		end


		local luckData = getLuckData(player)

		if luckData then

			print(
				"[LuckShopServer] Profile ready for:",
				player.Name
			)

			print(
				"[LuckShopServer] Equipped luck:",
				luckData.Equipped
			)

		end

	end)

end)


--==================================================
-- STARTUP
--==================================================

print("==================================================")
print("[LuckShopServer] READY")
print("==================================================")