--[[ ChickenMovementDriver (server). The missing link between a combat chicken's real Humanoid movement
	and the replicated "Action" attribute ChickenAnimator renders: nothing previously called SetAction for
	Walk/Run/JumpStart/Fall/Land (only ChickenCombatService did, for Attack1/2/3/Dash/Idle) - a spawned
	combat chicken's Humanoid moved and jumped natively via Roblox's default ControlModule (it has a real
	Humanoid + HumanoidRootPart + WalkSpeed, so WASD/jump work for free once it is a player's Character),
	but nothing ever translated that into the Action attribute, so Walk/Run/JumpStart/Fall/Land could only
	ever be seen by setting Action directly in a test script, never through real play.

	Never overrides Action while ChickenCombatService reports the chicken busy (mid-attack or mid-dash) -
	movement animation must never fight combat animation for the same attribute. ]]

local ChickenStateService = require(script.Parent:WaitForChild("ChickenStateService"))
local ChickenCombatService = require(script.Parent:WaitForChild("ChickenCombatService"))

local Driver = {}
local attached = setmetatable({}, { __mode = "k" }) -- model -> {conns}

local RUN_THRESHOLD = 0.55 -- fraction of WalkSpeed above which Walk becomes Run

function Driver.Attach(model: Model)
	if attached[model] then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local conns = {}
	attached[model] = conns

	local function setIfFree(action: string)
		if ChickenCombatService.IsBusy(model) then
			return
		end
		ChickenStateService.SetAction(model, action)
	end

	local function onStateChanged(_, new: Enum.HumanoidStateType)
		if new == Enum.HumanoidStateType.Jumping then
			setIfFree("JumpStart")
		elseif new == Enum.HumanoidStateType.Freefall then
			setIfFree("Fall")
		elseif new == Enum.HumanoidStateType.Landed then
			setIfFree("Land")
			task.delay(0.2, function()
				if attached[model] and humanoid.Parent and humanoid.MoveDirection.Magnitude < 0.05 then
					setIfFree("Idle")
				end
			end)
		elseif new == Enum.HumanoidStateType.Running then
			if humanoid.MoveDirection.Magnitude < 0.05 then
				setIfFree("Idle")
			end
		end
	end

	table.insert(conns, humanoid.StateChanged:Connect(onStateChanged))

	table.insert(conns, humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if humanoid:GetState() ~= Enum.HumanoidStateType.Running then
			return -- jumping/falling/landing already own Action; don't stomp it mid-air
		end
		local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
		if humanoid.MoveDirection.Magnitude < 0.05 then
			setIfFree("Idle")
		elseif humanoid.WalkSpeed > 0 and speed / humanoid.WalkSpeed >= RUN_THRESHOLD then
			setIfFree("Run")
		else
			setIfFree("Walk")
		end
	end))

	table.insert(conns, model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			Driver.Detach(model)
		end
	end))
end

function Driver.Detach(model: Model)
	local conns = attached[model]
	if not conns then
		return
	end
	attached[model] = nil
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
end

return Driver
