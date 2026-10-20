--!strict
-- RunTracker (ModuleScript) -> ReplicatedStorage.RunTracker
-- Follows one car through a run and measures it. Pure, see InputAxes. The
-- client runs it for the live HUD; the server runs it on the motion it sees,
-- and the server's result is the score that counts.
--
--   idle    no run
--   armed   touched a launch pad; lifting off within ArmTime starts a run
--   flying  in the air; ends on landing, on touching down on its roof or side
--           (crash), on stopping while still off its wheels, or on abort
--           (reset, or a wreck at zero toughness). Jumping farther than
--           TeleportDistance in one step also ends it as a reset, since the
--           car did not fly there.
--
-- Riding a rail (Grind) keeps a run going, or starts one without a launch
-- pad. Time on the rail counts as grind time instead of airtime, and wheels
-- touching or a slow car never end the run while it lasts.
--
-- A swing seat (Swing) is a launcher like a pad: riding it arms a run, and
-- leaving it into the air starts one. Coming down on a seat ends a run as a
-- landing, with the swing bonus unless it is the seat the run launched from.
--
-- Every full turn about one of the car's own axes is a trick: flip (x, pitch),
-- spin (y, yaw), or roll (z). Turning back the other way unwinds it, so
-- wobbling never adds up to a trick.
--
-- Unlike Contact, the state is changed in place, since a run keeps a list of
-- tricks.

local RunTracker = {}

local TAU = 2 * math.pi

export type TrickKind = "flip" | "spin" | "roll"

export type Trick = {
	kind: TrickKind,
	direction: number, -- 1 or -1, positive about the axis as in AirControl
	airtime: number, -- seconds into the flight when the turn completed
}

export type Ending = "landed" | "crashed" | "stopped" | "aborted" | "wrecked"

export type Result = {
	ending: Ending,
	airtime: number,
	grind: number, -- seconds on rails
	distance: number, -- flat studs from the launch point to where the run ended
	height: number, -- peak studs above the launch point
	tricks: { Trick },
	clean: boolean, -- landed upright
	swing: boolean, -- landed on a swing seat other than the one it launched from
	-- Where the run took off and ended, seen from above, for gaps (Gap).
	launchX: number,
	launchZ: number,
	endX: number,
	endZ: number,
	gaps: { string }?, -- the gaps it cleared, filled in by whoever scores it
}

-- One physics step. Position is the hull's; turn is how far the car rotated
-- this step in radians about its own axes; upY is its up vector's Y; lying is
-- Righting.lying, the car down on its roof or side.
export type Sample = {
	dt: number,
	airborne: boolean,
	onPad: boolean,
	x: number,
	y: number,
	z: number,
	turnX: number,
	turnY: number,
	turnZ: number,
	speed: number,
	upY: number,
	lying: boolean,
	grinding: boolean, -- on a rail (Grind.onRail)
	swing: string?, -- the swing whose seat it rides, if any
}

export type Tuning = {
	ArmTime: number,
	StopSpeed: number,
	StopTime: number,
	CleanUpY: number,
	TeleportDistance: number,
}

export type State = {
	phase: "idle" | "armed" | "flying",
	armTimer: number,
	launchX: number,
	launchY: number,
	launchZ: number,
	lastX: number,
	lastY: number,
	lastZ: number,
	peakY: number,
	airtime: number,
	grind: number,
	stoppedTime: number,
	turnedX: number,
	turnedY: number,
	turnedZ: number,
	tricks: { Trick },
	launchSwing: string?, -- the swing the run launched from, if any
}

function RunTracker.new(): State
	return {
		phase = "idle",
		armTimer = 0,
		launchX = 0,
		launchY = 0,
		launchZ = 0,
		lastX = 0,
		lastY = 0,
		lastZ = 0,
		peakY = 0,
		airtime = 0,
		grind = 0,
		stoppedTime = 0,
		turnedX = 0,
		turnedY = 0,
		turnedZ = 0,
		tricks = {},
		launchSwing = nil,
	}
end

local function reset(state: State)
	for key, value in RunTracker.new() :: any do
		(state :: any)[key] = value
	end
	state.launchSwing = nil
end

local function measure(state: State, ending: Ending, clean: boolean, swing: boolean): Result
	return {
		ending = ending,
		airtime = state.airtime,
		grind = state.grind,
		distance = math.sqrt((state.lastX - state.launchX) ^ 2 + (state.lastZ - state.launchZ) ^ 2),
		height = math.max(state.peakY - state.launchY, 0),
		tricks = table.clone(state.tricks),
		clean = clean,
		swing = swing,
		launchX = state.launchX,
		launchZ = state.launchZ,
		endX = state.lastX,
		endZ = state.lastZ,
	}
end

local function finish(state: State, ending: Ending, clean: boolean, swing: boolean?): Result
	local result = measure(state, ending, clean, swing == true)
	reset(state)
	return result
end

-- Adds this step's turn to an axis and returns the new total, logging a trick
-- each time the total passes a full turn.
local function turn(state: State, kind: TrickKind, total: number, delta: number): number
	total += delta
	while math.abs(total) >= TAU do
		local direction = if total > 0 then 1 else -1
		total -= direction * TAU
		table.insert(state.tricks, { kind = kind, direction = direction, airtime = state.airtime })
	end
	return total
end

local function moveTo(state: State, sample: Sample)
	state.lastX, state.lastY, state.lastZ = sample.x, sample.y, sample.z
end

local function fly(state: State, sample: Sample, tuning: Tuning): Result?
	local jump = math.sqrt((sample.x - state.lastX) ^ 2 + (sample.y - state.lastY) ^ 2 + (sample.z - state.lastZ) ^ 2)
	if jump > tuning.TeleportDistance then
		return finish(state, "aborted", false)
	end
	moveTo(state, sample)
	if sample.grinding then
		state.grind += sample.dt
		state.peakY = math.max(state.peakY, sample.y)
		state.stoppedTime = 0
		return nil
	end
	if sample.swing then
		return finish(state, "landed", sample.upY >= tuning.CleanUpY, sample.swing ~= state.launchSwing)
	end
	if not sample.airborne then
		return finish(state, "landed", sample.upY >= tuning.CleanUpY)
	end
	if sample.lying then
		return finish(state, "crashed", false)
	end

	state.airtime += sample.dt
	state.peakY = math.max(state.peakY, sample.y)
	state.turnedX = turn(state, "flip", state.turnedX, sample.turnX)
	state.turnedY = turn(state, "spin", state.turnedY, sample.turnY)
	state.turnedZ = turn(state, "roll", state.turnedZ, sample.turnZ)

	if sample.speed < tuning.StopSpeed then
		state.stoppedTime += sample.dt
		if state.stoppedTime >= tuning.StopTime then
			return finish(state, "stopped", false)
		end
	else
		state.stoppedTime = 0
	end
	return nil
end

-- Advances one step. Returns the result on the step a run ends, otherwise nil.
function RunTracker.step(state: State, sample: Sample, tuning: Tuning): Result?
	if state.phase == "flying" then
		return fly(state, sample, tuning)
	end

	if sample.grinding then
		state.phase = "flying"
		state.launchX, state.launchY, state.launchZ = sample.x, sample.y, sample.z
		moveTo(state, sample)
		state.peakY = sample.y
		return fly(state, sample, tuning)
	end

	if sample.onPad or sample.swing then
		state.phase = "armed"
		state.armTimer = tuning.ArmTime
		state.launchSwing = sample.swing
		state.launchX, state.launchY, state.launchZ = sample.x, sample.y, sample.z
		moveTo(state, sample)
		return nil
	end

	if state.phase == "armed" then
		if sample.airborne then
			state.phase = "flying"
			state.peakY = state.launchY
			return fly(state, sample, tuning)
		end
		moveTo(state, sample)
		state.armTimer -= sample.dt
		if state.armTimer <= 0 then
			reset(state)
		end
	end
	return nil
end

-- The flying run so far, as if it landed (not clean) where the car is now, for
-- a live score. Nil without a flying run.
function RunTracker.snapshot(state: State): Result?
	if state.phase ~= "flying" then
		return nil
	end
	return measure(state, "landed", false)
end

-- Ends any run in progress where the car last was, for resets, or with
-- `ending` "wrecked" for wrecks. Returns nil and disarms if no run was flying.
function RunTracker.abort(state: State, ending: Ending?): Result?
	if state.phase ~= "flying" then
		reset(state)
		return nil
	end
	return finish(state, ending or "aborted", false)
end

return RunTracker
