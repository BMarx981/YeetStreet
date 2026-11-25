--!strict
-- Tutorial (ModuleScript) -> ReplicatedStorage.Tutorial
-- The first-session tutorial's steps, one prompt at a time: Drive (hold gas
-- up to DriveSpeed), Ramp (until a run starts), Jets (JetHold seconds of jets
-- in a run), Tilt (TiltHold seconds of steering, gas, brake, pitch, or roll of
-- at least TiltInput in a run), Land (until the run ends). A player who owns
-- an upgrade level then sees Finish for FinishTime seconds. Anyone else is
-- walked to their first upgrade: Earn (more runs until one is affordable),
-- Garage (drive into a garage ring), Open (open the garage), Upgrade (buy
-- one), then Upgraded for FinishTime seconds. A run that ends during Jets or
-- Tilt keeps the step and asks for another launch (Again). The client feeds
-- it a Frame each step and calls runEnded when a run ends; prompt names the
-- line to show, and text picks it for the player's device. reconcile reads
-- the saved TutorialDone flag. Pure.

local Tutorial = {}

export type Device = "Keyboard" | "Gamepad" | "Touch"
export type Prompt =
	"Drive"
	| "Ramp"
	| "Again"
	| "Jets"
	| "Tilt"
	| "Land"
	| "Earn"
	| "Garage"
	| "Open"
	| "Upgrade"
	| "Upgraded"
	| "Finish"
export type Arrow = "Ramp" | "Garage"
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
	-- For the garage steps; missing counts as false.
	atGarage: boolean?, -- inside a garage's ring
	garageOpen: boolean?, -- the garage panel is open at a garage, not the car panel
	canAfford: boolean?, -- some upgrade level on this car is affordable
	upgraded: boolean?, -- the player owns an upgrade level
}

type Step = "Drive" | "Ramp" | "Jets" | "Tilt" | "Land" | "Earn" | "Garage" | "Open" | "Upgrade" | "Upgraded" | "Finish"

export type State = {
	step: Step,
	inRun: boolean,
	held: number, -- seconds toward the current step's hold, or left on Finish or Upgraded
	upgraded: boolean, -- from the last frame
	done: boolean,
}

function Tutorial.new(): State
	return { step = "Drive", inRun = false, held = 0, upgraded = false, done = false }
end

local function tilting(frame: Frame, tuning: Tuning): boolean
	local most = math.max(math.abs(frame.steer), math.abs(frame.throttle), math.abs(frame.pitch), math.abs(frame.roll))
	return most >= tuning.TiltInput
end

-- The garage step that fits where the player is on the way to an upgrade.
local function shopStep(frame: Frame): Step
	if not frame.canAfford then
		return "Earn"
	elseif frame.garageOpen then
		return "Upgrade"
	elseif frame.atGarage then
		return "Open"
	end
	return "Garage"
end

-- Moves the tutorial on by one frame.
function Tutorial.step(state: State, frame: Frame, tuning: Tuning)
	if state.done then
		return
	end
	state.inRun = frame.inRun
	state.upgraded = frame.upgraded == true
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
	elseif step == "Earn" or step == "Garage" or step == "Open" or step == "Upgrade" then
		if frame.upgraded then
			state.step = "Upgraded"
			state.held = tuning.FinishTime
		else
			state.step = shopStep(frame)
		end
	elseif step == "Finish" or step == "Upgraded" then
		state.held -= frame.dt
		if state.held <= 1e-6 then
			state.done = true
		end
	end
end

-- Call when a run ends: Land moves on to Finish for a player who owns an
-- upgrade, or Earn for one who doesn't, and other steps wait for the next
-- launch.
function Tutorial.runEnded(state: State, tuning: Tuning)
	state.inRun = false
	if not state.done and state.step == "Land" then
		if state.upgraded then
			state.step = "Finish"
			state.held = tuning.FinishTime
		else
			state.step = "Earn"
		end
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

-- What the arrow should point at: the hub ramp, the nearest garage, or
-- nothing.
function Tutorial.arrow(state: State): Arrow?
	local prompt = Tutorial.prompt(state)
	if prompt == "Ramp" or prompt == "Again" then
		return "Ramp"
	elseif prompt == "Garage" then
		return "Garage"
	end
	return nil
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
