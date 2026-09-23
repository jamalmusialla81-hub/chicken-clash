-- Chicken Clash UI theme: shared palette, fonts, formatting helpers, and the one reusable depth-button
-- constructor every primary button in the game should use. Existing callers (ChickenClashUI and every
-- combat/practice/match HUD) already pull colors from Theme.Colors dynamically, so updating the palette
-- here re-themes the whole game without rewriting every panel - only the VALUES changed below, every
-- existing key (Background/Panel/Gold/Text/etc) still exists so nothing that already requires this module
-- breaks.
local Theme = {}

-- Exact palette from the presentation-rebuild spec. Never pure black for a main panel - Navy900/Navy700
-- with warm cream text instead.
local PALETTE = {
	Navy900 = Color3.fromRGB(0x17, 0x1B, 0x2E),
	Navy700 = Color3.fromRGB(0x25, 0x2B, 0x46),
	Cream100 = Color3.fromRGB(0xFF, 0xF1, 0xD2),
	Gold500 = Color3.fromRGB(0xF5, 0xB8, 0x3D),
	Gold700 = Color3.fromRGB(0xD8, 0x87, 0x24),
	Orange500 = Color3.fromRGB(0xE9, 0x82, 0x32),
	Coral500 = Color3.fromRGB(0xF0, 0x64, 0x4B),
	Cyan400 = Color3.fromRGB(0x65, 0xD1, 0xE6),
	Green500 = Color3.fromRGB(0x67, 0xC9, 0x6B),
	Red500 = Color3.fromRGB(0xE6, 0x4D, 0x4D),
	Muted500 = Color3.fromRGB(0x74, 0x77, 0x8A),
	Outline900 = Color3.fromRGB(0x17, 0x13, 0x18),
	White = Color3.fromRGB(0xFF, 0xFF, 0xFF),
}
Theme.Palette = PALETTE

local function lighten(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v + amount, 0, 1))
end

-- perceived luminance (0-1) - decides whether a face needs dark or cream text. Real bug this fixes:
-- Theme.Button used to hardcode dark Outline900 text on every face, which was unreadable on the many
-- dark Navy/Panel-colored buttons (lane buttons, secondary actions) - only the bright Gold faces ever
-- had a legible dark label.
local function luminance(color: Color3): number
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

Theme.Colors = {
	Background = PALETTE.Navy900,
	Panel = PALETTE.Navy700,
	PanelRaised = lighten(PALETTE.Navy700, 0.06),
	Gold = PALETTE.Gold500,
	GoldDim = PALETTE.Gold700,
	Text = PALETTE.Cream100,
	TextMuted = PALETTE.Muted500,
	Success = PALETTE.Green500,
	Danger = PALETTE.Red500,
	Soon = PALETTE.Muted500,
	-- new tokens for the depth-button system / map-building palette rules
	Orange = PALETTE.Orange500,
	Coral = PALETTE.Coral500,
	Cyan = PALETTE.Cyan400,
	Outline = PALETTE.Outline900,
	White = PALETTE.White,
}

Theme.Fonts = {
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
}

-- rarity is the chicken's rank (1 = most common ... 50 = rarest)
local TIERS = {
	{ 4, Color3.fromRGB(205, 205, 205) },
	{ 8, Color3.fromRGB(95, 205, 95) },
	{ 13, Color3.fromRGB(70, 145, 255) },
	{ 19, Color3.fromRGB(170, 95, 255) },
	{ 26, Color3.fromRGB(255, 95, 200) },
	{ 33, Color3.fromRGB(255, 150, 55) },
	{ 41, Color3.fromRGB(255, 75, 75) },
	{ math.huge, Color3.fromRGB(255, 215, 65) },
}

function Theme.RarityColor(rank)
	rank = rank or 1
	for _, tier in ipairs(TIERS) do
		if rank <= tier[1] then
			return tier[2]
		end
	end
	return TIERS[#TIERS][2]
end

local UNITS = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

local function compact(value)
	for _, unit in ipairs(UNITS) do
		if value >= unit[1] then
			local scaled = value / unit[1]
			local text = (scaled >= 100 or scaled % 1 == 0) and string.format("%d", math.floor(scaled + 0.5)) or string.format("%.1f", scaled)
			return (text:gsub("%.0$", "")) .. unit[2]
		end
	end
	return string.format("%d", math.floor(value + 0.5))
end

-- "1 in 250,000,000" -> "1/250M"
function Theme.FormatOdds(chanceText)
	if type(chanceText) ~= "string" then
		return ""
	end
	local denominator = chanceText:match("1%s*in%s*([%d,]+)") or chanceText:match("1%s*/%s*([%d,]+)")
	local value = denominator and tonumber((denominator:gsub(",", "")))
	if not value then
		return chanceText
	end
	return "1 / " .. compact(value)
end

-- wallet numbers: 950 -> "950", 1500 -> "1.5K", 12345678 -> "12.3M"
function Theme.FormatNumber(n)
	n = tonumber(n) or 0
	if n < 1000 then
		return string.format("%d", math.floor(n))
	end
	for _, unit in ipairs(UNITS) do
		if n >= unit[1] then
			local v = n / unit[1]
			local text = v < 10 and string.format("%.2f", v) or (v < 100 and string.format("%.1f", v) or string.format("%d", math.floor(v)))
			if text:find("%.") then
				text = text:gsub("0+$", ""):gsub("%.$", "")
			end
			return text .. unit[2]
		end
	end
	return tostring(n)
end

-- currency cards want the FULL comma-grouped number ("1,000"), never compact ("1K") - a small, separate
-- helper rather than overloading FormatNumber's existing (and already-used-elsewhere) compact behavior.
function Theme.FormatFullNumber(n)
	n = math.floor(tonumber(n) or 0)
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	local s = tostring(n)
	local grouped = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return sign .. grouped
end

--==================================================================================================--
-- Theme.Button: the one reusable depth-button construction every primary button in the game uses.
-- Steps match the spec exactly: rounded rect -> vertical gradient (brighter top) -> darker offset lower
-- depth layer -> dark outline stroke -> inner highlight stroke -> soft shadow -> icon+label -> hover/press
-- tweens -> selected-state accent -> desaturated disabled state.
--==================================================================================================--
local TweenService = game:GetService("TweenService")
local HOVER_TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_TWEEN = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RETURN_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- opts: { text, icon (optional image asset id), size (UDim2), topColor, bottomColor (defaults to Gold),
--         onClick, selected (bool, starts selected), disabled (bool) }
function Theme.Button(parent: Instance, opts)
	opts = opts or {}
	local topColor = opts.topColor or Theme.Colors.Gold
	local bottomColor = opts.bottomColor or Theme.Colors.GoldDim
	local size = opts.size or UDim2.fromOffset(160, 48)

	local root = Instance.new("Frame")
	root.Name = opts.name or "Button"
	root.Size = size
	root.BackgroundTransparency = 1
	root.Parent = parent

	-- depth layer: darker, offset down a few pixels, sits BEHIND the main face
	local depth = Instance.new("Frame")
	depth.Name = "Depth"
	depth.AnchorPoint = Vector2.new(0.5, 0)
	depth.Position = UDim2.new(0.5, 0, 0, 5)
	depth.Size = UDim2.new(1, 0, 1, 0)
	depth.BackgroundColor3 = bottomColor
	depth.BorderSizePixel = 0
	depth.ZIndex = 1
	depth.Parent = root
	local depthCorner = Instance.new("UICorner")
	depthCorner.CornerRadius = UDim.new(0, 10)
	depthCorner.Parent = depth

	-- soft shadow below the depth layer
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0)
	shadow.Position = UDim2.new(0.5, 0, 0, 8)
	shadow.Size = UDim2.new(1, 16, 1, 10)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxasset://textures/ui/Controls/DropShadow.png"
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ImageTransparency = 0.55
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 118, 118)
	shadow.ZIndex = 0
	shadow.Parent = root

	-- main clickable face
	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, 0)
	face.BackgroundColor3 = topColor
	face.AutoButtonColor = false
	face.Text = ""
	face.ZIndex = 2
	face.Parent = root
	local faceCorner = Instance.new("UICorner")
	faceCorner.CornerRadius = UDim.new(0, 10)
	faceCorner.Parent = face
	local faceGradient = Instance.new("UIGradient")
	faceGradient.Color = ColorSequence.new(lighten(topColor, 0.12), topColor)
	faceGradient.Rotation = 90
	faceGradient.Parent = face

	-- dark outer outline
	local outline = Instance.new("UIStroke")
	outline.Color = Theme.Colors.Outline
	outline.Thickness = 2
	outline.Transparency = 0.1
	outline.Parent = face

	-- subtle cream inner highlight, inset slightly
	local highlight = Instance.new("UIStroke")
	highlight.Color = Theme.Colors.Text -- Cream100
	highlight.Thickness = 1
	highlight.Transparency = 0.75
	highlight.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	highlight.Parent = face

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -12, 1, -8)
	content.Position = UDim2.new(0.5, 0, 0.5, 0)
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.ZIndex = 3
	content.Parent = face
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Horizontal
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	contentLayout.Padding = UDim.new(0, 6)
	contentLayout.Parent = content

	if opts.icon then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(20, 20)
		icon.Image = opts.icon
		icon.ZIndex = 3
		icon.Parent = content
	end

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Label"
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(0, 0, 1, 0)
	textLabel.AutomaticSize = Enum.AutomaticSize.X
	textLabel.Font = Theme.Fonts.Bold
	textLabel.TextSize = opts.textSize or 16
	textLabel.Text = opts.text or ""
	textLabel.ZIndex = 3
	textLabel.Parent = content

	local api = { root = root, face = face, depth = depth, outline = outline }
	local selected = opts.selected == true
	local disabled = opts.disabled == true

	-- Selected mode uses the bright Gold face the spec calls for ("active mode uses Gold face with dark
	-- readable text"); text color is ALWAYS derived from whatever face color is actually showing, never
	-- hardcoded, so a dark face (Navy/Panel) gets cream text and a bright face (Gold/Cyan/Cream) gets
	-- dark text - this is what was missing before (every face got the same hardcoded dark text).
	local function effectiveFaceColor(): Color3
		if disabled then
			return Theme.Colors.TextMuted
		elseif selected then
			return Theme.Colors.Gold
		end
		return topColor
	end

	local function applyFace()
		local faceColor = effectiveFaceColor()
		faceGradient.Color = ColorSequence.new(lighten(faceColor, 0.12), faceColor)
		textLabel.TextColor3 = luminance(faceColor) > 0.55 and Theme.Colors.Outline or Theme.Colors.Text
		textLabel.TextTransparency = disabled and 0.3 or 0
		face.BackgroundTransparency = 0
		root.BackgroundTransparency = 1
		face.Active = not disabled
		outline.Transparency = disabled and 0.4 or 0.1
		outline.Color = (selected and not disabled) and Theme.Colors.Cyan or Theme.Colors.Outline
		outline.Thickness = (selected and not disabled) and 3 or 2
	end

	function api.SetSelected(value: boolean)
		selected = value
		applyFace()
	end

	function api.SetDisabled(value: boolean)
		disabled = value
		applyFace()
	end

	function api.SetText(text: string)
		textLabel.Text = text
	end

	-- For an ON/OFF toggle (spec: "Toggle ON uses Cyan/Green") rather than a Gold "selected mode" button -
	-- a distinct concept from SetSelected, which always forces the Gold "active mode" face.
	function api.SetTopColor(color: Color3)
		topColor = color
		applyFace()
	end

	applyFace()

	if not disabled then
		face.MouseEnter:Connect(function()
			TweenService:Create(root, HOVER_TWEEN, { Size = size * 1.04 }):Play()
		end)
		face.MouseLeave:Connect(function()
			TweenService:Create(root, RETURN_TWEEN, { Size = size }):Play()
		end)
		face.MouseButton1Down:Connect(function()
			TweenService:Create(root, PRESS_TWEEN, { Size = size * 0.96 }):Play()
		end)
		face.MouseButton1Up:Connect(function()
			TweenService:Create(root, RETURN_TWEEN, { Size = size * 1.04 }):Play()
		end)
		if opts.onClick then
			face.MouseButton1Click:Connect(opts.onClick)
		end
	end

	return api
end

--==================================================================================================--
-- Original reusable component kit (reference-informed pass: build components instead of styling every
-- button/panel independently). These wrap the same corner/stroke/gradient visual language already used
-- throughout the game rather than inventing a second design system.
--==================================================================================================--

-- Theme.Panel: base dark panel, no depth/selection behavior - the plain background surface other
-- components sit on. opts = { size, position, anchorPoint, color (defaults to Panel), transparency }.
function Theme.Panel(parent: Instance, opts)
	opts = opts or {}
	local panel = Instance.new("Frame")
	panel.Name = opts.name or "Panel"
	panel.Size = opts.size or UDim2.fromOffset(200, 100)
	panel.Position = opts.position or UDim2.fromScale(0, 0)
	panel.AnchorPoint = opts.anchorPoint or Vector2.new(0, 0)
	panel.BackgroundColor3 = opts.color or Theme.Colors.Panel
	panel.BackgroundTransparency = opts.transparency or 0.05
	panel.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, opts.cornerRadius or 10)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = opts.strokeColor or Theme.Colors.Gold
	stroke.Thickness = opts.strokeThickness or 1.5
	stroke.Transparency = opts.strokeTransparency or 0.35
	stroke.Parent = panel
	return panel
end

-- Theme.Card: a Panel plus an icon chip + title/value label pair, matching the health/dash/currency card
-- pattern already used in ChickenCombatHUD/ChickenClashUI. opts adds { iconColor, title, value }.
-- Returns { root, icon, titleLabel, valueLabel, SetTitle, SetValue }.
function Theme.Card(parent: Instance, opts)
	opts = opts or {}
	local root = Theme.Panel(parent, opts)
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 8, 0.5, 0)
	icon.Size = UDim2.fromOffset(30, 30)
	icon.BackgroundColor3 = opts.iconColor or Theme.Colors.Gold
	icon.Parent = root
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = icon

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 46, 0, 6)
	titleLabel.Size = UDim2.new(1, -58, 0, 16)
	titleLabel.Font = Theme.Fonts.Bold
	titleLabel.TextSize = 12
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Theme.Colors.Text
	titleLabel.Text = opts.title or ""
	titleLabel.Parent = root

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.BackgroundTransparency = 1
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.new(1, -8, 0, 6)
	valueLabel.Size = UDim2.fromOffset(60, 16)
	valueLabel.Font = Theme.Fonts.Bold
	valueLabel.TextSize = 12
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.TextColor3 = Theme.Colors.Text
	valueLabel.Text = opts.value or ""
	valueLabel.Parent = root

	local api = { root = root, icon = icon, titleLabel = titleLabel, valueLabel = valueLabel }
	function api.SetTitle(text: string)
		titleLabel.Text = text
	end
	function api.SetValue(text: string)
		valueLabel.Text = text
	end
	return api
end

-- Theme.HealthBar: framed bar + gradient fill, used for both health and generic progress. opts adds
-- { fillColor, position, size (of the bar itself, not a card) }. Returns { root, fill, SetFraction }.
function Theme.HealthBar(parent: Instance, opts)
	opts = opts or {}
	local frame = Instance.new("Frame")
	frame.Name = opts.name or "Bar"
	frame.Position = opts.position or UDim2.new(0, 0, 0, 0)
	frame.Size = opts.size or UDim2.new(1, 0, 0, 14)
	frame.BackgroundColor3 = Theme.Colors.Outline
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 5)
	frameCorner.Parent = frame

	local fillColor = opts.fillColor or Theme.Colors.Danger
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = frame
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = fill
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(lighten(fillColor, 0.25), fillColor)
	gradient.Rotation = 90
	gradient.Parent = fill

	local api = { root = frame, fill = fill }
	function api.SetFraction(frac: number)
		fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	end
	return api
end

-- Theme.CooldownIndicator: a HealthBar alias with cooldown-appropriate defaults (Cyan fill, starts full)
-- since a cooldown bar and a health bar are the same visual component with different semantics/color.
function Theme.CooldownIndicator(parent: Instance, opts)
	opts = opts or {}
	opts.fillColor = opts.fillColor or Theme.Colors.Cyan
	local api = Theme.HealthBar(parent, opts)
	api.SetFraction(1)
	return api
end

-- Theme.ViewportChickenPreview: a controlled ViewportFrame preview of a ReplicatedStorage.ChickenVisuals
-- model - strips scripts/Humanoids, anchors every part, disables collision, fits the bounding box, and
-- frames a three-quarter angle with neutral key/fill lighting. Returns { root, model } (model may be nil
-- if the visual name wasn't found) so a caller can re-color it (e.g. dimmed for a locked chicken).
function Theme.ViewportChickenPreview(parent: Instance, opts)
	opts = opts or {}
	local visualsFolder = game:GetService("ReplicatedStorage"):FindFirstChild("ChickenVisuals")
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = opts.name or "ChickenPreview"
	viewport.Size = opts.size or UDim2.fromOffset(120, 120)
	viewport.Position = opts.position or UDim2.new(0, 0, 0, 0)
	viewport.BackgroundTransparency = opts.backgroundTransparency or 1
	viewport.Ambient = Color3.fromRGB(150, 150, 165) -- neutral fill light
	viewport.LightColor = Color3.fromRGB(255, 250, 235) -- warm key light
	viewport.LightDirection = Vector3.new(-0.6, -0.7, -0.4)
	viewport.Parent = parent

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local source = visualsFolder and visualsFolder:FindFirstChild(opts.chickenName or "")
	local model = nil
	if source then
		model = source:Clone()
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Humanoid") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery = true, false, false, false
				if opts.tint then
					d.Color, d.Material = opts.tint, Enum.Material.SmoothPlastic
				end
			end
		end
		local cf, size = model:GetBoundingBox()
		model.WorldPivot = cf
		model:PivotTo(CFrame.new())
		model.Parent = worldModel

		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		-- three-quarter angle, never a flat front/side view
		local dir = Vector3.new(1, 0.35, 0.75).Unit
		cam.CFrame = CFrame.lookAt(dir * (math.max(size.X, size.Y, size.Z) * 2.1), Vector3.new(0, size.Y * 0.1, 0))
		cam.Parent = viewport
		viewport.CurrentCamera = cam
	end

	return { root = viewport, model = model }
end

return Theme
