local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("DataService"))
local ChickenEggConfig = require(ReplicatedStorage:WaitForChild("ChickenEggConfig"))
local MutationConfig = require(ReplicatedStorage:WaitForChild("MutationConfig"))

local sellEvent = ReplicatedStorage:WaitForChild("SellEggbox")
local resultEvent = ReplicatedStorage:WaitForChild("SellEggboxResult")
local sellingPlayers = {}

local function findEggbox(player)
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")

	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") and item:GetAttribute("EggCount") ~= nil then
				return item
			end
		end
	end

	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") and item:GetAttribute("EggCount") ~= nil then
				return item
			end
		end
	end

	return nil
end

local function getPriceForEggModel(eggModelName)
	for _, data in pairs(ChickenEggConfig) do
		if data.eggModelName == eggModelName then
			return data.price
		end
	end
	return nil
end

local function getBoxContents(eggBox)
	local encoded = eggBox:GetAttribute("EggContents")
	if typeof(encoded) ~= "string" then
		return nil
	end
	local success, contents = pcall(function()
		return HttpService:JSONDecode(encoded)
	end)
	if not success or typeof(contents) ~= "table" then
		return nil
	end
	return contents
end

sellEvent.OnServerEvent:Connect(function(player)
	if sellingPlayers[player] then
		return
	end
	sellingPlayers[player] = true

	local success, err = pcall(function()
		local eggBox = findEggbox(player)
		if not eggBox then
			resultEvent:FireClient(player, 0, 0, "NO_BOX")
			return
		end

		local contents = getBoxContents(eggBox)
		local eggCount = eggBox:GetAttribute("EggCount")
		if not contents then
			local eggModelName = eggBox:GetAttribute("EggModelName")
			local price = getPriceForEggModel(eggModelName)
			if typeof(eggCount) ~= "number" or eggCount <= 0 or not price then
				warn("[EggboxSelling] Invalid eggbox data on " .. eggBox.Name)
				resultEvent:FireClient(player, 0, 0, "INVALID")
				return
			end
			contents = {}
			for _ = 1, math.floor(eggCount) do
				table.insert(contents, {eggModelName = eggModelName, price = price})
			end
		end

		eggCount = #contents
		if eggCount <= 0 then
			resultEvent:FireClient(player, 0, 0, "INVALID")
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local cash = leaderstats and leaderstats:FindFirstChild("Cash")
		if not cash then
			warn("[EggboxSelling] No Cash value found for " .. player.Name)
			resultEvent:FireClient(player, 0, eggCount, "ERROR")
			return
		end

		local payout = 0
		for _, entry in ipairs(contents) do
			local price = tonumber(entry.price) or getPriceForEggModel(entry.eggModelName)
			if not price then
				warn("[EggboxSelling] Invalid egg type in " .. eggBox.Name)
				resultEvent:FireClient(player, 0, eggCount, "INVALID")
				return
			end

			local multiplier = 1
			if typeof(entry.mutations) == "table" then
				for _, mutationName in ipairs(entry.mutations) do
					multiplier *= MutationConfig.GetMultiplier(mutationName)
				end
			end
			payout += math.floor(price * multiplier)
		end
		eggBox:Destroy()
		DataService:Increment(player, "Cash", payout)
		resultEvent:FireClient(player, payout, eggCount, "SOLD")
		print("[EggboxSelling]", player.Name, "sold", eggCount, "eggs for $" .. payout)
	end)

	sellingPlayers[player] = nil
	if not success then
		warn("[EggboxSelling] Sale failed: " .. tostring(err))
	end
end)

print("[EggboxSelling] Selling system is ready!")