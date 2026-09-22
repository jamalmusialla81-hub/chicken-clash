--[[ PracticeService (server, authoritative). Phase 3: a standalone combat sandbox at the existing
	TrainingDojo island - no queue, no rounds, no opponent required. Reuses the exact same combat rig,
	ChickenStateService/ChickenCombatService/ChickenHealthService/ChickenMovementDriver pipeline
	MatchService uses for real matches, so anything that works in practice works identically in a real
	match (and vice versa) - this is deliberately NOT a separate parallel combat implementation.

	A player entering practice gets their own fighter clone (Character-swapped, same as a match) plus a
	personal training dummy tagged CombatChicken so the existing hitbox/HitEvent pipeline "just works"
	against it. The dummy's Humanoid.MaxHealth is set very high and PracticeService itself re-heals it
	every hit (rather than truly infinite health, which would need special-casing HitEvent/KOEvent
	everywhere else that assumes a finite Humanoid) - functionally infinite, zero special-casing required
	elsewhere in the combat pipeline. ]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChickenStateService = require(script.Parent:WaitForChild("ChickenStateService"))
local ChickenCombatService = require(script.Parent:WaitForChild("ChickenCombatService"))
local ChickenHealthService = require(script.Parent:WaitForChild("ChickenHealthService"))
local ChickenMovementDriver = require(script.Parent:WaitForChild("ChickenMovementDriver"))

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

local PracticeService = {}

local DUMMY_HEALTH = 100000
local FIGHTER_HEALTH = 100
-- Dojo's real Floor part is only 22x22 studs centered at (-63.41, 0.4, -63.41) (confirmed via direct
-- inspection after an earlier version of this constant placed both fighters ~23 studs off the actual
-- floor, off the edge of the small dojo island, and the same fallen-parts void-destroy bug found in
-- MatchService's arena spawn attachments repeated itself here) - center + a small offset keeps both
-- well inside the real floor bounds instead of guessing at the island's overall footprint.
local DUMMY_CENTER = Vector3.new(-63.4, 3, -63.4)
local COMBAT_RIG_TEMPLATE_NAME = "Golden Chicken"

local sessions = setmetatable({}, { __mode = "k" }) -- Player -> { fighter, dummy, folder, conns, mode, stats }

local function buildDummy(folder)
	local template = ServerStorage.CombatChickens[COMBAT_RIG_TEMPLATE_NAME]
	local dummy = template:Clone()
	dummy.Name = "PracticeDummy"
	dummy:PivotTo(CFrame.new(DUMMY_CENTER))
	dummy.Parent = folder
	CollectionService:AddTag(dummy, "CombatChicken")
	dummy:SetAttribute("IsPracticeDummy", true)
	ChickenStateService.Activate(dummy, nil)
	ChickenHealthService.Init(dummy, DUMMY_HEALTH)
	ChickenMovementDriver.Attach(dummy)
	return dummy
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
			if session.mode == "Strafing" and not ChickenCombatService.IsBusy(dummy) then
				local angle = os.clock() * 0.6
				local orbit = DUMMY_CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 4
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
			else -- Stationary
				hum:MoveTo(hrp.Position)
			end
		end
	end)
end

function PracticeService.Enter(player: Player)
	if sessions[player] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Practice_" .. player.UserId
	folder.Parent = workspace:FindFirstChild("ActiveMatches") or (function()
		local f = Instance.new("Folder")
		f.Name = "ActiveMatches"
		f.Parent = workspace
		return f
	end)()

	local template = ServerStorage.CombatChickens[COMBAT_RIG_TEMPLATE_NAME]
	local fighter = template:Clone()
	fighter.Name = player.Name .. "_Practice"
	fighter:PivotTo(CFrame.new(DUMMY_CENTER + Vector3.new(0, 0, 5), DUMMY_CENTER))
	fighter.Parent = folder
	CollectionService:AddTag(fighter, "CombatChicken")
	fighter:SetAttribute("OwnerUserId", player.UserId)
	ChickenStateService.Activate(fighter, player)
	ChickenHealthService.Init(fighter, FIGHTER_HEALTH)
	ChickenMovementDriver.Attach(fighter)

	local prevChar = player.Character
	player.Character = fighter
	if prevChar and prevChar ~= fighter then
		prevChar:Destroy()
	end

	local dummy = buildDummy(folder)

	local session = {
		player = player, fighter = fighter, dummy = dummy, folder = folder, conns = {},
		mode = "Stationary", infiniteHealth = true,
		stats = { combo = 0, lastHitAt = 0, totalDamage = 0, hits = 0, sessionStart = os.clock() },
	}
	sessions[player] = session

	table.insert(session.conns, ChickenCombatService.HitEvent.Event:Connect(function(attacker, victim, damage, actionName)
		if attacker ~= fighter or victim ~= dummy then
			return
		end
		local s = session.stats
		local now = os.clock()
		s.combo = (now - s.lastHitAt <= 1.5) and (s.combo + 1) or 1
		s.lastHitAt = now
		s.totalDamage += damage
		s.hits += 1
		local elapsed = math.max(now - s.sessionStart, 0.001)
		statsRemote:FireClient(player, {
			lastHit = damage, actionName = actionName, combo = s.combo,
			totalDamage = s.totalDamage, hitsPerSecond = s.hits / elapsed,
		})
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
	if mode == "Stationary" or mode == "Strafing" or mode == "Attacking" then
		session.mode = mode
	end
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
	ChickenHealthService.Reset(session.dummy)
	session.dummy:PivotTo(CFrame.new(DUMMY_CENTER))
	session.stats = { combo = 0, lastHitAt = 0, totalDamage = 0, hits = 0, sessionStart = os.clock() }
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
	ChickenMovementDriver.Detach(session.fighter)
	ChickenHealthService.Stop(session.fighter)
	ChickenStateService.Deactivate(session.fighter)
	ChickenMovementDriver.Detach(session.dummy)
	ChickenHealthService.Stop(session.dummy)
	ChickenStateService.Deactivate(session.dummy)
	player:SetAttribute("MatchState", "Lobby")
	cameraDirective:FireClient(player, "ReturnToLobby", nil)
	if session.folder then
		session.folder:Destroy()
	end
	if player.Parent then
		player:LoadCharacter()
	end
end

Players.PlayerRemoving:Connect(function(player)
	if sessions[player] then
		PracticeService.Exit(player)
	end
end)

-- remote wiring: every handler validates the player actually has an active practice session before
-- touching anything, and mode/boolean values are whitelisted/coerced rather than trusted verbatim.
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

return PracticeService
