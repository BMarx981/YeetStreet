--!strict
-- Gravitron (ModuleScript) -> ReplicatedStorage.Gravitron
-- The Corkscrew park's gravitron: a huge bowl that spins, open at the top
-- so cars get flung out. A flat round floor curves up into a wall that
-- leans out to the rim, and the whole bowl is tilted. Pure, see InputAxes.
--
-- Points are in the bowl's own space: from the floor's middle, Y up its
-- axis, the floor's top at Y 0. A point's `r` is how far out from the axis
-- it is. The ride's ground space is the same turned back upright: from the
-- ground under the floor's middle, heights from the floor, and the bowl's
-- +Y tipped Tilt toward +Z, so the floor's -Z edge is its high side.
--
-- Nothing really turns: the bowl stays put, and each driver's client pushes
-- its car round as if the surface carried it (carry), at a Speed that runs
-- through a fixed cycle of Stops on the server's clock, so every machine
-- agrees without sending anything. The faster it spins, the less the tyres
-- grip.

local Gravitron = {}

-- A speed the bowl holds for Hold seconds, studs per second at the wall's
-- foot.
export type Stop = {
	Speed: number,
	Hold: number,
}

export type Spin = {
	-- 1 turns the way CFrame.Angles(0, angle, 0) does as angle grows,
	-- counterclockwise seen from above; -1 the other way.
	Direction: number,
	Stops: { Stop },
	Ramp: number, -- seconds to ease from each stop to the next, and the last to the first
	MinGrip: number, -- times the tyres' grip at the fastest stop
	Carry: number, -- per second: how quickly the surface brings a car to its speed
}

export type Shape = {
	FloorRadius: number,
	CurveRadius: number, -- from the floor up into the wall
	Lean: number, -- degrees the wall leans out from the axis, over 0
	Height: number, -- the rim, up the axis from the floor
	Tilt: number, -- degrees the axis tips from upright
	Thickness: number,
	Clearance: number, -- under the bowl's lowest point, above the ground
}

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

-- Seconds for the whole cycle.
function Gravitron.period(spin: Spin): number
	local total = 0
	for _, stop in spin.Stops do
		total += stop.Hold + spin.Ramp
	end
	return total
end

-- The surface's speed at the wall's foot at `time` on the server's clock.
function Gravitron.speed(spin: Spin, time: number): number
	local stops = spin.Stops
	local t = time % Gravitron.period(spin)
	for i, stop in stops do
		if t < stop.Hold then
			return stop.Speed
		end
		t -= stop.Hold
		if t < spin.Ramp then
			local nextStop = stops[i % #stops + 1]
			return stop.Speed + (nextStop.Speed - stop.Speed) * ease(t / spin.Ramp)
		end
		t -= spin.Ramp
	end
	return stops[1].Speed
end

-- How far the wall's foot has gone round since time 0.
function Gravitron.travel(spin: Spin, time: number): number
	local stops = spin.Stops
	local period = Gravitron.period(spin)
	local cycles = math.floor(time / period)
	local whole = 0
	for i, stop in stops do
		whole += stop.Speed * stop.Hold + (stop.Speed + stops[i % #stops + 1].Speed) / 2 * spin.Ramp
	end
	local done = cycles * whole
	local t = time - cycles * period
	for i, stop in stops do
		if t < stop.Hold then
			return done + stop.Speed * t
		end
		done += stop.Speed * stop.Hold
		t -= stop.Hold
		local nextStop = stops[i % #stops + 1]
		if t < spin.Ramp then
			local u = t / spin.Ramp
			-- The ease's integral, u^3 - u^4 / 2.
			return done + spin.Ramp * (stop.Speed * u + (nextStop.Speed - stop.Speed) * (u ^ 3 - u ^ 4 / 2))
		end
		done += (stop.Speed + nextStop.Speed) / 2 * spin.Ramp
		t -= spin.Ramp
	end
	return done
end

-- How far `speed` is from the slowest stop (0) to the fastest (1).
function Gravitron.level(spin: Spin, speed: number): number
	local slowest, fastest = math.huge, -math.huge
	for _, stop in spin.Stops do
		slowest, fastest = math.min(slowest, stop.Speed), math.max(fastest, stop.Speed)
	end
	if fastest <= slowest then
		return 0
	end
	return math.clamp((speed - slowest) / (fastest - slowest), 0, 1)
end

-- Times the tyres' grip at `speed`.
function Gravitron.grip(spin: Spin, speed: number): number
	return 1 - (1 - spin.MinGrip) * Gravitron.level(spin, speed)
end

-- Where the curve ends and the wall starts leaning out, as (r, y).
function Gravitron.foot(shape: Shape): (number, number)
	local a = math.rad(90 - shape.Lean)
	return shape.FloorRadius + shape.CurveRadius * math.sin(a), shape.CurveRadius * (1 - math.cos(a))
end

function Gravitron.rimRadius(shape: Shape): number
	local r, y = Gravitron.foot(shape)
	return r + (shape.Height - y) * math.tan(math.rad(shape.Lean))
end

-- The surface's height `r` out from the axis, or nil beyond the rim.
function Gravitron.surfaceHeight(shape: Shape, r: number): number?
	local F, C = shape.FloorRadius, shape.CurveRadius
	local footR, footY = Gravitron.foot(shape)
	if r <= F then
		return 0
	elseif r <= footR then
		return C - math.sqrt(math.max(C * C - (r - F) ^ 2, 0))
	elseif r <= Gravitron.rimRadius(shape) + 1e-9 then
		return footY + (r - footR) / math.tan(math.rad(shape.Lean))
	end
	return nil
end

-- Whether (r, y) is in the bowl: over the surface, no more than `margin`
-- under it, and no more than `margin` over the rim.
function Gravitron.inside(shape: Shape, r: number, y: number, margin: number): boolean
	local surface = Gravitron.surfaceHeight(shape, r)
	return surface ~= nil and y >= surface - margin and y <= shape.Height + margin
end

-- The way into the bowl, square to the nearest part of the surface to
-- (r, y), as (out, up): out is away from the axis.
function Gravitron.normal(shape: Shape, r: number, y: number): (number, number)
	local F, C = shape.FloorRadius, shape.CurveRadius
	local lean = math.rad(shape.Lean)
	local footR, footY = Gravitron.foot(shape)

	-- The floor.
	local best = math.sqrt((r - math.clamp(r, 0, F)) ^ 2 + y * y)
	local nr, ny = 0, 1

	-- The curve, round its middle (F, C) from straight below it.
	local dx, dy = r - F, y - C
	local fromMiddle = math.sqrt(dx * dx + dy * dy)
	if fromMiddle > 1e-9 then
		local a = math.atan2(dx, -dy)
		if a >= 0 and a <= math.rad(90) - lean and math.abs(fromMiddle - C) < best then
			best = math.abs(fromMiddle - C)
			nr, ny = -dx / fromMiddle, -dy / fromMiddle
		end
	end

	-- The wall, from its foot up to the rim.
	local ux, uy = math.sin(lean), math.cos(lean)
	local along = math.clamp((r - footR) * ux + (y - footY) * uy, 0, (shape.Height - footY) / uy)
	local wall = math.sqrt((r - footR - ux * along) ^ 2 + (y - footY - uy * along) ^ 2)
	if wall < best then
		nr, ny = -math.cos(lean), math.sin(lean)
	end
	return nr, ny
end

-- How high the floor's middle sits over the ground, so the bowl's lowest
-- point, Thickness under its surface, is Clearance over the ground.
function Gravitron.centerHeight(shape: Shape): number
	local tilt = math.rad(shape.Tilt)
	return shape.FloorRadius * math.sin(tilt)
		+ shape.CurveRadius * (1 - math.cos(tilt))
		+ shape.Thickness
		+ shape.Clearance
end

-- A point in the bowl's space, in the ground space.
function Gravitron.fromLocal(shape: Shape, x: number, y: number, z: number): (number, number, number)
	local tilt = math.rad(shape.Tilt)
	local c, s = math.cos(tilt), math.sin(tilt)
	return x, Gravitron.centerHeight(shape) + y * c - z * s, y * s + z * c
end

-- A point in the ground space, in the bowl's space.
function Gravitron.toLocal(shape: Shape, x: number, y: number, z: number): (number, number, number)
	local tilt = math.rad(shape.Tilt)
	local c, s = math.cos(tilt), math.sin(tilt)
	local up = y - Gravitron.centerHeight(shape)
	return x, up * c + z * s, -up * s + z * c
end

-- How fast the surface moves at (x, z) in the bowl's space, spinning at
-- `speed`, as (x, z).
function Gravitron.surfaceVelocity(spin: Spin, shape: Shape, speed: number, x: number, z: number): (number, number)
	local footR = Gravitron.foot(shape)
	local rate = spin.Direction * speed / footR
	return rate * z, -rate * x
end

-- How the surface pushes a car at (x, z) moving at (vx, vz) in the bowl's
-- space, as (x, z): round the axis, Carry times how much slower it goes
-- round than the surface. Moving in or out is left alone.
function Gravitron.carry(
	spin: Spin,
	shape: Shape,
	speed: number,
	x: number,
	z: number,
	vx: number,
	vz: number
): (number, number)
	local r = math.sqrt(x * x + z * z)
	if r < 1e-6 then
		return 0, 0
	end
	-- Round the way the surface goes.
	local tx, tz = spin.Direction * z / r, -spin.Direction * x / r
	local sx, sz = Gravitron.surfaceVelocity(spin, shape, speed, x, z)
	local behind = (sx - vx) * tx + (sz - vz) * tz
	return tx * behind * spin.Carry, tz * behind * spin.Carry
end

-- Whether the surface `around` radians round the axis (the way
-- CFrame.Angles(0, angle, 0) turns) is on one of `stripes` stripes, with the
-- bowl turned `turned` radians. Stripes and the gaps between them are as
-- wide as each other, and a stripe starts at 0 when it has not turned.
function Gravitron.striped(around: number, turned: number, stripes: number): boolean
	return ((around - turned) / math.pi * stripes) % 2 < 1
end

return Gravitron
