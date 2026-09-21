local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local loadingScreen = ReplicatedFirst:FindFirstChild("LoadingScreenUi")

if loadingScreen then
	loadingScreen.Parent = playerGui
	ReplicatedFirst:RemoveDefaultLoadingScreen()

	local Container = loadingScreen.LoadingScreen
	local ProgressHolder = Container.ProgressHolder
	local ProgressBar = ProgressHolder.Bar
	local SkipBtn = Container.Middle.Skip
	local Icon = Container.Middle.GameIcon

	SkipBtn.Visible = false
	ProgressBar.Size = UDim2.fromScale(0, 1)

	local progressTween = TweenInfo.new(
		0.25,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	Icon.Rotation = -10

	local shakeTween = TweenService:Create(
		Icon,
		TweenInfo.new(
			1,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true
		),
		{
			Rotation = 10
		}
	)

	shakeTween:Play()

	task.delay(3, function()
		if loadingScreen.Parent then
			SkipBtn.Visible = true

			SkipBtn.BackgroundTransparency = 1
			SkipBtn.TextTransparency = 1

			TweenService:Create(
				SkipBtn,
				TweenInfo.new(
					0.35,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),
				{
					BackgroundTransparency = 0,
					TextTransparency = 0
				}
			):Play()
		end
	end)

	local skipped = false

	SkipBtn.MouseButton1Click:Connect(function()
		skipped = true
	end)

	local assets = game:GetDescendants()
	local totalAssets = #assets
	local loadedAssets = 0

	for _, asset in ipairs(assets) do
		if skipped then
			break
		end

		pcall(function()
			ContentProvider:PreloadAsync({ asset })
		end)

		loadedAssets += 1

		local progress = loadedAssets / totalAssets

		TweenService:Create(
			ProgressBar,
			progressTween,
			{
				Size = UDim2.fromScale(progress, 1)
			}
		):Play()

		task.wait()
	end

	if not game:IsLoaded() and not skipped then
		game.Loaded:Wait()
	end

	TweenService:Create(
		ProgressBar,
		TweenInfo.new(
			0.35,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			Size = UDim2.fromScale(1, 1)
		}
	):Play()

	task.wait(0.4)

	local originalFov = camera.FieldOfView

	camera.FieldOfView = 45

	local blur = Instance.new("BlurEffect")
	blur.Size = 24
	blur.Parent = Lighting

	TweenService:Create(
		camera,
		TweenInfo.new(
			1,
			Enum.EasingStyle.Cubic,
			Enum.EasingDirection.Out
		),
		{
			FieldOfView = originalFov
		}
	):Play()

	TweenService:Create(
		blur,
		TweenInfo.new(
			1,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			Size = 0
		}
	):Play()

	for _, obj in ipairs(loadingScreen:GetDescendants()) do
		if obj:IsA("Frame") or obj:IsA("CanvasGroup") then
			TweenService:Create(
				obj,
				TweenInfo.new(0.4),
				{
					BackgroundTransparency = 1
				}
			):Play()

		elseif obj:IsA("TextLabel") or obj:IsA("TextButton") then
			TweenService:Create(
				obj,
				TweenInfo.new(0.4),
				{
					TextTransparency = 1,
					BackgroundTransparency = 1
				}
			):Play()

		elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
			TweenService:Create(
				obj,
				TweenInfo.new(0.4),
				{
					ImageTransparency = 1,
					BackgroundTransparency = 1
				}
			):Play()

		elseif obj:IsA("UIStroke") then
			TweenService:Create(
				obj,
				TweenInfo.new(0.4),
				{
					Transparency = 1,
				}
			):Play()
		end
	end

	task.wait(1)

	blur:Destroy()
	loadingScreen:Destroy()
	
	task.delay(1, function ()
		local player = game:GetService("Players").LocalPlayer
		local uiCon = require(player.PlayerScripts.Controllers.UiController)
		local dailyRewards = require(player.PlayerScripts.Controllers.DailyRewardsController)
		local deadline = os.clock() + 5
		while os.clock() < deadline and not dailyRewards:IsRewardAvailable() do
			task.wait(0.1)
		end
		if dailyRewards:IsRewardAvailable() then
			uiCon:OpenFrame("DailyRewards")
		end
	end)
end