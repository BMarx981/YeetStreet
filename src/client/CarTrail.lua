--!strict
-- CarTrail (ModuleScript) -> StarterPlayerScripts.CarTrail
-- Draws a car's trail on this client, for every car (CarVisuals). The look
-- comes from the car's Trail attribute (Tuning.Trails.Looks), which the
-- server sets; a car without one gets no trail. It shows only in the air
-- (Trails.step), checked with a ray down from the hull every CheckEvery
-- seconds, and fades out after landing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Trails = require(ReplicatedStorage.Trails)
local Tuning = require(ReplicatedStorage.Tuning)

local T = Tuning.Trails

type Look = { Color: { number } }

local CarTrail = {}

local function lookOf(car: Model): Look?
	local id = car:GetAttribute("Trail")
	return if typeof(id) == "string" then (T.Looks :: { [string]: Look })[id] else nil
end

-- The rebirth trail's color for `rebirths`, for things that match it (the
-- rebirth banner and burst, nameplates); nil before the first rebirth.
function CarTrail.rebirthColor(rebirths: number): Color3?
	local id = Trails.forRebirths(rebirths, T.Rebirth)
	local look = if id then (T.Looks :: { [string]: Look })[id] else nil
	return if look then Color3.fromRGB(look.Color[1], look.Color[2], look.Color[3]) else nil
end

-- Gives `car` its trail at the back of `hull`, following its Trail
-- attribute, until the car is gone.
function CarTrail.add(car: Model, hull: BasePart)
	local back = hull.Size.Z / 2
	local left = Instance.new("Attachment")
	left.Name = "TrailLeft"
	left.Position = Vector3.new(-T.Width / 2, 0, back)
	left.Parent = hull
	local right = Instance.new("Attachment")
	right.Name = "TrailRight"
	right.Position = Vector3.new(T.Width / 2, 0, back)
	right.Parent = hull

	local trail = Instance.new("Trail")
	trail.Name = "CarTrail"
	trail.Attachment0 = left
	trail.Attachment1 = right
	trail.Lifetime = T.Lifetime
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0.3)
	trail.Enabled = false
	trail.Parent = hull

	local look = lookOf(car)
	local function showLook()
		look = lookOf(car)
		if look then
			trail.Color = ColorSequence.new(Color3.fromRGB(look.Color[1], look.Color[2], look.Color[3]))
		else
			trail.Enabled = false
		end
	end
	car:GetAttributeChangedSignal("Trail"):Connect(showLook)
	showLook()

	local ground = RaycastParams.new()
	ground.FilterType = Enum.RaycastFilterType.Exclude
	ground.FilterDescendantsInstances = { car }
	local air = Trails.newAir()
	local since = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		if car.Parent == nil or hull.Parent == nil then
			connection:Disconnect()
			return
		end
		since += dt
		if since < T.CheckEvery then
			return
		end
		local grounded = workspace:Raycast(hull.Position, Vector3.new(0, -T.AirCheck, 0), ground) ~= nil
		local up = Trails.step(air, grounded, since, T.LiftDelay)
		since = 0
		trail.Enabled = up and look ~= nil
	end)
end

return CarTrail
