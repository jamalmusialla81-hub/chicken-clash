--[[ ChickenCombatCamera (LocalScript, StarterPlayerScripts). Thin bootstrap only - all real logic lives
	in ReplicatedStorage.ChickenClash.ChickenCombatCameraController (a ModuleScript, not a LocalScript, so
	any other local client script - a future match-state service, CutsceneController, or the combat HUD -
	can require() the SAME live controller instance and call its state-transition API directly, instead of
	camera logic being locked inside one unreachable script). This file's only job is to trigger that
	module's one-time setup by requiring it. ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenCombatCameraController"))
