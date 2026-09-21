local Players = game:GetService("Players")
local PlotsFolder = workspace:WaitForChild("Plots")

for _, plot in ipairs(PlotsFolder:GetChildren()) do
	local spawnLoc = plot:FindFirstChild("SpawnLocation", true)
	if spawnLoc then
		spawnLoc.Transparency = 1
		spawnLoc.CanCollide = false
	end
end

-- Only treat a SurfaceGui as the plot nameplate if it actually has
-- the fields we expect. This is what prevents this script from
-- accidentally grabbing an unrelated SurfaceGui (like a chicken
-- upgrade pad) that also happens to be named "SurfaceGui" somewhere
-- else inside the same plot.
local function isNameplateSurfaceGui(candidate)
	if not candidate or not candidate:IsA("SurfaceGui") then
		return false
	end

	return candidate:FindFirstChild("PlayerName") ~= nil
		and candidate:FindFirstChild("ProfileIcon") ~= nil
end

local function updatePlot(plot, player)
	local surfaceGui = nil

	-- Try every "SurfaceGui" named descendant, not just the first one,
	-- and only accept it if it actually looks like the nameplate.
	for _, descendant in ipairs(plot:GetDescendants()) do
		if descendant.Name == "SurfaceGui" and isNameplateSurfaceGui(descendant) then
			surfaceGui = descendant
			break
		end
	end

	if not surfaceGui then
		local board = plot:FindFirstChild("Board", true)
		if board then
			local boardPart = board:FindFirstChild("Board", true)
			if boardPart then
				local baseInfo = boardPart:FindFirstChild("BaseInfo", true)
				if baseInfo and isNameplateSurfaceGui(baseInfo) then
					surfaceGui = baseInfo
				end
			end
		end
	end
	if not surfaceGui then
		print("[PlotManager] No SurfaceGui for", plot:GetFullName())
		return
	end

	local plotNamer = surfaceGui:FindFirstChild("PlayerName")
	local plotImage = surfaceGui:FindFirstChild("ProfileIcon")
	if not plotNamer then warn("[PlotManager] Missing PlayerName in", surfaceGui:GetFullName()) end
	if not plotImage then warn("[PlotManager] Missing ProfileIcon in", surfaceGui:GetFullName()) end

	if player then
		if plotNamer then plotNamer.Text = player.Name end
		if plotImage then
			plotImage.BackgroundTransparency = 1
			local success, content = pcall(function()
				return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			end)
			if success then plotImage.Image = content else warn("[PlotManager] Thumbnail failed for", player.Name, content) end
		end
	else
		if plotNamer then plotNamer.Text = "Unclaimed Land" end
		if plotImage then
			plotImage.Image = ""
			plotImage.BackgroundTransparency = 1
		end
	end
end

local function teleportToSpawn(player, plot)
	local spawnLoc = plot:FindFirstChild("SpawnLocation", true)
	if spawnLoc then
		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart")
		character:PivotTo(spawnLoc.CFrame * CFrame.new(0, 3, 0))
	end
end

local function releasePlot(plot)
	plot:SetAttribute("Owner", nil)
	updatePlot(plot, nil)
	local display = plot:FindFirstChild("ChickenDisplay")
	if display and display:GetAttribute("GeneratedChickenDisplay") then
		display:Destroy()
	end
end

local function onPlayerAdded(player)
	for _, plot in ipairs(PlotsFolder:GetChildren()) do
		local owner = plot:GetAttribute("Owner")
		if owner and not Players:GetPlayerByUserId(owner) then
			releasePlot(plot)
		end
	end

	local assignedPlot
	for i = 1, 8 do
		local plot = PlotsFolder:FindFirstChild("Plot " .. i) or PlotsFolder:FindFirstChild("Plot" .. i)
		if plot and not plot:GetAttribute("Owner") then
			plot:SetAttribute("Owner", player.UserId)
			player:SetAttribute("AssignedPlot", plot.Name)
			updatePlot(plot, player)
			assignedPlot = plot
			break
		end
	end

	if not assignedPlot then
		warn("[PlotManager] No unclaimed plot available for " .. player.Name)
		return
	end

	local function onCharacterAdded(character)
		character:WaitForChild("HumanoidRootPart")
		teleportToSpawn(player, assignedPlot)
		for _, box in ipairs(character:GetDescendants()) do
			if box:IsA("Model") and box.Name == "EggBox" then box:Destroy() end
		end
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then task.spawn(onCharacterAdded, player.Character) end
end

local function onPlayerRemoving(player)
	for _, plot in ipairs(PlotsFolder:GetChildren()) do
		if plot:GetAttribute("Owner") == player.UserId then
			releasePlot(plot)
		end
	end
	player:SetAttribute("AssignedPlot", nil)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end