--!strict
-- ReplayCamera (ModuleScript) -> StarterPlayerScripts.ReplayCamera
-- The camera while a replay plays. It circles the ghost car (ReplayOrbit)
-- and keeps its angle as the ghost moves, so the player can watch a jump
-- from any side.
--
--   Mouse    drag with either button to circle, wheel to zoom
--   Touch    drag one finger to circle, pinch to zoom
--   Gamepad  right stick to circle
--
-- Presses that land on buttons (processed input) never start a drag. Drags
-- are measured from Position, since an unlocked mouse may report no Delta.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ReplayOrbit = require(ReplicatedStorage.ReplayOrbit)
local Tuning = require(ReplicatedStorage.Tuning)

local R = Tuning.Replay

local ReplayCamera = {}

local orbit: ReplayOrbit.Orbit = ReplayOrbit.new(0, 0, R.CameraDistance, R)
local connections: { RBXScriptConnection } = {}
-- Where the mouse was while a button is held, nil otherwise.
local mouseAt: Vector3? = nil
-- Where each finger on the screen was.
local touches: { [InputObject]: Vector3 } = {}
local pinchFrom = 0 -- the distance when a pinch began
local stick = Vector2.zero

local function touchCount(): number
	local count = 0
	for _ in touches do
		count += 1
	end
	return count
end

local function isMouseButton(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2
end

-- Starts taking input to circle the camera, from `start`.
function ReplayCamera.start(start: ReplayOrbit.Orbit)
	ReplayCamera.stop()
	orbit = start
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end
			if isMouseButton(input) then
				mouseAt = input.Position
			elseif input.UserInputType == Enum.UserInputType.Touch then
				touches[input] = input.Position
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if isMouseButton(input) then
				mouseAt = nil
			elseif input.UserInputType == Enum.UserInputType.Touch then
				touches[input] = nil
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
			local kind = input.UserInputType
			local was = if kind == Enum.UserInputType.Touch then touches[input] else mouseAt
			if kind == Enum.UserInputType.MouseMovement and was then
				local moved = input.Position - was
				mouseAt = input.Position
				orbit = ReplayOrbit.turn(orbit, -moved.X * R.MouseTurn, moved.Y * R.MouseTurn, R)
			elseif kind == Enum.UserInputType.MouseWheel and not processed then
				orbit = ReplayOrbit.zoom(orbit, R.WheelZoom ^ input.Position.Z, R)
			elseif kind == Enum.UserInputType.Touch and was then
				local moved = input.Position - was
				touches[input] = input.Position
				if touchCount() == 1 then
					orbit = ReplayOrbit.turn(orbit, -moved.X * R.TouchTurn, moved.Y * R.TouchTurn, R)
				end
			elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
				local at = Vector2.new(input.Position.X, input.Position.Y)
				stick = if at.Magnitude > Tuning.Input.StickDeadzone then at else Vector2.zero
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.TouchPinch:Connect(
			function(_: { Vector2 }, scale: number, _: number, state: Enum.UserInputState, processed: boolean)
				if processed then
					return
				end
				if state == Enum.UserInputState.Begin then
					pinchFrom = orbit.distance
				elseif state == Enum.UserInputState.Change and pinchFrom > 0 and scale > 0 then
					orbit = ReplayOrbit.zoom(orbit, pinchFrom / scale / orbit.distance, R)
				end
			end
		)
	)
end

-- Stops taking input.
function ReplayCamera.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(touches)
	mouseAt = nil
	pinchFrom = 0
	stick = Vector2.zero
end

-- Points the camera at `focus` from where the orbit puts it.
function ReplayCamera.update(focus: Vector3, dt: number)
	if stick ~= Vector2.zero then
		orbit = ReplayOrbit.turn(orbit, -stick.X * R.StickTurn * dt, -stick.Y * R.StickTurn * dt, R)
	end
	local x, y, z = ReplayOrbit.offset(orbit)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(x, y, z), focus)
end

return ReplayCamera
