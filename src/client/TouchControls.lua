--!strict
-- TouchControls (ModuleScript) -> StarterPlayerScripts.TouchControls
-- On screen buttons for phones and tablets, placed for thumbs. Left thumb
-- steers and rolls, right thumb works gas, brake, and jets.
--
-- Each button counts the touches currently on it, so two fingers on one button
-- and a finger sliding off do not leave it stuck down. A press ends when the
-- touch's InputObject changes to End or Cancel, wherever the finger is.
--
-- The WINGS button shows only while the car is a PlaneCar (showWings).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputAxes = require(ReplicatedStorage.InputAxes)

local TouchControls = {}

export type Frame = { steer: number, throttle: number, roll: number, jet: boolean, reset: boolean, wings: boolean }

type ButtonSpec = {
	name: string,
	label: string,
	anchor: Vector2,
	position: UDim2,
	size: UDim2,
}

local BUTTONS: { ButtonSpec } = {
	{
		name = "Left",
		label = "<",
		anchor = Vector2.new(0, 1),
		position = UDim2.new(0, 24, 1, -24),
		size = UDim2.fromOffset(96, 96),
	},
	{
		name = "Right",
		label = ">",
		anchor = Vector2.new(0, 1),
		position = UDim2.new(0, 132, 1, -24),
		size = UDim2.fromOffset(96, 96),
	},
	{
		name = "RollLeft",
		label = "ROLL <",
		anchor = Vector2.new(0, 1),
		position = UDim2.new(0, 24, 1, -132),
		size = UDim2.fromOffset(96, 56),
	},
	{
		name = "RollRight",
		label = "ROLL >",
		anchor = Vector2.new(0, 1),
		position = UDim2.new(0, 132, 1, -132),
		size = UDim2.fromOffset(96, 56),
	},
	{
		name = "Gas",
		label = "GAS",
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -24, 1, -24),
		size = UDim2.fromOffset(110, 110),
	},
	{
		name = "Brake",
		label = "BRAKE",
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -146, 1, -24),
		size = UDim2.fromOffset(90, 90),
	},
	{
		name = "Jet",
		label = "JETS",
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -24, 1, -146),
		size = UDim2.fromOffset(110, 90),
	},
	{
		name = "Wings",
		label = "WINGS",
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -24, 1, -248),
		size = UDim2.fromOffset(110, 56),
	},
	{
		name = "Reset",
		label = "RESET",
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -24, 0, 72),
		size = UDim2.fromOffset(80, 40),
	},
}

local touches: { [string]: number } = {}
local gui: ScreenGui? = nil
local wingsShown = false

local function isDown(name: string): boolean
	return (touches[name] or 0) > 0
end

local function buildButton(parent: Instance, spec: ButtonSpec)
	local button = Instance.new("TextButton")
	button.Name = spec.name
	button.Text = spec.label
	button.AnchorPoint = spec.anchor
	button.Position = spec.position
	button.Size = spec.size
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	button.BackgroundTransparency = 0.45
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 20
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = button

	local function refresh()
		button.BackgroundTransparency = if isDown(spec.name) then 0.1 else 0.45
	end

	button.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
		then
			return
		end
		touches[spec.name] = (touches[spec.name] or 0) + 1
		refresh()
		local connection: RBXScriptConnection
		connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			local state = input.UserInputState
			if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				connection:Disconnect()
				touches[spec.name] = math.max((touches[spec.name] or 0) - 1, 0)
				refresh()
			end
		end)
	end)
end

local function build(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "TouchControls"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	for _, spec in BUTTONS do
		buildButton(screen, spec)
	end
	local wings = screen:FindFirstChild("Wings")
	if wings and wings:IsA("GuiObject") then
		wings.Visible = wingsShown
	end
	return screen
end

-- Shows the buttons on touch devices only. Hiding clears any held buttons.
function TouchControls.setVisible(visible: boolean)
	if visible and not UserInputService.TouchEnabled then
		return
	end
	if visible and not gui then
		gui = build()
	end
	if gui then
		gui.Enabled = visible
	end
	if not visible then
		table.clear(touches)
	end
end

-- Shows or hides the WINGS button, for whether the car is a PlaneCar.
function TouchControls.showWings(shown: boolean)
	wingsShown = shown
	local wings = gui and gui:FindFirstChild("Wings")
	if wings and wings:IsA("GuiObject") then
		wings.Visible = shown
	end
	if not shown then
		touches.Wings = nil
	end
end

function TouchControls.read(): Frame
	return {
		steer = InputAxes.fromKeys(isDown("Left"), isDown("Right")),
		throttle = InputAxes.fromKeys(isDown("Brake"), isDown("Gas")),
		roll = InputAxes.fromKeys(isDown("RollLeft"), isDown("RollRight")),
		jet = isDown("Jet"),
		reset = isDown("Reset"),
		wings = isDown("Wings"),
	}
end

return TouchControls
