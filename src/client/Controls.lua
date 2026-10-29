--!strict
-- Controls (ModuleScript) -> StarterPlayerScripts.Controls
-- Reads keyboard, gamepad, and touch into one frame of car input. Axes run
-- -1..1 with positive meaning right, gas, or nose down.
--
--   Keyboard  W/S or Up/Down gas and brake, A/D or Left/Right steer,
--             Space or Left Shift jets, Q/E roll, R reset, F wings, X or
--             left click fire
--   Gamepad   Right trigger gas, left trigger brake, left stick steer (and
--             pitch in the air), A jets, LB/RB roll, Y reset, D-pad up
--             wings, B fire
--   Touch     see TouchControls
-- No input reaches the car while the garage panel, teleport menu, invite
-- panel, or obby stage select is open (GarageMenu, TeleportMenu, InviteMenu,
-- ObbyHud), or while a replay plays (ReplayPlayer).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputAxes = require(ReplicatedStorage.InputAxes)
local Tuning = require(ReplicatedStorage.Tuning)
local GarageMenu = require(script.Parent.GarageMenu)
local InviteMenu = require(script.Parent.InviteMenu)
local ObbyHud = require(script.Parent.ObbyHud)
local ReplayPlayer = require(script.Parent.ReplayPlayer)
local TeleportMenu = require(script.Parent.TeleportMenu)
local TouchControls = require(script.Parent.TouchControls)

local K = Enum.KeyCode
local PAD = Enum.UserInputType.Gamepad1

local Controls = {}

export type Frame = {
	steer: number,
	throttle: number,
	pitch: number, -- gamepad stick only; the controller adds throttle in the air
	roll: number,
	jet: boolean,
	reset: boolean,
	exit: boolean,
	wings: boolean, -- turns a PlaneCar between plane and car
	fire: boolean, -- a PlaneCar's guns
}

local function anyKey(codes: { Enum.KeyCode }): boolean
	for _, code in codes do
		if UserInputService:IsKeyDown(code) then
			return true
		end
	end
	return false
end

function Controls.read(): Frame
	-- Buttons in the garage panel or the menus must not drive the car either.
	if
		GarageMenu.isOpen()
		or TeleportMenu.isOpen()
		or InviteMenu.isOpen()
		or ObbyHud.isOpen()
		or ReplayPlayer.isPlaying()
	then
		return {
			steer = 0,
			throttle = 0,
			pitch = 0,
			roll = 0,
			jet = false,
			reset = false,
			exit = false,
			wings = false,
			fire = false,
		}
	end
	-- Typing in chat must not drive the car.
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	local function key(codes: { Enum.KeyCode }): boolean
		return not typing and anyKey(codes)
	end

	local stickX, stickY, gas, brake = 0, 0, 0, 0
	local padJet, padRollLeft, padRollRight, padReset, padWings, padFire = false, false, false, false, false, false
	if UserInputService.GamepadEnabled then
		local stickZone = Tuning.Input.StickDeadzone
		local triggerZone = Tuning.Input.TriggerDeadzone
		for _, input in UserInputService:GetGamepadState(PAD) do
			if input.KeyCode == K.Thumbstick1 then
				stickX = InputAxes.deadzone(input.Position.X, stickZone)
				stickY = InputAxes.deadzone(input.Position.Y, stickZone)
			elseif input.KeyCode == K.ButtonR2 then
				gas = InputAxes.deadzone(input.Position.Z, triggerZone)
			elseif input.KeyCode == K.ButtonL2 then
				brake = InputAxes.deadzone(input.Position.Z, triggerZone)
			end
		end
		padJet = UserInputService:IsGamepadButtonDown(PAD, K.ButtonA)
		padRollLeft = UserInputService:IsGamepadButtonDown(PAD, K.ButtonL1)
		padRollRight = UserInputService:IsGamepadButtonDown(PAD, K.ButtonR1)
		padReset = UserInputService:IsGamepadButtonDown(PAD, K.ButtonY)
		padWings = UserInputService:IsGamepadButtonDown(PAD, K.DPadUp)
		padFire = UserInputService:IsGamepadButtonDown(PAD, K.ButtonB)
	end

	local touch = TouchControls.read()

	return {
		steer = InputAxes.combine({
			InputAxes.fromKeys(key({ K.A, K.Left }), key({ K.D, K.Right })),
			stickX,
			touch.steer,
		}),
		throttle = InputAxes.combine({
			InputAxes.fromKeys(key({ K.S, K.Down }), key({ K.W, K.Up })),
			gas - brake,
			touch.throttle,
		}),
		pitch = stickY,
		roll = InputAxes.combine({
			InputAxes.fromKeys(key({ K.Q }), key({ K.E })),
			InputAxes.fromKeys(padRollLeft, padRollRight),
			touch.roll,
		}),
		jet = key({ K.LeftShift }) or padJet or touch.jet,
		exit = key({ K.Space }),
		reset = key({ K.R }) or padReset or touch.reset,
		wings = key({ K.F }) or padWings or touch.wings,
		fire = key({ K.X })
			or (not typing and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1))
			or padFire
			or touch.fire,
	}
end

return Controls
