--!strict
-- ControlsMenu (ModuleScript) -> StarterPlayerScripts.ControlsMenu
-- The controls panel: which key or button does what, for the keyboard, a
-- gamepad, and touch. It shows only the sections for the devices this player
-- has. The CONTROLS button at the top right of the screen opens and closes it;
-- so do H, the gamepad Select button, the panel's X button, and gamepad B.
--
-- The car keeps taking input while the panel is open, so players can try a
-- key while they read about it. The keys here must match Controls,
-- CarController, and GarageMenu.
--
-- Above the controls, a SOUND row picks the engine sound setting
-- (Tuning.EngineSound.Settings). The server saves it (SoundSettings) and puts
-- it on the player as the EngineSound attribute, which lights the choice.
-- Under it, PLAY THE TUTORIAL teleports the car to the hub and starts the
-- tutorial again (TutorialHints).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local EngineSound = require(ReplicatedStorage.EngineSound)
local Tuning = require(ReplicatedStorage.Tuning)
local TutorialHints = require(script.Parent.TutorialHints)
local UiStyle = require(script.Parent.UiStyle)

local ControlsMenu = {}

type Row = { key: string, what: string }
type Group = { title: string, rows: { Row } }

local KEYBOARD: { Group } = {
	{
		title = "GET GOING",
		rows = {
			{ key = "Z", what = "Get your car (when on foot)" },
			{ key = "SPACE", what = "Hop out of your car" },
			{ key = "R", what = "Reset your car" },
		},
	},
	{
		title = "DRIVING",
		rows = {
			{ key = "W / S", what = "Gas and brake" },
			{ key = "A / D", what = "Steer" },
			{ key = "SHIFT", what = "Jets (uses fuel)" },
		},
	},
	{
		title = "IN THE AIR",
		rows = {
			{ key = "W / S", what = "Tip the nose down and up" },
			{ key = "A / D", what = "Turn left and right" },
			{ key = "Q / E", what = "Roll" },
			{ key = "SHIFT", what = "Jets" },
		},
	},
	{
		title = "MORE",
		rows = {
			{ key = "V", what = "Replay your last flight" },
			{ key = "G", what = "Open the garage (near one)" },
			{ key = "C", what = "Switch cars (on the ground)" },
			{ key = "F", what = "Wings or rotor (special cars)" },
			{ key = "X", what = "Fire (PlaneCar)" },
			{ key = "H", what = "Show or hide this panel" },
		},
	},
}

local GAMEPAD: { Group } = {
	{
		title = "GAMEPAD",
		rows = {
			{ key = "RT / LT", what = "Gas and brake" },
			{ key = "L STICK", what = "Steer, and tip the nose in the air" },
			{ key = "A", what = "Jets" },
			{ key = "LB / RB", what = "Roll" },
			{ key = "Y", what = "Reset your car" },
			{ key = "X", what = "Open the garage (near one)" },
			{ key = "D-PAD DOWN", what = "Replay your last flight" },
			{ key = "D-PAD UP", what = "Wings or rotor (special cars)" },
			{ key = "B", what = "Fire (PlaneCar)" },
		},
	},
}

local TOUCH: { Group } = {
	{
		title = "TOUCH",
		rows = {
			{ key = "< / >", what = "Steer, and turn in the air" },
			{ key = "GAS / BRAKE", what = "Drive, and tip the nose in the air" },
			{ key = "JETS", what = "Boost (uses fuel)" },
			{ key = "ROLL", what = "Roll in the air" },
			{ key = "RESET", what = "Reset your car" },
		},
	},
}

local SETTINGS = Tuning.EngineSound.Settings
local HUB = "Hub" -- the Teleport destination with the tutorial's ramp
local ROW = 34
local KEY_WIDTH = 110

local player = Players.LocalPlayer :: Player
local started = false
local open = false

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ControlsHelp"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- above the HUD and touch buttons

	-- Top right corner, in the Roblox top bar so the player list can't cover it.
	local openButton = UiStyle.sticker("Open", gui, "CONTROLS")
	openButton.AnchorPoint = Vector2.new(1, 1)
	openButton.Position = UDim2.new(1, -12, 0, -4)
	openButton.Size = UDim2.fromOffset(120, 32)
	UiStyle.springy(openButton)

	local panel, close = UiStyle.panel(gui, "CONTROLS", Vector2.new(420, 560))
	local top = UiStyle.HeaderHeight

	local list = Instance.new("ScrollingFrame")
	list.Name = "Details"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, top)
	list.Size = UDim2.new(1, 0, 1, -top)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UiStyle.Yellow
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local order = 0
	local function section(groups: { Group }): { GuiObject }
		local made: { GuiObject } = {}
		for _, group in groups do
			order += 1
			local heading = UiStyle.text("Heading", list, 20, true)
			heading.Text = group.title
			heading.TextColor3 = UiStyle.Yellow
			heading.LayoutOrder = order
			heading.Size = UDim2.new(1, -12, 0, 28)
			table.insert(made, heading)
			for _, row in group.rows do
				order += 1
				local frame = Instance.new("Frame")
				frame.Name = "Row"
				frame.BackgroundColor3 = UiStyle.Ink
				frame.LayoutOrder = order
				frame.Size = UDim2.new(1, -12, 0, ROW)
				frame.Parent = list
				UiStyle.corner(frame, 6)
				local key = UiStyle.text("Key", frame, 17, false)
				key.Text = row.key
				key.TextColor3 = UiStyle.Ink
				key.TextXAlignment = Enum.TextXAlignment.Center
				key.BackgroundTransparency = 0
				key.BackgroundColor3 = UiStyle.Yellow
				key.Position = UDim2.fromOffset(4, 3)
				key.Size = UDim2.fromOffset(KEY_WIDTH, ROW - 6)
				UiStyle.corner(key, 5)
				local what = UiStyle.text("What", frame, 16, false)
				what.Text = row.what
				what.TextWrapped = true
				what.Position = UDim2.fromOffset(KEY_WIDTH + 14, 0)
				what.Size = UDim2.new(1, -KEY_WIDTH - 20, 1, 0)
				table.insert(made, frame)
			end
		end
		return made
	end

	-- The SOUND heading and the ENGINE row, with one sticker per setting.
	local function soundRow()
		order += 1
		local heading = UiStyle.text("Heading", list, 20, true)
		heading.Text = "SOUND"
		heading.TextColor3 = UiStyle.Yellow
		heading.LayoutOrder = order
		heading.Size = UDim2.new(1, -12, 0, 28)

		order += 1
		local frame = Instance.new("Frame")
		frame.Name = "EngineSound"
		frame.BackgroundColor3 = UiStyle.Ink
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, -12, 0, ROW + 8)
		frame.Parent = list
		UiStyle.corner(frame, 6)
		local key = UiStyle.text("Key", frame, 17, false)
		key.Text = "ENGINE"
		key.TextColor3 = UiStyle.Ink
		key.TextXAlignment = Enum.TextXAlignment.Center
		key.BackgroundTransparency = 0
		key.BackgroundColor3 = UiStyle.Yellow
		key.Position = UDim2.fromOffset(4, 7)
		key.Size = UDim2.fromOffset(KEY_WIDTH, ROW - 6)
		UiStyle.corner(key, 5)

		local event = ReplicatedStorage:WaitForChild("EngineSoundEvent") :: RemoteEvent
		local choices: { [string]: TextButton } = {}
		local count = #SETTINGS
		for i, s in SETTINGS do
			local b = UiStyle.sticker(s.Name, frame, string.upper(s.Name))
			b.TextSize = 18
			b.Position = UDim2.new((i - 1) / count, KEY_WIDTH + 14 - (i - 1) * (KEY_WIDTH + 20) / count, 0, 6)
			b.Size = UDim2.new(1 / count, -(KEY_WIDTH + 20) / count - 6, 1, -12)
			UiStyle.springy(b)
			b.Activated:Connect(function()
				event:FireServer(s.Name)
			end)
			choices[s.Name] = b
		end

		local function light()
			local current = EngineSound.setting(player:GetAttribute("EngineSound"), SETTINGS)
			for name, b in choices do
				UiStyle.setSticker(b, name == current)
			end
		end
		light()
		player:GetAttributeChangedSignal("EngineSound"):Connect(light)
	end

	soundRow()

	-- A button that takes the car to the hub and starts the tutorial again.
	order += 1
	local again = UiStyle.sticker("Tutorial", list, "PLAY THE TUTORIAL")
	again.LayoutOrder = order
	again.Size = UDim2.new(1, -12, 0, ROW + 6)
	again.Rotation = 0
	UiStyle.springy(again)
	local keyboard = section(KEYBOARD)
	local gamepad = section(GAMEPAD)
	local touch = section(TOUCH)

	local function showSection(objects: { GuiObject }, visible: boolean)
		for _, obj in objects do
			obj.Visible = visible
		end
	end

	-- Devices can plug in after the game starts, so this runs on every open.
	local function pickSections()
		local hasKeyboard = UserInputService.KeyboardEnabled
		local hasPad = UserInputService.GamepadEnabled
		local hasTouch = UserInputService.TouchEnabled
		showSection(keyboard, hasKeyboard or not (hasPad or hasTouch))
		showSection(gamepad, hasPad)
		showSection(touch, hasTouch)
	end

	local function setOpen(value: boolean)
		if value then
			UiStyle.closeOtherMenus(panel)
			pickSections()
			list.CanvasPosition = Vector2.zero
		end
		open = value
		UiStyle.show(panel, value)
	end
	UiStyle.registerMenu(panel, function()
		if open then
			setOpen(false)
		end
	end)

	openButton.Activated:Connect(function()
		setOpen(not open)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	again.Activated:Connect(function()
		setOpen(false)
		local teleport = ReplicatedStorage:FindFirstChild("Teleport")
		if teleport and teleport:IsA("RemoteFunction") then
			pcall(teleport.InvokeServer, teleport, HUB)
		end
		TutorialHints.start()
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if
			(input.KeyCode == Enum.KeyCode.H and not processed)
			or input.KeyCode == Enum.KeyCode.ButtonSelect
		then
			setOpen(not open)
		elseif input.KeyCode == Enum.KeyCode.ButtonB and open then
			setOpen(false)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Builds the CONTROLS button and panel, once.
function ControlsMenu.start()
	if not started then
		started = true
		task.spawn(build)
	end
end

return ControlsMenu
