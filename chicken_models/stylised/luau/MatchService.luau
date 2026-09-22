--[[ MatchService (server, authoritative). The core 1v1 match loop this project never had - previously
	every combat/camera/VFX system was verified by scripting a CombatChicken clone directly; nothing ever
	queued two players, spawned their fighters, ran rounds, or returned them to the lobby.

	State machine per match: Preparing -> Entrance -> Countdown -> Active -> RoundEnd -> (loop back to
	Countdown for round 2/3, or) -> Results -> Returning. A player's OWN state is published on the Player
	instance as attributes (MatchState, MatchOpponentName, MatchRoundWins/OpponentRoundWins,
	MatchCountdownEndsAt, MatchRoundEndsAt, MatchResult) purely for client HUD display - these are
	server-authored (a LocalScript writing to its own Player's attributes never replicates to the server or
	other clients, so this is safe to read-only trust client-side) - but combat legality itself is NEVER
	decided from an attribute: ChickenCombatInputHandler calls MatchService.CanPlayerFight/GetPlayerChicken
	directly, so the model a request applies to is always resolved server-side from real match state, never
	from anything the client sends.

	No real second player available: queuing alone for BOT_FALLBACK_WAIT seconds pairs you with a
	server-controlled practice-bot opponent (clearly named, no real Player/OwnerUserId, so the camera/HUD
	auto-wiring correctly never treats it as anyone's own chicken) so the entire loop is testable solo. ]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local ChickenStateService = require(script.Parent:WaitForChild("ChickenStateService"))
local ChickenCombatService = require(script.Parent:WaitForChild("ChickenCombatService"))
local ChickenHealthService = require(script.Parent:WaitForChild("ChickenHealthService"))
local ChickenMovementDriver = require(script.Parent:WaitForChild("ChickenMovementDriver"))
local folder = game:GetService("ReplicatedStorage"):WaitForChild("ChickenClash")
local Catalog = require(folder:WaitForChild("GoldenChickenAnimationCatalog"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local cameraDirective = combatFolder:FindFirstChild("MatchCameraDirective")
if not cameraDirective then
	cameraDirective = Instance.new("RemoteEvent")
	cameraDirective.Name = "MatchCameraDirective"
	cameraDirective.Parent = combatFolder
end

local MatchService = {}

-- Real bug found in live testing: Roblox's default CharacterAutoLoads silently auto-respawns a player
-- with a brand-new DEFAULT avatar a few seconds after their Humanoid dies - which fired mid-match (a
-- round loss KOs the fighter's Humanoid) and replaced the custom fighter clone out from under
-- MatchService without it ever knowing, teleporting the player back to the world's default spawn while
-- the match server-side still thought they were fighting. Disabling auto-load and driving every
-- (re)spawn explicitly (initial join here, return-to-lobby in teardownMatch) is the standard fix for any
-- Roblox game using a non-default Character model.
Players.CharacterAutoLoads = false
Players.PlayerAdded:Connect(function(player)
	player:LoadCharacter()
end)

local MAX_HEALTH = 100
local ROUND_DURATION = 60
local COUNTDOWN_DURATION = 3
local WINS_NEEDED = 2
local BOT_FALLBACK_WAIT = 8
local SUDDEN_DEATH_DURATION = 10
local RETURN_DELAY = 4
local COMBAT_RIG_TEMPLATE_NAME = "Golden Chicken" -- only combat-ready chicken today; Phase 6 adds a second

local arenasFolder = workspace.Map.Arenas
local matchRigsFolder = workspace:FindFirstChild("ActiveMatches") or Instance.new("Folder")
matchRigsFolder.Name = "ActiveMatches"
matchRigsFolder.Parent = workspace

local queue = {} -- ordered list of real Players waiting
local queuedSince = {} -- Player -> os.clock()
local playerToMatch = setmetatable({}, { __mode = "k" }) -- Player -> Match
local matches = {} -- matchId -> Match
local matchIdCounter = 0

local BOT = setmetatable({ Name = "Practice Bot", isBot = true }, { __tostring = function() return "Practice Bot" end })

local function isBot(side)
	return type(side) == "table" and side.isBot == true
end

local function sideKey(side)
	return isBot(side) and "bot" or side
end

--============================== attribute publishing (display only) ==============================--
local function publish(player, name, value)
	if isBot(player) then
		return
	end
	player:SetAttribute(name, value)
end

local function publishBoth(match, name, valueFor)
	publish(match.players[1], name, valueFor(match.players[1], match.players[2]))
	publish(match.players[2], name, valueFor(match.players[2], match.players[1]))
end

--============================== arena reservation ==============================--
local function reserveArena()
	for _, arena in ipairs(arenasFolder:GetChildren()) do
		if arena:IsA("Model") and not arena:GetAttribute("Reserved") then
			arena:SetAttribute("Reserved", true)
			return arena
		end
	end
	return nil
end

local function releaseArena(arena)
	if arena then
		arena:SetAttribute("Reserved", false)
	end
end

--============================== chicken spawn/despawn ==============================--
local function spawnFighter(match, side, spawnAttachment)
	local template = ServerStorage.CombatChickens[COMBAT_RIG_TEMPLATE_NAME]
	local clone = template:Clone()
	clone.Name = isBot(side) and "PracticeBot_Fighter" or (side.Name .. "_Fighter")
	clone:PivotTo(spawnAttachment.WorldCFrame)
	clone.Parent = match.rigFolder

	CollectionService:AddTag(clone, "CombatChicken")
	if not isBot(side) then
		clone:SetAttribute("OwnerUserId", side.UserId)
	end
	clone:SetAttribute("MatchId", match.id)
	ChickenStateService.Activate(clone, isBot(side) and nil or side)
	ChickenHealthService.Init(clone, MAX_HEALTH)
	ChickenMovementDriver.Attach(clone)

	if not isBot(side) then
		local prevChar = side.Character
		side.Character = clone
		if prevChar and prevChar ~= clone then
			prevChar:Destroy()
		end
	end

	return clone
end

local function despawnFighter(match, side)
	local model = match.chickens[sideKey(side)]
	if not model then
		return
	end
	ChickenMovementDriver.Detach(model)
	ChickenHealthService.Stop(model)
	ChickenStateService.Deactivate(model)
	match.chickens[sideKey(side)] = nil
	if model.Parent then
		model:Destroy()
	end
end

--============================== bot AI (simple, server-only, clearly a placeholder opponent) ==============================--
local function runBotAI(match)
	task.spawn(function()
		while match.state ~= "Returning" and match.state ~= nil do
			task.wait(0.4 + math.random() * 0.4)
			if match.state ~= "Active" then
				continue
			end
			local bot = match.chickens.bot
			local human = match.chickens[match.players[1] == BOT and match.players[2] or match.players[1]]
			if not bot or not bot.Parent or not human or not human.Parent then
				continue
			end
			local botHum = bot:FindFirstChildOfClass("Humanoid")
			local botHrp = bot:FindFirstChild("HumanoidRootPart")
			local targetHrp = human:FindFirstChild("HumanoidRootPart")
			if not botHum or not botHrp or not targetHrp or botHum.Health <= 0 then
				continue
			end
			local dist = (targetHrp.Position - botHrp.Position).Magnitude
			if ChickenCombatService.IsBusy(bot) then
				continue
			end
			if dist > 6 then
				botHum:MoveTo(targetHrp.Position)
				if dist > 14 and math.random() < 0.5 then
					ChickenCombatService.RequestDash(bot, (targetHrp.Position - botHrp.Position).Unit)
				end
			else
				botHum:MoveTo(botHrp.Position) -- stop closing once in range
				if math.random() < 0.7 then
					ChickenCombatService.RequestAttack(bot)
				end
			end
		end
	end)
end

--============================== round lifecycle ==============================--
local function resetRound(match)
	for _, side in ipairs(match.players) do
		local model = match.chickens[sideKey(side)]
		if model and model.Parent then
			ChickenHealthService.Reset(model)
			local spawnName = model == match.chickens[sideKey(match.players[1])] and "SpawnA" or "SpawnB"
			local att = match.arena.Floor:FindFirstChild(spawnName)
			if att then
				model:PivotTo(att.WorldCFrame)
			end
			local hrp = model:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
			ChickenStateService.SetAction(model, "Idle")
		end
	end
end

local function countDamageDealt(match)
	-- best-effort deterministic tiebreak input: total damage each side has dealt this round
	return match.damageDealt or { }
end

local function decideRoundWinner(match): any
	local p1, p2 = match.players[1], match.players[2]
	local m1, m2 = match.chickens[sideKey(p1)], match.chickens[sideKey(p2)]
	local h1 = m1 and m1:FindFirstChildOfClass("Humanoid")
	local h2 = m2 and m2:FindFirstChildOfClass("Humanoid")
	local hp1 = h1 and h1.Health or 0
	local hp2 = h2 and h2.Health or 0
	if hp1 <= 0 and hp2 <= 0 then
		-- both down in the same tick: deterministic tiebreak, never a coin flip
		local dmg = countDamageDealt(match)
		if (dmg[sideKey(p1)] or 0) ~= (dmg[sideKey(p2)] or 0) then
			return (dmg[sideKey(p1)] or 0) > (dmg[sideKey(p2)] or 0) and p1 or p2
		end
		return tostring(p1) < tostring(p2) and p1 or p2
	elseif hp1 <= 0 then
		return p2
	elseif hp2 <= 0 then
		return p1
	elseif hp1 ~= hp2 then
		return hp1 > hp2 and p1 or p2
	else
		local dmg = countDamageDealt(match)
		if (dmg[sideKey(p1)] or 0) ~= (dmg[sideKey(p2)] or 0) then
			return (dmg[sideKey(p1)] or 0) > (dmg[sideKey(p2)] or 0) and p1 or p2
		end
		return tostring(p1) < tostring(p2) and p1 or p2 -- fully deterministic last resort, never random
	end
end

local function enterState(match, state)
	match.state = state
	publishBoth(match, "MatchState", function() return state end)
end

local function runRound(match)
	enterState(match, "Countdown")
	match.damageDealt = { [sideKey(match.players[1])] = 0, [sideKey(match.players[2])] = 0 }
	local countdownEnds = workspace:GetServerTimeNow() + COUNTDOWN_DURATION
	publishBoth(match, "MatchCountdownEndsAt", function() return countdownEnds end)
	task.wait(COUNTDOWN_DURATION)
	if match.state ~= "Countdown" then return end -- match was torn down mid-countdown

	enterState(match, "Active")
	local roundEnds = workspace:GetServerTimeNow() + ROUND_DURATION
	match.roundEndsAt = roundEnds
	publishBoth(match, "MatchRoundEndsAt", function() return roundEnds end)

	local koFired = false
	local koConn = ChickenHealthService.KOEvent.Event:Connect(function(victim)
		if match.chickens[sideKey(match.players[1])] == victim or match.chickens[sideKey(match.players[2])] == victim then
			koFired = true
		end
	end)
	local hitConn = ChickenCombatService.HitEvent.Event:Connect(function(attacker, _victim, damage)
		for _, side in ipairs(match.players) do
			if match.chickens[sideKey(side)] == attacker then
				match.damageDealt[sideKey(side)] = (match.damageDealt[sideKey(side)] or 0) + damage
			end
		end
	end)

	while match.state == "Active" and not koFired and workspace:GetServerTimeNow() < roundEnds do
		task.wait(0.1)
	end
	koConn:Disconnect()
	hitConn:Disconnect()
	if match.state ~= "Active" then return end -- torn down mid-round (disconnect/leave)

	enterState(match, "RoundEnd")
	local winner = decideRoundWinner(match)
	local loser = winner == match.players[1] and match.players[2] or match.players[1]
	-- ensure the losing side's Humanoid.Died actually fires exactly once, however the round ended
	-- (KO, timeout, or tiebreak), so the already-verified death-spectator camera path is the single
	-- consistent trigger rather than a second bespoke "you lost" signal.
	local loserModel = match.chickens[sideKey(loser)]
	if loserModel then
		local h = loserModel:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then
			h:TakeDamage(h.Health)
		end
	end

	match.wins[sideKey(winner)] += 1
	publishBoth(match, "MatchRoundWins", function(self_) return match.wins[sideKey(self_)] end)
	publishBoth(match, "MatchOpponentRoundWins", function(self_, opp) return match.wins[sideKey(opp)] end)
	task.wait(2)
	return winner
end

local function teardownMatch(match, reason)
	if match.torndown then return end
	match.torndown = true
	match.state = "Returning"
	for _, side in ipairs(match.players) do
		if not isBot(side) then
			publish(side, "MatchState", "Returning")
			-- idempotent: the winner's own victory-cutscene completion already calls this client-side, and
			-- the loser's camera (parked in DeathSpectator since their KO) needs this explicit push since
			-- nothing else would ever return it to Lobby on its own.
			cameraDirective:FireClient(side, "ReturnToLobby", nil)
		end
		despawnFighter(match, side)
		if not isBot(side) then
			playerToMatch[side] = nil
			-- give them back a normal hub avatar now that CharacterAutoLoads is off and their fighter
			-- clone (which was standing in as Character) has just been destroyed above.
			if side.Parent then
				side:LoadCharacter()
			end
		end
	end
	releaseArena(match.arena)
	matches[match.id] = nil
	if match.rigFolder then
		match.rigFolder:Destroy()
	end
end

local function runMatch(match)
	enterState(match, "Preparing")
	match.arena = reserveArena()
	if not match.arena then
		-- both slots busy: brief wait then retry once; if still none, abort cleanly rather than hang forever
		task.wait(3)
		match.arena = reserveArena()
		if not match.arena then
			for _, side in ipairs(match.players) do
				if not isBot(side) then publish(side, "MatchState", "Lobby") end
			end
			teardownMatch(match, "no_arena")
			return
		end
	end
	match.rigFolder = Instance.new("Folder")
	match.rigFolder.Name = "Match_" .. match.id
	match.rigFolder.Parent = matchRigsFolder

	local spawnA = match.arena.Floor.SpawnA
	local spawnB = match.arena.Floor.SpawnB
	match.chickens[sideKey(match.players[1])] = spawnFighter(match, match.players[1], spawnA)
	match.chickens[sideKey(match.players[2])] = spawnFighter(match, match.players[2], spawnB)

	publishBoth(match, "MatchOpponentName", function(_, opp) return tostring(isBot(opp) and opp.Name or opp.Name) end)
	publishBoth(match, "MatchRoundWins", function() return 0 end)
	publishBoth(match, "MatchOpponentRoundWins", function() return 0 end)

	if match.players[1] == BOT or match.players[2] == BOT then
		runBotAI(match)
	end

	-- entrance cinematic: plays for both, once, only before round 1 (kept brief/skippable per-client via
	-- the existing ChickenCutsceneController; server just waits out the same authored duration so Countdown
	-- starts in sync rather than trusting a client completion signal for match-critical timing).
	enterState(match, "Entrance")
	for _, side in ipairs(match.players) do
		local model = match.chickens[sideKey(side)]
		ChickenStateService.SetAction(model, "Entrance")
		if not isBot(side) then
			-- deterministic camera trigger (see MatchCameraBridge) instead of relying on the controller's
			-- own attribute-change auto-wiring, which can race a fast tag+Action burst and miss the cue.
			cameraDirective:FireClient(side, "EnterEntrance", model)
		end
	end
	task.wait(Catalog.Animations.Entrance.Duration + 0.25)
	if match.torndown then return end

	while true do
		local winner = runRound(match)
		if match.torndown then return end
		if match.wins[sideKey(match.players[1])] >= WINS_NEEDED or match.wins[sideKey(match.players[2])] >= WINS_NEEDED then
			break
		end
		resetRound(match)
		task.wait(1)
	end

	enterState(match, "Results")
	local finalWinner = match.wins[sideKey(match.players[1])] >= WINS_NEEDED and match.players[1] or match.players[2]
	publishBoth(match, "MatchResult", function(self_) return self_ == finalWinner and "Victory" or "Defeat" end)
	local winnerModel = match.chickens[sideKey(finalWinner)]
	if winnerModel and winnerModel.Parent then
		ChickenStateService.SetAction(winnerModel, "Victory")
		if not isBot(finalWinner) then
			cameraDirective:FireClient(finalWinner, "EnterVictory", winnerModel)
		end
	end
	task.wait(RETURN_DELAY)
	teardownMatch(match, "complete")
end

--============================== queueing ==============================--
function MatchService.Queue(player: Player)
	if playerToMatch[player] or table.find(queue, player) then
		return
	end
	table.insert(queue, player)
	queuedSince[player] = os.clock()
	publish(player, "MatchState", "Queued")

	task.spawn(function()
		while table.find(queue, player) do
			task.wait(0.5)
			if not table.find(queue, player) then
				return
			end
			if #queue >= 2 then
				local a = table.remove(queue, 1)
				local bIdx = table.find(queue, player) -- may have shifted
				local b
				for i, q in ipairs(queue) do
					if q ~= a then
						b = table.remove(queue, i)
						break
					end
				end
				if a and b then
					MatchService._startMatch(a, b)
				end
				return
			end
			if os.clock() - (queuedSince[player] or os.clock()) >= BOT_FALLBACK_WAIT then
				local idx = table.find(queue, player)
				if idx then
					table.remove(queue, idx)
					MatchService._startMatch(player, BOT)
				end
				return
			end
		end
	end)
end

function MatchService.Dequeue(player: Player)
	local idx = table.find(queue, player)
	if idx then
		table.remove(queue, idx)
		queuedSince[player] = nil
		publish(player, "MatchState", "Lobby")
	end
end

function MatchService._startMatch(a, b)
	matchIdCounter += 1
	local match = {
		id = matchIdCounter,
		players = { a, b },
		wins = { [sideKey(a)] = 0, [sideKey(b)] = 0 },
		chickens = {},
		state = "Preparing",
		torndown = false,
	}
	matches[match.id] = match
	if not isBot(a) then playerToMatch[a] = match end
	if not isBot(b) then playerToMatch[b] = match end
	task.spawn(runMatch, match)
end

--============================== queries used by the input handler / HUD ==============================--
function MatchService.CanPlayerFight(player: Player): boolean
	local match = playerToMatch[player]
	return match ~= nil and match.state == "Active"
end

function MatchService.GetPlayerChicken(player: Player): Model?
	local match = playerToMatch[player]
	if not match then
		return nil
	end
	return match.chickens[sideKey(player)]
end

function MatchService.IsInMatch(player: Player): boolean
	return playerToMatch[player] ~= nil
end

--============================== disconnect / leave handling ==============================--
Players.PlayerRemoving:Connect(function(player)
	MatchService.Dequeue(player)
	local match = playerToMatch[player]
	if match then
		teardownMatch(match, "player_left")
	end
end)

return MatchService
