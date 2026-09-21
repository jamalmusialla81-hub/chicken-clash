local TweenService = game:GetService("TweenService")
local ButtonAnimator = {}

-- Nazwy framów których dzieci są wykluczone z UIScale animacji
local EXCLUDED_PARENTS = {
    ["2EventsButtons"] = true,
    ["6BoostButtons"]  = true,
    ["4GiveButtons"]   = true,
}

local function isExcluded(button)
    local obj = button.Parent
    while obj do
        if EXCLUDED_PARENTS[obj.Name] then return true end
        obj = obj.Parent
    end
    return false
end

local function animateButton(button, scale)
    local uiScale = button:FindFirstChild("UIScale")
    if not uiScale then return end
    TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = scale
    }):Play()
end

-- Animacja dla buttonów w ListLayout - tylko brightness bez scale
local function animateEventButton(button, transparency)
    local cg = button:FindFirstChild("CandyGradient")
    if not cg then return end
    TweenService:Create(cg, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        ImageTransparency = transparency
    }):Play()
end

function ButtonAnimator.apply(button)
    if button:GetAttribute("ButtonAnimatorApplied") then return end
    button:SetAttribute("ButtonAnimatorApplied", true)

    if isExcluded(button) then
        -- Własna animacja brightness - zero wpływu na layout
        button.MouseEnter:Connect(function()
            animateEventButton(button, 0.25)
        end)
        button.MouseLeave:Connect(function()
            animateEventButton(button, 0)
        end)
        button.MouseButton1Down:Connect(function()
            animateEventButton(button, 0.5)
        end)
        button.MouseButton1Up:Connect(function()
            animateEventButton(button, 0.25)
        end)
        return
    end

    -- Normalna animacja UIScale dla reszty GUI
    if not button:FindFirstChild("UIScale") then
        Instance.new("UIScale", button)
    end
    button.MouseEnter:Connect(function()
        animateButton(button, 1.1)
    end)
    button.MouseLeave:Connect(function()
        animateButton(button, 1)
    end)
    button.MouseButton1Down:Connect(function()
        animateButton(button, 0.9)
    end)
    button.MouseButton1Up:Connect(function()
        animateButton(button, 1.1)
    end)
end

function ButtonAnimator.applyToGui(gui)
    local function process(obj)
        if obj:IsA("ImageButton") or obj:IsA("TextButton") then
            ButtonAnimator.apply(obj)
        end
        obj.ChildAdded:Connect(function(child)
            task.wait()
            process(child)
        end)
        for _, child in ipairs(obj:GetChildren()) do
            process(child)
        end
    end
    process(gui)
end

return ButtonAnimator