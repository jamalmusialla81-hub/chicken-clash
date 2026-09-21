local RS                  = game:GetService("ReplicatedStorage")
local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local AdminConfig       = require(ServerScriptService:WaitForChild("AdminConfig"))
local AdminActionRemote = RS:WaitForChild("AdminActionRemote")
local AdminCheckResult  = RS:WaitForChild("AdminCheckResult")

-- Rate limit: jeden check na gracza co 5 sekund (blokuje exploit spamowania)
local lastCheck = {}
local CHECK_COOLDOWN = 5

AdminActionRemote.OnServerEvent:Connect(function(player, action)
	if action ~= "check_admin" then return end
	local uid = player.UserId
	local now = tick()
	if lastCheck[uid] and (now - lastCheck[uid]) < CHECK_COOLDOWN then return end
	lastCheck[uid] = now
	AdminCheckResult:FireClient(player, AdminConfig.isAdmin(player))
end)

Players.PlayerRemoving:Connect(function(player)
	lastCheck[player.UserId] = nil
end)
