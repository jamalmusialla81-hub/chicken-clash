--[[
	EggAnimationConfig
	LOCATION: ServerScriptService.EggAnimationConfig  (ModuleScript)
]]

local Config = {}

--------------------------------------------------
-- LAUNCH (procedural fallback – unused in Moon-only mode)
--------------------------------------------------
Config.LaunchPower = 1.0
Config.LaunchHeight = 6
Config.LaunchDuration = 0.5
Config.LaunchDurationMinScale = 0.6
Config.LaunchAnticipationTime = 0.12
Config.LaunchAnticipationDrop = 0.3
Config.LaunchRotations = 1.25
Config.LandingBounceHeight = 0.35
Config.LandingBounceTime = 0.12

--------------------------------------------------
-- CONVEYOR (procedural fallback)
--------------------------------------------------
Config.ConveyorDuration = 3.0
Config.ConveyorEaseFraction = 0.15
Config.EggRollRadius = nil

--------------------------------------------------
-- DROP (procedural fallback)
--------------------------------------------------
Config.DropApproachTime = 0.25
Config.DropFallTime = 0.35
Config.SettleTime = 0.12
Config.SettleTilt = 6
Config.PostDropLinger = 0.15

--------------------------------------------------
-- MOON ANIMATOR PLAYBACK
--------------------------------------------------
Config.MoonAnimatorSavesFolderName = "MoonAnimator2Saves"
Config.MoonAnimationFrameRate = 60

Config.MoonMirrorOppositeRow = false
Config.MoonSlotsPerRow = 4
Config.MoonReferenceSlot = 4
Config.MoonLaunchLandingFrame = 91
Config.MoonTailStartFrame = nil

Config.DefaultMoonAnimation = "ChickenLaySlot4"

Config.SlotAnimations = {
	[4] = "ChickenLaySlot4",
}

--------------------------------------------------
-- MOON BRIDGE (roll on belt, then drop into box)
--------------------------------------------------
Config.MoonBridgeDropDistance = 2.5
Config.MoonBridgeDropTime = 0.35
-- Lift so the egg sits on top of the conveyor (raise if it still clips)
Config.MoonBeltYOffset = 0.5

--------------------------------------------------
-- MISC
--------------------------------------------------
Config.MaxLifetime = 20

return Config