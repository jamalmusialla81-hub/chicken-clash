local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("ShopRemotes")
local purchaseEvent = remotes:WaitForChild("PurchaseLuckBoost")
local resultEvent = remotes:WaitForChild("ShopResult")

local products = {
	Luck2x = { cost = 100, multiplier = 2, duration = 300, displayName = "2x Luck Boost" },
	Luck3x = { cost = 250, multiplier = 3, duration = 300, displayName = "3x Luck Boost" },
	Luck5x = { cost = 600, multiplier = 5, duration = 300, displayName = "5x Luck Boost" },
}

local function sendResult(player, success, message)
	resultEvent:FireClient(player, success, message)
end

local function purchase(player, productId)
	if typeof(productId) ~= "string" then
		sendResult(player, false, "Invalid shop item.")
		return
	end

	local product = products[productId]
	if not product then
		sendResult(player, false, "That boost is unavailable.")
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins or not (coins:IsA("IntValue") or coins:IsA("NumberValue")) then
		sendResult(player, false, "Coins are not ready yet.")
		return
	end

	if coins.Value < product.cost then
		sendResult(player, false, string.format("You need %d coins.", product.cost))
		return
	end

	coins.Value -= product.cost

	local now = os.time()
	local currentMultiplier = player:GetAttribute("GachaLuckMultiplier") or 1
	local currentExpiry = player:GetAttribute("GachaLuckBoostExpiresAt") or 0
	local startTime = math.max(now, currentExpiry)
	local multiplier = math.max(currentMultiplier, product.multiplier)

	player:SetAttribute("GachaLuckMultiplier", multiplier)
	player:SetAttribute("GachaLuckBoostExpiresAt", startTime + product.duration)
	sendResult(player, true, string.format("%s active for %d minutes!", product.displayName, product.duration / 60))
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("GachaLuckMultiplier", 1)
	player:SetAttribute("GachaLuckBoostExpiresAt", 0)
end)

purchaseEvent.OnServerEvent:Connect(purchase)
