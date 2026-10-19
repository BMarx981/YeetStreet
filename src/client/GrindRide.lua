--!strict
-- GrindRide (ModuleScript) -> StarterPlayerScripts.GrindRide
-- Rides the driven car along a rail (GrindRails). CarController calls step
-- each physics step; it puts a car that comes close to a rail, moving along
-- it, onto the rail. While step returns true the car is on the rail: this
-- places it on the grind line every step at the speed it got on with, and
-- CarController leaves driving, jets, and air control alone. The balance bar
-- (GrindBar) shows meanwhile, and steering keeps the marker in the zone
-- (Grind).
--
-- The ride ends at the end of the rail with a small pop, when the car slips
-- off toward the marker's side, or when jets are pressed, which hops it off.
-- A rail waits Cooldown seconds before it can catch the same car again, so a
-- car that slipped off falls instead of getting straight back on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Grind = require(ReplicatedStorage.Grind)
local GrindRails = require(ReplicatedStorage.GrindRails)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)
local GrindBar = require(script.Parent.GrindBar)

local GrindRide = {}

type Ride = {
	part: BasePart,
	rail: Grind.Rail,
	t: number, -- 0 at the rail's start, 1 at its end
	direction: number, -- 1 riding start to end, -1 the other way
	speed: number,
	along: Vector3, -- the way the car rides
	balance: Grind.Balance,
	rng: Rng.Rng,
}

local ride: Ride? = nil
local cooldownUntil: { [BasePart]: number } = {}
local jetHeld = false

local function tryCapture(hull: BasePart): Ride?
	local G = Tuning.Grind
	local p, v = hull.Position, hull.AssemblyLinearVelocity
	local now = os.clock()
	for part, rail in GrindRails.all() do
		if (cooldownUntil[part] or 0) > now then
			continue
		end
		local direction, t, speed = Grind.capture(rail, p.X, p.Y, p.Z, v.X, v.Y, v.Z, G)
		if direction then
			local a = Vector3.new(rail.ax, rail.ay, rail.az)
			local b = Vector3.new(rail.bx, rail.by, rail.bz)
			return {
				part = part,
				rail = rail,
				t = t,
				direction = direction,
				speed = math.clamp(math.abs(speed), G.RideMinSpeed, G.RideMaxSpeed),
				along = (b - a).Unit * direction,
				balance = Grind.balance(),
				rng = Rng.new(math.floor(os.clock() * 1000)),
			}
		end
	end
	return nil
end

local function setMotion(roots: { BasePart }, velocity: Vector3)
	for _, part in roots do
		part.AssemblyLinearVelocity = velocity
		part.AssemblyAngularVelocity = Vector3.zero
	end
end

local function release(current: Ride, roots: { BasePart }, velocity: Vector3)
	ride = nil
	cooldownUntil[current.part] = os.clock() + Tuning.Grind.Cooldown
	setMotion(roots, velocity)
	GrindBar.hide()
end

-- Puts the hull on the grind line, facing the way it rides.
local function place(model: Model, hull: BasePart, current: Ride)
	local x, y, z = Grind.point(current.rail, current.t, Tuning.Grind)
	local at = Vector3.new(x, y, z)
	local target = CFrame.lookAt(at, at + current.along)
	model:PivotTo(target * hull.CFrame:ToObjectSpace(model:GetPivot()))
end

-- Advances the ride, or starts one. Returns true while the car is on a rail.
function GrindRide.step(
	model: Model,
	hull: BasePart,
	roots: { BasePart },
	steer: number,
	jet: boolean,
	dt: number
): boolean
	local G = Tuning.Grind
	local jetPressed = jet and not jetHeld
	jetHeld = jet

	local current = ride or tryCapture(hull)
	if not current then
		return false
	end
	ride = current

	local fell = Grind.stepBalance(current.balance, steer, dt, current.rng, G)
	current.t += current.direction * current.speed * dt / Grind.length(current.rail)
	local up = Vector3.yAxis
	if current.t < 0 or current.t > 1 then
		release(current, roots, current.along * current.speed + up * G.EndPop)
		return false
	end
	if fell then
		local side = CFrame.lookAt(Vector3.zero, current.along).RightVector * math.sign(current.balance.marker)
		release(current, roots, current.along * current.speed * 0.7 + side * G.SlipSpeed)
		return false
	end
	if jetPressed then
		release(current, roots, current.along * current.speed + up * G.Hop)
		return false
	end

	place(model, hull, current)
	setMotion(roots, current.along * current.speed)
	GrindBar.show(current.balance)
	return true
end

-- Ends any ride at once, for resets and leaving the car.
function GrindRide.stop()
	ride = nil
	jetHeld = false
	GrindBar.hide()
end

return GrindRide
