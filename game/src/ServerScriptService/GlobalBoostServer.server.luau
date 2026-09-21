local Players             = game:GetService("Players")
local RS                  = game:GetService("ReplicatedStorage")
local MessagingService    = game:GetService("MessagingService")
local ServerScriptService = game:GetService("ServerScriptService")

local AdminConfig           = require(ServerScriptService:WaitForChild("AdminConfig"))
local SpeedBoostClientEvent = RS:WaitForChild("SpeedBoostClientEvent")
local RagdollClientEvent    = RS:WaitForChild("RagdollClientEvent")
local AdminActionRemote     = RS:WaitForChild("AdminActionRemote")

local TOPIC_SPEED   = "GlobalSpeedBoost"
local TOPIC_RAGDOLL = "GlobalRagdoll"
local MAX_SPEED_MULTIPLIER = 2

local boostEndTime   = 0
local boostActive    = false
local boostResetTask = nil

local function applySpeedBoost(duration)
	if boostResetTask then task.cancel(boostResetTask) boostResetTask = nil end
	if boostActive then
		for _, p in ipairs(Players:GetPlayers()) do
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed /= MAX_SPEED_MULTIPLIER end
		end
	end
	boostActive  = true
	boostEndTime = tick() + duration
	for _, p in ipairs(Players:GetPlayers()) do
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed *= MAX_SPEED_MULTIPLIER end
		SpeedBoostClientEvent:FireClient(p, duration)
	end
	boostResetTask = task.delay(duration, function()
		boostActive = false
		boostEndTime = 0
		for _, p in ipairs(Players:GetPlayers()) do
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed /= MAX_SPEED_MULTIPLIER end
			SpeedBoostClientEvent:FireClient(p, -1)
		end
		boostResetTask = nil
	end)
end

local function applyRagdoll()
	for _, p in ipairs(Players:GetPlayers()) do
		RagdollClientEvent:FireClient(p)
	end
end

Players.PlayerAdded:Connect(function(player)
	local remaining = boostEndTime - tick()
	if remaining <= 0 or not boostActive then return end
	player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed *= MAX_SPEED_MULTIPLIER end
	end)
	SpeedBoostClientEvent:FireClient(player, math.floor(remaining))
end)

pcall(function()
	MessagingService:SubscribeAsync(TOPIC_SPEED, function(msg)
		local duration = math.clamp(tonumber(msg.Data) or 60, 1, 3600)
		applySpeedBoost(duration)
	end)
end)

pcall(function()
	MessagingService:SubscribeAsync(TOPIC_RAGDOLL, function()
		applyRagdoll()
	end)
end)

AdminActionRemote.OnServerEvent:Connect(function(player, action, data)
	if not AdminConfig.isAdmin(player) then return end
	if typeof(data) ~= "table" then data = {} end

	if action == "boost_speed" then
		local duration = math.clamp(tonumber(data.duration) or 60, 1, 3600)
		-- scope "server" = this server only, skip MessagingService
		if data.scope == "server" then
			applySpeedBoost(duration)
		else
			local ok = pcall(MessagingService.PublishAsync, MessagingService, TOPIC_SPEED, tostring(duration))
			if not ok then applySpeedBoost(duration) end
		end

	elseif action == "boost_ragdoll" then
		if data.scope == "server" then
			applyRagdoll()
		else
			local ok = pcall(MessagingService.PublishAsync, MessagingService, TOPIC_RAGDOLL, "fire")
			if not ok then applyRagdoll() end
		end
	end
end)
