local TweenService = game:GetService("TweenService")

local DEFAULT_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local TabService = {}
TabService.__index = TabService

local function getHiddenPosition(frame, direction, originalPositions)
	local pos = originalPositions[frame]
	local size = frame.Size
	local anchor = frame.AnchorPoint

	if direction == "Up" then
		local visibleAbove = size.Y.Scale * (1 - anchor.Y)
		return UDim2.new(pos.X.Scale, pos.X.Offset, -(pos.Y.Scale + visibleAbove), pos.Y.Offset)
	elseif direction == "Down" then
		local visibleBelow = size.Y.Scale * anchor.Y
		return UDim2.new(pos.X.Scale, pos.X.Offset, 1 + visibleBelow, pos.Y.Offset)
	elseif direction == "Left" then
		local visibleLeft = size.X.Scale * (1 - anchor.X)
		return UDim2.new(-(pos.X.Scale + visibleLeft), pos.X.Offset, pos.Y.Scale, pos.Y.Offset)
	elseif direction == "Right" then
		local visibleRight = size.X.Scale * anchor.X
		return UDim2.new(1 + visibleRight, pos.X.Offset, pos.Y.Scale, pos.Y.Offset)
	end

	return pos
end

local function stopTweens(tweens)
	for _, tween in ipairs(tweens) do
		tween:Cancel()
	end
	table.clear(tweens)
end

function TabService.new(tabsByDirection, tweenInfo)
	local self = setmetatable({}, TabService)
	self.tweenInfo = tweenInfo or DEFAULT_TWEEN_INFO
	self.originalPositions = {}
	self.directions = {}
	self.activeTweens = {}

	for direction, frames in pairs(tabsByDirection) do
		for _, frame in ipairs(frames) do
			self.originalPositions[frame] = frame.Position
			self.directions[frame] = direction
		end
	end

	return self
end

function TabService:Hide(frames)
	stopTweens(self.activeTweens)

	for _, frame in ipairs(frames) do
		local direction = self.directions[frame]
		if direction ~= nil then
			local hiddenPos = getHiddenPosition(frame, direction, self.originalPositions)
			local tween = TweenService:Create(frame, self.tweenInfo, { Position = hiddenPos })
			table.insert(self.activeTweens, tween)
			tween:Play()
		end
	end
end

function TabService:Show(frames)
	stopTweens(self.activeTweens)

	for _, frame in ipairs(frames) do
		local original = self.originalPositions[frame]
		if original ~= nil then
			local tween = TweenService:Create(frame, self.tweenInfo, { Position = original })
			table.insert(self.activeTweens, tween)
			tween:Play()
		end
	end
end

function TabService:Apply(showFrames, hideFrames)
	stopTweens(self.activeTweens)

	for _, frame in ipairs(showFrames) do
		local original = self.originalPositions[frame]
		if original ~= nil then
			local tween = TweenService:Create(frame, self.tweenInfo, { Position = original })
			table.insert(self.activeTweens, tween)
			tween:Play()
		end
	end

	for _, frame in ipairs(hideFrames) do
		local direction = self.directions[frame]
		if direction ~= nil then
			local hiddenPos = getHiddenPosition(frame, direction, self.originalPositions)
			local tween = TweenService:Create(frame, self.tweenInfo, { Position = hiddenPos })
			table.insert(self.activeTweens, tween)
			tween:Play()
		end
	end
end

function TabService:HideAll()
	local frames = {}
	for frame in pairs(self.directions) do
		table.insert(frames, frame)
	end
	self:Hide(frames)
end

function TabService:ShowAll()
	local frames = {}
	for frame in pairs(self.directions) do
		table.insert(frames, frame)
	end
	self:Show(frames)
end

return TabService
