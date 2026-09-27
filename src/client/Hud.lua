--!strict
-- Hud (ModuleScript) -> StarterPlayerScripts.Hud
-- Jet fuel bar and a speed and airtime readout. The readout is for tuning
-- M0 feel; scoring arrives in M1.

local Players = game:GetService("Players")

local Hud = {}

type Parts = { gui: ScreenGui, fill: Frame, readout: TextLabel }

local parts: Parts? = nil

local FUEL_COLOR = Color3.fromRGB(255, 170, 40)
local BURN_COLOR = Color3.fromRGB(255, 90, 30)

local function build(): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	local bar = Instance.new("Frame")
	bar.Name = "Fuel"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 16)
	bar.Size = UDim2.fromOffset(260, 16)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	bar.BackgroundTransparency = 0.3
	bar.Parent = gui
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = FUEL_COLOR
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = fill

	local readout = Instance.new("TextLabel")
	readout.Name = "Readout"
	readout.AnchorPoint = Vector2.new(0.5, 0)
	readout.Position = UDim2.new(0.5, 0, 0, 36)
	readout.Size = UDim2.fromOffset(260, 28)
	readout.BackgroundTransparency = 1
	readout.Font = Enum.Font.GothamBold
	readout.TextSize = 20
	readout.TextColor3 = Color3.new(1, 1, 1)
	readout.TextStrokeTransparency = 0.5
	readout.Parent = gui

	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, fill = fill, readout = readout }
end

function Hud.setVisible(visible: boolean)
	if visible and not parts then
		parts = build()
	end
	if parts then
		parts.gui.Enabled = visible
	end
end

-- `airtime` is nil on the ground.
function Hud.update(fuelFraction: number, speed: number, airtime: number?, burning: boolean)
	local p = parts
	if not p then
		return
	end
	p.fill.Size = UDim2.fromScale(math.clamp(fuelFraction, 0, 1), 1)
	p.fill.BackgroundColor3 = if burning then BURN_COLOR else FUEL_COLOR
	local text = `{math.floor(speed + 0.5)} studs/s`
	if airtime then
		text ..= string.format("   air %.1fs", airtime)
	end
	p.readout.Text = text
end

return Hud
