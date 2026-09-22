--[[ ChickenCombatInputHandler (server, Script). The RemoteEvent boundary ChickenCombatService's own
	header comment asked for but never got built: "call RequestAttack(model)/RequestDash(model, direction)
	from whatever RemoteEvent handler validates the calling player owns model". Previously there was no
	RemoteEvent at all - every attack/dash in this project's whole history was triggered by a script
	directly calling ChickenCombatService, never by real client input.

	Security: the model a request applies to is ALWAYS resolved server-side via MatchService or
	PracticeService's own GetPlayerChicken(player) - the client never sends a model reference, so there is
	no way to name someone else's chicken. Every request also requires CanPlayerFight(player) from whichever
	of the two the player is actually in (a real match's Active state, or an active practice session), is
	rate-limited independently of ChickenCombatService's own busy/cooldown logic, and Dash's direction
	argument is type-checked (Vector3 or nil; anything else is a silent no-op, never an error) before it
	ever reaches ChickenCombatService's own NaN/inf sanitizer. ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ChickenCombatService = require(ServerScriptService.Combat:WaitForChild("ChickenCombatService"))
local MatchService = require(ServerScriptService.Combat:WaitForChild("MatchService"))
local PracticeService = require(ServerScriptService.Combat:WaitForChild("PracticeService"))

-- a player is only ever in a real match OR practice, never both (Enter/Queue both check the other's
-- state isn't already occupied) - checking both here just means one input path serves either context.
local function canFight(player: Player): boolean
	return MatchService.CanPlayerFight(player) or PracticeService.CanPlayerFight(player)
end
local function resolveChicken(player: Player): Model?
	return MatchService.GetPlayerChicken(player) or PracticeService.GetPlayerChicken(player)
end

local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local attackRemote = combatFolder:FindFirstChild("AttackRequest")
if not attackRemote then
	attackRemote = Instance.new("RemoteEvent")
	attackRemote.Name = "AttackRequest"
	attackRemote.Parent = combatFolder
end
local dashRemote = combatFolder:FindFirstChild("DashRequest")
if not dashRemote then
	dashRemote = Instance.new("RemoteEvent")
	dashRemote.Name = "DashRequest"
	dashRemote.Parent = combatFolder
end

-- independent of ChickenCombatService's own busy/cooldown rejection: caps raw remote fire rate so a
-- malicious client spamming the remote (even while every call is individually rejected) can't burn
-- server time re-validating hundreds of times per second.
local RATE_LIMIT_WINDOW = 0.1
local lastFire = setmetatable({}, { __mode = "k" })

local function rateLimited(player: Player): boolean
	local now = os.clock()
	local last = lastFire[player]
	if last and now - last < RATE_LIMIT_WINDOW then
		return true
	end
	lastFire[player] = now
	return false
end

attackRemote.OnServerEvent:Connect(function(player: Player)
	if rateLimited(player) then
		return
	end
	if not canFight(player) then
		return
	end
	local model = resolveChicken(player)
	if not model then
		return
	end
	ChickenCombatService.RequestAttack(model)
end)

dashRemote.OnServerEvent:Connect(function(player: Player, direction)
	if rateLimited(player) then
		return
	end
	if direction ~= nil and typeof(direction) ~= "Vector3" then
		return -- malformed payload: silently dropped, never errors, never reaches ChickenCombatService
	end
	if not canFight(player) then
		return
	end
	local model = resolveChicken(player)
	if not model then
		return
	end
	ChickenCombatService.RequestDash(model, direction)
end)
