local Players             = game:GetService("Players")
local RS                  = game:GetService("ReplicatedStorage")
local MessagingService    = game:GetService("MessagingService")
local TweenService        = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")

local AdminConfig = require(ServerScriptService:WaitForChild("AdminConfig"))

local StartEventRemote      = RS:WaitForChild("StartEventRemote")
local EventEndedRemote      = RS:WaitForChild("EventEndedRemote")
local EventTickRemote       = RS:WaitForChild("EventTickRemote")
local GlobalAnnounceEvent   = RS:WaitForChild("GlobalAnnounceEvent")
local PollStartRemote       = RS:WaitForChild("PollStartRemote")
local PollEndRemote         = RS:WaitForChild("PollEndRemote")
local PollUpdateRemote      = RS:WaitForChild("PollUpdateRemote")
local SpeedBoostClientEvent = RS:WaitForChild("SpeedBoostClientEvent")
local RagdollClientEvent    = RS:WaitForChild("RagdollClientEvent")
local CameraShakeRemote     = RS:WaitForChild("CameraShakeRemote")
local TsunamiRemote         = RS:WaitForChild("TsunamiRemote")
local AdminActionRemote     = RS:WaitForChild("AdminActionRemote")

local function broadcastAll(remote, ...)
	for _, p in ipairs(Players:GetPlayers()) do
		remote:FireClient(p, ...)
	end
end

local function handleGlobalTsunami()
	broadcastAll(CameraShakeRemote)
	broadcastAll(TsunamiRemote)
	task.delay(2, function()
		local model = RS:FindFirstChild("Tsunami3")
		if not model then return end
		local clone     = model:Clone()
		clone.Name      = "Tsunami3_Active"
		clone.Parent    = workspace
		local startPos  = Vector3.new(0, 95.157, 163.432)
		local endPos    = Vector3.new(0, 95.157, -351.137)
		local delta     = endPos - startPos
		local firstPart = clone:FindFirstChildWhichIsA("BasePart")
		if firstPart then
			local offset = startPos - firstPart.Position
			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CFrame   = CFrame.new(part.Position + offset)
					part.Anchored = true
				end
			end
		end
		local ti = TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				TweenService:Create(part, ti, {Position = part.Position + delta}):Play()
			end
		end
		task.delay(7, function()
			if clone and clone.Parent then clone:Destroy() end
		end)
	end)
end

local function handleGlobalAnnounce(data)
	if typeof(data.username) ~= "string" or typeof(data.message) ~= "string" then return end
	GlobalAnnounceEvent:FireAllClients(data.username, data.message)
end

local function handleGlobalPoll(data)
	if data.action == "start" then
		PollStartRemote:FireAllClients(data.question, data.opt1, data.opt2, data.duration)
	elseif data.action == "end" then
		PollEndRemote:FireAllClients(data.v1 or 0, data.v2 or 0)
	elseif data.action == "vote_update" then
		local v1    = tonumber(data.v1) or 0
		local v2    = tonumber(data.v2) or 0
		local total = v1 + v2
		local pct1  = total > 0 and math.floor(v1 / total * 100 + 0.5) or 0
		local pct2  = total > 0 and math.floor(v2 / total * 100 + 0.5) or 0
		PollUpdateRemote:FireAllClients(v1, v2, pct1, pct2)
	end
end

local topicHandlers = {
	GlobalAnnounce = handleGlobalAnnounce,
	GlobalPoll     = handleGlobalPoll,
	GlobalTsunami  = function(_) handleGlobalTsunami() end,
}

for topic, handler in pairs(topicHandlers) do
	pcall(function()
		MessagingService:SubscribeAsync(topic, function(msg)
			local ok, err = pcall(handler, msg.Data)
			if not ok then warn("[GlobalServer] " .. topic .. ": " .. tostring(err)) end
		end)
	end)
end

local HANDLED_ACTIONS = {
	tsunami  = true,
	announce = true,
}

AdminActionRemote.OnServerEvent:Connect(function(player, action, data)
	if not AdminConfig.isAdmin(player) then return end
	if typeof(action) ~= "string" then return end
	if not HANDLED_ACTIONS[action] then return end

	if action == "tsunami" then
		-- scope "server" = this server only, skip MessagingService
		if typeof(data) == "table" and data.scope == "server" then
			handleGlobalTsunami()
		else
			local ok = pcall(MessagingService.PublishAsync, MessagingService, "GlobalTsunami", {})
			if not ok then handleGlobalTsunami() end
		end

	elseif action == "announce" then
		if typeof(data) ~= "table" then return end
		local message = tostring(data.message or ""):sub(1, 200)
		if #message:gsub("%s", "") == 0 then return end
		local payload = {username = player.Name, message = message}
		local ok = pcall(MessagingService.PublishAsync, MessagingService, "GlobalAnnounce", payload)
		if not ok then
			GlobalAnnounceEvent:FireAllClients(player.Name, message)
		end
	end
end)
