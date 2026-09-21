local EventModule = {}
local activeGalaxySky

local function getAdminAbuse()
	local rs = game:GetService("ReplicatedStorage")
	for _, assets in ipairs(rs:GetChildren()) do
		local adminAbuse = assets:FindFirstChild("AdminAbuse")
		if adminAbuse then return adminAbuse end
	end
end

local function cloneAssetsToWorld(folderName)
	local Lighting   = game:GetService("Lighting")
	local adminAbuse = getAdminAbuse()
	local folder     = adminAbuse and adminAbuse:FindFirstChild(folderName)
	if not folder then return end
	local targets = {
		Candy = {VFX = Vector3.new(-19.926, 41, -88.431)},
		Galaxy = {VFX = Vector3.new(-19.926, 45.570, -88.431)},
	}
	for _, child in ipairs(folder:GetChildren()) do
		local clone  = child:Clone()
		clone.Name   = clone.Name .. "_EventActive"
		clone.Parent = child:IsA("Sky") and Lighting or workspace
		local target = targets[folderName] and targets[folderName][child.Name]
		if target and clone:IsA("Model") then
			local pivot = clone:GetPivot()
			clone:PivotTo(CFrame.new(target) * (pivot - pivot.Position))
		end
		if folderName == "Galaxy" and child:IsA("Sky") then
			activeGalaxySky = clone
		end
	end
end

local function clearEventAssets()
	local Lighting = game:GetService("Lighting")
	if activeGalaxySky then
		activeGalaxySky:Destroy()
		activeGalaxySky = nil
	end
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name:match("_EventActive$") then obj:Destroy() end
	end
	for _, obj in ipairs(Lighting:GetChildren()) do
		if obj.Name:match("_EventActive$") then obj:Destroy() end
	end
end

EventModule.EVENTS = {
	{
		id            = "RadioactiveSpawn",
		name          = "Radioactive",
		icon          = "rbxassetid://0",
		musicKey      = "radioactive",
		announceColor = "#39ff14",
		announceMsg   = "Radio Active Event has Just Started!",
		onStart       = function() cloneAssetsToWorld("RadioActive") end,
		onEnd         = clearEventAssets,
	},
	{
		id            = "CandySpawn",
		name          = "Candy",
		icon          = "rbxassetid://0",
		musicKey      = "candy",
		announceColor = "#ff69b4",
		announceMsg   = "Candy Event has Just Started!",
		onStart       = function() cloneAssetsToWorld("Candy") end,
		onEnd         = clearEventAssets,
	},
	{
		id            = "MagmaSpawn",
		name          = "Magma",
		icon          = "rbxassetid://0",
		musicKey      = "magma",
		announceColor = "#ff6600",
		announceMsg   = "Lava Event has Just Started!",
		onStart       = function() cloneAssetsToWorld("Magma") end,
		onEnd         = clearEventAssets,
	},
	{
		id            = "DiscoEvent",
		name          = "Disco",
		icon          = "rbxassetid://0",
		musicKey      = "disco",
		announceColor = "#bf00ff",
		announceMsg   = "Disco Event has Just Started!",
		onStart = function(triggerUserId)
			-- Clone all Disco folder assets except the Character
			local Lighting   = game:GetService("Lighting")
			local folder     = getAdminAbuse()
			folder          = folder and folder:FindFirstChild("Disco")
			local templateChar = folder and folder:FindFirstChild("Character")

			if folder then
				for _, child in ipairs(folder:GetChildren()) do
					if child.Name == "Character" then continue end
					local clone  = child:Clone()
					clone.Name   = clone.Name .. "_EventActive"
					clone.Parent = child:IsA("Sky") and Lighting or workspace
					if clone:IsA("Model") then
						local target = child.Name == "DJ Set" and Vector3.new(-12.819, 36.465, -196.599)
							or child.Name == "VFX" and Vector3.new(-19.926, 41, -88.431)
						if target then
							local pivot = clone:GetPivot()
							clone:PivotTo(CFrame.new(target) * (pivot - pivot.Position))
						end
					end
				end
			end

			local SPAWN_CF = CFrame.new(-13.728, 45.157, -203.178) * CFrame.Angles(0, math.rad(180), 0)

			-- Build the triggering admin's avatar at scale 15, R15
			local charModel
			if triggerUserId then
				local Players = game:GetService("Players")
				local ok, desc = pcall(function()
					return Players:GetHumanoidDescriptionFromUserId(triggerUserId)
				end)
				if ok then
					desc.HeightScale = 15
					desc.WidthScale  = 15
					desc.DepthScale  = 15
					desc.HeadScale   = 15
					local ok2, model = pcall(function()
						return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
					end)
					if ok2 then charModel = model end
				end
			end

			-- Fallback to template Character clone if avatar fetch fails
			if not charModel and templateChar then
				charModel = templateChar:Clone()
			end

			if charModel then
				charModel.Name = "DiscoCharacter_EventActive"
				-- Remove any default player-linked scripts
				for _, s in ipairs(charModel:GetDescendants()) do
					if s:IsA("BaseScript") then s:Destroy() end
				end
				-- Clone the EmoteScript (includes its Animation child) from the template
				if templateChar then
					local emoteScript = templateChar:FindFirstChild("EmoteScript")
					if emoteScript then
						emoteScript:Clone().Parent = charModel
					end
				end
				-- Place into workspace, position and rotate
				charModel.Parent = workspace
				charModel:PivotTo(SPAWN_CF)
				-- Only anchor HumanoidRootPart so Motor6D joints can still animate the limbs
				local hrp = charModel:FindFirstChild("HumanoidRootPart")
				if hrp then hrp.Anchored = true end
			end

			-- Event music is intentionally disabled.
		end,
		onEnd = clearEventAssets,
	},
	{
		id            = "SpaceEvent",
		name          = "Space",
		icon          = "rbxassetid://0",
		musicKey      = "",
		announceColor = "#00cfff",
		announceMsg   = "Space Event has Just Started!",
		onStart = function()
			cloneAssetsToWorld("Galaxy")
			workspace.Gravity = 30
			local snd        = Instance.new("Sound")
			-- Event music is intentionally disabled.
		end,
		onEnd = function()
			clearEventAssets()
			workspace.Gravity = 196.2
		end,
	},
}

function EventModule.getById(id)
	for _, ev in ipairs(EventModule.EVENTS) do
		if ev.id == id then return ev end
	end
	return nil
end

return EventModule
