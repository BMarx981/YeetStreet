--!strict
-- ReplayControls (ModuleScript) -> StarterPlayerScripts.ReplayControls
-- The buttons for replays, in the menus' street garage look (UiStyle).
--
-- While driving, a REPLAY sticker under TELEPORT plays the last flight
-- (ReplayRecorder). It shows once there is one, and bounces when a new one
-- is ready. While a replay plays, a bar along the bottom has play/pause,
-- buttons to the older and newer flights kept, a scrub bar to drag through
-- the clip, the speed (Tuning.Replay.Speeds), and close, with which flight it
-- is, its airtime, and the time above it.
--
--   Keyboard  V plays or closes (CarController); driving keys close it
--   Gamepad   D-pad down plays or closes (CarController), left and right pick
--             the flight, A pauses, B closes
--
-- What pressing REPLAY does belongs to CarController (start's `toggle` and
-- `play`), since it has the car to hide and hold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplayClock = require(ReplicatedStorage.ReplayClock)
local ReplayTape = require(ReplicatedStorage.ReplayTape)
local Tuning = require(ReplicatedStorage.Tuning)
local ReplayPlayer = require(script.Parent.ReplayPlayer)
local ReplayRecorder = require(script.Parent.ReplayRecorder)
local UiStyle = require(script.Parent.UiStyle)

local R = Tuning.Replay
local K = Enum.KeyCode

-- Keys that drive the car. Pressing one closes the replay to drive on.
local DRIVE_KEYS = { K.W, K.A, K.S, K.D, K.Up, K.Down, K.Left, K.Right, K.Space, K.LeftShift, K.ButtonR2, K.ButtonL2 }

local BAR_WIDTH = 560
local BAR_HEIGHT = 60
local BUTTON = 44
local SPEED_WIDTH = 64
local STEP_WIDTH = 36
local GAP = 8
local SCRUB_HEIGHT = 14
local KNOB = 22
-- Symbols the sticker font draws; ❚❚ and ✕ come out blank in it.
local PLAY = "▶"
local PAUSE = "II"
local CLOSE = "✖"
local OLDER = "<"
local NEWER = ">"

local ReplayControls = {}

local started = false
local driving = false

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function speedLabel(speed: number): string
	return if speed < 1 then `1/{math.floor(1 / speed + 0.5)}x` else `{string.format("%g", speed)}x`
end

local function symbol(name: string, parent: Instance, text: string, width: number): TextButton
	local b = UiStyle.sticker(name, parent, text)
	b.Size = UDim2.fromOffset(width, BUTTON)
	return b
end

local function build(toggle: () -> (), play: (ReplayRecorder.Replay) -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = "ReplayControls"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- above the HUD and touch buttons

	-- Top right, in the Roblox top bar so the player list can't cover it. Left
	-- of the TELEPORT button, so no hole shows while it is hidden.
	local open = UiStyle.sticker("Open", gui, "REPLAY")
	open.AnchorPoint = Vector2.new(1, 1)
	open.Position = UDim2.new(1, -268, 0, -4)
	open.Size = UDim2.fromOffset(120, 32)
	open.Visible = false
	UiStyle.springy(open)
	open.Activated:Connect(toggle)

	-- Above the bottom edge, clear of the admin command bar.
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -96)
	bar.Size = UDim2.new(0.95, 0, 0, BAR_HEIGHT)
	bar.BackgroundColor3 = UiStyle.Asphalt
	bar.Visible = false
	bar.Parent = gui
	UiStyle.corner(bar, 12)
	UiStyle.stroke(bar, 3, UiStyle.Ink, true)
	local most = Instance.new("UISizeConstraint")
	most.MaxSize = Vector2.new(BAR_WIDTH, BAR_HEIGHT)
	most.Parent = bar

	local status = UiStyle.text("Status", bar, 18, true)
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.new(0, 4, 0, -6)
	status.Size = UDim2.new(1, -8, 0, 22)

	local pause = symbol("Pause", bar, PAUSE, BUTTON)
	pause.AnchorPoint = Vector2.new(0, 0.5)
	pause.Position = UDim2.new(0, GAP, 0.5, 0)
	UiStyle.springy(pause)

	local older = symbol("Older", bar, OLDER, STEP_WIDTH)
	older.AnchorPoint = Vector2.new(0, 0.5)
	older.Position = UDim2.new(0, 2 * GAP + BUTTON, 0.5, 0)
	UiStyle.springy(older)

	local newer = symbol("Newer", bar, NEWER, STEP_WIDTH)
	newer.AnchorPoint = Vector2.new(0, 0.5)
	newer.Position = UDim2.new(0, 3 * GAP + BUTTON + STEP_WIDTH, 0.5, 0)
	UiStyle.springy(newer)

	local close = symbol("Close", bar, CLOSE, BUTTON)
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -GAP, 0.5, 0)
	UiStyle.springy(close)

	local speed = symbol("Speed", bar, speedLabel(1), SPEED_WIDTH)
	speed.AnchorPoint = Vector2.new(1, 0.5)
	speed.Position = UDim2.new(1, -(2 * GAP + BUTTON), 0.5, 0)
	UiStyle.springy(speed)

	-- A button, so presses on it never reach the camera's drag.
	local left = 4 * GAP + BUTTON + 2 * STEP_WIDTH
	local right = 4 * GAP + BUTTON + SPEED_WIDTH
	local scrub = Instance.new("TextButton")
	scrub.Name = "Scrub"
	scrub.Text = ""
	scrub.AutoButtonColor = false
	scrub.AnchorPoint = Vector2.new(0, 0.5)
	scrub.Position = UDim2.new(0, left + KNOB / 2, 0.5, 0)
	scrub.Size = UDim2.new(1, -(left + right + KNOB), 0, SCRUB_HEIGHT)
	scrub.BackgroundColor3 = UiStyle.Ink
	scrub.Parent = bar
	UiStyle.corner(scrub, SCRUB_HEIGHT // 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = UiStyle.Yellow
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = scrub
	UiStyle.corner(fill, SCRUB_HEIGHT // 2)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(KNOB, KNOB)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = scrub
	UiStyle.corner(knob, KNOB // 2)
	UiStyle.stroke(knob, 2, UiStyle.Ink, true)

	pause.Activated:Connect(function()
		local clock = ReplayPlayer.clock()
		if clock then
			ReplayClock.togglePause(clock)
		end
	end)
	speed.Activated:Connect(function()
		local clock = ReplayPlayer.clock()
		if clock then
			clock.speed = ReplayClock.nextSpeed(clock.speed, R.Speeds)
		end
	end)
	close.Activated:Connect(ReplayPlayer.stop)

	-- The flight `by` places on from the one playing, nil past either end.
	local function neighbor(by: number): ReplayRecorder.Replay?
		local current = ReplayPlayer.current()
		return if current then ReplayTape.step(ReplayRecorder.recent(), current, by) else nil
	end
	-- Plays it at the same speed as the one before.
	local function pick(by: number)
		local clock = ReplayPlayer.clock()
		local replay = neighbor(by)
		if not (clock and replay) then
			return
		end
		local pace = clock.speed
		play(replay)
		local picked = ReplayPlayer.clock()
		if picked then
			picked.speed = pace
		end
	end
	older.Activated:Connect(function()
		pick(-1)
	end)
	newer.Activated:Connect(function()
		pick(1)
	end)

	local scrubbing = false
	local function seekTo(x: number)
		local clock = ReplayPlayer.clock()
		if clock and scrub.AbsoluteSize.X > 0 then
			ReplayClock.seek(clock, (x - scrub.AbsolutePosition.X) / scrub.AbsoluteSize.X)
		end
	end
	scrub.InputBegan:Connect(function(input: InputObject)
		if isPress(input) then
			scrubbing = true
			seekTo(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local moving = input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		if scrubbing and moving then
			seekTo(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if isPress(input) then
			scrubbing = false
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local clock = ReplayPlayer.clock()
		if not clock or processed then
			return
		end
		if table.find(DRIVE_KEYS, input.KeyCode) or input.KeyCode == K.ButtonB then
			ReplayPlayer.stop()
		elseif input.KeyCode == K.ButtonA then
			ReplayClock.togglePause(clock)
		elseif input.KeyCode == K.DPadLeft then
			pick(-1)
		elseif input.KeyCode == K.DPadRight then
			pick(1)
		end
	end)

	local shown: ReplayRecorder.Replay? = nil
	RunService.RenderStepped:Connect(function()
		local clock = ReplayPlayer.clock()
		local last = ReplayRecorder.last()
		open.Visible = driving and last ~= nil and clock == nil
		if last ~= shown then
			shown = last
			if open.Visible then
				UiStyle.bounce(open)
			end
		end
		bar.Visible = clock ~= nil
		if clock then
			local played = ReplayClock.fraction(clock)
			fill.Size = UDim2.fromScale(played, 1)
			knob.Position = UDim2.fromScale(played, 0.5)
			pause.Text = if clock.paused then PLAY else PAUSE
			speed.Text = speedLabel(clock.speed)
			older.Visible = neighbor(-1) ~= nil
			newer.Visible = neighbor(1) ~= nil
			local recent = ReplayRecorder.recent()
			local current = ReplayPlayer.current()
			local at = if current then table.find(recent, current) else nil
			status.Text = string.format(
				"JUMP %s  %.1f s AIR  %.1f / %.1f s",
				if at then `{at} OF {#recent}` else "",
				if current then current.airtime else 0,
				math.min(clock.time, clock.duration),
				clock.duration
			)
		end
	end)

	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
end

-- Builds the buttons, once. `toggle` plays the last replay or closes one, and
-- `play` plays the one given.
function ReplayControls.start(toggle: () -> (), play: (ReplayRecorder.Replay) -> ())
	if not started then
		started = true
		build(toggle, play)
	end
end

-- Shows the REPLAY button while the player drives.
function ReplayControls.setDriving(on: boolean)
	driving = on
end

return ReplayControls
