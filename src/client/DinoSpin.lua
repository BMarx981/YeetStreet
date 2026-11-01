--!strict
-- DinoSpin (ModuleScript) -> StarterPlayerScripts.DinoSpin
-- The Dino Mystery Box's wheel: every dino car slides past a marker, slows
-- down, and lands on the car the server already gave the player. It only shows
-- the result, so closing it early loses nothing.

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DinoBox = require(ReplicatedStorage.DinoBox)
local DinoCars = require(ReplicatedStorage.DinoCars)
local Economy = require(ReplicatedStorage.Economy)
local Tuning = require(ReplicatedStorage.Tuning)
local CarPreview = require(script.Parent.CarPreview)
local UiStyle = require(script.Parent.UiStyle)

local DinoSpin = {}

export type Spin = {
	-- Spins to `winner`. `closed` runs when the panel goes away, and `equip`
	-- after that if the player asks to drive the car.
	play: (winner: string, closed: () -> (), equip: () -> ()) -> (),
	close: () -> (),
}

type Tile = {
	frame: Frame,
	preview: CarPreview.Preview,
	car: Economy.Car,
}

local VISIBLE = 3 -- whole cars showing, so the wrap from one side to the other stays out of sight
local FIT = 0.95 -- room in a window for the long necks and horns
local BARE: Economy.Levels = { Speed = 0, Jets = 0, Toughness = 0, Grip = 0, Brakes = 0 }

function DinoSpin.new(parent: Instance): Spin
	local gui = Instance.new("ScreenGui")
	gui.Name = "DinoSpin"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6 -- above the garage panel
	gui.Parent = parent

	local panel, closeButton = UiStyle.panel(gui, "DINO BOX", Vector2.new(560, 360))
	local top = UiStyle.HeaderHeight

	local wheel = Instance.new("Frame")
	wheel.Name = "Wheel"
	wheel.Position = UDim2.fromOffset(0, top)
	wheel.Size = UDim2.new(1, 0, 1, -(top + 88))
	wheel.BackgroundColor3 = UiStyle.Ink
	wheel.ClipsDescendants = true
	wheel.Parent = panel
	UiStyle.corner(wheel, 8)

	local tiles: { Tile } = {}
	local rewards = Tuning.DinoMystery.Rewards
	for _, reward in rewards do
		local car = Economy.findCar(Tuning.Ladder, reward.CarId)
		if car then
			local frame = Instance.new("Frame")
			frame.Name = car.Id
			frame.AnchorPoint = Vector2.new(0.5, 0)
			frame.Size = UDim2.fromScale(1 / VISIBLE, 1)
			frame.BackgroundTransparency = 1
			frame.Parent = wheel
			local window = Instance.new("Frame")
			window.Name = "Window"
			window.Size = UDim2.new(1, 0, 1, -24)
			window.BackgroundTransparency = 1
			window.Parent = frame
			local label = UiStyle.text("Name", frame, 16, true)
			label.AnchorPoint = Vector2.new(0, 1)
			label.Position = UDim2.fromScale(0, 1)
			label.Size = UDim2.new(1, 0, 0, 22)
			label.Text = string.upper(car.Name)
			label.TextXAlignment = Enum.TextXAlignment.Center
			table.insert(tiles, { frame = frame, preview = CarPreview.new(window, FIT), car = car })
		end
	end

	-- Loaded up front so the first spin doesn't show empty windows.
	task.spawn(function()
		local meshes = {}
		for _, tile in tiles do
			local mesh = DinoCars.mesh(tile.car.Look)
			if mesh then
				table.insert(meshes, mesh)
			end
		end
		ContentProvider:PreloadAsync(meshes)
	end)

	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.Position = UDim2.fromScale(0.5, 0)
	marker.Size = UDim2.fromScale(1 / VISIBLE, 1)
	marker.BackgroundTransparency = 1
	marker.ZIndex = 2
	marker.Parent = wheel
	UiStyle.stroke(marker, 3, UiStyle.Yellow, true)

	local result = UiStyle.text("Result", panel, 18, false)
	result.AnchorPoint = Vector2.new(0, 1)
	result.Position = UDim2.new(0, 0, 1, -44)
	result.Size = UDim2.new(1, 0, 0, 40)
	result.TextXAlignment = Enum.TextXAlignment.Center
	result.TextColor3 = UiStyle.Yellow
	result.TextWrapped = true

	local equipButton = UiStyle.sticker("Equip", panel, "EQUIP")
	equipButton.AnchorPoint = Vector2.new(0.5, 1)
	equipButton.Position = UDim2.fromScale(0.5, 1)
	equipButton.Size = UDim2.fromOffset(150, 38)
	UiStyle.springy(equipButton)

	local connection: RBXScriptConnection? = nil
	local closed: (() -> ())? = nil
	local equip: (() -> ())? = nil

	local function place(position: number)
		for i, tile in tiles do
			tile.frame.Position = UDim2.fromScale(0.5 + DinoBox.offset(i, position, #tiles) / VISIBLE, 0)
		end
	end

	local function close()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if panel.Visible then
			UiStyle.show(panel, false)
		end
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
		local after = closed
		closed = nil
		if after then
			after()
		end
	end

	local function play(winner: string, onClosed: () -> (), onEquip: () -> ())
		local index = 1
		local blurb = ""
		for i, tile in tiles do
			tile.preview.set(tile.car, BARE)
			if tile.car.Id == winner then
				index = i
			end
		end
		for _, reward in rewards do
			if reward.CarId == winner then
				blurb = reward.Blurb
			end
		end
		closed = onClosed
		equip = onEquip
		equipButton.Visible = false
		result.Text = "The egg is hatching..."
		place(0)
		UiStyle.show(panel, true)

		local duration = Tuning.DinoMystery.SpinTime
		local stop = DinoBox.stop(#tiles, index, Tuning.DinoMystery.SpinTurns)
		local elapsed = 0
		local shown = 0
		connection = RunService.RenderStepped:Connect(function(dt: number)
			for _, tile in tiles do
				tile.preview.spin(dt)
			end
			if elapsed >= duration then
				return
			end
			elapsed += dt
			local position = DinoBox.position(elapsed, duration, stop)
			place(position)
			local passed = math.floor(position + 0.5)
			if passed ~= shown then
				shown = passed
				UiStyle.play("Click")
			end
			if elapsed >= duration then
				result.Text = `You got the {string.upper(tiles[index].car.Name)}! {blurb}`
				equipButton.Visible = true
				UiStyle.play("Buy")
				UiStyle.flash(wheel)
				UiStyle.bounce(tiles[index].frame)
				if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel.Parent :: Instance) then
					GuiService.SelectedObject = equipButton
				end
			end
		end)
	end

	closeButton.Activated:Connect(close)
	equipButton.Activated:Connect(function()
		local after = equip
		close()
		if after then
			after()
		end
	end)

	return { play = play, close = close }
end

return DinoSpin
