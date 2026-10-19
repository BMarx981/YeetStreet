--!strict
-- GrindBar (ModuleScript) -> StarterPlayerScripts.GrindBar
-- The balance bar at the bottom of the screen while grinding a rail: a green
-- zone that drifts and a marker to keep inside it (Grind). The zone turns red
-- while the marker is outside it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Grind = require(ReplicatedStorage.Grind)
local Tuning = require(ReplicatedStorage.Tuning)

local GrindBar = {}

local BAR_COLOR = Color3.fromRGB(20, 20, 28)
local IN_COLOR = Color3.fromRGB(70, 200, 90)
local OUT_COLOR = Color3.fromRGB(220, 70, 60)

type Parts = {
	gui: ScreenGui,
	zone: Frame,
	marker: TextLabel,
}

local parts: Parts? = nil

local function build(): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "GrindBar"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -60)
	bar.Size = UDim2.new(0.5, 0, 0, 24)
	bar.BackgroundColor3 = BAR_COLOR
	bar.BackgroundTransparency = 0.25
	bar.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 24)
	limit.Parent = bar
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bar

	local zone = Instance.new("Frame")
	zone.Name = "Zone"
	zone.AnchorPoint = Vector2.new(0.5, 0)
	-- The bar runs from -1 to 1, so the zone's width is ZoneHalf of it.
	zone.Size = UDim2.fromScale(Tuning.Grind.ZoneHalf, 1)
	zone.BackgroundColor3 = IN_COLOR
	zone.BorderSizePixel = 0
	zone.Parent = bar

	local marker = Instance.new("TextLabel")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 1)
	marker.Size = UDim2.fromOffset(24, 24)
	marker.BackgroundTransparency = 1
	marker.Text = "▼"
	marker.TextScaled = true
	marker.TextColor3 = Color3.new(1, 1, 1)
	marker.TextStrokeTransparency = 0.3
	marker.Font = Enum.Font.GothamBlack
	marker.Parent = bar

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 1, 2)
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Text = "BALANCE: steer to keep the arrow in the green"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.Parent = bar

	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, zone = zone, marker = marker }
end

-- Shows the bar for this balance state.
function GrindBar.show(balance: Grind.Balance)
	local p = parts or build()
	parts = p
	p.gui.Enabled = true
	p.zone.Position = UDim2.fromScale((balance.zone + 1) / 2, 0)
	p.zone.BackgroundColor3 = if Grind.inZone(balance, Tuning.Grind) then IN_COLOR else OUT_COLOR
	p.marker.Position = UDim2.fromScale((balance.marker + 1) / 2, 0)
end

function GrindBar.hide()
	if parts then
		parts.gui.Enabled = false
	end
end

return GrindBar
