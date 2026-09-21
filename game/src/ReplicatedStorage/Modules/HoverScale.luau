local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local TAG_NAME = "_Hover"
local SCALE_NAME = "HoverScale"
local HOVER_SCALE = 1.05
local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local HoverScale = {}

local function getOrCreateScale(guiObject)
	local scale = guiObject:FindFirstChildOfClass("UIScale")
	if scale == nil then
		scale = Instance.new("UIScale")
		scale.Name = SCALE_NAME
		scale.Scale = 1
		scale.Parent = guiObject
	end

	return scale
end

local function tweenScale(scale, target)
	TweenService:Create(scale, TWEEN_INFO, {
		Scale = target,
	}):Play()
end

local function bindHover(guiObject)
	if not guiObject:IsA("GuiObject") then
		return
	end

	local scale = getOrCreateScale(guiObject)

	guiObject.MouseEnter:Connect(function()
		tweenScale(scale, HOVER_SCALE)
	end)

	guiObject.MouseLeave:Connect(function()
		tweenScale(scale, 1)
	end)
end

function HoverScale.Start()
	for _, instance in CollectionService:GetTagged(TAG_NAME) do
		bindHover(instance)
	end

	CollectionService:GetInstanceAddedSignal(TAG_NAME):Connect(bindHover)
end

return HoverScale
