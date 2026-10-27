--!strict
-- UiStyle (ModuleScript) -> StarterPlayerScripts.UiStyle
-- The street garage look the menus share: an asphalt panel with a hazard
-- stripe band under its title, steel plate rows with bolts in the corners,
-- and yellow sticker buttons that tilt a little while they can be pressed.
-- Only looks; each menu still decides what its parts do.

local UiStyle = {}

UiStyle.Yellow = Color3.fromRGB(255, 196, 0)
UiStyle.Ink = Color3.fromRGB(22, 22, 26)
UiStyle.Asphalt = Color3.fromRGB(38, 40, 46)
UiStyle.Red = Color3.fromRGB(220, 60, 50)
UiStyle.Cash = Color3.fromRGB(120, 230, 120)

UiStyle.TitleFont = Enum.Font.LuckiestGuy
UiStyle.BodyFont = Enum.Font.GothamBold

-- Where a panel's content starts, below the title and the stripe band.
UiStyle.HeaderHeight = 64

local PLATE_TOP = Color3.fromRGB(150, 156, 166)
local PLATE_BOTTOM = Color3.fromRGB(96, 102, 112)
local BOLT_COLOR = Color3.fromRGB(70, 74, 82)
local STRIPE_WIDTH = 10
local STRIPE_SPACING = 20
local STRIPE_COUNT = 64 -- wide enough for any panel
local STICKER_TILT = -2
local GLOW_THICKNESS = 4
local PIP_WIDTH = 18
local PIP_HEIGHT = 10
local PIP_GAP = 4

function UiStyle.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- An outline around a frame or button (border) or around a label's letters.
function UiStyle.stroke(parent: Instance, thickness: number, color: Color3, border: boolean): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color
	s.ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

-- A left-aligned white label. Titles get the chunky font and an ink outline.
function UiStyle.text(name: string, parent: Instance, size: number, title: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = if title then UiStyle.TitleFont else UiStyle.BodyFont
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	if title then
		UiStyle.stroke(label, 2, UiStyle.Ink, false)
	end
	return label
end

-- A thin yellow and black band, as wide as its parent.
function UiStyle.hazard(parent: Instance): Frame
	local band = Instance.new("Frame")
	band.Name = "Hazard"
	band.BackgroundColor3 = UiStyle.Ink
	band.BorderSizePixel = 0
	band.ClipsDescendants = true
	band.Size = UDim2.new(1, 0, 0, 12)
	band.Parent = parent
	for i = -1, STRIPE_COUNT do
		local stripe = Instance.new("Frame")
		stripe.BackgroundColor3 = UiStyle.Yellow
		stripe.BorderSizePixel = 0
		stripe.AnchorPoint = Vector2.new(0.5, 0.5)
		stripe.Position = UDim2.new(0, i * STRIPE_SPACING, 0.5, 0)
		stripe.Size = UDim2.fromOffset(STRIPE_WIDTH, 40)
		stripe.Rotation = 40
		stripe.Parent = band
	end
	return band
end

-- Turns a frame or button into a steel plate with a bolt in each corner.
function UiStyle.plate(frame: GuiObject)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	UiStyle.corner(frame, 8)
	UiStyle.stroke(frame, 2, UiStyle.Ink, true)
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Color = ColorSequence.new(PLATE_TOP, PLATE_BOTTOM)
	shine.Parent = frame
	for _, at in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local bolt = Instance.new("Frame")
		bolt.Name = "Bolt"
		bolt.AnchorPoint = at
		bolt.Position = UDim2.new(at.X, if at.X == 0 then 5 else -5, at.Y, if at.Y == 0 then 5 else -5)
		bolt.Size = UDim2.fromOffset(7, 7)
		bolt.BackgroundColor3 = BOLT_COLOR
		bolt.BorderSizePixel = 0
		bolt.Parent = frame
		UiStyle.corner(bolt, 4)
	end
end

-- Outlines a plate in yellow, for something the player can buy right now.
function UiStyle.setGlow(frame: GuiObject, on: boolean)
	local edge = frame:FindFirstChildWhichIsA("UIStroke")
	if edge then
		edge.Color = if on then UiStyle.Yellow else UiStyle.Ink
		edge.Thickness = if on then GLOW_THICKNESS else 2
	end
end

-- A round dark badge with a yellow rim, holding an emoji icon.
function UiStyle.badge(parent: Instance, icon: string, size: number): TextLabel
	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.Text = icon
	badge.TextSize = math.floor(size * 0.6)
	badge.BackgroundColor3 = UiStyle.Asphalt
	badge.Size = UDim2.fromOffset(size, size)
	badge.Parent = parent
	UiStyle.corner(badge, size)
	UiStyle.stroke(badge, 3, UiStyle.Yellow, true)
	return badge
end

-- A row of level pips; UiStyle.setPips lights them from the left.
function UiStyle.pips(parent: Instance, count: number): Frame
	local bar = Instance.new("Frame")
	bar.Name = "Pips"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.fromOffset(count * (PIP_WIDTH + PIP_GAP) - PIP_GAP, PIP_HEIGHT)
	bar.Parent = parent
	for i = 1, count do
		local pip = Instance.new("Frame")
		pip.Name = `Pip{i}`
		pip.Position = UDim2.fromOffset((i - 1) * (PIP_WIDTH + PIP_GAP), 0)
		pip.Size = UDim2.fromOffset(PIP_WIDTH, PIP_HEIGHT)
		pip.BorderSizePixel = 0
		pip.Parent = bar
		UiStyle.corner(pip, 3)
		UiStyle.stroke(pip, 1.5, UiStyle.Ink, true)
	end
	UiStyle.setPips(bar, 0)
	return bar
end

function UiStyle.setPips(bar: Frame, filled: number)
	for _, pip in bar:GetChildren() do
		if pip:IsA("Frame") then
			local lit = (tonumber(string.match(pip.Name, "%d+")) or 0) <= filled
			pip.BackgroundColor3 = if lit then UiStyle.Yellow else UiStyle.Asphalt
			pip.BackgroundTransparency = if lit then 0 else 0.5
		end
	end
end

-- A sticker button: yellow with a white edge while it can be pressed.
function UiStyle.sticker(name: string, parent: Instance, label: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = label
	b.Font = UiStyle.TitleFont
	b.TextSize = 20
	b.AutoButtonColor = true
	b.Parent = parent
	UiStyle.corner(b, 8)
	UiStyle.stroke(b, 3, Color3.new(1, 1, 1), true)
	UiStyle.setSticker(b, true)
	return b
end

-- Lit stickers are yellow and tilted; unlit ones sit flat on the asphalt.
function UiStyle.setSticker(b: TextButton, lit: boolean)
	b.BackgroundColor3 = if lit then UiStyle.Yellow else UiStyle.Asphalt
	b.TextColor3 = if lit then UiStyle.Ink else Color3.new(1, 1, 1)
	b.Rotation = if lit then STICKER_TILT else 0
	local edge = b:FindFirstChildWhichIsA("UIStroke")
	if edge then
		edge.Transparency = if lit then 0 else 0.7
	end
end

-- A hidden menu panel with its title, a red X to close it, and the stripe
-- band. Content goes from UiStyle.HeaderHeight down.
function UiStyle.panel(parent: Instance, title: string, maxSize: Vector2): (Frame, TextButton)
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.85)
	panel.BackgroundColor3 = UiStyle.Asphalt
	panel.Active = true
	panel.Visible = false
	panel.Parent = parent
	UiStyle.corner(panel, 14)
	UiStyle.stroke(panel, 4, UiStyle.Ink, true)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = maxSize
	limit.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local heading = UiStyle.text("Title", panel, 34, true)
	heading.Text = title
	heading.TextColor3 = UiStyle.Yellow
	heading.Size = UDim2.new(0.5, 0, 0, 38)

	local close = UiStyle.sticker("Close", panel, "X")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -2, 0, 2)
	close.Size = UDim2.fromOffset(34, 34)
	close.BackgroundColor3 = UiStyle.Red
	close.TextColor3 = Color3.new(1, 1, 1)

	local band = UiStyle.hazard(panel)
	band.Position = UDim2.fromOffset(0, 44)

	return panel, close
end

return UiStyle
