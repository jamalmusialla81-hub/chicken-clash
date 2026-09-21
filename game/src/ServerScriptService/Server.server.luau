--[[
	SERVER LOADER (rebuilt)

	The original loader was accidentally overwritten by a template script, so this
	one was reconstructed from how the modules in ServerScriptService.Services are
	written. It is NOT the original code. If you have the original, prefer that.

	What it does:
	  1. require() every ModuleScript in Services
	  2. call :init() on each one that has it   (ReplicationService, LeaderstatsService first)
	  3. call :start() on each one that has it  (DataService first)

	DataService:start() runs last of all the init calls so every service has already
	connected to GlobalSignals.DataService.PlayerProfileLoaded before any profile loads.
	A failure in one service is reported but never stops the others.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Services")

local INIT_FIRST = { "ReplicationService", "LeaderstatsService" }
local START_FIRST = { "DataService" }

local function protectedCall(label: string, fn: () -> ())
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then
		warn(`[Server loader] {label} failed:\n{err}`)
	end
end

local loaded: { [string]: any } = {}

for _, module in Services:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, result = xpcall(require, debug.traceback, module)
		if ok and type(result) == "table" then
			loaded[module.Name] = result
		elseif not ok then
			warn(`[Server loader] could not require {module.Name}:\n{result}`)
		end
	end
end

local function orderedNames(first: { string }): { string }
	local names, seen = {}, {}
	for _, name in first do
		if loaded[name] then
			table.insert(names, name)
			seen[name] = true
		end
	end
	local rest = {}
	for name in loaded do
		if not seen[name] then
			table.insert(rest, name)
		end
	end
	table.sort(rest)
	table.move(rest, 1, #rest, #names + 1, names)
	return names
end

-- init phase. Each init runs in its own thread so one that yields cannot block the rest.
for _, name in orderedNames(INIT_FIRST) do
	local service = loaded[name]
	if type(service.init) == "function" then
		task.spawn(protectedCall, `{name}:init`, function()
			service:init()
		end)
	end
end

-- start phase
for _, name in orderedNames(START_FIRST) do
	local service = loaded[name]
	if type(service.start) == "function" then
		task.spawn(protectedCall, `{name}:start`, function()
			service:start()
		end)
	end
end

print("[Server loader] services initialized")
