--[[ GoldenChickenAnimationCatalog
	Single source of truth for every Golden Chicken production animation: asset ID, version, FPS, frame
	count, duration, loop, priority, markers, purpose, and the Moon Animator project it was authored in.
	AssetId is "PENDING_UPLOAD" until Jakob publishes each Moon project (creator 1723752359) and fills in
	the real rbxassetid. ChickenAnimator must never hardcode an animation ID anywhere else - always look
	it up here.
]]

local Catalog = {}

Catalog.Creator = 1723752359

Catalog.Animations = {
	Idle = {
		AssetId = "PENDING_UPLOAD",
		Version = 1,
		MoonProject = "GoldChicken_Idle",
		FPS = 24,
		Frames = 96,
		Duration = 96 / 24,
		Loop = true,
		Priority = Enum.AnimationPriority.Idle,
		Markers = {},
		Purpose = "Default standing loop: proud chest, breathing, tiny asymmetric wing/head motion.",
	},
	Walk = {
		AssetId = "PENDING_UPLOAD",
		Version = 1,
		MoonProject = "GoldChicken_Walk",
		FPS = 24,
		Frames = 24,
		Duration = 24 / 24,
		Loop = true,
		Priority = Enum.AnimationPriority.Movement,
		Markers = {"LeftFootstep", "RightFootstep"},
		Purpose = "Ground locomotion, walk speed.",
	},
	Run = {
		AssetId = "PENDING_UPLOAD",
		Version = 1,
		MoonProject = "GoldChicken_Run",
		FPS = 24,
		Frames = 16,
		Duration = 16 / 24,
		Loop = true,
		Priority = Enum.AnimationPriority.Movement,
		Markers = {"LeftFootstep", "RightFootstep"},
		Purpose = "Ground locomotion, run speed.",
	},
	JumpStart = {
		AssetId = "PENDING_UPLOAD",
		Version = 1,
		MoonProject = "GoldChicken_Jump",
		FPS = 24,
		Frames = 12,
		Duration = 12 / 24,
		Loop = false,
		Priority = Enum.AnimationPriority.Movement,
		Markers = {"Takeoff"},
		Purpose = "Compression + explosive extension into airborne state.",
	},
	Fall = {
		AssetId = "PENDING_UPLOAD",
		Version = 1,
		MoonProject = "GoldChicken_Fall",
		FPS = 24,
		Frames = 24,
		Duration = 24 / 24,
		Loop = true,
		Priority = Enum.AnimationPriority.Movement,
		Markers = {},
		Purpose = "Airborne hold: wings partially open, legs gathering beneath body.",
	},
	Land = {
		AssetId = "PENDING_UPLOAD",
		Version = 1,
		MoonProject = "GoldChicken_Land",
		FPS = 24,
		Frames = 16,
		Duration = 16 / 24,
		Loop = false,
		Priority = Enum.AnimationPriority.Movement,
		Markers = {"Land", "Recover"},
		Purpose = "Ground contact, compression, rebound into a usable gameplay pose.",
	},
	Dash = {
		AssetId = "PENDING_UPLOAD",
		Version = 1,
		MoonProject = "GoldChicken_Dash",
		FPS = 24,
		Frames = 18,
		Duration = 18 / 24,
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		Markers = {"Windup", "DashStart", "VFX", "DashEnd", "Recover"},
		Purpose = "Server-validated dash visual: windup, spear-like commitment, brake, recovery. No baked displacement.",
	},
	M1_1 = {
		AssetId = "PENDING_UPLOAD",
		Version = 1,
		MoonProject = "GoldChicken_M1_1",
		FPS = 24,
		Frames = 18,
		Duration = 18 / 24,
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		Markers = {"Windup", "OnSwing", "ActiveStart", "Impact", "VFX", "Sound", "ComboOpen", "ActiveEnd", "ComboClose", "Recover"},
		Purpose = "Combo hit 1: fast wing-guard bash opener, feeds M1_2.",
	},
	M1_2 = {
		AssetId = "PENDING_UPLOAD",
		Version = 1,
		MoonProject = "GoldChicken_M1_2",
		FPS = 24,
		Frames = 20,
		Duration = 20 / 24,
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		Markers = {"Windup", "ActiveStart", "Impact", "VFX", "Sound", "ComboOpen", "ActiveEnd", "ComboClose", "Recover"},
		Purpose = "Combo hit 2: opposite-wing follow-up, stronger torso rotation.",
	},
	M1_3 = {
		AssetId = "PENDING_UPLOAD",
		Version = 1,
		MoonProject = "GoldChicken_M1_3",
		FPS = 24,
		Frames = 28,
		Duration = 28 / 24,
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		Markers = {"Windup", "Charge", "OnSwing", "ActiveStart", "Impact", "VFX", "Sound", "ActiveEnd", "ComboClose", "Recover"},
		Purpose = "Combo finisher: heavy loaded leg/torso strike, compressed timing, heavy overshoot.",
	},
	Entrance = {
		AssetId = "PENDING_UPLOAD",
		Version = 1,
		MoonProject = "GoldChicken_Entr",
		FPS = 24,
		Frames = 90,
		Duration = 90 / 24,
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		Markers = {"EntranceStart", "AuraOn", "CameraBeat", "Title", "EntranceEnd"},
		Purpose = "Match-start reveal cinematic pose sequence, pairs with CutsceneController camera track.",
	},
	Victory = {
		AssetId = "PENDING_UPLOAD",
		Version = 1,
		MoonProject = "GoldChicken_Vic",
		FPS = 24,
		Frames = 90,
		Duration = 90 / 24,
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		Markers = {"VictoryStart", "VFX", "Sound", "FinalPose", "VictoryEnd"},
		Purpose = "Match-end triumphant pose sequence, strong held final frame for results screen.",
	},
}

function Catalog.IsReady(name: string): boolean
	local entry = Catalog.Animations[name]
	return entry ~= nil and entry.AssetId ~= "PENDING_UPLOAD" and entry.AssetId ~= nil
end

function Catalog.AllReady(): boolean
	for _, entry in pairs(Catalog.Animations) do
		if entry.AssetId == "PENDING_UPLOAD" or entry.AssetId == nil then
			return false
		end
	end
	return true
end

function Catalog.PendingList()
	local pending = {}
	for name, entry in pairs(Catalog.Animations) do
		if entry.AssetId == "PENDING_UPLOAD" or entry.AssetId == nil then
			table.insert(pending, name)
		end
	end
	table.sort(pending)
	return pending
end

return Catalog
