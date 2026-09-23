--[[ PracticeLaneLandmarks (client, LocalScript). Phase 3 finish: gives the Practice Range's four lane
	signs (Stationary/Strafing/Attacking/Combo, built in the Gate 4 map pass) real per-lane identity beyond
	static text - the active lane's floor accent lights up and its sign shows live stats, driven by the
	same "PracticeStats" RemoteEvent PracticeHUD already reads (PracticeService now also includes the
	session's current `mode` in that payload). Everything else (floor arrows, the sign geometry itself) was
	built directly in the map pass and needs no script.

	Lane center coordinates below intentionally mirror PracticeService's server-only LANE_DUMMY_POS/
	RANGE_CENTER constants (not exposed to the client) - this is the same duplication already implicit in
	how the lane signs/patches were hand-placed to match those positions during the map pass. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIStateController = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("UIStateController"))

local player = Players.LocalPlayer
local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local statsRemote = combatFolder:WaitForChild("PracticeStats")

local lanes = workspace.Map.PracticeRange:WaitForChild("Lanes")

local LANE_PATCH_POS = {
	Stationary = Vector3.new(480, 9.1, 10),
	Strafing = Vector3.new(500, 9.1, 10),
	Attacking = Vector3.new(520, 9.1, 10),
	Combo = Vector3.new(500, 9.1, 35),
}

local signs = {} -- mode -> { main = TextLabel, counter = TextLabel }
local rings = {} -- mode -> AccentRing (BasePart)
local baseColors = {} -- mode -> original AccentRing Color3, so highlight can be reverted exactly

for _, c in ipairs(lanes:GetChildren()) do
	if c.Name == "LaneSign" then
		local bb = c:FindFirstChildWhichIsA("BillboardGui")
		local main = bb and bb:FindFirstChildWhichIsA("TextLabel")
		local counter = bb and bb:FindFirstChild("CounterLabel")
		if main then
			local mode = main.Text:gsub(" Lane$", "")
			if LANE_PATCH_POS[mode] then
				signs[mode] = { main = main, counter = counter }
			end
		end
	elseif c.Name == "LanePatch" then
		local ring = c:FindFirstChild("AccentRing")
		if ring then
			for mode, pos in pairs(LANE_PATCH_POS) do
				if (c.Position - pos).Magnitude < 1 then
					rings[mode] = ring
					baseColors[mode] = ring.Color
					break
				end
			end
		end
	end
end

local currentMode: string? = nil

local function setActiveLane(mode: string?)
	if mode == currentMode then
		return
	end
	currentMode = mode
	for m, ring in pairs(rings) do
		if m == mode then
			ring.Material = Enum.Material.Neon
		else
			ring.Material = Enum.Material.SmoothPlastic
			ring.Color = baseColors[m]
		end
	end
	for m, entry in pairs(signs) do
		if m ~= mode and entry.counter then
			entry.counter.Text = "-- hits"
			entry.counter.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
	end
end

local function onStats(payload)
	if UIStateController.GetMode() ~= "Practice" then
		return
	end
	local mode = payload.mode
	if not mode or not signs[mode] then
		return
	end
	setActiveLane(mode)
	local entry = signs[mode]
	if entry.counter then
		entry.counter.Text = string.format(
			"%d dmg  ·  x%d combo (best x%d)",
			math.floor(payload.totalDamage or 0),
			math.floor(payload.combo or 0),
			math.floor(payload.highestCombo or 0)
		)
		entry.counter.TextColor3 = Color3.fromRGB(255, 241, 210)
	end
end

statsRemote.OnClientEvent:Connect(onStats)

UIStateController.OnModeChanged(function(mode)
	if mode ~= "Practice" then
		setActiveLane(nil)
	end
end)
