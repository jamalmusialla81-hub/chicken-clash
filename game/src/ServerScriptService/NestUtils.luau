--==================================================
-- NEST UTILS
-- Shared plot/nest detection logic. Pulled out of
-- ChickenRollService so any other script (like
-- ChickenLevelServer) that needs to know "which nest is
-- slot N" or "what plot does this player own" uses the exact
-- same computation — never a second copy that could drift out
-- of sync with the original.
--==================================================

local Workspace = game:GetService("Workspace")

local plotsFolder = Workspace:WaitForChild("Plots")

local NestUtils = {}

local STRAW_COLOR = Vector3.new(0.890196, 0.768627, 0.321569)
local COLOR_TOLERANCE = 0.06

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = {}


function NestUtils.GetNestSlots(plot)

	--==================================================
	-- PREFERRED: explicit NestOrder attribute
	-- If you set a Number attribute "NestOrder" (1, 2, 3, 4...)
	-- directly on each nest Model in Studio, that ordering is
	-- used directly — no color guessing, fully deterministic.
	--==================================================

	local orderedModels = {}

	for _, child in ipairs(plot:GetChildren()) do
		if child:IsA("Model") then
			local order = child:GetAttribute("NestOrder")
			if type(order) == "number" then
				table.insert(orderedModels, { model = child, order = order })
			end
		end
	end

	if #orderedModels > 0 then

		table.sort(orderedModels, function(a, b)
			return a.order < b.order
		end)

		local slots = {}

		for _, entry in ipairs(orderedModels) do

			local nestPos = entry.model:GetPivot().Position
			local standPos = Vector3.new(nestPos.X, nestPos.Y + 8, nestPos.Z)

			local result = Workspace:Raycast(standPos, Vector3.new(0, -30, 0), raycastParams)
			local standY = result and result.Position.Y or (nestPos.Y + 0.5)

			table.insert(slots, {
				model = entry.model,
				cf = CFrame.new(Vector3.new(standPos.X, standY, standPos.Z))
					* CFrame.Angles(0, math.rad(-90), 0),
			})
		end

		print(
			"[NestUtils] Using NestOrder attributes for "
				.. plot:GetFullName()
				.. " — "
				.. #slots
				.. " nest(s), in order: "
				.. table.concat((function()
					local names = {}
					for _, s in ipairs(slots) do table.insert(names, s.model.Name) end
					return names
				end)(), ", ")
		)

		return slots
	end

	--==================================================
	-- SECOND CHOICE: nest Model literally named a plain number
	-- ("1", "2", "3"...). This matches your actual setup with
	-- zero manual attribute-setting needed.
	--==================================================

	if #orderedModels == 0 then

		for _, child in ipairs(plot:GetChildren()) do
			if child:IsA("Model") then
				local numericName = tonumber(child.Name)
				if numericName then
					table.insert(orderedModels, { model = child, order = numericName })
				end
			end
		end

		if #orderedModels > 0 then

			table.sort(orderedModels, function(a, b)
				return a.order < b.order
			end)

			local slots = {}

			for _, entry in ipairs(orderedModels) do

				local nestPos = entry.model:GetPivot().Position
				local standPos = Vector3.new(nestPos.X, nestPos.Y + 8, nestPos.Z)

				local result = Workspace:Raycast(standPos, Vector3.new(0, -30, 0), raycastParams)
				local standY = result and result.Position.Y or (nestPos.Y + 0.5)

				table.insert(slots, {
					model = entry.model,
					cf = CFrame.new(Vector3.new(standPos.X, standY, standPos.Z))
						* CFrame.Angles(0, math.rad(-90), 0),
				})
			end

			print(
				"[NestUtils] Using numeric-named nest Models for "
					.. plot:GetFullName()
					.. " — "
					.. #slots
					.. " nest(s), in order: "
					.. table.concat((function()
						local names = {}
						for _, s in ipairs(slots) do table.insert(names, s.model.Name) end
						return names
					end)(), ", ")
			)

			return slots
		end
	end

	--==================================================
	-- LAST RESORT: straw-color detection (original method)
	--==================================================

	local slots = {}
	raycastParams.FilterDescendantsInstances = {}

	for _, child in ipairs(plot:GetChildren()) do

		if child:IsA("Model") then

			for _, part in ipairs(child:GetDescendants()) do

				if part:IsA("BasePart") then

					local c = part.Color

					if math.abs(c.R - STRAW_COLOR.X) < COLOR_TOLERANCE
						and math.abs(c.G - STRAW_COLOR.Y) < COLOR_TOLERANCE
						and math.abs(c.B - STRAW_COLOR.Z) < COLOR_TOLERANCE then

						local nestPos = child:GetPivot().Position

						local standPos = Vector3.new(
							nestPos.X,
							nestPos.Y + 8,
							nestPos.Z
						)

						local result = Workspace:Raycast(
							standPos,
							Vector3.new(0, -30, 0),
							raycastParams
						)

						local standY =
							result and result.Position.Y or (nestPos.Y + 0.5)

						table.insert(slots, {
							model = child,
							cf = CFrame.new(Vector3.new(standPos.X, standY, standPos.Z))
								* CFrame.Angles(0, math.rad(-90), 0),
						})

						break
					end
				end
			end
		end
	end

	table.sort(slots, function(a, b)

		local pa = a.cf.Position
		local pb = b.cf.Position

		if math.abs(pa.Z - pb.Z) > 1 then
			return pa.Z > pb.Z
		end

		return pa.X < pb.X
	end)

	-- DIAGNOSTIC: this print is the key thing to check. If this
	-- number is less than your actual nest count, straw-color
	-- detection is failing on some nests (likely a slightly
	-- different color/tolerance) — set NestOrder attributes
	-- instead of debugging the color match further.
	print(
		"[NestUtils] Straw-color fallback detected "
			.. #slots
			.. " nest(s) in "
			.. plot:GetFullName()
			.. " out of "
			.. #plot:GetChildren()
			.. " total children. If this is fewer than your real "
			.. "nest count, set a NestOrder attribute on each nest "
			.. "Model instead of relying on color detection."
	)

	return slots
end


function NestUtils.FindPlayerPlot(player)

	local assigned = player:GetAttribute("AssignedPlot")

	if assigned then

		local plot = plotsFolder:FindFirstChild(assigned)

		if plot and plot:GetAttribute("Owner") == player.UserId then
			return plot
		end
	end

	for _, plot in ipairs(plotsFolder:GetChildren()) do

		if plot:GetAttribute("Owner") == player.UserId then
			return plot
		end
	end

	return nil
end




function NestUtils.GetDisplayFolder(plot)

	local display = plot:FindFirstChild("ChickenDisplay")

	if not display then

		display = Instance.new("Folder")
		display.Name = "ChickenDisplay"
		display:SetAttribute("GeneratedChickenDisplay", true)
		display.Parent = plot
	end

	return display
end


-- Convenience: find the Nest MODEL for a given equipped chicken's
-- NestIndex + plot, without having to recompute slots everywhere.

function NestUtils.GetNestModelForIndex(plot, nestIndex)

	local slots = NestUtils.GetNestSlots(plot)
	local slot = slots[nestIndex]

	return slot and slot.model or nil
end


return NestUtils