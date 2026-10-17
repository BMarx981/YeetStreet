--!strict
-- CarSensor (ModuleScript) -> ReplicatedStorage.CarSensor
-- Reads a car's state each physics step: wheels on the ground, any launch pad
-- under them, flying, lying on its roof or side, any hit it took, and the
-- RunTracker sample.
-- The driving client and the server both read cars through this, so the
-- server scores a run from the same inputs the client's HUD uses.
--
-- Not pure: it raycasts, and keeps the contact state and last hull CFrame and
-- velocity between steps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contact = require(ReplicatedStorage.Contact)
local Righting = require(ReplicatedStorage.Righting)
local RunTracker = require(ReplicatedStorage.RunTracker)
local Tuning = require(ReplicatedStorage.Tuning)

local CarSensor = {}

local WHEEL_NAMES = { "FL", "FR", "RL", "RR" }

export type Sensor = {
	hull: BasePart,
	wheels: { BasePart },
	wheelRadius: number,
	rayParams: RaycastParams,
	contact: Contact.State,
	lastCFrame: CFrame?,
	lastVelocity: Vector3?,
}

export type Reading = {
	wheelsDown: number,
	pad: BasePart?,
	airborne: boolean,
	lying: boolean,
	-- The change in velocity since the last step that gravity does not
	-- explain, in the car's own space (see Impact). Zero after a reset.
	impact: Vector3,
	sample: RunTracker.Sample,
}

-- Rays ignore the car itself and everything in `ignore` (its driver). Returns
-- nil until the hull, wheels, and WheelRadius attribute have replicated.
function CarSensor.new(model: Model, ignore: { Instance }): Sensor?
	local hull = model:FindFirstChild("Hull")
	local wheelRadius = model:GetAttribute("WheelRadius")
	if not (hull and hull:IsA("BasePart") and typeof(wheelRadius) == "number") then
		return nil
	end
	local wheels: { BasePart } = {}
	for _, name in WHEEL_NAMES do
		local wheel = model:FindFirstChild(`Wheel{name}`)
		if not (wheel and wheel:IsA("BasePart")) then
			return nil
		end
		table.insert(wheels, wheel)
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = table.clone(ignore)
	table.insert(exclude, model)
	rayParams.FilterDescendantsInstances = exclude
	-- Only what a car can collide with, so knocked props are never ground.
	rayParams.CollisionGroup = "Cars"

	return {
		hull = hull,
		wheels = wheels,
		wheelRadius = wheelRadius,
		rayParams = rayParams,
		contact = Contact.new(),
		lastCFrame = nil,
		lastVelocity = nil,
	}
end

-- Counts wheels touching the ground and returns any launch pad under them.
local function probe(sensor: Sensor, cf: CFrame): (number, BasePart?)
	local down = -cf.UpVector * (sensor.wheelRadius + Tuning.Contact.ProbeMargin)
	local count = 0
	local pad: BasePart? = nil
	for _, wheel in sensor.wheels do
		local hit = workspace:Raycast(wheel.Position, down, sensor.rayParams)
		if hit then
			count += 1
			local part = hit.Instance
			if part:IsA("BasePart") and part:GetAttribute("LaunchSpeed") then
				pad = part
			end
		end
	end
	return count, pad
end

-- The hull's rotation since the last step, in its own axes.
local function turn(last: CFrame?, cf: CFrame): Vector3
	if not last then
		return Vector3.zero
	end
	local axis, angle = last:ToObjectSpace(cf):ToAxisAngle()
	return if angle > 1e-6 then axis * angle else Vector3.zero
end

-- Gravity takes Gravity * dt off the vertical speed each step, so add that
-- back; what is left came from hitting something (or the jets, which are far
-- weaker than any hit worth counting). A step that moved the car farther than
-- TeleportDistance was a reset, not a hit.
local function impact(last: CFrame?, lastVelocity: Vector3?, cf: CFrame, velocity: Vector3, dt: number): Vector3
	if not (last and lastVelocity) then
		return Vector3.zero
	end
	if (cf.Position - last.Position).Magnitude > Tuning.Run.TeleportDistance then
		return Vector3.zero
	end
	local change = velocity - lastVelocity + Vector3.new(0, workspace.Gravity * dt, 0)
	return cf:VectorToObjectSpace(change)
end

function CarSensor.read(sensor: Sensor, dt: number): Reading
	local cf = sensor.hull.CFrame
	local velocity = sensor.hull.AssemblyLinearVelocity
	local wheelsDown, pad = probe(sensor, cf)
	local C = Tuning.Contact
	sensor.contact = Contact.step(sensor.contact, wheelsDown, dt, C.AirDelay, C.LandWheels)

	local RT = Tuning.Righting
	local groundClose = workspace:Raycast(cf.Position, Vector3.new(0, -RT.GroundProbe, 0), sensor.rayParams) ~= nil
	local lying = Righting.lying(wheelsDown, cf.UpVector.Y, groundClose, RT)

	local rotation = turn(sensor.lastCFrame, cf)
	local hit = impact(sensor.lastCFrame, sensor.lastVelocity, cf, velocity, dt)
	sensor.lastCFrame = cf
	sensor.lastVelocity = velocity
	return {
		wheelsDown = wheelsDown,
		pad = pad,
		airborne = sensor.contact.airborne,
		lying = lying,
		impact = hit,
		sample = {
			dt = dt,
			airborne = sensor.contact.airborne,
			onPad = pad ~= nil,
			x = cf.Position.X,
			y = cf.Position.Y,
			z = cf.Position.Z,
			turnX = rotation.X,
			turnY = rotation.Y,
			turnZ = rotation.Z,
			speed = velocity.Magnitude,
			upY = cf.UpVector.Y,
			lying = lying,
		},
	}
end

return CarSensor
