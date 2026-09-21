local RS                  = game:GetService("ReplicatedStorage")
local Players             = game:GetService("Players")
local MessagingService    = game:GetService("MessagingService")
local ServerScriptService = game:GetService("ServerScriptService")

local AdminConfig          = require(ServerScriptService:WaitForChild("AdminConfig"))
local EventModule          = require(RS:WaitForChild("EventModule"))
local StartEventRemote     = RS:WaitForChild("StartEventRemote")
local EventTickRemote      = RS:WaitForChild("EventTickRemote")
local EventEndedRemote     = RS:WaitForChild("EventEndedRemote")
local AnnounceRemote       = RS:WaitForChild("GlobalAnnounceEvent")
local CameraShakeRemote    = RS:WaitForChild("CameraShakeRemote")
local AdminActionRemote    = RS:WaitForChild("AdminActionRemote")
local EventTransitionReady = RS:WaitForChild("EventTransitionReady")
local ActiveEventState = require(ServerScriptService:WaitForChild("ActiveEventState"))

local currentEvent        = nil
local currentThread       = nil
local activeEventId       = nil
local tickThread          = nil
local activeTriggerUserId = nil

local function broadcastAll(remote, ...)
	for _, p in ipairs(Players:GetPlayers()) do
		remote:FireClient(p, ...)
	end
end

local function getMusicId(musicKey)
	local cfg = RS:FindFirstChild("MusicConfig")
	if not cfg then return "" end
	local sv = cfg:FindFirstChild(musicKey)
	return sv and sv.Value or ""
end

local function stopCurrentEvent()
	if currentEvent then
		local ok, err = pcall(currentEvent.onEnd)
		if not ok then warn("[EventServer] onEnd error: " .. tostring(err)) end
		currentEvent = nil
	end
	if currentThread then pcall(task.cancel, currentThread) currentThread = nil end
	if tickThread    then pcall(task.cancel, tickThread)    tickThread    = nil end
	activeEventId       = nil
	ActiveEventState.Clear()
	activeTriggerUserId = nil
end

local function startTickTimer(eventId, duration)
	if tickThread then pcall(task.cancel, tickThread) end
	tickThread = task.spawn(function()
		local remaining = duration
		while remaining > 0 do
			task.wait(1)
			remaining -= 1
			broadcastAll(EventTickRemote, eventId, remaining)
		end
		broadcastAll(EventEndedRemote, eventId)
		stopCurrentEvent()
	end)
end

EventTransitionReady.OnServerInvoke = function(player, eventId)
	if eventId ~= activeEventId then return false end
	local eventDef = EventModule.getById(eventId)
	if not eventDef then return false end
	local ok, err = pcall(eventDef.onStart, activeTriggerUserId)
	if not ok then warn("[EventServer] onStart error: " .. tostring(err)) end
	currentEvent = eventDef
	return true
end

local function runEventLocal(data)
	stopCurrentEvent()
	local eventDef = EventModule.getById(data.eventId)
	if not eventDef then return end
	local duration = math.clamp(tonumber(data.duration) or 60, 1, 3600)
	local musicId  = getMusicId(eventDef.musicKey or "")

	activeEventId       = data.eventId
	ActiveEventState.Set(data.eventId)
	activeTriggerUserId = data.triggerUserId

	broadcastAll(CameraShakeRemote)
	if eventDef.announceMsg then
		AnnounceRemote:FireAllClients("__EVENT__", eventDef.announceMsg, eventDef.announceColor)
	end
	broadcastAll(StartEventRemote, data.eventId, duration, musicId, eventDef.icon or "")
	startTickTimer(data.eventId, duration)
end

pcall(function()
	MessagingService:SubscribeAsync("GlobalEvent", function(msg)
		local data = msg.Data
		if data.action == "start" then
			runEventLocal(data)
		elseif data.action == "end" then
			if currentEvent and currentEvent.id == data.eventId then
				stopCurrentEvent()
				broadcastAll(EventEndedRemote, data.eventId)
			end
		end
	end)
end)

AdminActionRemote.OnServerEvent:Connect(function(player, action, data)
	if not AdminConfig.isAdmin(player) then return end
	if action ~= "event" then return end
	if typeof(data) ~= "table" then return end

	local eventId  = tostring(data.eventId or "")
	local duration = math.clamp(tonumber(data.duration) or 60, 1, 3600)
	if not EventModule.getById(eventId) then return end

	local eventDef = EventModule.getById(eventId)
	local musicId  = getMusicId(eventDef.musicKey or "")
	local payload  = {
		action        = "start",
		eventId       = eventId,
		duration      = duration,
		musicId       = musicId,
		icon          = eventDef.icon or "",
		announceMsg   = eventDef.announceMsg,
		announceColor = eventDef.announceColor,
		triggerUserId = player.UserId,
	}

	-- If scope is "server", run locally only — skip MessagingService
	if data.scope == "server" then
		runEventLocal(payload)
	else
		local ok = pcall(MessagingService.PublishAsync, MessagingService, "GlobalEvent", payload)
		if not ok then runEventLocal(payload) end
	end
end)
