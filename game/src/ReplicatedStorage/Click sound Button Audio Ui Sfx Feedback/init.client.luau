script.Parent.MouseButton1Click:Connect(function()
	script.Disabled = true
	script.Click:Play()
	wait(0.1)
	script.Disabled = false
end)
