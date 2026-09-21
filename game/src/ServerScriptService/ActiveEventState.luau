local ActiveEventState = {}

local activeEventId

function ActiveEventState.Set(eventId)
	activeEventId = eventId
end

function ActiveEventState.Get()
	return activeEventId
end

function ActiveEventState.Clear()
	activeEventId = nil
end

return ActiveEventState
