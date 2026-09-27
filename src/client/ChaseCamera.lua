--!strict
-- ChaseCamera (ModuleScript) -> StarterPlayerScripts.ChaseCamera
-- Follows behind the car. On the ground it looks along the car's nose. In the
-- air it looks along the direction of travel, so flips and spins happen in
-- front of the camera instead of whipping it around. FOV widens with speed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local C = Tuning.Camera

local ChaseCamera = {}

local heading: Vector3? = nil

local function wantedHeading(hull: BasePart, airborne: boolean): Vector3?
	local velocity = hull.AssemblyLinearVelocity
	local want = hull.CFrame.LookVector
	if airborne and velocity.Magnitude > C.FollowVelocityAbove then
		want = velocity.Unit
	end
	-- Straight up or down has no "behind"; keep the last heading instead.
	if Vector3.new(want.X, 0, want.Z).Magnitude < 1e-3 then
		return nil
	end
	return Vector3.new(want.X, math.clamp(want.Y, -C.MaxPitch, C.MaxPitch), want.Z).Unit
end

function ChaseCamera.update(hull: BasePart, airborne: boolean, dt: number)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	local want = wantedHeading(hull, airborne)
	if not heading then
		heading = want or hull.CFrame.LookVector
	elseif want then
		local blended = heading:Lerp(want, 1 - math.exp(-C.TurnSharpness * dt))
		if blended.Magnitude > 1e-3 then
			heading = blended.Unit
		end
	end
	local dir = heading :: Vector3

	local focus = hull.Position + Vector3.yAxis * C.FocusHeight
	local position = focus - dir * C.Distance + Vector3.yAxis * C.Height
	camera.CFrame = CFrame.lookAt(position, focus)

	local speedT = math.clamp(hull.AssemblyLinearVelocity.Magnitude / C.FovFullSpeed, 0, 1)
	camera.FieldOfView = C.Fov + C.FovBoost * speedT
end

function ChaseCamera.release()
	heading = nil
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = C.Fov
end

return ChaseCamera
