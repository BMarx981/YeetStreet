--!strict
-- MissileCamera (ModuleScript) -> StarterPlayerScripts.MissileCamera
-- The camera while riding a silo missile. It sits behind the nose and turns
-- with the missile, and the player looks around from there (Missile.lookAngles):
--
--   Mouse    where the pointer is on the screen, no button needed
--   Touch    drag one finger away from where it landed
--   Gamepad  right stick

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Missile = require(ReplicatedStorage.Missile)
local Tuning = require(ReplicatedStorage.Tuning)

local M = Tuning.Silo.Missile
local LOOK = { LookYaw = M.LookYaw, LookPitch = M.LookPitch, LookDeadzone = M.LookDeadzone }

local MissileCamera = {}

local base: CFrame? = nil
local stick = Vector2.zero
local touchFrom: { [InputObject]: Vector3 } = {}
local touchLook = Vector2.zero

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.Touch and not processed then
		touchFrom[input] = input.Position
	end
end)

UserInputService.InputChanged:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		stick = Vector2.new(input.Position.X, -input.Position.Y)
	elseif input.UserInputType == Enum.UserInputType.Touch then
		local from = touchFrom[input]
		if from then
			local size = workspace.CurrentCamera.ViewportSize
			local moved = input.Position - from
			touchLook = Vector2.new(2 * moved.X / size.X, 2 * moved.Y / size.Y)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		stick = Vector2.zero
	elseif touchFrom[input] then
		touchFrom[input] = nil
		touchLook = Vector2.zero
	end
end)

-- Where the player is looking, from -1 to 1 each way across the screen.
local function pointing(): Vector2
	if stick.Magnitude > M.LookDeadzone then
		return stick
	elseif touchLook ~= Vector2.zero then
		return touchLook
	elseif UserInputService.MouseEnabled then
		local size = workspace.CurrentCamera.ViewportSize
		local at = UserInputService:GetMouseLocation()
		return Vector2.new(2 * at.X / size.X - 1, 2 * at.Y / size.Y - 1)
	end
	return Vector2.zero
end

function MissileCamera.update(hull: BasePart, dt: number)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = M.CameraFov

	local want = hull.CFrame.Rotation
	base = if base then base:Lerp(want, 1 - math.exp(-M.CameraSharpness * dt)) else want
	local at = pointing()
	local yaw, pitch = Missile.lookAngles(LOOK, at.X, at.Y)
	local view = (base :: CFrame) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)

	local position = hull.Position - view.LookVector * M.CameraDistance + view.UpVector * M.CameraHeight
	camera.CFrame = CFrame.lookAt(position, hull.Position, view.UpVector)
end

-- Forgets the ride, so the next starts from behind the missile.
function MissileCamera.release()
	base = nil
end

return MissileCamera
