--[[ PracticeChickenSelect (client, LocalScript). Phase 4: the chicken-selection UI PracticeService's
	`PracticeSelectChickenRequest` remote has been waiting for since the Phase 6 ChickenDefinitions
	refactor - that module's own header comment says plainly "no chicken-selection UI exists yet; that is
	a later pass," and `PracticeChickenLocked` was already wired into PracticeHUD (a toast) with nothing
	upstream ever firing the select request that toast responds to. This is that later pass.

	ChickenDefinitions' header ALSO warns that CombatCompatible must never be read client-side as ground
	truth, since validation runs server-only against ServerStorage rigs that never replicate. So this
	reads a small server-authoritative snapshot via the new `Combat.GetChickenRoster` RemoteFunction
	(added in ChickenTemplateService alongside the validation bootstrap it already ran) instead of
	requiring ChickenDefinitions directly.

	Selecting a chicken re-enters PracticeService.SetChicken, which already fires the existing
	Entrance cutscene for the new fighter (see PracticeService's cameraDirective calls) - that IS this
	project's "chicken switch transformation sequence": reusing the real cinematic instead of building a
	second, redundant one.

	Right now the roster is exactly two entries (Golden - the only combat-verified rig - and Red, always
	shown locked with its real validator rejection reason) since ChickenDefinitions.List has only ever had
	those two combat character definitions written; the grid scrolls and lays out generically so it needs
	no changes whenever more are added. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("Theme"))
local UIStateController = require(ReplicatedStorage:WaitForChild("ChickenClash"):WaitForChild("UIStateController"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local combatFolder = ReplicatedStorage:WaitForChild("Combat")
local selectRemote = combatFolder:WaitForChild("PracticeSelectChickenRequest")
local rosterFunction = combatFolder:WaitForChild("GetChickenRoster")
local ownedFolder = player:WaitForChild("Chickens")

--============================== gui shell ==============================--
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PracticeChickenSelect"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 35
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Theme.Panel(screenGui, {
	name = "ChickenSelectPanel",
	size = UDim2.fromOffset(560, 320),
	position = UDim2.new(0.5, 0, 0.5, 0),
	anchorPoint = Vector2.new(0.5, 0.5),
})
panel.Visible = false
panel.ZIndex = 5

local function setOpen(open: boolean)
	panel.Visible = open
end

local toggleApi = Theme.Button(screenGui, {
	name = "ChickenSelectToggle",
	text = "CHICKEN",
	size = UDim2.fromOffset(120, 40),
	textSize = 13,
	onClick = function()
		setOpen(not panel.Visible)
	end,
})
toggleApi.root.AnchorPoint = Vector2.new(1, 0)
toggleApi.root.Position = UDim2.new(1, -16, 0, 16)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -60, 0, 28)
title.Position = UDim2.new(0, 16, 0, 12)
title.Font = Theme.Fonts.Bold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Theme.Colors.Gold
title.Text = "SELECT CHICKEN"
title.Parent = panel

local closeApi = Theme.Button(panel, {
	name = "Close",
	text = "X",
	size = UDim2.fromOffset(32, 32),
	textSize = 14,
	topColor = Theme.Colors.Coral,
	onClick = function()
		setOpen(false)
	end,
})
closeApi.root.AnchorPoint = Vector2.new(1, 0)
closeApi.root.Position = UDim2.new(1, -12, 0, 10)

local cardHolder = Instance.new("ScrollingFrame")
cardHolder.Name = "Cards"
cardHolder.BackgroundTransparency = 1
cardHolder.BorderSizePixel = 0
cardHolder.Size = UDim2.new(1, -32, 1, -64)
cardHolder.Position = UDim2.new(0, 16, 0, 52)
cardHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
cardHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
cardHolder.ScrollBarThickness = 6
cardHolder.Parent = panel

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(150, 220)
grid.CellPadding = UDim2.fromOffset(14, 14)
grid.SortOrder = Enum.SortOrder.Name
grid.Parent = cardHolder

--============================== card population ==============================--
local function ownsChicken(displayName: string): boolean
	local v = ownedFolder:FindFirstChild(displayName)
	return v ~= nil and v:IsA("IntValue") and v.Value > 0
end

local function buildCards()
	for _, c in ipairs(cardHolder:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end

	local ok, roster = pcall(function()
		return rosterFunction:InvokeServer()
	end)
	if not ok or type(roster) ~= "table" then
		warn("[PracticeChickenSelect] GetChickenRoster failed: " .. tostring(roster))
		return
	end

	for _, entry in ipairs(roster) do
		local owned = ownsChicken(entry.DisplayName)
		local locked = not owned or not entry.CombatCompatible

		local card = Theme.Panel(cardHolder, { name = entry.Id .. "Card", size = UDim2.fromOffset(150, 220) })

		Theme.ViewportChickenPreview(card, {
			chickenName = entry.DisplayName,
			size = UDim2.new(1, -16, 0, 110),
			position = UDim2.new(0, 8, 0, 8),
			tint = locked and Color3.fromRGB(90, 90, 90) or nil,
		})

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, -16, 0, 20)
		nameLabel.Position = UDim2.new(0, 8, 0, 122)
		nameLabel.Font = Theme.Fonts.Bold
		nameLabel.TextSize = 14
		nameLabel.TextColor3 = Theme.Colors.Text
		nameLabel.Text = entry.DisplayName
		nameLabel.Parent = card

		local statusLabel = Instance.new("TextLabel")
		statusLabel.BackgroundTransparency = 1
		statusLabel.Size = UDim2.new(1, -16, 0, 44)
		statusLabel.Position = UDim2.new(0, 8, 0, 144)
		statusLabel.Font = Theme.Fonts.Body
		statusLabel.TextSize = 11
		statusLabel.TextWrapped = true
		statusLabel.TextYAlignment = Enum.TextYAlignment.Top
		statusLabel.TextColor3 = Theme.Colors.TextMuted
		statusLabel.Text = (not owned) and "Not owned"
			or (not entry.CombatCompatible) and (entry.CombatUnavailableReason or "Not combat-ready")
			or "Ready"
		statusLabel.Parent = card

		local selectApi = Theme.Button(card, {
			name = "Select",
			text = locked and "LOCKED" or "SELECT",
			size = UDim2.new(1, -16, 0, 32),
			textSize = 12,
			disabled = locked,
			onClick = (not locked) and function()
				selectRemote:FireServer(entry.Id)
				setOpen(false)
			end or nil,
		})
		selectApi.root.Position = UDim2.new(0, 8, 0, 190)
	end
end

panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		buildCards()
	end
end)

--============================== practice-only gating ==============================--
local function applyMode(mode: string)
	screenGui.Enabled = (mode == "Practice")
	if mode ~= "Practice" then
		setOpen(false)
	end
end

applyMode(UIStateController.GetMode())
UIStateController.OnModeChanged(applyMode)
