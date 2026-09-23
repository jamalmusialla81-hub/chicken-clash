--[[ QuickMatchPresentation (client, LocalScript). Reference-informed Phase 6: separates Quick Match
	PRESENTATION (this file) from queue logic (MatchService/ArenaQueuePrompt, unchanged, still fully
	authoritative). Drives two sinks from the same real signal - the player's own "MatchState" attribute:

	1. A visible world-space terminal at the Hub's Arena Portal (QuickMatchTerminal, built alongside this
	   script) - what a player physically standing there sees.
	2. A small persistent overlay bar visible from anywhere in the Lobby - since Quick Match can also be
	   started from the Lobby dock button, not only by walking to the portal.

	Pad states actually reachable from real signals: Idle, Queued, Cancelled (a brief local flash right
	after this script's own Cancel button fires while already Queued). There is deliberately no
	"OpponentFound"/"Preparing"/"EnteringMatch" state built here: MatchService's MatchState goes straight
	from "Queued" to a real match state ("Preparing") the instant a match is found - there is no separate
	"opponent found, about to start" server signal to read, so one is not fabricated. Once MatchState
	leaves "Queued"/"Lobby"/"Practice" for a real match state, this script hides and hands off cleanly to
	MatchHUD's own pre-fight card and the existing Entrance cutscene, rather than building a second,
	overlapping "match found" screen. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("Theme"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local quickMatchRemote = combatFolder:WaitForChild("QuickMatchRequest")

local terminal = workspace.Map.Hub.ArenaPortal.Portal:WaitForChild("QuickMatchTerminal")
local terminalGui = terminal:WaitForChild("SurfaceGui")
local stateLabel = terminalGui.Background.StateLabel
local subLabel = terminalGui.Background.SubLabel

--============================== overlay (visible anywhere, not just at the portal) ==============================--
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuickMatchOverlay"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 40
screenGui.Enabled = false
screenGui.Parent = playerGui

local overlay = Theme.Panel(screenGui, {
	name = "Overlay",
	size = UDim2.fromOffset(300, 60),
	position = UDim2.new(0.5, 0, 0, 16),
	anchorPoint = Vector2.new(0.5, 0),
})

local overlayLabel = Instance.new("TextLabel")
overlayLabel.BackgroundTransparency = 1
overlayLabel.Position = UDim2.new(0, 12, 0, 6)
overlayLabel.Size = UDim2.new(1, -112, 0, 20)
overlayLabel.Font = Theme.Fonts.Bold
overlayLabel.TextSize = 14
overlayLabel.TextXAlignment = Enum.TextXAlignment.Left
overlayLabel.TextColor3 = Theme.Colors.Gold
overlayLabel.Text = "SEARCHING..."
overlayLabel.Parent = overlay

local overlayTimer = Instance.new("TextLabel")
overlayTimer.BackgroundTransparency = 1
overlayTimer.Position = UDim2.new(0, 12, 0, 26)
overlayTimer.Size = UDim2.new(1, -112, 0, 18)
overlayTimer.Font = Theme.Fonts.Body
overlayTimer.TextSize = 12
overlayTimer.TextXAlignment = Enum.TextXAlignment.Left
overlayTimer.TextColor3 = Theme.Colors.TextMuted
overlayTimer.Text = "0:00"
overlayTimer.Parent = overlay

local cancelApi = Theme.Button(overlay, {
	name = "Cancel",
	text = "CANCEL",
	size = UDim2.fromOffset(80, 34),
	textSize = 12,
	topColor = Theme.Colors.Coral,
	bottomColor = Theme.Colors.Panel,
})
cancelApi.root.AnchorPoint = Vector2.new(1, 0.5)
cancelApi.root.Position = UDim2.new(1, -10, 0.5, 0)

--============================== state derivation ==============================--
local queuedSince: number? = nil
local cancelFlashUntil = 0

cancelApi.face.MouseButton1Click:Connect(function()
	if player:GetAttribute("MatchState") == "Queued" then
		cancelFlashUntil = os.clock() + 1.2
	end
	quickMatchRemote:FireServer()
end)

local function formatTimer(seconds: number): string
	seconds = math.floor(math.max(seconds, 0))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function render()
	local matchState = player:GetAttribute("MatchState")
	local cancelling = os.clock() < cancelFlashUntil
	local queued = matchState == "Queued"
	-- Once a real match state exists (anything other than Lobby/Queued/Practice), this presentation
	-- hands off entirely - MatchHUD/the Entrance cutscene own the rest of the flow from here.
	local realMatchState = matchState ~= nil and matchState ~= "Lobby" and matchState ~= "Queued" and matchState ~= "Practice"

	screenGui.Enabled = (queued or cancelling) and not realMatchState

	if cancelling then
		overlayLabel.Text = "QUEUE CANCELLED"
		overlayTimer.Text = ""
		stateLabel.Text = "CANCELLED"
		subLabel.Text = "Step up to queue again"
	elseif queued then
		overlayLabel.Text = "SEARCHING FOR OPPONENT..."
		overlayTimer.Text = queuedSince and formatTimer(os.clock() - queuedSince) or "0:00"
		stateLabel.Text = "SEARCHING..."
		subLabel.Text = "Opponent or training bot incoming"
	elseif not realMatchState then
		stateLabel.Text = "QUICK MATCH"
		subLabel.Text = "Step up to queue"
	end
end

player:GetAttributeChangedSignal("MatchState"):Connect(function()
	local matchState = player:GetAttribute("MatchState")
	queuedSince = (matchState == "Queued") and os.clock() or nil
	render()
end)

-- The queued search timer needs a steady tick even though MatchState itself isn't changing every frame.
task.spawn(function()
	while true do
		render()
		task.wait(0.5)
	end
end)

render()
