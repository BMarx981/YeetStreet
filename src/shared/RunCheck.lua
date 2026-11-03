--!strict
-- RunCheck (ModuleScript) -> ReplicatedStorage.RunCheck
-- Checks that a run the server saw could have been flown. Pure, see
-- InputAxes. The driver's game moves its own car, so a cheat can move it any
-- way it likes; the server feeds this every update it sees of the car during
-- a run, and the car's own jet stats, and it says whether the motion fits.
-- Limits are in Tuning.RunCheck, picked from real flights (FlightProbe).
--
--   Fuel   Over each Window, the change in velocity that gravity does not
--          explain is push, and jets give at most JetPower of it a second.
--          The push of the whole run, in seconds of jets, must fit the tank:
--          JetFuel times FuelMargin, plus FuelSlack. Endless fuel or a car
--          held up in the air runs over. A car with weaker jets than
--          MinJetPower (the Frog Car has none) is measured as if it had
--          that much, for the scrapes and bounces every flight has.
--   Boost  A Window with a hit in it (one update whose velocity changed by
--          HitChange more than gravity and full jets explain) pushed the car
--          off something. Hitting things never adds energy, so it may end at
--          most BoostSlack (per unit mass) above the most energy the car had
--          in the Window before it or at its start. A velocity that drops
--          for an update or two and comes back, as after a hitch, gains
--          nothing.
--   Drift  Over each DriftWindow, the car must be where its reported
--          velocity takes it, give or take DriftBase plus DriftGapScale times
--          its top speed times the longest gap between updates there, since
--          updates arrive unevenly. A car moved without the velocity showing
--          it drifts; one whose velocity is faked to match is caught by Fuel
--          or Boost instead.
--
-- Turning is not checked: real tumbles spin far faster than air control.
--
-- The server marks an update excused while it knows the game itself threw
-- the car (a launch pad under it, the kaiju's zap, a tower burst, and so on);
-- any Window or DriftWindow holding an excused update is skipped. The first
-- check to fail is the reason; the run goes on being measured.

local RunCheck = {}

export type Reason = "Fuel" | "Boost" | "Drift"

-- One update of the car's hull, t in seconds.
export type Sample = {
	t: number,
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	excused: boolean?,
}

-- The car's own jets (Economy.CarStats).
export type Stats = {
	JetPower: number,
	JetFuel: number,
}

export type Tuning = {
	Gravity: number,
	Window: number,
	HitChange: number,
	FuelMargin: number,
	FuelSlack: number,
	MinJetPower: number,
	BoostSlack: number,
	DriftWindow: number,
	DriftBase: number,
	DriftGapScale: number,
}

export type Report = {
	reason: Reason?,
	fuel: number, -- seconds of jets the run's push took
	fuelLimit: number,
	boost: number, -- most energy a Window with a hit gained, per unit mass
	drift: number, -- worst drift as a share of its limit; over 1 fails
}

export type State = {
	last: Sample?,
	-- The Window so far.
	windowStart: Sample?,
	windowHit: boolean,
	windowExcused: boolean,
	windowPeak: number, -- the most energy at an update in it so far
	lastPeak: number, -- the most energy at an update in the Window before
	-- The DriftWindow so far: where the reported velocity says the car went.
	driftStart: Sample?,
	driftX: number,
	driftY: number,
	driftZ: number,
	driftGap: number,
	driftSpeed: number,
	driftExcused: boolean,
	reason: Reason?,
	fuel: number,
	boost: number,
	drift: number,
}

function RunCheck.new(): State
	return {
		last = nil,
		windowStart = nil,
		windowHit = false,
		windowExcused = false,
		windowPeak = -math.huge,
		lastPeak = -math.huge,
		driftStart = nil,
		driftX = 0,
		driftY = 0,
		driftZ = 0,
		driftGap = 0,
		driftSpeed = 0,
		driftExcused = false,
		reason = nil,
		fuel = 0,
		boost = 0,
		drift = 0,
	}
end

local function length(x: number, y: number, z: number): number
	return math.sqrt(x * x + y * y + z * z)
end

local function speed(s: Sample): number
	return length(s.vx, s.vy, s.vz)
end

-- Per unit mass.
local function energy(s: Sample, tuning: Tuning): number
	return 0.5 * speed(s) ^ 2 + tuning.Gravity * s.y
end

local function fuelLimit(stats: Stats, tuning: Tuning): number
	return stats.JetFuel * tuning.FuelMargin + tuning.FuelSlack
end

local function fail(state: State, reason: Reason)
	state.reason = state.reason or reason
end

local function openWindow(state: State, sample: Sample, tuning: Tuning)
	state.windowStart = sample
	state.windowPeak = energy(sample, tuning)
	state.windowHit = false
	state.windowExcused = sample.excused == true
end

local function openDrift(state: State, sample: Sample)
	state.driftStart = sample
	state.driftX, state.driftY, state.driftZ = 0, 0, 0
	state.driftGap = 0
	state.driftSpeed = speed(sample)
	state.driftExcused = sample.excused == true
end

-- Measures the Window from its start to `b`.
local function closeWindow(state: State, b: Sample, stats: Stats, tuning: Tuning)
	local a = state.windowStart
	if not a or b.t <= a.t or state.windowExcused then
		return
	end
	local dt = b.t - a.t
	if state.windowHit then
		local gain = energy(b, tuning) - math.max(energy(a, tuning), state.lastPeak)
		state.boost = math.max(state.boost, gain)
		if gain > tuning.BoostSlack then
			fail(state, "Boost")
		end
		return
	end
	local push = length(b.vx - a.vx, b.vy - a.vy + tuning.Gravity * dt, b.vz - a.vz)
	state.fuel += push / math.max(stats.JetPower, tuning.MinJetPower)
	if state.fuel > fuelLimit(stats, tuning) then
		fail(state, "Fuel")
	end
end

-- Measures the DriftWindow from its start to `b`.
local function closeDrift(state: State, b: Sample, tuning: Tuning)
	local a = state.driftStart
	if not a or b.t <= a.t or state.driftExcused then
		return
	end
	local off = length(b.x - a.x - state.driftX, b.y - a.y - state.driftY, b.z - a.z - state.driftZ)
	local limit = tuning.DriftBase + tuning.DriftGapScale * state.driftSpeed * state.driftGap
	state.drift = math.max(state.drift, off / limit)
	if off > limit then
		fail(state, "Drift")
	end
end

-- Adds one update the server saw while the run flies. Updates no later than
-- the last one are skipped.
function RunCheck.step(state: State, sample: Sample, stats: Stats, tuning: Tuning)
	local last = state.last
	if last and sample.t <= last.t then
		return
	end
	state.last = sample
	if not last then
		openWindow(state, sample, tuning)
		openDrift(state, sample)
		return
	end
	local dt = sample.t - last.t
	local excused = sample.excused == true

	local change = length(sample.vx - last.vx, sample.vy - last.vy + tuning.Gravity * dt, sample.vz - last.vz)
	state.windowHit = state.windowHit or change >= tuning.HitChange + math.max(stats.JetPower, tuning.MinJetPower) * dt
	state.windowExcused = state.windowExcused or excused
	local windowStart = state.windowStart
	if windowStart and sample.t - windowStart.t >= tuning.Window then
		closeWindow(state, sample, stats, tuning)
		state.lastPeak = math.max(state.windowPeak, energy(sample, tuning))
		openWindow(state, sample, tuning)
	else
		state.windowPeak = math.max(state.windowPeak, energy(sample, tuning))
	end

	state.driftX += (last.vx + sample.vx) / 2 * dt
	state.driftY += (last.vy + sample.vy) / 2 * dt
	state.driftZ += (last.vz + sample.vz) / 2 * dt
	state.driftGap = math.max(state.driftGap, dt)
	state.driftSpeed = math.max(state.driftSpeed, speed(sample))
	state.driftExcused = state.driftExcused or excused
	local driftStart = state.driftStart
	if driftStart and sample.t - driftStart.t >= tuning.DriftWindow then
		closeDrift(state, sample, tuning)
		openDrift(state, sample)
	end
end

-- Measures what is left of the last windows and says how the run did.
function RunCheck.finish(state: State, stats: Stats, tuning: Tuning): Report
	local last = state.last
	if last then
		closeWindow(state, last, stats, tuning)
		closeDrift(state, last, tuning)
	end
	return {
		reason = state.reason,
		fuel = state.fuel,
		fuelLimit = fuelLimit(stats, tuning),
		boost = state.boost,
		drift = state.drift,
	}
end

return RunCheck
