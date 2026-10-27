--!strict
-- CarPreview (ModuleScript) -> StarterPlayerScripts.CarPreview
-- A small 3D view of a ladder car for the garage, built from its seed and
-- levels the same way CarVisuals builds real cars (CarDesign and CarParts),
-- with stand-in wheels like the car gallery's. The camera circles the car
-- rather than the car turning, so spinning moves one CFrame. It only draws
-- in a ViewportFrame; nothing here is in the world or touches physics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarDesign = require(ReplicatedStorage.CarDesign)
local CarKit = require(ReplicatedStorage.CarKit)
local CarParts = require(ReplicatedStorage.CarParts)
local Economy = require(ReplicatedStorage.Economy)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)

local CarPreview = {}

export type Preview = {
	viewport: ViewportFrame,
	-- Shows this car with these look levels, rebuilding only if they changed.
	set: (car: Economy.Car, levels: Economy.Levels) -> (),
	spin: (dt: number) -> (),
}

local FIELD_OF_VIEW = 30
local PITCH = math.rad(18) -- how far the camera looks down at the car
local START_ANGLE = math.rad(215) -- a three-quarter view of the nose, which points to -z
local SPIN_SPEED = 0.6 -- radians per second
local FIT = 0.62 -- under 1 lets the car fill more of the view than its bounding sphere would
local WHEEL_COLOR = Color3.fromRGB(30, 30, 34)

local function wheels(design: CarDesign.Design, model: Model)
	if design.hideWheels then
		return
	end
	local C = Tuning.Chassis
	local wheelY = C.MountY + C.SlideLow + C.SuspensionSag
	for _, side in { -1, 1 } do
		for _, ends in { -1, 1 } do
			local wheel = Instance.new("Part")
			wheel.Name = "Wheel"
			wheel.Shape = Enum.PartType.Cylinder
			wheel.Size = Vector3.new(C.WheelWidth, 2 * C.WheelRadius, 2 * C.WheelRadius)
			wheel.CFrame = CFrame.new(side * C.TrackHalf, wheelY, ends * C.WheelbaseHalf)
			wheel.Color = WHEEL_COLOR
			wheel.Material = Enum.Material.SmoothPlastic
			wheel.Anchored = true
			wheel.Parent = model
		end
	end
end

function CarPreview.new(parent: Instance): Preview
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(150, 150, 160)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -2, -1)
	viewport.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD_OF_VIEW
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local model: Model? = nil
	local shown = ""
	local center = Vector3.zero
	local distance = 20
	local angle = START_ANGLE

	local function aim()
		camera.CFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0) * CFrame.Angles(-PITCH, 0, 0) * CFrame.new(0, 0, distance)
	end

	local function set(car: Economy.Car, levels: Economy.Levels)
		local key =
			`{car.Seed}|{car.Archetype}|{car.Tier}|{levels.Speed}|{levels.Jets}|{levels.Toughness}|{levels.Grip}|{levels.Brakes}`
		if key == shown then
			return
		end
		shown = key
		if model then
			model:Destroy()
		end
		local input = { archetype = car.Archetype, tier = car.Tier, levels = levels }
		local design = CarDesign.design(Rng.new(car.Seed), input, CarKit, Tuning.CarLooks)
		local built = Instance.new("Model")
		built.Name = "Car"
		CarParts.build(design, CFrame.new(), built)
		wheels(design, built)
		built.Parent = viewport
		model = built
		local box, size = built:GetBoundingBox()
		center = box.Position
		distance = FIT * (size.Magnitude / 2) / math.sin(math.rad(FIELD_OF_VIEW / 2))
		aim()
	end

	local function spin(dt: number)
		angle += SPIN_SPEED * dt
		aim()
	end

	return { viewport = viewport, set = set, spin = spin }
end

return CarPreview
