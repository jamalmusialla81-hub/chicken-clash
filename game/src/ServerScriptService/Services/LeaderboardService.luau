local LeaderboardService = {}

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GlobalFunctions = require(ReplicatedStorage.Utils.GlobalFunctions)

local DataService = require(script.Parent.DataService)

local CashStore
pcall(function()
	CashStore = DataStoreService:GetOrderedDataStore("Cash")
end)

local LeaderboardModel = workspace.Leaderboards.Leaderboard
local LeaderboardUi = LeaderboardModel.LeaderboardPart.SurfaceGui.ScrollingFrame
local LeaderboardContainer = LeaderboardUi.Container

local EntryTemplate = LeaderboardUi.LeaderboardScript.Template

local MAX_ENTRIES = 100
local REFRESH_TIME = 20
local SAVE_INTERVAL = 10

local Entries = {}

local function GetTemplate(rank)
	return EntryTemplate
end

local function CreateEntries()
	for rank = 1, MAX_ENTRIES do
		local entry = GetTemplate(rank):Clone()

		entry.Name = tostring(rank)
		entry.LayoutOrder = rank
		entry.Visible = false
		entry.Parent = LeaderboardContainer

		Entries[rank] = {
			Frame = entry,
			PlayerName = entry:FindFirstChild("NameLabel"),
			Value = entry:FindFirstChild("NumberLabel"),
			Rank = entry:FindFirstChild("RankLabel"),
		}
	end
end

local function UpdateLeaderboard()
	local success, pages = pcall(function()
		return CashStore:GetSortedAsync(false, MAX_ENTRIES)
	end)

	if not success then
		warn("Failed to load leaderboard")
		return
	end

	local data = pages:GetCurrentPage()

	for rank = 1, MAX_ENTRIES do
		local entry = Entries[rank]
		local row = data[rank]

		if row then
			entry.Frame.Visible = true

			if entry.PlayerName then
				local username = "Unknown"

				pcall(function()
					username = Players:GetNameFromUserIdAsync(tonumber(row.key))
				end)

				entry.PlayerName.Text = username
			end

			if entry.Value then
				entry.Value.Text = GlobalFunctions.FormatNumber(row.value)
			end

			if entry.Rank then
				entry.Rank.Text = "#" .. rank
			end
		else
			entry.Frame.Visible = false
		end
	end
end

local function StartPlayerUpdates(player)
	task.spawn(function()
		while player.Parent do
			task.wait(SAVE_INTERVAL)

			local success, cash = pcall(function()
				return DataService:Get(player, "Cash")
			end)

			if success and cash then
				pcall(function()
					CashStore:SetAsync(player.UserId, cash)
				end)
			end
		end
	end)
end

function LeaderboardService:init()
	CreateEntries()

	for _, player in Players:GetPlayers() do
		StartPlayerUpdates(player)
	end

	Players.PlayerAdded:Connect(StartPlayerUpdates)

	task.spawn(function()
		UpdateLeaderboard()

		while true do
			task.wait(REFRESH_TIME)
			UpdateLeaderboard()
		end
	end)
end

return LeaderboardService