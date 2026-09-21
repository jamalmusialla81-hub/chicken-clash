-- Run in the SERVER runtime of a playtest. Builds flat ground, a 15 degree ramp, a platform and 8 stairs, and a stand-in chicken
-- built by the real ChickenRig module (stand-in parts, NOT final art).
local RS = game.ReplicatedStorage
local Rig = require(RS.ChickenClash.ChickenRig)
local arena = workspace:FindFirstChild("__ChickenTest") or Instance.new("Folder")
arena.Name = "__ChickenTest" arena.Parent = workspace
arena:ClearAllChildren()
local function block(name, size, cf) local p = Instance.new("Part") p.Name = name p.Size = size p.CFrame = cf p.Anchored = true p.Material = Enum.Material.Concrete p.Color = Color3.fromRGB(120, 130, 150) p.Parent = arena return p end
local OX, OZ = 2000, 2000
block("Flat", Vector3.new(60, 2, 40), CFrame.new(OX + 25, -1, OZ))
local ang, L, T = math.rad(15), 22, 1
local dir, nrm = Vector3.new(math.cos(ang), math.sin(ang), 0), Vector3.new(-math.sin(ang), math.cos(ang), 0)
local start = Vector3.new(OX + 40, 0, OZ)
block("Ramp", Vector3.new(L, T, 16), CFrame.new(start + dir * (L / 2) - nrm * (T / 2)) * CFrame.Angles(0, 0, ang))
local topY, topX = math.sin(ang) * L, start.X + math.cos(ang) * L
block("Platform", Vector3.new(20, 1, 16), CFrame.new(topX + 10, topY - 0.5, OZ))
for i = 1, 8 do block("Step" .. i, Vector3.new(2, 0.5, 16), CFrame.new(topX + 20 + 2 * i - 1, topY + 0.5 * i - 0.25, OZ)) end
local model = Rig.BuildProxy("ProxyChicken")
model.Parent = workspace
model:PivotTo(CFrame.new(OX, 0, OZ) * model.PrimaryPart.CFrame)
model.PrimaryPart:SetNetworkOwner(nil)
model.Humanoid.WalkSpeed = 14
return model
