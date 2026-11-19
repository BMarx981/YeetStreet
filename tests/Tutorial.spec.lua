--!strict
local Check = require("./Check")
local Tutorial = require("../src/shared/Tutorial")

local function text(word: string): Tutorial.Text
	return { Keyboard = `{word} key`, Gamepad = `{word} pad`, Touch = `{word} touch` }
end

local T: Tutorial.Tuning = {
	DriveSpeed = 20,
	JetHold = 0.5,
	TiltInput = 0.5,
	TiltHold = 0.5,
	FinishTime = 4,
	Text = {
		Drive = text("Drive"),
		Ramp = text("Ramp"),
		Again = text("Again"),
		Jets = text("Jets"),
		Tilt = text("Tilt"),
		Land = text("Land"),
		Finish = text("Finish"),
	},
}

local function frame(overrides: { [string]: any }?): Tutorial.Frame
	local f: Tutorial.Frame = {
		dt = 0.1,
		speed = 0,
		inRun = false,
		throttle = 0,
		steer = 0,
		pitch = 0,
		roll = 0,
		burning = false,
	}
	for k, v in overrides or {} do
		(f :: any)[k] = v
	end
	return f
end

-- Steps `state` with `f` until `seconds` have passed.
local function hold(state: Tutorial.State, f: Tutorial.Frame, seconds: number)
	for _ = 1, math.round(seconds / f.dt) do
		Tutorial.step(state, f, T)
	end
end

local function atJets(): Tutorial.State
	local state = Tutorial.new()
	Tutorial.step(state, frame({ speed = 30, throttle = 1 }), T)
	Tutorial.step(state, frame({ inRun = true }), T)
	return state
end

Check.test("starts on Drive", function()
	Check.eq(Tutorial.prompt(Tutorial.new()), "Drive")
end)

Check.test("gas below DriveSpeed stays on Drive", function()
	local state = Tutorial.new()
	Tutorial.step(state, frame({ speed = 10, throttle = 1 }), T)
	Check.eq(Tutorial.prompt(state), "Drive")
end)

Check.test("rolling at speed without gas stays on Drive", function()
	local state = Tutorial.new()
	Tutorial.step(state, frame({ speed = 30 }), T)
	Check.eq(Tutorial.prompt(state), "Drive")
end)

Check.test("gas at DriveSpeed moves on to Ramp", function()
	local state = Tutorial.new()
	Tutorial.step(state, frame({ speed = 20, throttle = 1 }), T)
	Check.eq(Tutorial.prompt(state), "Ramp")
end)

Check.test("reverse gas does not count as driving", function()
	local state = Tutorial.new()
	Tutorial.step(state, frame({ speed = 30, throttle = -1 }), T)
	Check.eq(Tutorial.prompt(state), "Drive")
end)

Check.test("a run starting moves Ramp on to Jets", function()
	Check.eq(Tutorial.prompt(atJets()), "Jets")
end)

Check.test("a run starting on Drive skips straight to Jets", function()
	local state = Tutorial.new()
	Tutorial.step(state, frame({ inRun = true }), T)
	Check.eq(Tutorial.prompt(state), "Jets")
end)

Check.test("jets held for JetHold in a run move on to Tilt", function()
	local state = atJets()
	hold(state, frame({ inRun = true, burning = true }), 0.4)
	Check.eq(Tutorial.prompt(state), "Jets", "before JetHold")
	hold(state, frame({ inRun = true, burning = true }), 0.1)
	Check.eq(Tutorial.prompt(state), "Tilt", "at JetHold")
end)

Check.test("jet time adds up across short bursts", function()
	local state = atJets()
	hold(state, frame({ inRun = true, burning = true }), 0.3)
	hold(state, frame({ inRun = true }), 0.5)
	hold(state, frame({ inRun = true, burning = true }), 0.2)
	Check.eq(Tutorial.prompt(state), "Tilt")
end)

Check.test("jets on the ground don't count", function()
	local state = atJets()
	hold(state, frame({ burning = true }), 2)
	Check.eq(Tutorial.prompt(state), "Again")
end)

Check.test("a run ending before Jets is done asks for another launch", function()
	local state = atJets()
	Tutorial.runEnded(state, T)
	Check.eq(Tutorial.prompt(state), "Again", "on the ground")
	Tutorial.step(state, frame({ inRun = true }), T)
	Check.eq(Tutorial.prompt(state), "Jets", "back in the air")
end)

local function atTilt(): Tutorial.State
	local state = atJets()
	hold(state, frame({ inRun = true, burning = true }), 0.5)
	return state
end

Check.test("steering, gas, brake, pitch, or roll in a run count as tilt", function()
	for _, key in { "steer", "throttle", "pitch", "roll" } do
		for _, value in { 1, -1 } do
			local state = atTilt()
			hold(state, frame({ inRun = true, [key] = value }), 0.5)
			Check.eq(Tutorial.prompt(state), "Land", `{key} {value}`)
		end
	end
end)

Check.test("light stick input below TiltInput does not count", function()
	local state = atTilt()
	hold(state, frame({ inRun = true, steer = 0.3, pitch = -0.2 }), 2)
	Check.eq(Tutorial.prompt(state), "Tilt")
end)

Check.test("tilt time starts fresh after Jets", function()
	local state = atJets()
	hold(state, frame({ inRun = true, burning = true }), 1)
	Check.eq(Tutorial.prompt(state), "Tilt", "jets done")
	hold(state, frame({ inRun = true, steer = 1 }), 0.4)
	Check.eq(Tutorial.prompt(state), "Tilt", "jet time didn't carry over")
end)

Check.test("a run ending before Tilt is done asks for another launch", function()
	local state = atTilt()
	Tutorial.runEnded(state, T)
	Check.eq(Tutorial.prompt(state), "Again")
end)

local function atLand(): Tutorial.State
	local state = atTilt()
	hold(state, frame({ inRun = true, steer = 1 }), 0.5)
	return state
end

Check.test("Land waits for the run to end, then shows Finish", function()
	local state = atLand()
	hold(state, frame({ inRun = true }), 3)
	Check.eq(Tutorial.prompt(state), "Land", "still flying")
	Tutorial.runEnded(state, T)
	Check.eq(Tutorial.prompt(state), "Finish")
	Check.eq(state.done, false, "not done yet")
end)

Check.test("Finish shows for FinishTime, then the tutorial is done", function()
	local state = atLand()
	Tutorial.runEnded(state, T)
	hold(state, frame(), 3.9)
	Check.eq(state.done, false, "before FinishTime")
	Check.eq(Tutorial.prompt(state), "Finish")
	hold(state, frame(), 0.1)
	Check.eq(state.done, true, "at FinishTime")
	Check.eq(Tutorial.prompt(state), nil, "no prompt once done")
end)

Check.test("a run ending on Drive or Ramp changes nothing", function()
	local state = Tutorial.new()
	Tutorial.runEnded(state, T)
	Check.eq(Tutorial.prompt(state), "Drive")
	Tutorial.step(state, frame({ speed = 30, throttle = 1 }), T)
	Tutorial.runEnded(state, T)
	Check.eq(Tutorial.prompt(state), "Ramp")
end)

Check.test("the arrow shows on Ramp and Again only", function()
	local state = Tutorial.new()
	Check.eq(Tutorial.showArrow(state), false, "Drive")
	Tutorial.step(state, frame({ speed = 30, throttle = 1 }), T)
	Check.eq(Tutorial.showArrow(state), true, "Ramp")
	Tutorial.step(state, frame({ inRun = true }), T)
	Check.eq(Tutorial.showArrow(state), false, "Jets")
	Tutorial.runEnded(state, T)
	Check.eq(Tutorial.showArrow(state), true, "Again")
end)

Check.test("text picks the line for the device", function()
	Check.eq(Tutorial.text("Jets", "Keyboard", T), "Jets key")
	Check.eq(Tutorial.text("Jets", "Gamepad", T), "Jets pad")
	Check.eq(Tutorial.text("Jets", "Touch", T), "Jets touch")
end)

Check.test("device follows the last input type's name", function()
	Check.eq(Tutorial.device("Touch"), "Touch")
	Check.eq(Tutorial.device("Gamepad1"), "Gamepad")
	Check.eq(Tutorial.device("Gamepad4"), "Gamepad")
	Check.eq(Tutorial.device("Keyboard"), "Keyboard")
	Check.eq(Tutorial.device("MouseButton1"), "Keyboard")
	Check.eq(Tutorial.device("MouseMovement"), "Keyboard")
end)

Check.test("a saved done flag stays done", function()
	Check.eq(Tutorial.reconcile(true, 0), true)
end)

Check.test("a saved false flag stays false, even with a best run", function()
	Check.eq(Tutorial.reconcile(false, 500), false)
end)

Check.test("an old record with a best run counts as done", function()
	Check.eq(Tutorial.reconcile(nil, 500), true)
end)

Check.test("an old record with no best run, or a new player, is not done", function()
	Check.eq(Tutorial.reconcile(nil, 0), false)
	Check.eq(Tutorial.reconcile(nil, nil), false)
	Check.eq(Tutorial.reconcile(nil, "junk"), false)
	Check.eq(Tutorial.reconcile("yes", 500), false)
end)

Check.finish("Tutorial")
