--[[ PracticeService (server, authoritative). Phase 3 built this as a sandbox at the small TrainingDojo
	island; this pass moves the actual training space to a large, dedicated Practice Range far from the
	hub/match arenas (see workspace.Map.PracticeRange), reached via the hub's practice portal, while
	reusing the exact same combat rig, ChickenStateService/ChickenCombatService/ChickenHealthService/
	ChickenMovementDriver pipeline MatchService uses for real matches - this is deliberately NOT a second
	parallel combat implementation, and NOT a second practice system alongside this one.

	A player entering practice gets their own fighter clone (Character-swapped, same as a match) plus a
	personal training dummy tagged CombatChicken so the existing hitbox/HitEvent pipeline "just works"
	against it. The dummy's Humanoid.MaxHealth is set very high and PracticeService itself re-heals it
	every hit (rather than truly infinite health, which would need special-casing HitEvent/KOEvent
	everywhere else that assumes a finite Humanoid) - functionally infinite, zero special-casing required
	elsewhere in the combat pipeline.

	Four lanes (Stationary/Strafing/Attacking/Combo) are real physical positions in the range, not just an
	AI-behavior label - switching lanes teleports both the dummy and the player's fighter there. A fifth
	"lane", the dash/movement obstacle course, is pure level geometry (ring gates) with no server logic of
	its own - there is nothing to score or gate server-side about running through space, so nothing here
	pretends otherwise. Parry has no lane: Phase 3 never built parry, so there is nothing to practice yet. ]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChickenStateService = require(script.Parent:WaitForChild("ChickenStateService"))
local ChickenCombatService = require(script.Parent:WaitForChild("ChickenCombatService"))
local ChickenHealthService = require(script.Parent:WaitForChild("ChickenHealthService"))
local ChickenMovementDriver = require(script.Parent:WaitForChild("ChickenMovementDriver"))
local LobbyReturn = require(script.Parent:WaitForChild("LobbyReturn"))
local ChickenDefinitions = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenDefinitions"))

local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local cameraDirective = combatFolder:FindFirstChild("MatchCameraDirective")
if not cameraDirective then
	cameraDirective = Instance.new("RemoteEvent")
	cameraDirective.Name = "MatchCameraDirective"
	cameraDirective.Parent = combatFolder
end
local statsRemote = combatFolder:FindFirstChild("PracticeStats")
if not statsRemote then
	statsRemote = Instance.new("RemoteEvent")
	statsRemote.Name = "PracticeStats"
	statsRemote.Parent = combatFolder
end

local function getOrCreateRemote(name)
	local r = combatFolder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = combatFolder
	end
	return r
end
local modeRemote = getOrCreateRemote("PracticeModeRequest")
local infiniteHealthRemote = getOrCreateRemote("PracticeInfiniteHealthRequest")
local resetRemote = getOrCreateRemote("PracticeResetRequest")
local clearStatsRemote = getOrCreateRemote("PracticeClearStatsRequest")
local exitRemote = getOrCreateRemote("PracticeExitRequest")
local chickenSelectRemote = getOrCreateRemote("PracticeSelectChickenRequest")
local chickenLockedRemote = getOrCreateRemote("PracticeChickenLocked") -- server -> client: attempted a locked/incompatible chicken

local PracticeService = {}

local DUMMY_HEALTH = 100000
local FIGHTER_HEALTH = 100

-- Practice Range: a large dedicated space far from the hub and every match arena (arenas live at
-- x=300; this sits well clear of them so a stray dash/raycast in either space can never reach the other).
local RANGE_CENTER = Vector3.new(500, 10, 0)
local SPAWN_POINT = RANGE_CENTER + Vector3.new(0, 0, -30) -- near the selection station + return portal

-- Real physical lane centers (relative to RANGE_CENTER) - switching lanes teleports the dummy AND the
-- fighter here, not just a behavior flag.
local LANE_DUMMY_POS = {
	Stationary = RANGE_CENTER + Vector3.new(-20, 0, 10),
	Strafing = RANGE_CENTER + Vector3.new(0, 0, 10),
	Attacking = RANGE_CENTER + Vector3.new(20, 0, 10),
	Combo = RANGE_CENTER + Vector3.new(0, 0, 35),
}
local LANE_FIGHTER_OFFSET = {
	Stationary = Vector3.new(0, 0, -8),
	Strafing = Vector3.new(0, 0, -8),
	Attacking = Vector3.new(0, 0, -8),
	Combo = Vector3.new(0, 0, -4), -- close range on purpose - this lane is about combo strings, not closing distance
}

local sessions = setmetatable({}, { __mode = "k" }) -- Player -> { fighter, dummy, folder, conns, mode, stats, defId }

-- Phase 6: both the dummy and the fighter use the SAME resolved chicken definition, so practice actually
-- reflects the chicken the player will fight with.
local function buildDummy(folder, defId, pos)
	local def = ChickenDefinitions.Get(defId)
	local template = ServerStorage.CombatChickens[def.CombatModelName]
	local dummy = template:Clone()
	dummy.Name = "PracticeDummy"
	dummy:PivotTo(CFrame.new(pos))
	dummy.Parent = folder
	dummy:SetAttribute("ChickenDefId", defId)
	CollectionService:AddTag(dummy, "CombatChicken")
	dummy:SetAttribute("IsPracticeDummy", true)
	ChickenStateService.Activate(dummy, nil)
	ChickenHealthService.Init(dummy, DUMMY_HEALTH)
	ChickenMovementDriver.Attach(dummy)
	return dummy
end

local function buildFighter(folder, defId, player, pos, lookAt)
	local def = ChickenDefinitions.Get(defId)
	local template = ServerStorage.CombatChickens[def.CombatModelName]
	local fighter = template:Clone()
	fighter.Name = player.Name .. "_Practice"
	fighter:PivotTo(CFrame.new(pos, lookAt))
	fighter.Parent = folder
	fighter:SetAttribute("ChickenDefId", defId)
	CollectionService:AddTag(fighter, "CombatChicken")
	fighter:SetAttribute("OwnerUserId", player.UserId)
	ChickenStateService.Activate(fighter, player)
	ChickenHealthService.Init(fighter, def.Stats.MaxHealth or FIGHTER_HEALTH)
	ChickenMovementDriver.Attach(fighter)
	return fighter
end

local function freshStats()
	return { combo = 0, lastHitAt = 0, totalDamage = 0, hits = 0, highestCombo = 0, sessionStart = os.clock() }
end

local function pushStats(session, extra)
	local s = session.stats
	local elapsed = math.max(os.clock() - s.sessionStart, 0.001)
	local payload = {
		combo = s.combo, totalDamage = s.totalDamage, hitsPerSecond = s.hits / elapsed,
		highestCombo = s.highestCombo, sessionTime = elapsed, mode = session.mode,
	}
	if extra then
		for k, v in pairs(extra) do payload[k] = v end
	end
	statsRemote:FireClient(session.player, payload)
end

local function runDummyAI(session)
	task.spawn(function()
		while sessions[session.player] == session do
			task.wait(0.5)
			local dummy = session.dummy
			local fighter = session.fighter
			if not dummy or not dummy.Parent or not fighter or not fighter.Parent then
				continue
			end
			local hum = dummy:FindFirstChildOfClass("Humanoid")
			local hrp = dummy:FindFirstChild("HumanoidRootPart")
			local targetHrp = fighter:FindFirstChild("HumanoidRootPart")
			if not hum or not hrp or not targetHrp then
				continue
			end
			-- keep the "infinite health" option meaningfully infinite regardless of mode
			if session.infiniteHealth and hum.Health < hum.MaxHealth then
				hum.Health = hum.MaxHealth
				dummy:SetAttribute("Health", hum.Health)
			end
			local lanePos = LANE_DUMMY_POS[session.mode] or LANE_DUMMY_POS.Stationary
			if session.mode == "Strafing" and not ChickenCombatService.IsBusy(dummy) then
				local angle = os.clock() * 0.6
				local orbit = lanePos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 4
				hum:MoveTo(orbit)
			elseif session.mode == "Attacking" then
				local dist = (targetHrp.Position - hrp.Position).Magnitude
				if not ChickenCombatService.IsBusy(dummy) then
					if dist > 6 then
						hum:MoveTo(targetHrp.Position)
					elseif math.random() < 0.6 then
						ChickenCombatService.RequestAttack(dummy)
					end
				end
			else -- Stationary / Combo: holds position, absorbs whatever combo the player throws
				hum:MoveTo(hrp.Position)
			end
		end
	end)
end

local function teardownFighterAndDummy(session)
	if session.fighter then
		ChickenMovementDriver.Detach(session.fighter)
		ChickenHealthService.Stop(session.fighter)
		ChickenStateService.Deactivate(session.fighter)
		session.fighter:Destroy()
	end
	if session.dummy then
		ChickenMovementDriver.Detach(session.dummy)
		ChickenHealthService.Stop(session.dummy)
		ChickenStateService.Deactivate(session.dummy)
		session.dummy:Destroy()
	end
end

function PracticeService.Enter(player: Player)
	if sessions[player] then
		return
	end
	local defId = ChickenDefinitions.ResolveForPlayer(player)
	local folder = Instance.new("Folder")
	folder.Name = "Practice_" .. player.UserId
	folder.Parent = workspace:FindFirstChild("ActiveMatches") or (function()
		local f = Instance.new("Folder")
		f.Name = "ActiveMatches"
		f.Parent = workspace
		return f
	end)()

	local mode = "Stationary"
	local dummyPos = LANE_DUMMY_POS[mode]
	local fighterPos = dummyPos + LANE_FIGHTER_OFFSET[mode]
	local fighter = buildFighter(folder, defId, player, fighterPos, dummyPos)

	local prevChar = player.Character
	player.Character = fighter
	if prevChar and prevChar ~= fighter then
		prevChar:Destroy()
	end

	local dummy = buildDummy(folder, defId, dummyPos)

	local session = {
		player = player, fighter = fighter, dummy = dummy, folder = folder, conns = {},
		mode = mode, infiniteHealth = true, defId = defId,
		stats = freshStats(),
	}
	sessions[player] = session

	table.insert(session.conns, ChickenCombatService.HitEvent.Event:Connect(function(attacker, victim, damage, actionName)
		if attacker ~= session.fighter or victim ~= session.dummy then
			return
		end
		local s = session.stats
		local now = os.clock()
		s.combo = (now - s.lastHitAt <= 1.5) and (s.combo + 1) or 1
		s.lastHitAt = now
		s.totalDamage += damage
		s.hits += 1
		s.highestCombo = math.max(s.highestCombo, s.combo)
		pushStats(session, { lastHit = damage, actionName = actionName })
	end))

	player:SetAttribute("MatchState", "Practice")
	cameraDirective:FireClient(player, "SetChicken", fighter)
	cameraDirective:FireClient(player, "EnterEntrance", fighter) -- brief entrance is fine; skippable client-side already
	runDummyAI(session)
end

function PracticeService.SetDummyMode(player: Player, mode: string)
	local session = sessions[player]
	if not session then
		return
	end
	if not LANE_DUMMY_POS[mode] then
		return
	end
	session.mode = mode
	local dummyPos = LANE_DUMMY_POS[mode]
	local fighterPos = dummyPos + LANE_FIGHTER_OFFSET[mode]
	if session.dummy and session.dummy.Parent then
		ChickenHealthService.Reset(session.dummy)
		session.dummy:PivotTo(CFrame.new(dummyPos, fighterPos))
	end
	if session.fighter and session.fighter.Parent then
		session.fighter:PivotTo(CFrame.new(fighterPos, dummyPos))
		local hrp = session.fighter:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end
	session.stats = freshStats()
	pushStats(session)
end

-- Phase 6/portal-practice-range: switching chicken mid-session fully tears down the previous fighter,
-- camera, tracks, VFX, sounds and connections before spawning the new one - reusing the exact same
-- teardown path Exit() uses for the fighter/dummy pair, then rebuilding fresh (never mutating a live
-- rig's ChickenDefId in place, which would leave client-side animator/aura/camera state pointing at the
-- old definition's cached tracks). Rejects any chicken the rig-compatibility validator hasn't cleared.
function PracticeService.SetChicken(player: Player, defId: string)
	local session = sessions[player]
	if not session then
		return
	end
	local def = ChickenDefinitions.Get(defId)
	if not def then
		return
	end
	if not def.CombatCompatible then
		chickenLockedRemote:FireClient(player, defId, def.CombatUnavailableReason or "Not combat-ready yet")
		return
	end
	if defId == session.defId then
		return
	end

	local dummyPos = LANE_DUMMY_POS[session.mode] or LANE_DUMMY_POS.Stationary
	local fighterPos = dummyPos + (LANE_FIGHTER_OFFSET[session.mode] or LANE_FIGHTER_OFFSET.Stationary)

	-- build the replacement fighter/dummy and swap player.Character to it BEFORE tearing down the old
	-- pair, same ordering MatchService/Enter already use everywhere else - player.Character must never
	-- point at an about-to-be-destroyed instance, even briefly.
	local newFighter = buildFighter(session.folder, defId, player, fighterPos, dummyPos)
	local newDummy = buildDummy(session.folder, defId, dummyPos)

	local oldFighter, oldDummy = session.fighter, session.dummy
	player.Character = newFighter
	session.fighter = newFighter
	session.dummy = newDummy
	session.defId = defId
	session.stats = freshStats()

	ChickenMovementDriver.Detach(oldFighter)
	ChickenHealthService.Stop(oldFighter)
	ChickenStateService.Deactivate(oldFighter)
	oldFighter:Destroy()
	ChickenMovementDriver.Detach(oldDummy)
	ChickenHealthService.Stop(oldDummy)
	ChickenStateService.Deactivate(oldDummy)
	oldDummy:Destroy()

	cameraDirective:FireClient(player, "SetChicken", newFighter)
	cameraDirective:FireClient(player, "EnterEntrance", newFighter)
	pushStats(session)
end

function PracticeService.SetInfiniteHealth(player: Player, enabled: boolean)
	local session = sessions[player]
	if session then
		session.infiniteHealth = enabled == true
	end
end

function PracticeService.ResetDummy(player: Player)
	local session = sessions[player]
	if not session or not session.dummy or not session.dummy.Parent then
		return
	end
	local dummyPos = LANE_DUMMY_POS[session.mode] or LANE_DUMMY_POS.Stationary
	ChickenHealthService.Reset(session.dummy)
	session.dummy:PivotTo(CFrame.new(dummyPos))
	session.stats = freshStats()
	pushStats(session)
end

-- "Clear Stats" is deliberately distinct from ResetDummy: it only zeroes the counters, without
-- repositioning or re-healing the dummy - a player mid-drill can wipe their numbers without losing position.
function PracticeService.ClearStats(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	session.stats = freshStats()
	pushStats(session)
end

function PracticeService.CanPlayerFight(player: Player): boolean
	return sessions[player] ~= nil
end

function PracticeService.GetPlayerChicken(player: Player): Model?
	local session = sessions[player]
	return session and session.fighter
end

function PracticeService.IsInPractice(player: Player): boolean
	return sessions[player] ~= nil
end

function PracticeService.Exit(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	for _, c in ipairs(session.conns) do
		c:Disconnect()
	end
	teardownFighterAndDummy(session)
	player:SetAttribute("MatchState", "Lobby")
	cameraDirective:FireClient(player, "ReturnToLobby", nil)
	if session.folder then
		session.folder:Destroy()
	end
	LobbyReturn.RestoreAvatar(player)
end

Players.PlayerRemoving:Connect(function(player)
	if sessions[player] then
		PracticeService.Exit(player)
	end
end)

-- remote wiring: every handler validates the player actually has an active practice session before
-- touching anything, and mode/boolean/string values are whitelisted/coerced rather than trusted verbatim.
modeRemote.OnServerEvent:Connect(function(player: Player, mode)
	if type(mode) ~= "string" then
		return
	end
	PracticeService.SetDummyMode(player, mode)
end)

infiniteHealthRemote.OnServerEvent:Connect(function(player: Player, enabled)
	PracticeService.SetInfiniteHealth(player, enabled == true)
end)

resetRemote.OnServerEvent:Connect(function(player: Player)
	PracticeService.ResetDummy(player)
end)

clearStatsRemote.OnServerEvent:Connect(function(player: Player)
	PracticeService.ClearStats(player)
end)

-- Lets the HUD's top-left "RETURN TO HUB" button do exactly what walking to the return gate does -
-- same PracticeService.Exit call PracticeRangePrompts' ReturnToHubPrompt already uses.
exitRemote.OnServerEvent:Connect(function(player: Player)
	if PracticeService.IsInPractice(player) then
		PracticeService.Exit(player)
	end
end)

chickenSelectRemote.OnServerEvent:Connect(function(player: Player, defId)
	if type(defId) ~= "string" then
		return
	end
	PracticeService.SetChicken(player, defId)
end)

return PracticeService
