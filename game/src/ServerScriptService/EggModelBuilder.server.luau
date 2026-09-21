local ReplicatedStorage = game:GetService("ReplicatedStorage")

local chickenFolder = ReplicatedStorage:WaitForChild("Chicken")
local eggFolder = chickenFolder:WaitForChild("Eggs")
local source = eggFolder:WaitForChild("Egg")

local definitions = {
	{"EggGolden", Color3.fromRGB(255, 190, 30), Color3.fromRGB(255, 245, 110), Enum.Material.Neon},
	{"EggObsidian", Color3.fromRGB(18, 18, 28), Color3.fromRGB(125, 55, 210), Enum.Material.Slate},
	{"EggIce", Color3.fromRGB(90, 190, 235), Color3.fromRGB(220, 255, 255), Enum.Material.Glass},
	{"EggStorm", Color3.fromRGB(45, 55, 85), Color3.fromRGB(125, 190, 255), Enum.Material.Neon},
	{"EggToxic", Color3.fromRGB(70, 180, 45), Color3.fromRGB(180, 255, 40), Enum.Material.Neon},
	{"EggShadow", Color3.fromRGB(25, 20, 40), Color3.fromRGB(125, 70, 220), Enum.Material.Slate},
	{"EggLight", Color3.fromRGB(255, 244, 170), Color3.fromRGB(255, 255, 255), Enum.Material.Neon},
	{"EggPhantom", Color3.fromRGB(38, 25, 65), Color3.fromRGB(180, 130, 255), Enum.Material.Neon},
	{"EggSpirit", Color3.fromRGB(220, 245, 255), Color3.fromRGB(255, 180, 255), Enum.Material.ForceField},
	{"EggVoid", Color3.fromRGB(8, 5, 18), Color3.fromRGB(90, 30, 180), Enum.Material.Neon},
	{"EggGalaxy", Color3.fromRGB(35, 20, 95), Color3.fromRGB(255, 80, 220), Enum.Material.Neon},
	{"EggNebula", Color3.fromRGB(100, 35, 150), Color3.fromRGB(70, 220, 255), Enum.Material.Neon},
	{"EggSolar", Color3.fromRGB(230, 80, 20), Color3.fromRGB(255, 245, 70), Enum.Material.Neon},
	{"EggLunar", Color3.fromRGB(80, 110, 180), Color3.fromRGB(190, 220, 255), Enum.Material.Glass},
	{"EggEclipse", Color3.fromRGB(12, 12, 22), Color3.fromRGB(255, 120, 35), Enum.Material.Neon},
	{"EggComet", Color3.fromRGB(70, 150, 220), Color3.fromRGB(255, 255, 255), Enum.Material.Neon},
	{"EggMeteor", Color3.fromRGB(95, 45, 30), Color3.fromRGB(255, 120, 35), Enum.Material.Neon},
	{"EggPlasma", Color3.fromRGB(220, 45, 120), Color3.fromRGB(80, 255, 255), Enum.Material.Neon},
	{"EggQuantum", Color3.fromRGB(60, 30, 130), Color3.fromRGB(100, 255, 220), Enum.Material.Neon},
	{"EggCosmic", Color3.fromRGB(20, 15, 55), Color3.fromRGB(255, 120, 220), Enum.Material.Neon},
	{"EggCelestial", Color3.fromRGB(245, 225, 160), Color3.fromRGB(120, 220, 255), Enum.Material.Neon},
	{"EggAncient", Color3.fromRGB(105, 65, 40), Color3.fromRGB(255, 170, 50), Enum.Material.Slate},
	{"EggMythic", Color3.fromRGB(190, 40, 55), Color3.fromRGB(255, 190, 40), Enum.Material.Neon},
	{"EggDivine", Color3.fromRGB(255, 225, 90), Color3.fromRGB(255, 255, 255), Enum.Material.Neon},
	{"EggEthereal", Color3.fromRGB(150, 240, 255), Color3.fromRGB(255, 190, 255), Enum.Material.ForceField},
	{"EggInfinity", Color3.fromRGB(35, 210, 190), Color3.fromRGB(210, 80, 255), Enum.Material.Neon},
	{"EggOmega", Color3.fromRGB(25, 25, 35), Color3.fromRGB(255, 45, 45), Enum.Material.Neon},
	{"EggGlitched", Color3.fromRGB(30, 255, 150), Color3.fromRGB(255, 30, 190), Enum.Material.Neon},
	{"EggCorrupted", Color3.fromRGB(35, 8, 45), Color3.fromRGB(125, 255, 35), Enum.Material.Neon},
	{"EggReality", Color3.fromRGB(120, 30, 170), Color3.fromRGB(255, 255, 255), Enum.Material.Neon},
	{"EggTimekeeper", Color3.fromRGB(35, 120, 155), Color3.fromRGB(255, 205, 60), Enum.Material.Metal},
	{"EggSingularity", Color3.fromRGB(5, 5, 10), Color3.fromRGB(160, 40, 255), Enum.Material.Neon},
	{"EggCreator", Color3.fromRGB(255, 255, 255), Color3.fromRGB(70, 170, 255), Enum.Material.Neon},
	{"EggAlmighty", Color3.fromRGB(255, 185, 35), Color3.fromRGB(255, 255, 255), Enum.Material.Neon},
	{"EggThe", Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 210, 45), Enum.Material.Neon},
}

local function addAccent(model, color, index)
	local accent = Instance.new("Part")
	accent.Name = "Egg Theme Accent " .. index
	accent.Shape = Enum.PartType.Ball
	accent.Size = Vector3.new(0.16, 0.16, 0.16)
	accent.Color = color
	accent.Material = Enum.Material.Neon
	accent.Anchored = true
	accent.CanCollide = false
	accent.CanTouch = false
	accent.CanQuery = false
	local pivot = model:GetPivot()
	local angle = index * math.pi * 0.5
	accent.CFrame = pivot * CFrame.new(math.cos(angle) * 0.9, 0.2 + math.sin(angle) * 0.35, math.sin(angle) * 0.9)
	accent.Parent = model
end

for _, definition in ipairs(definitions) do
	local name, primary, secondary, material = table.unpack(definition)
	local existing = eggFolder:FindFirstChild(name)
	if not existing then
		local egg = source:Clone()
		egg.Name = name
		local pivot = egg:GetPivot()
		for _, descendant in ipairs(egg:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Color = primary
				descendant.Material = material
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
		for index = 1, 4 do
			addAccent(egg, secondary, index)
		end
		egg:PivotTo(pivot)
		egg.Parent = eggFolder
		print("[EggModelBuilder] Created " .. name)
	end
end

print("[EggModelBuilder] Egg model pass complete")