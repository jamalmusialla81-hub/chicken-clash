local BaseRoll = {
	RollTime = 0.5,
	RollCooldown = 0.25,
	VisibleRollingItems = 7,
	RollSteps = 20,
	RollStepSlowdown = 1.18,

	LuckRollWeight = 30,
	SlimeRollWeight = 70,

	ColumnWidthScale = 0.14,
	ColumnHeightScale = 0.5,
	ColumnGapScale = 0.04,
	CenterItemSize = UDim2.fromScale(0.82, 0.82),
	EdgeItemSize = UDim2.fromScale(0, 0),

	ColumnTweenTime = 0.25,
	MiddlePaddingScale = 0.1,

	ItemTweenStyle = Enum.EasingStyle.Quad,
	ItemTweenDirection = Enum.EasingDirection.Out,
	ColumnTweenStyle = Enum.EasingStyle.Quad,
	ColumnTweenDirection = Enum.EasingDirection.Out,

	FinalSlimeScale = 1.4,
	FinalSlimeScaleTime = 0.18,
	FinalSlimeHoldTime = 0.35,

	HideAfterRollDelay = 0.6,
	AutoRollDelay = 0.1,

	SettleTime = 0.5,
	SettleDownFactor = 0.15,
	SettleUpFactor = 0.25,
	SettleMaxOffsetScale = 0.5,
}

return BaseRoll
