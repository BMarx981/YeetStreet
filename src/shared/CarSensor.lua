--!strict
-- CarSensor (ModuleScript) -> ReplicatedStorage.CarSensor
-- Reads a car's state each physics step: wheels on the ground, any launch pad
-- or lava (parts tagged Lava) under them, flying, lying on its roof or side, riding a rail (GrindRails)
-- or a swing seat (Swings), any hit it took, and the RunTracker sample.
-- The driving client and the server both read cars through this, so the
-- server scores a run from the same inputs the client's HUD uses.
--
-- Not pure: it raycasts, and keeps the contact state and last hull CFrame and
-- velocity between steps.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contact = require(ReplicatedStorage.Contact)
local GrindRails = require(ReplicatedStorage.GrindRails)
local Righting = require(ReplicatedStorage.Righting)
local RunTracker = require(ReplicatedStorage.RunTracker)
local Swings = require(ReplicatedStorage.Swings)
local Tuning = require(ReplicatedStorage.Tuning)

local CarSensor = {}

local WHEEL_NAMES = { "FL", "FR", "RL", "RR" }

export type Sensor = {
	model: Model,
	hull: BasePart,
	wheels: { BasePart },
	wheelRadius: number,
	ownerId: number, -- the car's OwnerUserId, 0 if it has none
	rayParams: RaycastParams,
	contact: Contact.State,
	lastCFrame: CFrame?,
	lastVelocity: Vector3?,
}

export type Reading = {
	wheelsDown: number,
	pad: BasePart?,
	-- An any-way pad (LaunchPitch) a little way under the car while no
	-- wheel is on a pad. One throws a car off at once, quicker than the
	-- server may see a wheel on it, so this counts as on it for arming a run
	-- (sample.onPad), though only a wheel on a pad launches.
	padBelow: BasePart?,
	lava: boolean, -- a wheel, or the hull from just above, is on lava
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

	local ownerId = model:GetAttribute("OwnerUserId")
	return {
		model = model,
		hull = hull,
		wheels = wheels,
		wheelRadius = wheelRadius,
		ownerId = if typeof(ownerId) == "number" then ownerId else 0,
		rayParams = rayParams,
		contact = Contact.new(),
		lastCFrame = nil,
		lastVelocity = nil,
	}
end

local function isLava(part: Instance): boolean
	return CollectionService:HasTag(part, "Lava")
end

-- Counts wheels touching the ground and returns any launch pad under them,
-- and whether any of them is on lava.
local function probe(sensor: Sensor, cf: CFrame): (number, BasePart?, boolean)
	local down = -cf.UpVector * (sensor.wheelRadius + Tuning.Contact.ProbeMargin)
	local count = 0
	local pad: BasePart? = nil
	local lava = false
	for _, wheel in sensor.wheels do
		local hit = workspace:Raycast(wheel.Position, down, sensor.rayParams)
		if hit then
			count += 1
			local part = hit.Instance
			if part:IsA("BasePart") and part:GetAttribute("LaunchSpeed") then
				pad = part
			end
			lava = lava or isLava(part)
		end
	end
	return count, pad, lava
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

-- The car was just let go in the air after being held still (the
-- pterodactyl): it is flying, and the jump from where it was last read to
-- its speed now is not a hit or a turn.
function CarSensor.dropped(sensor: Sensor)
	sensor.contact = { airborne = true, airtime = 0 }
	sensor.lastCFrame = nil
	sensor.lastVelocity = nil
end

-- `up` is which way the car should be the right way up: world up, or inside
-- a tube, toward its middle line.
function CarSensor.read(sensor: Sensor, dt: number, up: Vector3?): Reading
	local cf = sensor.hull.CFrame
	local velocity = sensor.hull.AssemblyLinearVelocity
	local wheelsDown, pad, wheelsInLava = probe(sensor, cf)
	local C = Tuning.Contact
	sensor.contact = Contact.step(sensor.contact, wheelsDown, dt, C.AirDelay, C.LandWheels)

	local RT = Tuning.Righting
	local upward = up or Vector3.yAxis
	local ground = workspace:Raycast(cf.Position, -upward * RT.GroundProbe, sensor.rayParams)
	local lying = Righting.lying(wheelsDown, cf.UpVector:Dot(upward), ground ~= nil, RT)

	local padBelow: BasePart? = nil
	if not pad then
		local below = workspace:Raycast(cf.Position, Vector3.new(0, -Tuning.Launch.AnyWayReach, 0), sensor.rayParams)
		if below and below.Instance:IsA("BasePart") and below.Instance:GetAttribute("LaunchPitch") ~= nil then
			padBelow = below.Instance
		end
	end

	local rotation = turn(sensor.lastCFrame, cf)
	local hit = impact(sensor.lastCFrame, sensor.lastVelocity, cf, velocity, dt)
	sensor.lastCFrame = cf
	sensor.lastVelocity = velocity
	return {
		wheelsDown = wheelsDown,
		pad = pad,
		padBelow = padBelow,
		lava = wheelsInLava or (ground ~= nil and isLava(ground.Instance)),
		airborne = sensor.contact.airborne,
		lying = lying,
		impact = hit,
		sample = {
			dt = dt,
			airborne = sensor.contact.airborne,
			onPad = (pad ~= nil and pad:GetAttribute("NoRun") ~= true) or padBelow ~= nil,
			x = cf.Position.X,
			y = cf.Position.Y,
			z = cf.Position.Z,
			turnX = rotation.X,
			turnY = rotation.Y,
			turnZ = rotation.Z,
			speed = velocity.Magnitude,
			upY = cf.UpVector.Y,
			lying = lying,
			grinding = GrindRails.onAny(cf.Position, velocity),
			swing = Swings.ridden(sensor.ownerId, cf.Position),
			wingsOut = sensor.model:GetAttribute("PlaneCar") == true and sensor.model:GetAttribute("WingsOut") == true,
		},
	}
end

return CarSensor
