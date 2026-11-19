--!strict
-- Tutorial (ModuleScript) -> ReplicatedStorage.Tutorial
-- The first-session tutorial's steps, one prompt at a time: Drive (hold gas
-- up to DriveSpeed), Ramp (until a run starts), Jets (JetHold seconds of jets
-- in a run), Tilt (TiltHold seconds of steering, gas, brake, pitch, or roll of
-- at least TiltInput in a run), Land (until the run ends), then Finish for
-- FinishTime seconds. A run that ends during Jets or Tilt keeps the step and
-- asks for another launch (Again). The client feeds it a Frame each step and
-- calls runEnded when a run ends; prompt names the line to show, and text
-- picks it for the player's device. reconcile reads the saved TutorialDone
-- flag. Pure.

local Tutorial = {}

export type Device = "Keyboard" | "Gamepad" | "Touch"
export type Prompt = "Drive" | "Ramp" | "Again" | "Jets" | "Tilt" | "Land" | "Finish"
export type Text = { Keyboard: string, Gamepad: string, Touch: string }

export type Tuning = {
	DriveSpeed: number, -- studs per second
	JetHold: number, -- seconds
	TiltInput: number, -- 0..1
	TiltHold: number, -- seconds
	FinishTime: number, -- seconds
	Text: { [string]: Text },
}

export type Frame = {
	dt: number,
	speed: number,
	inRun: boolean,
	throttle: number,
	steer: number,
	pitch: number,
	roll: number,
	burning: boolean,
}

type Step = "Drive" | "Ramp" | "Jets" | "Tilt" | "Land" | "Finish"

export type State = {
	step: Step,
	inRun: boolean,
	held: number, -- seconds toward the current step's hold, or left on Finish
	done: boolean,
}

function Tutorial.new(): State
	return { step = "Drive", inRun = false, held = 0, done = false }
end

local function tilting(frame: Frame, tuning: Tuning): boolean
	local most = math.max(math.abs(frame.steer), math.abs(frame.throttle), math.abs(frame.pitch), math.abs(frame.roll))
	return most >= tuning.TiltInput
end

-- Moves the tutorial on by one frame.
function Tutorial.step(state: State, frame: Frame, tuning: Tuning)
	if state.done then
		return
	end
	state.inRun = frame.inRun
	local step = state.step
	if step == "Drive" or step == "Ramp" then
		if frame.inRun then
			state.step = "Jets"
			state.held = 0
		elseif step == "Drive" and frame.throttle > 0 and frame.speed >= tuning.DriveSpeed then
			state.step = "Ramp"
		end
	elseif step == "Jets" then
		if frame.inRun and frame.burning then
			state.held += frame.dt
		end
		-- A little slack so frame-sized steps that add up to the hold count.
		if state.held >= tuning.JetHold - 1e-6 then
			state.step = "Tilt"
			state.held = 0
		end
	elseif step == "Tilt" then
		if frame.inRun and tilting(frame, tuning) then
			state.held += frame.dt
		end
		if state.held >= tuning.TiltHold - 1e-6 then
			state.step = "Land"
			state.held = 0
		end
	elseif step == "Finish" then
		state.held -= frame.dt
		if state.held <= 1e-6 then
			state.done = true
		end
	end
end

-- Call when a run ends: Land moves on to Finish, and other steps wait for the
-- next launch.
function Tutorial.runEnded(state: State, tuning: Tuning)
	state.inRun = false
	if not state.done and state.step == "Land" then
		state.step = "Finish"
		state.held = tuning.FinishTime
	end
end

-- The line to show now, or nil once the tutorial is done.
function Tutorial.prompt(state: State): Prompt?
	if state.done then
		return nil
	end
	local step = state.step
	if (step == "Jets" or step == "Tilt") and not state.inRun then
		return "Again"
	end
	return step
end

-- Whether the arrow over the hub ramp should show.
function Tutorial.showArrow(state: State): boolean
	local prompt = Tutorial.prompt(state)
	return prompt == "Ramp" or prompt == "Again"
end

function Tutorial.text(prompt: Prompt, device: Device, tuning: Tuning): string
	return tuning.Text[prompt][device]
end

-- The device a prompt should name, from the name of the player's last
-- Enum.UserInputType.
function Tutorial.device(inputTypeName: string): Device
	if inputTypeName == "Touch" then
		return "Touch"
	elseif string.sub(inputTypeName, 1, 7) == "Gamepad" then
		return "Gamepad"
	end
	return "Keyboard"
end

-- The saved TutorialDone flag. Records from before the tutorial have none, and
-- count as done if they ever scored a run.
function Tutorial.reconcile(saved: any, best: any): boolean
	if saved == nil then
		return typeof(best) == "number" and best > 0
	end
	return saved == true
end

return Tutorial
