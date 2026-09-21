local MarketplaceServicePlus = {}
MarketplaceServicePlus.__index = MarketplaceServicePlus

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local ServerUtils = ServerScriptService.Utils
local ServerClasses = ServerScriptService.Classes
local ReplicatedUtils = ReplicatedStorage.Utils
local Config = ReplicatedStorage.Configuration
local GlobalSignals = require(ServerUtils.GlobalSignals)
local ReplicationService = require(script.Parent.ReplicationService)
local DataService = require(script.Parent.DataService)
local Packets = require(ReplicatedUtils.Packets)

local General = require(Config.General)
local Passes = require(Config.Passes)
local PassesRewards = require(script.PassesRewards)
local Products = require(Config.Products)
local ProdcutsRewards = require(script.ProductsRewards)
local Packs = require(Config.Packs)
local PacksRewards = require(script.PacksRewards)

local PlayerPasses = {}
local GiftingCache = {}

local function LoadPlayerPasses(player:Player, profile):{[string]: {["Gifted"]:boolean}}
	local ownedPasses = {}
	for passName, passInfo in Passes do
		if profile.GiftedPasses and profile.GiftedPasses[passName] then
			ownedPasses[passName] = {Gifted = true}
			continue
		end

		local success, data = pcall(function ()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passInfo.PassID)
		end)
		if success and data then
			ownedPasses[passName] = {Gifted = false}
		end
	end
	return ownedPasses
end

local function GetPassName(passID:number):string
	for passName, passInfo in Passes do
		if passInfo.PassID == passID then
			return passName
		end
	end
	return nil
end

local function GetProductInfo(productID:number):{type:string, name:string}
	for passName, passInfo in Passes do
		if passInfo.GiftID == productID then
			return {type = "Pass Gift", name = passName}
		end
	end
	for productName, productInfo in Products do
		if productInfo.ProductID == productID then
			return {type = "Product Purchase", name = productName}
		elseif productInfo.GiftID == productID then
			return {type = "Product Gift", name = productName}
		end
	end
	for packName, packInfo in Packs do
		if packInfo.ProductID == productID then
			return {type = "Pack Purchase", name = packName}
		end
	end
	return {type = "Unknown", name = ""}
end

function MarketplaceServicePlus:init()
	GlobalSignals.DataService.PlayerProfileLoaded:Connect(function (player:Player, profile)
		local ownedPasses = LoadPlayerPasses(player, profile)
		if ownedPasses then
			PlayerPasses[player.UserId] = ownedPasses
			local PassReplicationEntry = ReplicationService.new(`{player.UserId}_Passes`, table.clone(ownedPasses), false, {player})
			for passName, passData in pairs(ownedPasses) do
				MarketplaceServicePlus:GivePass(player.UserId, passName, false)
			end
		end
		
		local plrPacks = profile.Packs
		local PackReplicationEntry = ReplicationService.new(`{player.UserId}_Packs`, table.clone(plrPacks), false, {player})
	end)

	GlobalSignals.DataService.ProfileMessageProcess:Connect(function (player:Player, message)
		if message.MessageType ~= "Gift" then return end
		repeat task.wait(.1) until not player.Parent or PlayerPasses[player.UserId]
		if message.GiftType == "Pass" then
			MarketplaceServicePlus:GivePass(player.UserId, message.GiftItemName, true, message.Gifter, message.Timestamp, true)
		elseif message.GiftType == "Product" then
			MarketplaceServicePlus:GiveProduct(player.UserId, message.GiftItemName, true, message.Gifter, message.Timestamp, true)
		end
	end)

	Players.PlayerRemoving:Connect(function (player)
		if PlayerPasses[player.UserId] then
			PlayerPasses[player.UserId] = nil
		end

		if GiftingCache[player.UserId] then
			GiftingCache[player.UserId] = nil
		end

		ReplicationService.Destroy(`{player.UserId}_Passes`)
		ReplicationService.Destroy(`{player.UserId}_Packs`)
	end)

	MarketplaceService.ProcessReceipt = function (receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

		local productID:number = receiptInfo.ProductId
		local productInfo = GetProductInfo(productID)

		if productInfo.type == "Pass Gift" then
			local cache = GiftingCache[player.UserId]
			if cache and cache.Target and cache.PassName == productInfo.name then
				MarketplaceServicePlus:GivePass(cache.Target, cache.PassName, true, player.UserId, os.time(), true) 
			end
		elseif productInfo.type == "Product Gift" then
			local cache = GiftingCache[player.UserId]
			if cache and cache.Target and cache.ProductName == productInfo.name then
				MarketplaceServicePlus:GiveProduct(cache.Target, cache.ProductName, true, player.UserId, os.time(), true)
			end
		elseif productInfo.type == "Product Purchase" then
			MarketplaceServicePlus:GiveProduct(player.UserId, productInfo.name, false, nil, os.time(), true)
		elseif productInfo.type == "Pack Purchase" then
			MarketplaceServicePlus:GivePack(player, productInfo.name)
		end

		GiftingCache[player.UserId] = nil

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

function MarketplaceServicePlus:start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function (player:Player, passID:number, purchased:boolean)
		if not purchased then return end
		local passName = GetPassName(passID)
		if not passName then return end
		MarketplaceServicePlus:GivePass(player.UserId, passName, false, nil, nil, true) 
	end)
	Packets.Marketplace.CheckPassOwned.OnServerInvoke = function (player:Player, targetID:number, passName:string)
		return MarketplaceServicePlus:PlayerOwnsPass(targetID, passName)
	end
	Packets.Marketplace.StartGifting.OnServerEvent:Connect(function (player:Player, targetID:number, giftType:string, giftName:string)
		local fromAdmin = table.find(General.Admins, player.UserId)
		if giftType == "Pass" then
			if fromAdmin then
				MarketplaceServicePlus:GivePass(targetID, giftName, true, player.UserId, os.time(), true)
				return
			end
			MarketplaceServicePlus:StartPassGift(player, giftName, targetID)
		elseif giftType == "Product" then
			if fromAdmin then
				MarketplaceServicePlus:GiveProduct(targetID, giftName, true, player.UserId, os.time(), true)
				return
			end
			MarketplaceServicePlus:StartProductGift(player, giftName, targetID)
		end
	end)
end

function MarketplaceServicePlus:PlayerOwnsPack(player:Player, packName:string)
	local plrPacks = DataService:Get(player, "Packs")
	print(plrPacks)
	print(packName)
	if table.find(plrPacks, packName) then
		return true
	end
	return false
end

function MarketplaceServicePlus:PlayerOwnsPass(targetID:number, passName:string):boolean
	local ownsPass = false
	local targetPlayer = Players:GetPlayerByUserId(targetID)

	if targetPlayer then
		if PlayerPasses[targetID] and PlayerPasses[targetID][passName] then
			ownsPass = true
		else
			ownsPass = MarketplaceService:UserOwnsGamePassAsync(targetID, Passes[passName].PassID)
		end
	else
		local targetProfile = DataService:OfflineProfileRead(targetID)
		if targetProfile then
			local targetProfileData = targetProfile.Data
			if targetProfileData.GiftedPasses and targetProfileData.GiftedPasses[passName] then
				ownsPass = true
			else
				if targetProfile.global_updates then
					for _, gift in targetProfile.global_updates do
						local giftData = gift[2]
						if giftData.MessageType == "Gift" and giftData.GiftType == "Pass" and giftData.GiftItemName == passName then
							ownsPass = true
							break
						end
					end
				end
				if not ownsPass then
					ownsPass = MarketplaceService:UserOwnsGamePassAsync(targetID, Passes[passName].PassID)
				end
			end
		end
	end
	return ownsPass
end

function MarketplaceServicePlus:StartPassGift(gifter:Player, passName:string, targetID:number)
	if MarketplaceServicePlus:PlayerOwnsPass(targetID, passName) then
		Packets.Notification.Prompt:FireClient(gifter, "Error", "Player already owns the gamepass")
		return false 
	end

	local giftProductID = Passes[passName].GiftID
	if not giftProductID then return end

	GiftingCache[gifter.UserId] = {
		PassName = passName,
		Target = targetID
	}
	Packets.Marketplace.PromptStart:FireClient(gifter)
	MarketplaceService:PromptProductPurchase(gifter, giftProductID)
end

function MarketplaceServicePlus:StartProductGift(gifter:Player, productName:string, targetID:number)
	local giftProductID = Products[productName].GiftID
	if not giftProductID then return end

	GiftingCache[gifter.UserId] = {
		ProductName = productName,
		Target = targetID
	}
	Packets.Marketplace.PromptStart:FireClient(gifter)
	MarketplaceService:PromptProductPurchase(gifter, giftProductID)
end

function MarketplaceServicePlus:GivePass(playerID:number, passName:string, isGift:boolean, giftSenderID:number?, timestamp:number?, isNew:boolean)
	local TargetPlayer = Players:GetPlayerByUserId(playerID)

	if not TargetPlayer then
		if isGift then
			DataService:MessagePlayer(playerID, {
				GiftType = "Pass",
				GiftItemName = passName,
				Timestamp = timestamp,
				Gifter = giftSenderID
			}, "Gift")
		end
	else
		if not PlayerPasses[playerID] then PlayerPasses[playerID] = {} end
		PlayerPasses[playerID][passName] = {Gifted = (isGift == true)}

		local playerGiftedPasses = DataService:Get(TargetPlayer, "GiftedPasses") 
		if playerGiftedPasses then
			if isGift then
				playerGiftedPasses[passName] = true
			end
		end

		GlobalSignals.MarketplaceService.PassAcquired:Fire(TargetPlayer, passName)

		local replication = ReplicationService.new(`{playerID}_Passes`)
		replication.Data = table.clone(PlayerPasses[playerID])
		replication:PushData()

		local rewardFunction = PassesRewards[passName]
		if rewardFunction then
			task.spawn(function()
				local success, err
				for i = 1, 5 do
					success, err = pcall(function ()
						rewardFunction(TargetPlayer)
					end)
					if success then break end
					task.wait(1)
				end
			end)
		end
	end

	if isNew then
		if isGift then
			local gifter = Players:GetPlayerByUserId(giftSenderID)
			if gifter then
				Packets.Notification.Prompt:FireClient(gifter, "Success", "Sent gift successfully 🎉")
				Packets.Conffeti.Emit:FireClient(gifter)
			end
			if TargetPlayer then
				Packets.Notification.Prompt:FireClient(TargetPlayer, "Success", `Someone sent you {passName} gamepass 🎉`)
			end
		else
			if TargetPlayer then
				Packets.Notification.Prompt:FireClient(TargetPlayer, "Success", `Purchased {passName} gamepass successfully 🎉`)
				Packets.Conffeti.Emit:FireClient(TargetPlayer)
			end
		end
	end
end

function MarketplaceServicePlus:GiveProduct(playerID:number, productName:string, isGift:boolean, giftSenderID:number?, timestamp:number?, isNew:boolean)
	local TargetPlayer = Players:GetPlayerByUserId(playerID)

	if not TargetPlayer then
		if isGift then
			DataService:MessagePlayer(playerID, {
				GiftType = "Product",
				GiftItemName = productName,
				Timestamp = timestamp,
				Gifter = giftSenderID
			}, "Gift")
		end
	else
		local rewardFunction = ProdcutsRewards[productName]
		if not rewardFunction then return end

		task.spawn(function()
			local success, err
			for i = 1, 5 do
				success, err = pcall(function ()
					rewardFunction(TargetPlayer)
				end)
				if success then break end
				task.wait(1)
			end
		end)
	end
	if isNew then
		if isGift then
			local gifter = Players:GetPlayerByUserId(giftSenderID)
			if gifter then
				Packets.Notification.Prompt:FireClient(gifter, "Success", "Sent gift successfully 🎉")
				Packets.Conffeti.Emit:FireClient(gifter)
			end
			if TargetPlayer then
				Packets.Notification.Prompt:FireClient(TargetPlayer, "Success", `Someone sent you {productName} 🎉`)
			end
		else
			if TargetPlayer then
				Packets.Notification.Prompt:FireClient(TargetPlayer, "Success", `Purchased {productName} successfully 🎉`)
				Packets.Conffeti.Emit:FireClient(TargetPlayer)
			end
		end
	end
end

function MarketplaceServicePlus:GivePack(player:Player, packName:string)
	local plrPacks = DataService:Get(player, "Packs")
	if not plrPacks then return false end
	if table.find(plrPacks, packName) then return false end
	DataService:ArrayInsert(player, "Packs", packName)
	
	local rewardFunction = PacksRewards[packName]
	
	task.spawn(function()
		local success, err
		for i = 1, 5 do
			success, err = pcall(function ()
				rewardFunction(player)
			end)
			if success then break end
			task.wait(1)
		end
	end)
	Packets.Notification.Prompt:FireClient(player, "Success", `Purchased {packName} successfully 🎉`)
	Packets.Conffeti.Emit:FireClient(player)
	
	local replication = ReplicationService.new(`{player.UserId}_Packs`)
	replication.Data = table.clone( DataService:Get(player, "Packs"))
	replication:PushData()
end

return MarketplaceServicePlus