--!strict
-- CarBuilder (ModuleScript) -> ServerScriptService.CarBuilder
-- Builds the M0 car. Physics and looks are separate:
--
--   Hull      invisible collision box, carries all the chassis mass
--   Hub<W>    per wheel, slides on a PrismaticConstraint held up by a spring
--   Wheel<W>  cylinder on a motor HingeConstraint from its hub
--
-- Steering turns the front Mount attachments about the hull's up axis. The
-- prismatic aligns the hub to its mount, so the hub, axle, and wheel turn with
-- it. The client owns the car and drives every constraint; the server only
-- builds it and writes the stats as attributes.
--
-- The looks aren't built here: each client builds them from the car's look
-- attributes (CarVisuals).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local C = Tuning.Chassis

local CarBuilder = {}

local WHEELS = {
	{ name = "FL", side = -1, lengthways = -1, steers = true },
	{ name = "FR", side = 1, lengthways = -1, steers = true },
	{ name = "RL", side = -1, lengthways = 1, steers = false },
	{ name = "RR", side = 1, lengthways = 1, steers = false },
}

local function newPart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function attach(name: string, cframe: CFrame, parent: Instance): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = cframe
	attachment.Parent = parent
	return attachment
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function totalMass(model: Model): number
	local mass = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Massless then
			mass += descendant:GetMass()
		end
	end
	return mass
end

function CarBuilder.build(stats: typeof(Tuning.StarterCar), spawn: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Car"

	local hull = newPart("Hull", C.HullSize, CFrame.identity, model)
	hull.Transparency = 1
	hull.CollisionGroup = "Cars"
	hull.RootPriority = 10
	hull.CustomPhysicalProperties = PhysicalProperties.new(C.HullDensity, C.HullFriction, 0, 1, 1)
	model.PrimaryPart = hull

	local center = attach("Center", CFrame.identity, hull)

	local spin = Instance.new("AngularVelocity")
	spin.Name = "AirSpin"
	spin.Attachment0 = center
	spin.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	spin.AngularVelocity = Vector3.zero
	spin.MaxTorque = 0
	spin.Enabled = false
	spin.Parent = hull

	local jet = Instance.new("VectorForce")
	jet.Name = "Jet"
	jet.Attachment0 = center
	jet.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	jet.ApplyAtCenterOfMass = true
	jet.Force = Vector3.zero
	jet.Parent = hull

	-- The Brakes upgrade's push against travel on the ground (CarController).
	local brake = Instance.new("VectorForce")
	brake.Name = "Brake"
	brake.Attachment0 = center
	brake.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	brake.ApplyAtCenterOfMass = true
	brake.Force = Vector3.zero
	brake.Parent = hull

	-- Holds the car to a city tube's wall (CarController), in world space.
	local stick = Instance.new("VectorForce")
	stick.Name = "Stick"
	stick.Attachment0 = center
	stick.RelativeTo = Enum.ActuatorRelativeTo.World
	stick.ApplyAtCenterOfMass = true
	stick.Force = Vector3.zero
	stick.Parent = hull

	local driverSeat = Instance.new("Seat")
	driverSeat.Name = "DriverSeat"
	driverSeat.Size = Vector3.new(2, 0.4, 2)
	driverSeat.CFrame = CFrame.new(C.SeatOffset)
	driverSeat.Transparency = 1
	driverSeat.CanCollide = false
	driverSeat.CanQuery = false
	driverSeat.CanTouch = false
	driverSeat.Massless = true
	driverSeat:SetAttribute("CarSeat", true)
	driverSeat.Parent = model
	weld(hull, driverSeat)

	local hubs: { BasePart } = {}
	for _, spec in WHEELS do
		local mountPos = Vector3.new(spec.side * C.TrackHalf, C.MountY, spec.lengthways * C.WheelbaseHalf)
		-- The prismatic slides along its attachment's X axis, so X points up.
		-- Y points to the car's right, which gives the hub the hull's orientation.
		local slideFrame = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.xAxis)
		local mount = attach(`Mount{spec.name}`, CFrame.new(mountPos) * slideFrame, hull)
		mount:SetAttribute("Steers", spec.steers)
		local springTop = attach(`SpringTop{spec.name}`, CFrame.new(mountPos + Vector3.new(0, C.SpringTop, 0)), hull)

		local restSlide = C.SlideLow + C.SuspensionSag
		local wheelCFrame = CFrame.new(mountPos + Vector3.new(0, restSlide, 0))

		local hub = newPart(`Hub{spec.name}`, Vector3.one * C.HubSize, wheelCFrame, model)
		hub.Transparency = 1
		hub.CanCollide = false
		hub.CanQuery = false
		hub.CanTouch = false
		hub.CustomPhysicalProperties = PhysicalProperties.new(C.HubDensity, 0.3, 0, 1, 1)
		local hubSlide = attach("Slide", slideFrame, hub)
		-- Hinge axis (the attachment's X) along the car's right.
		local hubAxle = attach("AxlePoint", CFrame.identity, hub)
		table.insert(hubs, hub)

		local slide = Instance.new("PrismaticConstraint")
		slide.Name = "Suspension"
		slide.Attachment0 = mount
		slide.Attachment1 = hubSlide
		slide.LimitsEnabled = true
		slide.LowerLimit = C.SlideLow
		slide.UpperLimit = C.SlideHigh
		slide.Restitution = 0
		slide.Parent = hub

		local spring = Instance.new("SpringConstraint")
		spring.Name = "Spring"
		spring.Attachment0 = springTop
		spring.Attachment1 = hubSlide
		spring.FreeLength = C.SpringTop - C.SlideLow
		spring.Parent = hub

		local wheel = newPart(
			`Wheel{spec.name}`,
			Vector3.new(C.WheelWidth, C.WheelRadius * 2, C.WheelRadius * 2),
			wheelCFrame,
			model
		)
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Color = Color3.fromRGB(30, 30, 32)
		wheel.Material = Enum.Material.SmoothPlastic
		wheel.CollisionGroup = "Wheels"
		-- High weights so the wheel's own friction and zero bounce win against
		-- whatever surface it touches. Rear wheels grip a little more, so at the
		-- limit the nose runs wide instead of the tail stepping out.
		local grip = if spec.steers then stats.Grip else stats.Grip * C.RearGripFactor
		wheel.CustomPhysicalProperties = PhysicalProperties.new(C.WheelDensity, grip, 0, 100, 100)
		local wheelAxle = attach("AxlePoint", CFrame.identity, wheel)

		local axle = Instance.new("HingeConstraint")
		axle.Name = "Axle"
		axle.Attachment0 = hubAxle
		axle.Attachment1 = wheelAxle
		axle.ActuatorType = Enum.ActuatorType.Motor
		axle.MotorMaxTorque = 0
		axle.AngularVelocity = 0
		axle.Parent = wheel

		-- Wheels swing inside the hull's footprint when steering.
		local noHull = Instance.new("NoCollisionConstraint")
		noHull.Part0 = hull
		noHull.Part1 = wheel
		noHull.Parent = wheel
	end

	-- Spring rate from the car's weight, so the rest height holds when mass or
	-- gravity is retuned.
	local mass = totalMass(model)
	local cornerMass = mass / #WHEELS
	local stiffness = cornerMass * Tuning.World.Gravity / C.SuspensionSag
	local damping = C.DampingRatio * 2 * math.sqrt(stiffness * cornerMass)
	for _, hub in hubs do
		local spring = hub:FindFirstChild("Spring") :: SpringConstraint
		spring.Stiffness = stiffness
		spring.Damping = damping
	end

	for key, value in (stats :: any) :: { [string]: any } do
		model:SetAttribute(key, value)
	end
	model:SetAttribute("WheelRadius", C.WheelRadius)
	model:SetAttribute("SpawnCFrame", spawn)

	model:PivotTo(spawn)
	return model
end

return CarBuilder
