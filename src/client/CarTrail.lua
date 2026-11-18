--!strict
-- CarTrail (ModuleScript) -> StarterPlayerScripts.CarTrail
-- Draws a car's trail on this client, for every car (CarVisuals). The look
-- comes from the car's Trail attribute (Tuning.Trails.Looks), which the
-- server sets; a car without one gets no trail. It shows only in the air
-- (Trails.step), checked with a ray down from the hull every CheckEvery
-- seconds, and fades out after landing. A replay ghost gets one too (ghost,
-- showGhost), from the look its car had, stepped on the replay's clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Flames = require(ReplicatedStorage.Flames)
local Trails = require(ReplicatedStorage.Trails)
local Tuning = require(ReplicatedStorage.Tuning)

local T = Tuning.Trails

-- One Color, or Colors that run along the trail from the car back.
type Look = { Color: { number }?, Colors: { { number } }? }

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- The trail's colors, spaced along it the way a prize flame's are.
local function sequence(look: Look): ColorSequence
	local colors = look.Colors or { look.Color :: { number } }
	if #colors == 1 then
		return ColorSequence.new(rgb(colors[1]))
	end
	local keypoints = {}
	for i, stop in Flames.stops(#colors) do
		table.insert(keypoints, ColorSequenceKeypoint.new(stop, rgb(colors[i])))
	end
	return ColorSequence.new(keypoints)
end

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
	return if look and look.Color then rgb(look.Color) else nil
end

-- A trail at the back of `hull`, off until something lights it.
local function build(hull: BasePart): Trail
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
	return trail
end

-- Gives `car` its trail at the back of `hull`, following its Trail
-- attribute, until the car is gone.
function CarTrail.add(car: Model, hull: BasePart)
	local trail = build(hull)
	local look = lookOf(car)
	local function showLook()
		look = lookOf(car)
		if look then
			trail.Color = sequence(look)
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

-- A replay ghost's trail, stepped by ReplayPlayer.
export type Ghost = {
	trail: Trail,
	hull: BasePart,
	ground: RaycastParams,
	air: Trails.Air,
	since: number, -- replay seconds since the last air check
}

-- The trail for replay ghost `ghost`, at the back of `hull` (a stand-in for
-- the car's hull that moves with it), in the look of the ghost's Trail
-- attribute, copied from its car. Nil if the car had no trail.
function CarTrail.ghost(ghost: Model, hull: BasePart): Ghost?
	local look = lookOf(ghost)
	if not look then
		return nil
	end
	local trail = build(hull)
	trail.Color = sequence(look)
	local ground = RaycastParams.new()
	ground.FilterType = Enum.RaycastFilterType.Exclude
	local cars = workspace:FindFirstChild("Cars")
	ground.FilterDescendantsInstances = if cars then { ghost, cars } else { ghost }
	return { trail = trail, hull = hull, ground = ground, air = Trails.newAir(), since = 0 }
end

-- Steps a ghost's trail on by `dt` replay seconds (0 while paused). A seek
-- wipes what it had drawn, so it doesn't streak across the jump.
function CarTrail.showGhost(g: Ghost, dt: number, seek: boolean)
	if seek then
		g.trail:Clear()
		g.air = Trails.newAir()
		g.since = T.CheckEvery
	end
	g.since += dt
	if g.since < T.CheckEvery then
		return
	end
	local grounded = workspace:Raycast(g.hull.Position, Vector3.new(0, -T.AirCheck, 0), g.ground) ~= nil
	g.trail.Enabled = Trails.step(g.air, grounded, g.since, T.LiftDelay)
	g.since = 0
end

return CarTrail
