--!strict
-- SiloTraps (ModuleScript) -> ReplicatedStorage.SiloTraps
-- The booby traps down the silo's ramp (Tuning.Silo.Traps). Nothing is sent
-- while they move: every machine works out where each is from the server's
-- clock. Each client draws them (SiloTrapsLook), and CarController asks `push`
-- how one knocks its own car.
--
-- A popper is a slab that shoots out of the column across the ramp. Each
-- period it may fire or not, at a moment of its own, with a warning first. It
-- only knocks a car while shooting out; the rest of the time it is out, it is
-- solid, like a wall. A sweeper is a block that rests at one end of its run,
-- darts to the other, rests, and darts back. It only knocks a car while
-- darting; resting, it is solid too.
--
-- Coordinates are studs from the shaft's middle, Y = 0 on the floor's top.
-- `along` is radians down the ramp from its start, as in Silo.rampPoint. Pure,
-- see InputAxes.

local SiloTraps = {}

local TURN = 2 * math.pi
local MODULUS = 2147483647

export type Ramp = {
	Pitch: number,
	InnerRadius: number,
	OuterRadius: number,
	LipWidth: number,
}

export type Popper = {
	First: number, -- turns down the ramp
	Every: number,
	Last: number,
	Width: number, -- along the ramp
	Height: number,
	Reach: number, -- out from the column, fully out
	Period: number,
	Chance: number,
	Warn: number,
	Out: number,
	Hold: number,
	Back: number,
	PushOut: number,
	PushUp: number,
}

export type Sweeper = {
	First: number,
	Every: number,
	Last: number,
	Across: number,
	Height: number,
	Length: number, -- along the ramp
	Travel: number, -- studs along the ramp's flat from end to end
	Move: number,
	Hold: number,
	PushAlong: number,
	PushOut: number,
	PushUp: number,
}

export type Config = {
	Margin: number, -- how much room round a trap still counts as a hit
	HullHeight: number, -- a car's middle above the ramp
	Reach: number, -- how far above or below a trap's level still counts
	Poppers: Popper,
	Sweepers: Sweeper,
}

export type Trap = {
	kind: "popper" | "sweeper",
	id: number,
	along: number,
}

-- The middle of the ramp's flat, where a sweeper runs.
function SiloTraps.lane(ramp: Ramp): number
	return (ramp.InnerRadius + ramp.OuterRadius - ramp.LipWidth) / 2
end

function SiloTraps.layout(config: Config): { Trap }
	local traps: { Trap } = {}
	local function add(kind: "popper" | "sweeper", spec: { First: number, Every: number, Last: number })
		local turns = spec.First
		while turns <= spec.Last do
			table.insert(traps, { kind = kind, id = #traps + 1, along = turns * TURN })
			turns += spec.Every
		end
	end
	add("popper", config.Poppers)
	add("sweeper", config.Sweepers)
	return traps
end

-- A number from 0 up to 1 for this popper, period, and purpose, the same on
-- every machine.
local function roll(id: number, slot: number, purpose: number): number
	local state = (id * 7919 + slot * 104729 + purpose * 1299709) % (MODULUS - 1) + 1
	for _ = 1, 3 do
		state = state * 48271 % MODULUS
	end
	return (state - 1) / (MODULUS - 1)
end

-- When popper `id` starts its warning in period `slot`, in seconds from the
-- period's start, or nil if it stays in that period.
function SiloTraps.popperStart(p: Popper, id: number, slot: number): number?
	if roll(id, slot, 1) >= p.Chance then
		return nil
	end
	local spare = math.max(p.Period - p.Warn - p.Out - p.Hold - p.Back, 0)
	return roll(id, slot, 2) * spare
end

-- Seconds since popper `id` started its warning at `time`, or nil if it
-- hasn't in this period.
local function sinceStart(p: Popper, id: number, time: number): number?
	local slot = math.floor(time / p.Period)
	local start = SiloTraps.popperStart(p, id, slot)
	if not start then
		return nil
	end
	local since = time - slot * p.Period - start
	return if since >= 0 then since else nil
end

-- How far out popper `id` is at `time`, from 0 (in the column) to 1.
function SiloTraps.popperExtent(p: Popper, id: number, time: number): number
	local since = sinceStart(p, id, time)
	if not since or since < p.Warn then
		return 0
	end
	since -= p.Warn
	if since < p.Out then
		return since / p.Out
	end
	since -= p.Out
	if since < p.Hold then
		return 1
	end
	since -= p.Hold
	return if since < p.Back then 1 - since / p.Back else 0
end

-- Whether popper `id` is shooting out at `time`, the only time it knocks a car.
function SiloTraps.popperExtending(p: Popper, id: number, time: number): boolean
	local since = sinceStart(p, id, time)
	return since ~= nil and since >= p.Warn and since < p.Warn + p.Out
end

-- Whether popper `id` is warning at `time`, about to shoot out.
function SiloTraps.popperWarning(p: Popper, id: number, time: number): boolean
	local since = sinceStart(p, id, time)
	return since ~= nil and since < p.Warn
end

-- The sweeper's place in its cycle at `time`, from its own start: each takes
-- its turn a little after the last.
local function sweeperTime(s: Sweeper, id: number, time: number): number
	return (time + id * 0.37 * s.Hold) % (2 * (s.Hold + s.Move))
end

local function ease(u: number): number
	return u * u * (3 - 2 * u)
end

-- How far along the ramp's flat sweeper `id` is from the middle of its run.
function SiloTraps.sweeperOffset(s: Sweeper, id: number, time: number): number
	local t = sweeperTime(s, id, time)
	local out: number
	if t < s.Hold then
		out = 0
	elseif t < s.Hold + s.Move then
		out = ease((t - s.Hold) / s.Move)
	elseif t < 2 * s.Hold + s.Move then
		out = 1
	else
		out = 1 - ease((t - 2 * s.Hold - s.Move) / s.Move)
	end
	return s.Travel * (out - 0.5)
end

-- Which way sweeper `id` is darting along the ramp at `time`: 1 down it, -1
-- back up it, 0 resting.
function SiloTraps.sweeperMoving(s: Sweeper, id: number, time: number): number
	local t = sweeperTime(s, id, time)
	if t < s.Hold then
		return 0
	elseif t < s.Hold + s.Move then
		return 1
	elseif t < 2 * s.Hold + s.Move then
		return 0
	end
	return -1
end

-- The velocity a trap gives a car at (x, y, z) moving at (vx, vy, vz) at
-- `time`, or nil if none reaches it. A popper shooting out shoves it out and
-- up, and a darting sweeper does too, plus along the way it darts. Either one
-- at any other time does nothing here: it is a solid wall (SiloTrapsLook).
function SiloTraps.push(
	ramp: Ramp,
	config: Config,
	traps: { Trap },
	time: number,
	x: number,
	y: number,
	z: number,
	vx: number,
	_vy: number,
	vz: number
): (number?, number?, number?)
	local r = math.sqrt(x * x + z * z)
	if r < 1e-6 then
		return nil, nil, nil
	end
	local outX, outZ = x / r, z / r
	-- Down the ramp, at this point.
	local downX, downZ = z / r, -x / r
	local angle = math.atan2(-z, x)
	local lane = SiloTraps.lane(ramp)
	for _, trap in traps do
		local apart = (angle - trap.along + math.pi) % TURN - math.pi
		local rampY = -ramp.Pitch * (trap.along + apart) / TURN + config.HullHeight
		if math.abs(y - rampY) > config.Reach then
			continue
		end
		if trap.kind == "popper" then
			local P = config.Poppers
			local extent = SiloTraps.popperExtent(P, trap.id, time)
			if
				SiloTraps.popperExtending(P, trap.id, time)
				and math.abs(apart) * r <= P.Width / 2 + config.Margin
				and r <= ramp.InnerRadius + P.Reach * extent + config.Margin
			then
				return vx + outX * P.PushOut, P.PushUp, vz + outZ * P.PushOut
			end
		else
			local S = config.Sweepers
			local moving = SiloTraps.sweeperMoving(S, trap.id, time)
			local offset = SiloTraps.sweeperOffset(S, trap.id, time)
			if
				moving ~= 0
				and math.abs(apart * lane - offset) <= S.Length / 2 + config.Margin
				and math.abs(r - lane) <= S.Across / 2 + config.Margin
			then
				local along = moving * S.PushAlong
				return outX * S.PushOut + downX * along, S.PushUp, outZ * S.PushOut + downZ * along
			end
		end
	end
	return nil, nil, nil
end

return SiloTraps
