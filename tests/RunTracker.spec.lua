--!strict
local Check = require("./Check")
local RunTracker = require("../src/shared/RunTracker")

local TUNING: RunTracker.Tuning = {
	ArmTime = 1,
	StopSpeed = 4,
	StopTime = 1,
	CleanUpY = 0.7,
	TeleportDistance = 80,
}

local DT = 0.1

-- A grounded, upright, moving car at the origin unless overridden.
local function sample(fields: { [string]: any }?): RunTracker.Sample
	local s: { [string]: any } = {
		dt = DT,
		airborne = false,
		onPad = false,
		x = 0,
		y = 0,
		z = 0,
		turnX = 0,
		turnY = 0,
		turnZ = 0,
		speed = 100,
		upY = 1,
		lying = false,
		grinding = false,
	}
	for key, value in fields or {} do
		s[key] = value
	end
	return (s :: any) :: RunTracker.Sample
end

local function step(state: RunTracker.State, fields: { [string]: any }?): RunTracker.Result?
	return RunTracker.step(state, sample(fields), TUNING)
end

-- Pad at the origin, then lift off.
local function launched(): RunTracker.State
	local state = RunTracker.new()
	step(state, { onPad = true })
	step(state, { airborne = true })
	return state
end

Check.test("starts with no run", function()
	local state = RunTracker.new()
	Check.eq(state.phase, "idle")
end)

Check.test("leaving the ground without a launch pad is not a run", function()
	local state = RunTracker.new()
	Check.eq(step(state, { airborne = true }), nil)
	Check.eq(state.phase, "idle")
	Check.eq(step(state, { airborne = false }), nil, "landing")
end)

Check.test("a launch pad then lift off starts a run", function()
	local state = RunTracker.new()
	step(state, { onPad = true })
	Check.eq(state.phase, "armed")
	step(state, { airborne = true })
	Check.eq(state.phase, "flying")
end)

Check.test("driving off a pad without jumping disarms after the arm time", function()
	local state = RunTracker.new()
	step(state, { onPad = true })
	for _ = 1, 9 do
		step(state)
	end
	Check.eq(state.phase, "armed", "still inside the arm time")
	step(state, { dt = 0.2 })
	Check.eq(state.phase, "idle")
end)

Check.test("landing ends the run with airtime, distance, and height", function()
	local state = launched()
	step(state, { airborne = true, x = 30, y = 40, z = -40 })
	step(state, { airborne = true, x = 60, y = 20, z = -80 })
	local result = step(state, { x = 60, y = 0, z = -80 }) :: RunTracker.Result
	Check.eq(result.ending, "landed")
	Check.near(result.airtime, 0.3, "airtime")
	Check.near(result.distance, 100, "distance is flat, launch to landing")
	Check.near(result.height, 40, "peak height above the launch point")
	Check.eq(#result.tricks, 0)
	Check.eq(state.phase, "idle", "ready for the next run")
end)

Check.test("the launch point is the last pad contact", function()
	local state = RunTracker.new()
	step(state, { onPad = true, z = -5, y = 10 })
	step(state, { onPad = true, z = -10, y = 20 })
	step(state, { airborne = true, z = -20, y = 25 })
	local result = step(state, { z = -50, y = 0 }) :: RunTracker.Result
	Check.near(result.distance, 40)
	Check.near(result.height, 5)
end)

Check.test("a full rotation on each axis counts a trick with its direction", function()
	local state = launched()
	local quarter = math.pi / 2
	for _ = 1, 4 do
		step(state, { airborne = true, turnX = quarter })
	end
	for _ = 1, 4 do
		step(state, { airborne = true, turnY = -quarter })
	end
	for _ = 1, 4 do
		step(state, { airborne = true, turnZ = quarter })
	end
	local result = step(state) :: RunTracker.Result
	Check.eq(#result.tricks, 3)
	Check.eq(result.tricks[1].kind, "flip")
	Check.eq(result.tricks[1].direction, 1)
	Check.eq(result.tricks[2].kind, "spin")
	Check.eq(result.tricks[2].direction, -1)
	Check.eq(result.tricks[3].kind, "roll")
	Check.eq(result.tricks[3].direction, 1)
	Check.near(result.tricks[1].airtime, 0.5, "when the flip completed")
end)

Check.test("tricks show on the state while flying", function()
	local state = launched()
	step(state, { airborne = true, turnY = 2 * math.pi })
	Check.eq(#state.tricks, 1)
end)

Check.test("wobbling back and forth is not a rotation", function()
	local state = launched()
	for _ = 1, 10 do
		step(state, { airborne = true, turnX = 3 })
		step(state, { airborne = true, turnX = -3 })
	end
	local result = step(state) :: RunTracker.Result
	Check.eq(#result.tricks, 0)
end)

Check.test("two and a half rotations count two tricks", function()
	local state = launched()
	for _ = 1, 10 do
		step(state, { airborne = true, turnY = math.pi / 2 })
	end
	local result = step(state) :: RunTracker.Result
	Check.eq(#result.tricks, 2)
end)

Check.test("an upright landing is clean, a sideways one is not", function()
	local clean = step(launched(), { upY = 0.9 }) :: RunTracker.Result
	Check.eq(clean.clean, true)
	local messy = step(launched(), { upY = 0.5 }) :: RunTracker.Result
	Check.eq(messy.clean, false)
end)

Check.test("stopping off its wheels ends the run after the stop time", function()
	local state = launched()
	for _ = 1, 9 do
		Check.eq(step(state, { airborne = true, speed = 1, upY = -1 }), nil)
	end
	local result = step(state, { airborne = true, speed = 1, upY = -1, dt = 0.2 }) :: RunTracker.Result
	Check.eq(result.ending, "stopped")
	Check.eq(result.clean, false)
	Check.eq(state.phase, "idle")
end)

Check.test("moving again resets the stop timer", function()
	local state = launched()
	for _ = 1, 9 do
		step(state, { airborne = true, speed = 1 })
	end
	step(state, { airborne = true, speed = 50 })
	Check.eq(step(state, { airborne = true, speed = 1 }), nil)
end)

Check.test("abort ends a run where the car last was", function()
	local state = launched()
	step(state, { airborne = true, z = -70, y = 30 })
	local result = RunTracker.abort(state) :: RunTracker.Result
	Check.eq(result.ending, "aborted")
	Check.near(result.distance, 70)
	Check.near(result.height, 30)
	Check.eq(result.clean, false)
	Check.eq(state.phase, "idle")
end)

Check.test("abort can end the run as a wreck", function()
	local state = launched()
	step(state, { airborne = true, z = -70, y = 30 })
	local result = RunTracker.abort(state, "wrecked") :: RunTracker.Result
	Check.eq(result.ending, "wrecked")
	Check.near(result.distance, 70)
	Check.eq(result.clean, false)
	Check.eq(state.phase, "idle")
end)

Check.test("abort without a run returns nothing and disarms", function()
	local state = RunTracker.new()
	Check.eq(RunTracker.abort(state), nil)
	step(state, { onPad = true })
	Check.eq(RunTracker.abort(state), nil)
	Check.eq(state.phase, "idle")
end)

Check.test("snapshot reads a flying run without ending it", function()
	local state = launched()
	step(state, { airborne = true, z = -30, y = 12, turnY = 2 * math.pi })
	local snap = RunTracker.snapshot(state) :: RunTracker.Result
	Check.near(snap.distance, 30)
	Check.near(snap.height, 12)
	Check.near(snap.airtime, 0.2)
	Check.eq(#snap.tricks, 1)
	Check.eq(snap.ending, "landed", "scored as if it landed now")
	Check.eq(snap.clean, false)
	Check.eq(state.phase, "flying")
	step(state, { airborne = true, turnY = 2 * math.pi })
	Check.eq(#snap.tricks, 1, "a snapshot does not change as the run goes on")
end)

Check.test("snapshot is nil without a flying run", function()
	local state = RunTracker.new()
	Check.eq(RunTracker.snapshot(state), nil)
	step(state, { onPad = true })
	Check.eq(RunTracker.snapshot(state), nil)
end)

Check.test("touching down on the roof or side ends the run as a crash", function()
	local state = launched()
	step(state, { airborne = true, z = -50, y = 20 })
	local result = step(state, { airborne = true, lying = true, z = -60, upY = -1 }) :: RunTracker.Result
	Check.eq(result.ending, "crashed")
	Check.eq(result.clean, false)
	Check.near(result.distance, 60)
	Check.eq(state.phase, "idle", "righting onto the wheels afterward is not a landing")
end)

Check.test("jumping too far in one step ends the run as a reset where the car last was", function()
	local state = launched()
	step(state, { airborne = true, z = -70, y = 30 })
	local result = step(state, { x = 20, y = 2, z = 700 }) :: RunTracker.Result
	Check.eq(result.ending, "aborted", "a teleport back to spawn is not a landing")
	Check.near(result.distance, 70)
	Check.near(result.height, 30)
	Check.eq(result.clean, false)
	Check.eq(state.phase, "idle")
end)

Check.test("fast flight and lift off after rolling past the pad are not teleports", function()
	local state = RunTracker.new()
	step(state, { onPad = true, z = -500 })
	step(state, { z = -560 })
	step(state, { airborne = true, z = -620 })
	step(state, { airborne = true, z = -699 })
	Check.eq(state.phase, "flying")
end)

Check.test("a run without grinding has no grind time", function()
	local state = launched()
	local result = step(state, { airborne = false, z = -10 }) :: RunTracker.Result
	Check.eq(result.grind, 0)
end)

Check.test("getting on a rail starts a run without a launch pad", function()
	local state = RunTracker.new()
	Check.eq(step(state, { grinding = true, airborne = true, y = 5 }), nil)
	Check.eq(state.phase, "flying")
end)

Check.test("time on a rail counts as grind time, not airtime", function()
	local state = launched()
	step(state, { airborne = true, z = -10 })
	for i = 1, 3 do
		step(state, { grinding = true, airborne = true, z = -10 - i * 10 })
	end
	local snapshot = RunTracker.snapshot(state) :: RunTracker.Result
	Check.near(snapshot.airtime, 0.2, "airtime: lift off and one step")
	Check.near(snapshot.grind, 0.3, "grind")
end)

Check.test("wheels touching while on a rail do not end the run", function()
	local state = RunTracker.new()
	step(state, { grinding = true, airborne = false })
	Check.eq(step(state, { grinding = true, airborne = false, z = -10 }), nil)
	Check.eq(step(state, { grinding = true, airborne = false, z = -20, speed = 0 }), nil, "slow on the rail")
	Check.eq(state.phase, "flying")
end)

Check.test("landing after a grind ends the run with the grind time", function()
	local state = RunTracker.new()
	for i = 1, 4 do
		step(state, { grinding = true, airborne = true, z = -i * 10 })
	end
	step(state, { airborne = true, z = -50 })
	local result = step(state, { airborne = false, z = -60 }) :: RunTracker.Result
	Check.eq(result.ending, "landed")
	Check.near(result.grind, 0.4)
	Check.near(result.airtime, 0.1)
	Check.near(result.distance, 50, "from where the grind started")
end)

Check.finish("RunTracker")
