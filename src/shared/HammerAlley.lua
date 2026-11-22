--!strict
-- HammerAlley (ModuleScript) -> ReplicatedStorage.HammerAlley
-- The Scrapyard's Hammer Alley (Tuning.Scrapyard.Alley): a walled lane of
-- giant hammers, run from the server's clock so every machine agrees where
-- they are. Places are in the lane's own studs: x across it (0 down the
-- middle), y up from the floor, a along it from the start. Each hammer turns
-- about a pivot on a line along the lane, at an angle from straight down.
--
-- A "Swing" hammer hangs from a beam over the middle of the lane and swings
-- from side to side, batting a car toward the wall and up. A "Slam" hammer
-- stands straight up on a pivot just outside one wall (Side -1 left, 1
-- right), slams down flat across the lane, holds, and slowly rises again;
-- while it slams and holds it knocks a car back toward the start and bounces
-- it. Phase (0 to 1) shifts a hammer's timing by that share of its period.
--
-- A car is hit when its hull's middle comes within the head's half size plus
-- Reach of the line from the pivot out to the end of the head, and within
-- the head's half length plus Reach of it along the lane. Pure, see
-- InputAxes.

local HammerAlley = {}

export type Swing = {
	Height: number, -- the pivot above the floor
	Length: number, -- from the pivot to the head's middle
	Amplitude: number, -- degrees each way
	Period: number,
	HeadSize: number, -- across and up
	HeadLength: number, -- along the lane
	SideKick: number,
	Lift: number,
}

export type Slam = {
	Height: number,
	Length: number,
	PivotOut: number, -- the pivot past the lane's edge
	Period: number,
	Slam: number, -- seconds to come down
	Hold: number,
	Rise: number,
	HeadSize: number,
	HeadLength: number,
	Up: number,
	Back: number,
}

export type Config = {
	Width: number,
	Reach: number,
	Swing: Swing,
	Slam: Slam,
}

export type Hammer = {
	Kind: "Swing" | "Slam",
	At: number,
	Side: number,
	Phase: number,
}

local function cycle(period: number, phase: number, time: number): number
	return ((time / period + phase) % 1) * period
end

-- The swing's angle and which way it is moving (1 or -1).
local function swingAngle(s: Swing, h: Hammer, time: number): (number, number)
	local turn = 2 * math.pi * (time / s.Period + h.Phase)
	local moving = if math.cos(turn) >= 0 then h.Side else -h.Side
	return h.Side * math.rad(s.Amplitude) * math.sin(turn), moving
end

-- The slam's angle from straight down, in degrees before its side is
-- applied: 180 up, 90 flat across the lane.
local function slamDegrees(s: Slam, h: Hammer, time: number): number
	local t = cycle(s.Period, h.Phase, time)
	if t < s.Slam then
		local u = t / s.Slam
		return 180 - 90 * u * u
	end
	t -= s.Slam
	if t < s.Hold then
		return 90
	end
	t -= s.Hold
	if t < s.Rise then
		local u = t / s.Rise
		return 90 + 90 * u * u * (3 - 2 * u)
	end
	return 180
end

-- The hammer's pivot, its angle from straight down, its arm and head sizes.
local function pose(c: Config, h: Hammer, time: number): (number, number, number, number, number, number)
	if h.Kind == "Swing" then
		local s = c.Swing
		local angle = swingAngle(s, h, time)
		return 0, s.Height, angle, s.Length, s.HeadSize, s.HeadLength
	end
	local s = c.Slam
	local px = h.Side * (c.Width / 2 + s.PivotOut)
	return px, s.Height, -h.Side * math.rad(slamDegrees(s, h, time)), s.Length, s.HeadSize, s.HeadLength
end

-- The middle of the hammer's head at `time`, across and up.
function HammerAlley.head(c: Config, h: Hammer, time: number): (number, number)
	local px, py, angle, length = pose(c, h, time)
	return px + length * math.sin(angle), py - length * math.cos(angle)
end

-- Whether the hammer reaches a car's hull at (x, y, a) at `time`, `slack`
-- studs further out.
function HammerAlley.touching(
	c: Config,
	h: Hammer,
	time: number,
	x: number,
	y: number,
	a: number,
	slack: number
): boolean
	local px, py, angle, length, size, headLength = pose(c, h, time)
	if math.abs(a - h.At) > headLength / 2 + c.Reach + slack then
		return false
	end
	local dx, dy = math.sin(angle), -math.cos(angle)
	local along = math.clamp((x - px) * dx + (y - py) * dy, 0, length + size / 2)
	local cx, cy = px + dx * along, py + dy * along
	local reach = size / 2 + c.Reach + slack
	return (x - cx) ^ 2 + (y - cy) ^ 2 <= reach * reach
end

-- Whether the hammer can knock a car at `time`: a swing always, a slam only
-- while it comes down and holds.
local function active(c: Config, h: Hammer, time: number): boolean
	if h.Kind == "Swing" then
		return true
	end
	local s = c.Slam
	return cycle(s.Period, h.Phase, time) < s.Slam + s.Hold
end

-- The velocity, across, up and along, the first hammer to reach a car at
-- (x, y, a) moving at (vx, vy, va) gives it at `time`, or nil.
function HammerAlley.push(
	c: Config,
	hammers: { Hammer },
	time: number,
	x: number,
	y: number,
	a: number,
	vx: number,
	_vy: number,
	va: number
): (number?, number?, number?)
	for _, h in hammers do
		if active(c, h, time) and HammerAlley.touching(c, h, time, x, y, a, 0) then
			if h.Kind == "Swing" then
				local _, moving = swingAngle(c.Swing, h, time)
				return moving * c.Swing.SideKick, c.Swing.Lift, va
			end
			return vx, c.Slam.Up, -c.Slam.Back
		end
	end
	return nil, nil, nil
end

local SAMPLE = 0.02 -- seconds between the times smacked tries

-- Whether any hammer could have knocked a car at (x, y, a) at any time from
-- `from` to `to`, `slack` studs further out.
function HammerAlley.smacked(
	c: Config,
	hammers: { Hammer },
	from: number,
	to: number,
	x: number,
	y: number,
	a: number,
	slack: number
): boolean
	for _, h in hammers do
		local time = from
		while time <= to + 1e-9 do
			if active(c, h, time) and HammerAlley.touching(c, h, time, x, y, a, slack) then
				return true
			end
			time += SAMPLE
		end
	end
	return false
end

return HammerAlley
