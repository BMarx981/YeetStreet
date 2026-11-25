--!strict
-- ChaseCamera (ModuleScript) -> StarterPlayerScripts.ChaseCamera
-- Follows behind the car. On the ground it looks along the car's nose. In the
-- air it looks along the direction of travel, so flips and spins happen in
-- front of the camera instead of whipping it around. A plane with its wings
-- out always looks along its nose, so the camera stays behind the driver even
-- while it sinks. FOV widens with speed.
-- Up is world up, except inside a city tube, where it is toward the tube's
-- middle line, so the camera rolls round with a car driving on the walls.
-- A hit-stop (Juice) briefly holds the view and punches the zoom.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Juice = require(ReplicatedStorage.Juice)
local Tuning = require(ReplicatedStorage.Tuning)

local C = Tuning.Camera

local ChaseCamera = {}

local heading: Vector3? = nil
local cameraUp = Vector3.yAxis
-- The running hit-stop: when it started and the view it holds.
local stoppedAt: number? = nil
local held: CFrame? = nil

local function wantedHeading(hull: BasePart, airborne: boolean, up: Vector3, followNose: boolean): Vector3?
	local velocity = hull.AssemblyLinearVelocity
	local want = hull.CFrame.LookVector
	if airborne and not followNose and velocity.Magnitude > C.FollowVelocityAbove then
		want = velocity.Unit
	end
	-- Straight up or down has no "behind"; keep the last heading instead.
	local level = want - up * want:Dot(up)
	if level.Magnitude < 1e-3 then
		return nil
	end
	return (level + up * math.clamp(want:Dot(up), -C.MaxPitch, C.MaxPitch)).Unit
end

function ChaseCamera.update(hull: BasePart, airborne: boolean, dt: number, up: Vector3?, followNose: boolean?)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	local blend = 1 - math.exp(-C.TurnSharpness * dt)
	local rolled = cameraUp:Lerp(up or Vector3.yAxis, blend)
	if rolled.Magnitude > 1e-3 then
		cameraUp = rolled.Unit
	end

	local want = wantedHeading(hull, airborne, cameraUp, followNose == true)
	if not heading then
		heading = want or hull.CFrame.LookVector
	elseif want then
		local blended = heading:Lerp(want, blend)
		if blended.Magnitude > 1e-3 then
			heading = blended.Unit
		end
	end
	local dir = heading :: Vector3

	local focus = hull.Position + cameraUp * C.FocusHeight
	local position = focus - dir * C.Distance + cameraUp * C.Height
	local view = CFrame.lookAt(position, focus, cameraUp)

	local speedT = math.clamp(hull.AssemblyLinearVelocity.Magnitude / C.FovFullSpeed, 0, 1)
	local fov = C.Fov + C.FovBoost * speedT

	local at, from = stoppedAt, held
	if at and from then
		local stop = Juice.hitStop(os.clock() - at, Tuning.Juice)
		if stop.done then
			stoppedAt, held = nil, nil
		else
			view = from:Lerp(view, stop.blend)
			fov += stop.fov
		end
	end
	camera.CFrame = view
	camera.FieldOfView = fov
end

-- Holds the camera's view for a moment while the car moves on, then catches
-- up with a zoom punch, for a PERFECT landing.
function ChaseCamera.hitStop()
	stoppedAt = os.clock()
	held = workspace.CurrentCamera.CFrame
end

function ChaseCamera.release()
	stoppedAt, held = nil, nil
	heading = nil
	cameraUp = Vector3.yAxis
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = C.Fov
end

return ChaseCamera
