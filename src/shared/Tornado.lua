--!strict
-- Tornado (ModuleScript) -> ReplicatedStorage.Tornado
-- One tornado: where it touches down, how tall it is, where it wanders,
-- which cars it sucks in, and how they ride up and get thrown out. Pure, see
-- InputAxes. The server steps every tornado and decides every catch and
-- throw; clients only draw them.
--
--   touchdown  comes down from the sky for TouchTime, catching nothing
--   roam       wanders toward spots Edge inside the area it touched down
--              in at Speed, for its life (LifeMin to LifeMax, rolled by the
--              server). It keeps roaming past its life while anyone rides.
--   lift       goes back up for LiftTime, catching nothing
--   gone       the server takes it away and drops a new one somewhere else
--
-- Its funnel is BaseRadius wide at the ground and TopSpread studs wider for
-- every stud up, to its height (MinHeight to MaxHeight, see height). While
-- it roams it catches any car inside the funnel, from CatchBelow under the
-- ground to its top, ground or air. A caught car rides round the middle at
-- RideRadius of the funnel's width there, Spin radians a second, climbing
-- Climb studs a second and tumbling Tumble radians a second. A car caught
-- within RiderGap radians of another rider is moved to the middle of the
-- widest gap, so riders never stack.
--
-- A rider is thrown out at the top, or once its jets have burned EscapeJets
-- seconds on the way up. It leaves along its spin, turned FlingOut outward,
-- at FlingSpeed flat and FlingUp up. It is let go inside the funnel, so this
-- tornado won't catch it again for Recatch seconds.
--
-- Heights ("up") are studs above the ground under the tornado. Angles round
-- the middle are radians from +X toward +Z. Positions are world studs.

local Tornado = {}

-- Same as Rng.Rng, declared here so this module needs no require.
type Rng = {
	next: () -> number,
	range: (low: number, high: number) -> number,
	int: (low: number, high: number) -> number,
}

-- A rectangle on the ground (MapLayout.Area's shape): X and Z are its
-- middle, Width runs along X and Depth along Z.
export type Area = {
	X: number,
	Z: number,
	Width: number,
	Depth: number,
}

export type Spot = {
	x: number,
	z: number,
	area: Area,
}

export type Phase = "touchdown" | "roam" | "lift" | "gone"

export type Rider = {
	id: any,
	angle: number,
	up: number,
	tumble: number,
	jetsFor: number,
}

export type State = {
	x: number,
	z: number,
	height: number,
	life: number,
	area: Area,
	phase: Phase,
	phaseAge: number,
	goalX: number?,
	goalZ: number?,
	riders: { Rider },
	-- Cars thrown out lately, with the seconds left before it may catch them.
	thrown: { [any]: number },
}

-- A car as the server sees it: `up` is its height above the ground under
-- the tornado.
export type Car = {
	id: any,
	x: number,
	up: number,
	z: number,
}

-- Where a rider is: its middle, the way it faces (yaw, radians, the
-- direction it spins), and how far it has tumbled.
export type Place = {
	x: number,
	up: number,
	z: number,
	yaw: number,
	tumble: number,
}

-- A rider let go, where it was and how fast it leaves.
export type Throw = {
	id: any,
	why: "top" | "jets",
	x: number,
	up: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
}

export type Tuning = {
	MinHeight: number,
	MaxHeight: number,
	LifeMin: number,
	LifeMax: number,
	TouchTime: number,
	LiftTime: number,
	Edge: number,
	Apart: number,
	Tries: number,
	Speed: number,
	GoalReach: number,
	BaseRadius: number,
	TopSpread: number,
	CatchBelow: number,
	Climb: number,
	Spin: number,
	RideRadius: number,
	Tumble: number,
	RiderGap: number,
	EscapeJets: number,
	Recatch: number,
	FlingSpeed: number,
	FlingUp: number,
	FlingOut: number,
}

local TAU = 2 * math.pi

-- A tornado's height for a roll from 0 to 1, never outside MinHeight to
-- MaxHeight.
function Tornado.height(roll: number, t: Tuning): number
	local r = math.clamp(roll, 0, 1)
	return t.MinHeight + (t.MaxHeight - t.MinHeight) * r
end

-- A random spot Edge inside one of `areas`, picked by how big each is, and
-- at least Apart from every one of `others`. Nil when Tries picks found none.
function Tornado.pickSpot(areas: { Area }, others: { { x: number, z: number } }, rng: Rng, t: Tuning): Spot?
	local total = 0
	for _, a in areas do
		total += a.Width * a.Depth
	end
	if total <= 0 then
		return nil
	end
	for _ = 1, t.Tries do
		local pick = rng.next() * total
		local area = areas[#areas]
		for _, a in areas do
			pick -= a.Width * a.Depth
			if pick < 0 then
				area = a
				break
			end
		end
		local halfX = math.max(area.Width / 2 - t.Edge, 0)
		local halfZ = math.max(area.Depth / 2 - t.Edge, 0)
		local x = area.X + rng.range(-halfX, halfX)
		local z = area.Z + rng.range(-halfZ, halfZ)
		local clear = true
		for _, o in others do
			if (x - o.x) ^ 2 + (z - o.z) ^ 2 < t.Apart ^ 2 then
				clear = false
				break
			end
		end
		if clear then
			return { x = x, z = z, area = area }
		end
	end
	return nil
end

-- A new tornado touching down at (x, z), `height` tall, roaming for `life`
-- seconds inside `area`.
function Tornado.new(x: number, z: number, height: number, life: number, area: Area): State
	return {
		x = x,
		z = z,
		height = height,
		life = life,
		area = area,
		phase = "touchdown",
		phaseAge = 0,
		goalX = nil,
		goalZ = nil,
		riders = {},
		thrown = {},
	}
end

-- How wide the funnel is `up` studs above the ground (its radius).
function Tornado.radiusAt(s: State, up: number, t: Tuning): number
	return t.BaseRadius + math.clamp(up, 0, s.height) * t.TopSpread
end

-- From angle `a` to angle `b` the short way round, from -pi to pi.
function Tornado.angleGap(a: number, b: number): number
	local d = (b - a) % TAU
	if d > math.pi then
		d -= TAU
	end
	return d
end

-- Where `angle` lands once spread from the other riders: itself if no rider
-- is within RiderGap, otherwise the middle of the widest gap between them.
local function spread(s: State, angle: number, t: Tuning): number
	local crowded = false
	for _, r in s.riders do
		if math.abs(Tornado.angleGap(r.angle, angle)) < t.RiderGap then
			crowded = true
			break
		end
	end
	if not crowded then
		return angle
	end
	local angles = {}
	for _, r in s.riders do
		table.insert(angles, r.angle % TAU)
	end
	table.sort(angles)
	local best, bestGap = angle, -1
	for i, a in angles do
		local nextAngle = if i < #angles then angles[i + 1] else angles[1] + TAU
		local gap = nextAngle - a
		if gap > bestGap then
			best, bestGap = a + gap / 2, gap
		end
	end
	return best % TAU
end

-- Catches every car in `cars` inside the funnel that is not already riding,
-- while it roams. Returns the ids caught.
function Tornado.catch(s: State, cars: { Car }, t: Tuning): { any }
	local caught = {}
	if s.phase ~= "roam" then
		return caught
	end
	for _, car in cars do
		local riding = false
		for _, r in s.riders do
			if r.id == car.id then
				riding = true
				break
			end
		end
		if riding or s.thrown[car.id] or car.up < -t.CatchBelow or car.up > s.height then
			continue
		end
		local dx, dz = car.x - s.x, car.z - s.z
		local reach = Tornado.radiusAt(s, car.up, t)
		if dx * dx + dz * dz > reach * reach then
			continue
		end
		local angle = spread(s, math.atan2(dz, dx), t)
		table.insert(s.riders, {
			id = car.id,
			angle = angle,
			up = math.clamp(car.up, 0, s.height),
			tumble = 0,
			jetsFor = 0,
		})
		table.insert(caught, car.id)
	end
	return caught
end

-- Takes rider `id` off without throwing it, for a car that is gone. Returns
-- whether it was riding.
function Tornado.drop(s: State, id: any): boolean
	for i, r in s.riders do
		if r.id == id then
			table.remove(s.riders, i)
			return true
		end
	end
	return false
end

-- Where rider `r` is now.
function Tornado.riderAt(s: State, r: Rider, t: Tuning): Place
	local radius = Tornado.radiusAt(s, r.up, t) * t.RideRadius
	local cx, cz = math.cos(r.angle), math.sin(r.angle)
	-- Facing along the spin, (-sin, cos), as a yaw: 0 facing -Z and positive
	-- turning left, like the parks' Heading.
	local fx, fz = -cz, cx
	local yaw = math.atan2(-fx, -fz)
	return {
		x = s.x + cx * radius,
		up = r.up,
		z = s.z + cz * radius,
		yaw = yaw,
		tumble = r.tumble,
	}
end

-- Wanders toward its goal at Speed, picking a new goal Edge inside its area
-- on reaching it.
local function wander(s: State, dt: number, rng: Rng, t: Tuning)
	local gx, gz = s.goalX or s.x, s.goalZ or s.z
	if s.goalX == nil or (gx - s.x) ^ 2 + (gz - s.z) ^ 2 <= t.GoalReach ^ 2 then
		local halfX = math.max(s.area.Width / 2 - t.Edge, 0)
		local halfZ = math.max(s.area.Depth / 2 - t.Edge, 0)
		gx = s.area.X + rng.range(-halfX, halfX)
		gz = s.area.Z + rng.range(-halfZ, halfZ)
		s.goalX, s.goalZ = gx, gz
	end
	local dx, dz = gx - s.x, gz - s.z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist <= 0 then
		return
	end
	local move = math.min(t.Speed * dt, dist)
	s.x += dx / dist * move
	s.z += dz / dist * move
end

-- Moves the tornado and its riders on by `dt` seconds. `jets` says which
-- riders' jets burn (by id). Returns the riders thrown out.
function Tornado.step(s: State, dt: number, rng: Rng, jets: { [any]: boolean }, t: Tuning): { Throw }
	s.phaseAge += dt
	if s.phase == "roam" or s.phase == "lift" then
		wander(s, dt, rng, t)
	end
	for id, left in s.thrown do
		s.thrown[id] = if left > dt then left - dt else nil
	end

	local thrown: { Throw } = {}
	for i = #s.riders, 1, -1 do
		local r = s.riders[i]
		r.up = math.min(r.up + t.Climb * dt, s.height)
		r.angle = (r.angle + t.Spin * dt) % TAU
		r.tumble = (r.tumble + t.Tumble * dt) % TAU
		if jets[r.id] then
			r.jetsFor += dt
		end
		local why: ("top" | "jets")? = nil
		if r.jetsFor >= t.EscapeJets then
			why = "jets"
		elseif r.up >= s.height then
			why = "top"
		end
		if why then
			local at = Tornado.riderAt(s, r, t)
			local cx, cz = math.cos(r.angle), math.sin(r.angle)
			local fx, fz = -cz + cx * t.FlingOut, cx + cz * t.FlingOut
			local flat = math.sqrt(fx * fx + fz * fz)
			table.insert(thrown, {
				id = r.id,
				why = why,
				x = at.x,
				up = at.up,
				z = at.z,
				vx = fx / flat * t.FlingSpeed,
				vy = t.FlingUp,
				vz = fz / flat * t.FlingSpeed,
			})
			s.thrown[r.id] = t.Recatch
			table.remove(s.riders, i)
		end
	end

	if s.phase == "touchdown" and s.phaseAge >= t.TouchTime then
		s.phase, s.phaseAge = "roam", 0
	elseif s.phase == "roam" and s.phaseAge >= s.life and #s.riders == 0 then
		s.phase, s.phaseAge = "lift", 0
	elseif s.phase == "lift" and s.phaseAge >= t.LiftTime then
		s.phase, s.phaseAge = "gone", 0
	end
	return thrown
end

return Tornado
