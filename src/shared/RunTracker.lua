--!strict
-- RunTracker (ModuleScript) -> ReplicatedStorage.RunTracker
-- Follows one car through a run and measures it. Pure, see InputAxes. The
-- client runs it for the live HUD; the server runs it on the motion it sees,
-- and the server's result is the score that counts.
--
--   idle    no run
--   armed   touched a launch pad; lifting off within ArmTime starts a run
--   flying  in the air; ends on landing, on stopping while still off its
--           wheels (on its roof), or on abort (reset)
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

export type Ending = "landed" | "stopped" | "aborted"

export type Result = {
	ending: Ending,
	airtime: number,
	distance: number, -- flat studs from the launch point to where the run ended
	height: number, -- peak studs above the launch point
	tricks: { Trick },
	clean: boolean, -- landed upright
}

-- One physics step. Position is the hull's; turn is how far the car rotated
-- this step in radians about its own axes; upY is its up vector's Y.
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
}

export type Tuning = {
	ArmTime: number,
	StopSpeed: number,
	StopTime: number,
	CleanUpY: number,
}

export type State = {
	phase: "idle" | "armed" | "flying",
	armTimer: number,
	launchX: number,
	launchY: number,
	launchZ: number,
	lastX: number,
	lastZ: number,
	peakY: number,
	airtime: number,
	stoppedTime: number,
	turnedX: number,
	turnedY: number,
	turnedZ: number,
	tricks: { Trick },
}

function RunTracker.new(): State
	return {
		phase = "idle",
		armTimer = 0,
		launchX = 0,
		launchY = 0,
		launchZ = 0,
		lastX = 0,
		lastZ = 0,
		peakY = 0,
		airtime = 0,
		stoppedTime = 0,
		turnedX = 0,
		turnedY = 0,
		turnedZ = 0,
		tricks = {},
	}
end

local function reset(state: State)
	for key, value in RunTracker.new() :: any do
		(state :: any)[key] = value
	end
end

local function finish(state: State, ending: Ending, clean: boolean): Result
	local result: Result = {
		ending = ending,
		airtime = state.airtime,
		distance = math.sqrt((state.lastX - state.launchX) ^ 2 + (state.lastZ - state.launchZ) ^ 2),
		height = math.max(state.peakY - state.launchY, 0),
		tricks = state.tricks,
		clean = clean,
	}
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

local function fly(state: State, sample: Sample, tuning: Tuning): Result?
	state.lastX, state.lastZ = sample.x, sample.z
	if not sample.airborne then
		return finish(state, "landed", sample.upY >= tuning.CleanUpY)
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

	if sample.onPad then
		state.phase = "armed"
		state.armTimer = tuning.ArmTime
		state.launchX, state.launchY, state.launchZ = sample.x, sample.y, sample.z
		return nil
	end

	if state.phase == "armed" then
		if sample.airborne then
			state.phase = "flying"
			state.peakY = state.launchY
			return fly(state, sample, tuning)
		end
		state.armTimer -= sample.dt
		if state.armTimer <= 0 then
			reset(state)
		end
	end
	return nil
end

-- Ends any run in progress where the car last was, for resets. Returns nil and
-- disarms if no run was flying.
function RunTracker.abort(state: State): Result?
	if state.phase ~= "flying" then
		reset(state)
		return nil
	end
	return finish(state, "aborted", false)
end

return RunTracker
