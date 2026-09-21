local tool = script.Parent

local ANIM_ID = "rbxassetid://86738932848336"

local track = nil

local function stopAnim()
	if track then
		track:Stop(0.15)
		track = nil
	end
end

local function playAnim(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	stopAnim()

	local animation = Instance.new("Animation")
	animation.AnimationId = ANIM_ID

	local ok, result = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	animation:Destroy()

	if not ok then
		warn("[EggboxTool] Failed to load animation:", result)
		return
	end

	track = result
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(0.2)
end

tool.Equipped:Connect(function()
	local character = tool.Parent

	if character and character:IsA("Model") then
		playAnim(character)
	end
end)

tool.Unequipped:Connect(function()
	stopAnim()
end)

tool.Destroying:Connect(function()
	stopAnim()
end)
