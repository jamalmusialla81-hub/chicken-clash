local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sellEvent = ReplicatedStorage:WaitForChild("SellEggbox")

sellEvent.OnServerEvent:Connect(function(player)
	warn("[EggboxSelling] Ignored duplicate sale listener for " .. player.Name)
end)

print("[EggboxSelling] Duplicate listener disabled; ServerScriptService/Script owns sales.")