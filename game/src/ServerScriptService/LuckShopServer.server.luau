--==================================================
-- LUCK SHOP SERVER
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

print("==================================================")
print("[LuckShopServer] STARTING")
print("==================================================")


--==================================================
-- DATA SERVICE
-- (Needed so purchases actually write Luck.Equipped.
--  This was missing before, which is why ChickenRollService
--  always saw Luck as nil / fell back to 1x no matter what
--  a player bought.)
--==================================================

local dataServiceModule = ServerScriptService:FindFirstChild("DataService", true)

assert(
	dataServiceModule and dataServiceModule:IsA("ModuleScript"),
	"DataService ModuleScript could not be found anywhere inside ServerScriptService"
)

local DataService = require(dataServiceModule)


--==================================================
-- REMOTES
--==================================================

local remotes = ReplicatedStorage:WaitForChild("LuckShopRemotes")

local purchaseRemote = remotes:WaitForChild("PurchaseLuck")

print("[LuckShopServer] PurchaseLuck found")


--==================================================
-- SHOP
--==================================================

local function getShopContainer(player)

	local playerGui = player:FindFirstChild("PlayerGui")

	if not playerGui then
		return nil
	end

	local main = playerGui:FindFirstChild("Main")

	if not main then
		return nil
	end

	local frames = main:FindFirstChild("Frames")

	if not frames then
		return nil
	end

	local rollShop = frames:FindFirstChild("RollShop")

	if not rollShop then
		return nil
	end

	local scrollingFrame = rollShop:FindFirstChild("ScrollingFrame")

	if not scrollingFrame then
		return nil
	end

	return scrollingFrame:FindFirstChild("Frame")
end

local function findItem(player, itemName)

	local container = getShopContainer(player)

	if not container then
		warn("[LuckShopServer] Could not resolve shop container for " .. player.Name)
		return nil
	end

	return container:FindFirstChild(itemName)
end


--==================================================
-- CANONICAL LUCK TIERS + PRICES
-- These MUST exactly match ChickenRollService's luckValues list,
-- or a purchased tier silently gives zero Luck benefit (this was
-- an actual bug found in the existing shop: it had a stray
-- 500,000,000 tier not in the official list, and was MISSING the
-- true final 500,000,000,000 tier entirely).
--
-- This patch re-stamps every shop item's Luck + Price attributes
-- to these canonical values the moment each player joins, based
-- on their current relative order (sorted by whatever Luck value
-- they currently have) — so it self-corrects regardless of
-- whatever's currently sitting in Studio's Attributes panel.
--
-- Prices are the requested nerf: much steeper curve so reaching
-- late tiers takes far longer than a few minutes.
--==================================================

local CANONICAL_LUCK_TIERS = {
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

local CANONICAL_PRICES = {
	0,                     -- 1x        (free starting tier)
	100,                   -- 5x        (Upgrade 1)
	50000,                 -- 20x       (Upgrade 2)
	500000,                -- 50x       (Upgrade 3)
	2500000,               -- 200x
	15000000,              -- 1,000x
	75000000,              -- 5,000x
	400000000,             -- 20,000x
	2000000000,            -- 100,000x
	10000000000,           -- 500,000x
	50000000000,           -- 2,000,000x
	250000000000,          -- 10,000,000x
	1000000000000,         -- 50,000,000x
	5000000000000,         -- 200,000,000x
	25000000000000,        -- 1,000,000,000x
	100000000000000,       -- 5,000,000,000x
	500000000000000,       -- 20,000,000,000x
	2000000000000000,      -- 100,000,000,000x
	10000000000000000,     -- 500,000,000,000x
}

local function patchShopItemsForPlayer(player)

	local container = nil
	local deadline = os.clock() + 15

	while player.Parent == Players and os.clock() < deadline do

		container = getShopContainer(player)

		if container then
			break
		end

		task.wait(0.5)
	end

	if not container then
		warn("[LuckShopServer] Could not find shop container to patch for " .. player.Name .. " after waiting 15s (will not retry).")
		return
	end

	local items = {}

	for _, child in ipairs(container:GetChildren()) do

		if child:IsA("GuiObject") and type(child:GetAttribute("Luck")) == "number" then
			table.insert(items, child)
		end
	end

	-- Sort by CURRENT Luck value ascending. Even if one value is
	-- wrong (like the stray 500,000,000 bug), the overall relative
	-- ORDER of items is still correct, so this reliably recovers
	-- the intended tier order before re-stamping correct values.
	table.sort(items, function(a, b)
		return a:GetAttribute("Luck") < b:GetAttribute("Luck")
	end)

	if #items ~= #CANONICAL_LUCK_TIERS then

		warn(
			"[LuckShopServer] Expected "
				.. #CANONICAL_LUCK_TIERS
				.. " shop items but found "
				.. #items
				.. " for "
				.. player.Name
				.. " — patching as many as line up, but check the shop UI for missing/extra items."
		)
	end

	for index, item in ipairs(items) do

		local luck = CANONICAL_LUCK_TIERS[index]
		local price = CANONICAL_PRICES[index]

		if luck and price then

			item:SetAttribute("Luck", luck)
			item:SetAttribute("Price", price)
		end
	end

	print("[LuckShopServer] Patched " .. #items .. " shop item(s) with canonical Luck/Price values for " .. player.Name)
end


--==================================================
-- PURCHASE
--==================================================

purchaseRemote.OnServerEvent:Connect(function(
	player,
	itemName,
	clientLuck,
	clientPrice
)

	print("==================================================")
	print("[LuckShopServer] PURCHASE REQUEST")
	print("Player:", player.Name)
	print("Item:", itemName)
	print("Client Luck:", clientLuck)
	print("Client Price:", clientPrice)
	print("==================================================")


	-- Find item
	local item = findItem(player, itemName)

	if not item then

		warn(
			"[LuckShopServer] Item not found:",
			itemName
		)

		return
	end


	--==================================================
	-- ATTRIBUTES
	--==================================================

	local purchased = item:GetAttribute("Purchased")
	local equipped = item:GetAttribute("Equipped")
	local rawLuck = item:GetAttribute("Luck")
	local price = item:GetAttribute("Price")


	print(
		"[LuckShopServer] ATTRIBUTES:",
		"Purchased =", purchased,
		"Equipped =", equipped,
		"Luck =", rawLuck,
		"(type:", typeof(rawLuck), ")",
		"Price =", price
	)


	--==================================================
	-- COERCE LUCK TO A REAL NUMBER
	-- THIS IS THE ROOT CAUSE OF "BUYING 20,000x STILL
	-- ROLLS #1-5": if the "Luck" attribute on this shop
	-- item was ever set as a String in Explorer (e.g. "20000"
	-- or "20,000") instead of a Number, it used to save fine
	-- but ChickenRollService's `type(x) == "number"` check
	-- would silently reject it and fall back to 1x Luck —
	-- with NO error shown anywhere. This block catches that
	-- and fixes it, and now blocks the purchase loudly instead
	-- of saving garbage if it truly isn't a number.
	--==================================================

	local luck = rawLuck

	if type(luck) == "string" then
		luck = tonumber((luck:gsub(",", "")))
	end

	if type(luck) ~= "number" then

		warn(
			"[LuckShopServer] *** BLOCKED PURCHASE *** The 'Luck' attribute on "
				.. itemName
				.. " is not a usable number (raw value: "
				.. tostring(rawLuck)
				.. ", type: "
				.. typeof(rawLuck)
				.. "). Go to this item in Explorer and make sure its 'Luck' "
				.. "attribute is set to a Number type, not String."
		)

		return
	end


	-- Already purchased
	if purchased == true then

		warn(
			"[LuckShopServer] Already purchased:",
			itemName
		)

		return
	end


	-- Validate price
	if typeof(price) ~= "number" then

		warn(
			"[LuckShopServer] Invalid price:",
			itemName
		)

		return
	end


	--==================================================
	-- CASH
	--==================================================

	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then

		warn(
			"[LuckShopServer] leaderstats missing"
		)

		return
	end


	local cash = leaderstats:FindFirstChild("Cash")

	if not cash then

		warn(
			"[LuckShopServer] Cash missing"
		)

		return
	end


	print(
		"[LuckShopServer] Cash before:",
		cash.Value
	)


	--==================================================
	-- CHECK CASH
	--==================================================

	if cash.Value < price then

		warn(
			"[LuckShopServer] NOT ENOUGH CASH"
		)

		return
	end


	--==================================================
	-- TAKE CASH
	--==================================================

	DataService:Increment(player, "Cash", -price)

	print(
		"[LuckShopServer] Cash after:",
		cash.Value
	)


	--==================================================
	-- PURCHASE
	--==================================================

	item:SetAttribute(
		"Purchased",
		true
	)

	-- Automatically equip
	item:SetAttribute(
		"Equipped",
		true
	)


	--==================================================
	-- SAVE LUCK TO PROFILE
	-- This is the fix: ChickenRollService reads
	-- Luck.Equipped from DataService to decide the roll
	-- window. Without this write, it was always nil, so
	-- every player was stuck at the 1x Luck window (#1-5)
	-- no matter what they bought.
	--==================================================

	local saved = DataService:Set(player, { "Luck", "Equipped" }, luck)

	if saved then

		print(
			"[LuckShopServer] Saved Luck.Equipped =",
			luck,
			"for",
			player.Name
		)
	else

		warn(
			"[LuckShopServer] FAILED to save Luck.Equipped for",
			player.Name
		)
	end


	-- Unequip every other item
	local playerGui = player:FindFirstChild("PlayerGui")

	if playerGui then

		local main = playerGui:FindFirstChild("Main")

		if main then

			local frames = main:FindFirstChild("Frames")

			if frames then

				local rollShop = frames:FindFirstChild("RollShop")

				if rollShop then

					local scrollingFrame =
						rollShop:FindFirstChild("ScrollingFrame")

					if scrollingFrame then

						local container =
							scrollingFrame:FindFirstChild("Frame")

						if container then

							for _, otherItem in ipairs(
								container:GetChildren()
								) do

								if otherItem:IsA("GuiObject")
									and otherItem ~= item
								then

									if otherItem:GetAttribute(
										"Equipped"
										) == true then

										otherItem:SetAttribute(
											"Equipped",
											false
										)

									end

								end

							end

						end

					end

				end

			end

		end

	end


	print(
		"[LuckShopServer] PURCHASE SUCCESS:",
		itemName
	)

	print(
		"[LuckShopServer] Purchased =",
		item:GetAttribute("Purchased")
	)

	print(
		"[LuckShopServer] Equipped =",
		item:GetAttribute("Equipped")
	)

	print("==================================================")

end)


print("==================================================")
print("[LuckShopServer] READY")
print("==================================================")


--==================================================
-- PATCH SHOP ITEMS ON JOIN
-- Corrects every player's shop Luck/Price attributes to the
-- canonical values the moment their UI loads.
--==================================================

Players.PlayerAdded:Connect(function(player)
	task.spawn(patchShopItemsForPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(patchShopItemsForPlayer, player)
end