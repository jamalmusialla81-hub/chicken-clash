--==================================================
-- CHICKEN LEVEL SERVER
-- Watches each plot's ChickenDisplay folder for equipped/
-- unequipped chickens, and activates/deactivates the matching
-- nest's Upgrade pad accordingly.
--
-- EXPECTED HIERARCHY (per nest Model, e.g. Plots.Plot1.3):
--   [Nest Model]
--     └── Upgrade
--           └── UpgradePart
--                 ├── ClickDetector
--                 └── SurfaceGui
--                       └── Frame
--                             ├── TextBox   (upgrade price, e.g. "$5")
--                             └── TextLabel (e.g. "Level 1 -> Level 2")
--
-- SurfaceGui.Enabled is treated as "is a chicken here right now".
--
-- EVERY step below now prints or warns, on purpose — this file
-- had a silent-failure bug before (a missing pad piece was
-- treated as "nothing to do here" instead of an error), which
-- made a real bug invisible. Better to be noisy while this is
-- still being wired up.
--==================================================

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local NestUtils = require(ServerScriptService:FindFirstChild("NestUtils", true))
local ChickenLevelService = require(ServerScriptService:FindFirstChild("ChickenLevelService", true))
local SoundPlayer = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundPlayer"))

local plotsFolder = Workspace:WaitForChild("Plots")

--==================================================
-- DUPLICATE-INSTANCE GUARD
--==================================================

if _G.ChickenLevelServerActive then
	warn(
		"[ChickenLevelServer] ANOTHER COPY OF THIS SCRIPT IS ALREADY RUNNING. "
			.. "Find and delete the duplicate. This instance is shutting down."
	)
	return
end

_G.ChickenLevelServerActive = true

--==================================================
-- FIND THE UPGRADE UI PIECES FOR A NEST MODEL
-- Every missing piece now warns exactly what's missing and where.
--==================================================

local function getUpgradeParts(nestModel)

	local label = nestModel:GetFullName()

	local upgradeFolder = nestModel:FindFirstChild("Upgrade")
	if not upgradeFolder then
		warn("[ChickenLevelServer] No 'Upgrade' folder/model found under " .. label)
		return nil
	end

	-- Accept either the new name (UpgradePart) or the old one (Part),
	-- so this keeps working regardless of which you used.
	local part = upgradeFolder:FindFirstChild("UpgradePart") or upgradeFolder:FindFirstChild("Part")
	if not part then
		warn(
			"[ChickenLevelServer] No 'UpgradePart' (or 'Part') found under "
				.. upgradeFolder:GetFullName()
				.. ". Children found: "
				.. table.concat((function()
					local names = {}
					for _, c in ipairs(upgradeFolder:GetChildren()) do table.insert(names, c.Name) end
					return names
				end)(), ", ")
		)
		return nil
	end

	local clickDetector = part:FindFirstChildOfClass("ClickDetector")
	if not clickDetector then
		warn("[ChickenLevelServer] No ClickDetector found under " .. part:GetFullName())
		return nil
	end

	local surfaceGui = part:FindFirstChildOfClass("SurfaceGui")
	if not surfaceGui then
		warn("[ChickenLevelServer] No SurfaceGui found under " .. part:GetFullName())
		return nil
	end

	local frame = surfaceGui:FindFirstChild("Frame")
	if not frame then
		warn("[ChickenLevelServer] No 'Frame' found under " .. surfaceGui:GetFullName())
		return nil
	end

	local priceBox = frame:FindFirstChild("TextBox")
	local levelLabel = frame:FindFirstChild("TextLabel")

	if not priceBox then
		warn("[ChickenLevelServer] No 'TextBox' (price) found under " .. frame:GetFullName())
	end

	if not levelLabel then
		warn("[ChickenLevelServer] No 'TextLabel' (level text) found under " .. frame:GetFullName())
	end

	return {
		part = part,
		clickDetector = clickDetector,
		surfaceGui = surfaceGui,
		frame = frame,
		priceBox = priceBox,
		levelLabel = levelLabel,
	}
end

--==================================================
-- TRACK ACTIVE CLICK CONNECTIONS
--==================================================

local activeConnections = {}
local cashConnections = {}

local function disconnectPad(part)

	local connection = activeConnections[part]

	if connection then
		connection:Disconnect()
		activeConnections[part] = nil
		print("[ChickenLevelServer] Disconnected old click handler on " .. part:GetFullName())
	end

	local cashConn = cashConnections[part]

	if cashConn then
		cashConn:Disconnect()
		cashConnections[part] = nil
	end
end

--==================================================
-- LEVEL TIER (border color, persistent — separate from the
-- transient afford/can't-afford background fill)
--==================================================

local TIER_BRACKETS = {
	{ minLevel = 100, color = Color3.fromRGB(80, 220, 255), name = "Diamond" },
	{ minLevel = 50, color = Color3.fromRGB(255, 215, 0), name = "Gold" },
	{ minLevel = 25, color = Color3.fromRGB(200, 200, 210), name = "Silver" },
	{ minLevel = 10, color = Color3.fromRGB(205, 127, 50), name = "Bronze" },
}

local function getTierColor(level)

	for _, bracket in ipairs(TIER_BRACKETS) do
		if level >= bracket.minLevel then
			return bracket.color, bracket.name
		end
	end

	return nil, nil
end

local function getOrCreateStroke(frame)

	local stroke = frame:FindFirstChildOfClass("UIStroke")

	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Parent = frame
	end

	return stroke
end

local function updateTierBorder(ui, level)

	if not ui.frame then
		return
	end

	local stroke = getOrCreateStroke(ui.frame)
	local color = getTierColor(level)

	if color then
		stroke.Color = color
		stroke.Transparency = 0
	else
		-- Below the first tier bracket: no special border.
		stroke.Transparency = 1
	end
end

--==================================================
-- MILESTONE FLOURISH
-- Every 10 levels: bigger sound + a particle burst on the pad,
-- on top of the normal per-click feedback.
--==================================================

local MILESTONE_INTERVAL = 10

local function isMilestoneLevel(level)
	return level % MILESTONE_INTERVAL == 0
end

local function playMilestoneFlourish(ui)

	-- Distinct sound for hitting a milestone. Falls back silently
	-- (just a warn from SoundPlayer) if you haven't added a Sound
	-- named "Milestone" yet — add one to RollSounds when ready.
	SoundPlayer.Play("Milestone")

	-- Particle burst on the pad itself. No Texture set, so it uses
	-- Roblox's default particle look — guaranteed to render without
	-- needing a specific asset id.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.0)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.4)
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
	emitter.Parent = ui.part

	emitter:Emit(30)
	Debris:AddItem(emitter, 1.5)
end

--==================================================
-- PER-CLICK JUICE
-- A quick punchy scale bounce on every successful upgrade —
-- separate from milestones, this fires every single click so
-- spamming the button always feels satisfying.
--==================================================

local function getOrCreateScale(frame)

	local scale = frame:FindFirstChildOfClass("UIScale")

	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = frame
	end

	return scale
end

local function playUpgradeClickJuice(ui)

	if not ui.frame then
		return
	end

	local scale = getOrCreateScale(ui.frame)

	local punchUp = TweenService:Create(
		scale,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 1.18 }
	)

	local settleBack = TweenService:Create(
		scale,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 1 }
	)

	punchUp:Play()
	punchUp.Completed:Once(function()
		settleBack:Play()
	end)

	-- Every-click feedback sound (short, satisfying — think "cha-ching").
	-- Falls back to "Tick" (already used by the roll reel, so it's
	-- guaranteed to exist) if you haven't added a dedicated one yet.
	if not SoundPlayer.Play("UpgradeSuccess") then
		SoundPlayer.Play("Tick")
	end
end

--==================================================
-- AFFORDABILITY COLOR
-- Green if the owner can currently afford the upgrade, red if not.
--==================================================

local AFFORDABLE_COLOR = Color3.fromRGB(60, 200, 80)
local UNAFFORDABLE_COLOR = Color3.fromRGB(200, 60, 60)

local function updateAffordabilityColor(ui, ownerPlayer, upgradeCost)

	if not ui.frame then
		return
	end

	local leaderstats = ownerPlayer:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")

	if not cash then
		return
	end

	ui.frame.BackgroundColor3 = (cash.Value >= upgradeCost) and AFFORDABLE_COLOR or UNAFFORDABLE_COLOR
end

--==================================================
-- UPDATE PAD DISPLAY TEXT
--==================================================

local function refreshPadText(ui, level, upgradeCost, ownerPlayer)

	if ui.priceBox then
		ui.priceBox.Text = "$" .. tostring(upgradeCost)
	end

	if ui.levelLabel then
		ui.levelLabel.Text = "Level " .. tostring(level) .. " -> Level " .. tostring(level + 1)
	end

	updateTierBorder(ui, level)

	if ownerPlayer then
		updateAffordabilityColor(ui, ownerPlayer, upgradeCost)
	end

	print(
		"[ChickenLevelServer] Refreshed pad text on "
			.. ui.part:GetFullName()
			.. " -> Level "
			.. tostring(level)
			.. ", cost $"
			.. tostring(upgradeCost)
	)
end

--==================================================
-- ACTIVATE PAD FOR AN EQUIPPED CHICKEN
--==================================================

local function activatePad(chickenModel)

	print("[ChickenLevelServer] activatePad called for " .. chickenModel:GetFullName())

	local nestIndex = chickenModel:GetAttribute("NestIndex")
	local ownerUserId = chickenModel:GetAttribute("OwnerUserId")
	local baseChickenName = chickenModel:GetAttribute("ChickenName")
	local uniqueChickenName = chickenModel:GetAttribute("InventoryName")

	print(
		"[ChickenLevelServer] Attributes -> NestIndex:",
		nestIndex,
		"OwnerUserId:",
		ownerUserId,
		"ChickenName:",
		baseChickenName,
		"InventoryName:",
		uniqueChickenName
	)

	if not nestIndex or not ownerUserId or not baseChickenName or not uniqueChickenName then
		warn("[ChickenLevelServer] Equipped model missing expected attributes, skipping upgrade pad setup.")
		return
	end

	local plot = chickenModel.Parent and chickenModel.Parent.Parent

	if not plot then
		warn("[ChickenLevelServer] Could not resolve plot for " .. chickenModel:GetFullName())
		return
	end

	print("[ChickenLevelServer] Resolved plot:", plot:GetFullName())

	local nestModel = NestUtils.GetNestModelForIndex(plot, nestIndex)

	if not nestModel then
		warn("[ChickenLevelServer] Could not resolve nest model for NestIndex " .. tostring(nestIndex) .. " in " .. plot:GetFullName())
		return
	end

	print("[ChickenLevelServer] Resolved nest model:", nestModel:GetFullName())

	local ui = getUpgradeParts(nestModel)

	if not ui then
		warn("[ChickenLevelServer] getUpgradeParts FAILED for " .. nestModel:GetFullName() .. " — pad will not activate. See warnings above for exactly what's missing.")
		return
	end

	print("[ChickenLevelServer] Found full upgrade UI at " .. ui.part:GetFullName())

	local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)

	if not ownerPlayer then
		warn("[ChickenLevelServer] Owner player (UserId " .. tostring(ownerUserId) .. ") not currently in-game, skipping.")
		return
	end

	local level = ChickenLevelService.GetLevel(ownerPlayer, uniqueChickenName)
	local eggValue = ChickenLevelService.GetEggValue(baseChickenName, level)
	chickenModel:SetAttribute("Level", level)
	chickenModel:SetAttribute("EggValue", eggValue)

	local upgradeCost = ChickenLevelService.GetUpgradeCost(level)

	ui.surfaceGui.Enabled = true
	refreshPadText(ui, level, upgradeCost, ownerPlayer)

	disconnectPad(ui.part)

	-- Live-update the red/green coloring whenever the owner's
	-- cash changes (e.g. from selling eggs), not just on activate.
	local leaderstats = ownerPlayer:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")

	if cash then
		cashConnections[ui.part] = cash.Changed:Connect(function()
			local currentLevel = ChickenLevelService.GetLevel(ownerPlayer, uniqueChickenName)
			local currentCost = ChickenLevelService.GetUpgradeCost(currentLevel)
			updateAffordabilityColor(ui, ownerPlayer, currentCost)
		end)
	end

	activeConnections[ui.part] = ui.clickDetector.MouseClick:Connect(function(clickingPlayer)

		print("[ChickenLevelServer] Click received on " .. ui.part:GetFullName() .. " from " .. clickingPlayer.Name)

		if plot:GetAttribute("Owner") ~= clickingPlayer.UserId then
			warn(
				"[ChickenLevelServer] Click rejected: "
					.. clickingPlayer.Name
					.. " does not own "
					.. plot:GetFullName()
					.. " (owner UserId is "
					.. tostring(plot:GetAttribute("Owner"))
					.. ")"
			)
			return
		end

		if chickenModel.Parent == nil then
			warn("[ChickenLevelServer] Click rejected: chicken model no longer equipped (was unequipped mid-click).")
			return
		end

		local success, newLevelOrReason, newCost, newEggValue =
			ChickenLevelService.TryUpgrade(clickingPlayer, uniqueChickenName, baseChickenName)

		if not success then
			warn("[ChickenLevelServer] Upgrade failed for " .. clickingPlayer.Name .. ": " .. tostring(newLevelOrReason))

			-- Distinct sound specifically for "couldn't afford it",
			-- not other failure reasons (e.g. no longer owning it).
			if newLevelOrReason == "Not enough cash" then
				SoundPlayer.Play("InsufficientFunds")
			end

			-- Briefly flash red harder so a failed click (e.g. not
			-- enough cash) gives immediate feedback, then settle
			-- back to the normal affordability color.
			if ui.frame then
				ui.frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
				task.delay(0.15, function()
					local lvl = ChickenLevelService.GetLevel(clickingPlayer, uniqueChickenName)
					local cst = ChickenLevelService.GetUpgradeCost(lvl)
					updateAffordabilityColor(ui, clickingPlayer, cst)
				end)
			end

			return
		end

		print(
			"[ChickenLevelServer] Upgrade SUCCESS for "
				.. clickingPlayer.Name
				.. " -> "
				.. uniqueChickenName
				.. " is now Level "
				.. tostring(newLevelOrReason)
				.. ", new egg value $"
				.. tostring(newEggValue)
		)

		chickenModel:SetAttribute("Level", newLevelOrReason)
		chickenModel:SetAttribute("EggValue", newEggValue)

		refreshPadText(ui, newLevelOrReason, newCost, clickingPlayer)

		-- Every successful click gets a satisfying bounce + sound...
		playUpgradeClickJuice(ui)

		-- ...and hitting a multiple of 10 gets an extra flourish on
		-- top of that.
		if isMilestoneLevel(newLevelOrReason) then
			playMilestoneFlourish(ui)
		end
	end)

	print("[ChickenLevelServer] Click handler connected on " .. ui.part:GetFullName())
end

--==================================================
-- DEACTIVATE PAD ON UNEQUIP
--==================================================

local function deactivatePad(chickenModel)

	print("[ChickenLevelServer] deactivatePad called for " .. chickenModel:GetFullName())

	local nestIndex = chickenModel:GetAttribute("NestIndex")

	if not nestIndex then
		warn("[ChickenLevelServer] No NestIndex attribute on unequipped model, cannot find its pad.")
		return
	end

	local plot = chickenModel.Parent and chickenModel.Parent.Parent

	if not plot then
		return
	end

	local nestModel = NestUtils.GetNestModelForIndex(plot, nestIndex)

	if not nestModel then
		return
	end

	local ui = getUpgradeParts(nestModel)

	if not ui then
		return
	end

	disconnectPad(ui.part)

	ui.surfaceGui.Enabled = false

	if ui.priceBox then
		ui.priceBox.Text = ""
	end

	if ui.levelLabel then
		ui.levelLabel.Text = ""
	end

	if ui.frame then
		ui.frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	end

	print("[ChickenLevelServer] Deactivated pad " .. ui.part:GetFullName())
end

--==================================================
-- WATCH A PLOT'S ChickenDisplay FOLDER
--==================================================

local watchedPlots = {}

local function watchChickenDisplay(display)

	print("[ChickenLevelServer] Watching ChickenDisplay at " .. display:GetFullName())

	for _, existingModel in ipairs(display:GetChildren()) do
		if existingModel:IsA("Model") then
			activatePad(existingModel)
		end
	end

	display.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			activatePad(child)
		end
	end)

	display.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			deactivatePad(child)
		end
	end)
end

local function watchPlot(plot)

	if watchedPlots[plot] then
		return
	end

	watchedPlots[plot] = true

	local display = plot:FindFirstChild("ChickenDisplay")

	if display then
		watchChickenDisplay(display)
	else
		print("[ChickenLevelServer] No ChickenDisplay yet in " .. plot:GetFullName() .. " — will watch for it to appear.")
	end

	plot.ChildAdded:Connect(function(child)
		if child.Name == "ChickenDisplay" then
			watchChickenDisplay(child)
		end
	end)
end

--==================================================
-- START
--==================================================

for _, plot in ipairs(plotsFolder:GetChildren()) do
	watchPlot(plot)
end

plotsFolder.ChildAdded:Connect(watchPlot)

print("[ChickenLevelServer] READY")