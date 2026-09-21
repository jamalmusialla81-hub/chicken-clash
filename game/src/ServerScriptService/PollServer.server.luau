local Players             = game:GetService("Players")
local RS                  = game:GetService("ReplicatedStorage")
local MessagingService    = game:GetService("MessagingService")
local ServerScriptService = game:GetService("ServerScriptService")

local AdminConfig       = require(ServerScriptService:WaitForChild("AdminConfig"))
local PollVoteRemote    = RS:WaitForChild("PollVoteRemote")
local PollEndRemote     = RS:WaitForChild("PollEndRemote")
local PollStartRemote   = RS:WaitForChild("PollStartRemote")
local PollUpdateRemote  = RS:WaitForChild("PollUpdateRemote")
local AdminActionRemote = RS:WaitForChild("AdminActionRemote")

local VOTE_COOLDOWN = 0.5

local poll = {
	active       = false,
	id           = 0,
	votes        = {option1 = 0, option2 = 0},
	voted        = {},  -- userId -> optionNum
	rateLimits   = {},  -- userId -> lastVoteTime
	thread       = nil,
}

local function broadcastVoteUpdate()
	local v1, v2 = poll.votes.option1, poll.votes.option2
	local total  = v1 + v2
	local pct1   = total > 0 and math.floor(v1 / total * 100 + 0.5) or 0
	local pct2   = total > 0 and math.floor(v2 / total * 100 + 0.5) or 0
	PollUpdateRemote:FireAllClients(v1, v2, pct1, pct2)
end

local function stopPoll()
	if poll.thread then pcall(task.cancel, poll.thread) poll.thread = nil end
	poll.active     = false
	poll.voted      = {}
	poll.rateLimits = {}
end

local function startPollLocal(question, opt1, opt2, duration, newId)
	stopPoll()
	poll.id     = newId
	poll.active = true
	poll.votes  = {option1 = 0, option2 = 0}

	local myId = newId
	poll.thread = task.spawn(function()
		task.wait(duration)
		if poll.id ~= myId or not poll.active then return end
		local v1, v2 = poll.votes.option1, poll.votes.option2
		stopPoll()
		pcall(MessagingService.PublishAsync, MessagingService, "GlobalPoll", {
			action = "end", v1 = v1, v2 = v2, pollId = myId,
		})
	end)
end

AdminActionRemote.OnServerEvent:Connect(function(player, action, data)
	if not AdminConfig.isAdmin(player) then return end
	if action ~= "poll_start" then return end
	if typeof(data) ~= "table" then return end

	local question = typeof(data.question) == "string" and data.question:sub(1, 150) or ""
	local opt1     = typeof(data.opt1) == "string"     and data.opt1:sub(1, 50)      or ""
	local opt2     = typeof(data.opt2) == "string"     and data.opt2:sub(1, 50)      or ""
	local duration = math.clamp(tonumber(data.duration) or 60, 5, 600)
	local scope    = typeof(data.scope) == "string" and data.scope or "global"  -- default to global if not provided

	if #question:gsub("%s", "") == 0 then return end
	if #opt1:gsub("%s", "") == 0 or #opt2:gsub("%s", "") == 0 then return end

	local newId = os.time()

	if scope == "server" then
		-- Server-only: run the poll locally, skip MessagingService entirely
		startPollLocal(question, opt1, opt2, duration, newId)
		PollStartRemote:FireAllClients(question, opt1, opt2, duration)
	else
		-- Global: publish to all servers via MessagingService; fall back to local on failure
		local ok = pcall(MessagingService.PublishAsync, MessagingService, "GlobalPoll", {
			action = "start", question = question, opt1 = opt1, opt2 = opt2,
			duration = duration, pollId = newId,
		})
		if not ok then
			startPollLocal(question, opt1, opt2, duration, newId)
			PollStartRemote:FireAllClients(question, opt1, opt2, duration)
		end
	end
end)

PollVoteRemote.OnServerEvent:Connect(function(player, optionNum)
	if not poll.active then return end
	if optionNum ~= 1 and optionNum ~= 2 then return end

	local uid = player.UserId
	if poll.voted[uid] then return end

	local now = tick()
	if poll.rateLimits[uid] and (now - poll.rateLimits[uid]) < VOTE_COOLDOWN then return end
	poll.rateLimits[uid] = now
	poll.voted[uid]      = optionNum

	local ok = pcall(MessagingService.PublishAsync, MessagingService, "GlobalPollVote", {
		option = optionNum, pollId = poll.id, userId = uid,
	})
	if not ok then
		if optionNum == 1 then poll.votes.option1 += 1 else poll.votes.option2 += 1 end
		broadcastVoteUpdate()
	end
end)

pcall(function()
	MessagingService:SubscribeAsync("GlobalPollVote", function(msg)
		local data = msg.Data
		if data.pollId ~= poll.id or not poll.active then return end
		if data.option == 1 then poll.votes.option1 += 1 else poll.votes.option2 += 1 end
		broadcastVoteUpdate()
	end)
end)

pcall(function()
	MessagingService:SubscribeAsync("GlobalPoll", function(msg)
		local data = msg.Data
		if data.action == "start" then
			startPollLocal(data.question, data.opt1, data.opt2, data.duration, data.pollId)
			PollStartRemote:FireAllClients(data.question, data.opt1, data.opt2, data.duration)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local uid = player.UserId
	poll.voted[uid]      = nil
	poll.rateLimits[uid] = nil
end)
