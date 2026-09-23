--[[ PracticeRangePrompts (server, Script). Wires the Practice Range's own return gate and
	chicken-selection station prompts to PracticeService - the range's local interactions, as opposed to
	TrainingDojoPrompt, which wires the hub-side portal that gets a player INTO practice in the first
	place. Selection prompts read their target chicken from a "ChickenDefId" attribute set at build time
	(see the range-building pass), so this script needs no per-chicken special-casing and will pick up any
	future ChickenDefinitions entry automatically. ]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PracticeService = require(ServerScriptService.Combat:WaitForChild("PracticeService"))
local ChickenDefinitions = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("ChickenDefinitions"))

local range = workspace.Map:WaitForChild("PracticeRange")

local returnPrompt = range.ReturnGate.ReturnPromptHolder.ReturnToHubPrompt
returnPrompt.Triggered:Connect(function(player: Player)
	if PracticeService.IsInPractice(player) then
		PracticeService.Exit(player)
	end
end)

-- Locked/incompatible chickens must be shown clearly, never silently fail: ActionText itself says
-- "Locked" and the prompt still fires so the player gets the real reason via PracticeChickenLocked
-- (SetChicken rejects it and fires that remote - see PracticeService).
local function refreshPromptText(prompt, defId)
	local def = ChickenDefinitions.Get(defId)
	if not def then
		return
	end
	if def.CombatCompatible then
		prompt.ActionText = "Select " .. def.DisplayName
	else
		prompt.ActionText = "Locked"
	end
end

for _, pedestal in ipairs(range.ChickenSelectStation:GetChildren()) do
	local prompt = pedestal:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		local defId = prompt:GetAttribute("ChickenDefId")
		refreshPromptText(prompt, defId)
		prompt.Triggered:Connect(function(player: Player)
			if PracticeService.IsInPractice(player) then
				PracticeService.SetChicken(player, defId)
			end
		end)
	end
end
