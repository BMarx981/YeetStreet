--!strict
-- Scoring (ModuleScript) -> ReplicatedStorage.Scoring
-- Turns a finished run from RunTracker into points. Pure, see InputAxes.
--
--   total = (airtime + distance + height + tricks + smash) * combo * clean
--
-- Each repeat of the same trick (kind and direction) pays RepeatFalloff times
-- the last, down to RepeatFloor of full points. The combo grows by ComboStep
-- for each different trick after the first. A clean landing multiplies on top.
-- Smash points pay for each part knocked off the car during the run; only the
-- server knows those, so the client's own score leaves them out. A run that
-- crashes, ends off its wheels, or ends by reset keeps its base points and
-- loses the combo and clean bonus, which is all a crash ever costs.

local Scoring = {}

-- Same shapes as RunTracker's Trick and Result, declared here so this module
-- needs no require.
export type TrickKind = "flip" | "spin" | "roll"

export type Trick = {
	kind: TrickKind,
	direction: number,
	airtime: number,
}

export type Run = {
	ending: "landed" | "crashed" | "stopped" | "aborted",
	airtime: number,
	distance: number,
	height: number,
	tricks: { Trick },
	clean: boolean,
}

export type Tuning = {
	AirtimePerSecond: number,
	DistancePerStud: number,
	HeightPerStud: number,
	FlipPoints: number,
	SpinPoints: number,
	RollPoints: number,
	RepeatFalloff: number,
	RepeatFloor: number,
	ComboStep: number,
	ComboMax: number,
	CleanMultiplier: number,
	SmashPoints: number,
}

export type Score = {
	airtime: number,
	distance: number,
	height: number,
	trickPoints: { number }, -- one per trick, in the order they were done
	smash: number,
	base: number,
	combo: number,
	clean: number, -- multiplier, 1 when not clean
	total: number,
}

local function round(x: number): number
	return math.floor(x + 0.5)
end

local function trickBase(kind: TrickKind, tuning: Tuning): number
	if kind == "flip" then
		return tuning.FlipPoints
	elseif kind == "spin" then
		return tuning.SpinPoints
	end
	return tuning.RollPoints
end

-- Directions follow AirControl's axes: a positive flip lifts the nose, a
-- positive spin swings it left, a positive roll lifts the right side.
local TRICK_NAMES: { [TrickKind]: { [number]: string } } = {
	flip = { [1] = "Backflip", [-1] = "Frontflip" },
	spin = { [1] = "Spin left", [-1] = "Spin right" },
	roll = { [1] = "Barrel roll left", [-1] = "Barrel roll right" },
}

function Scoring.trickName(trick: Trick): string
	return TRICK_NAMES[trick.kind][trick.direction]
end

-- `smashes` is how many parts broke off the car during the run.
function Scoring.score(run: Run, tuning: Tuning, smashes: number?): Score
	local airtime = round(run.airtime * tuning.AirtimePerSecond)
	local distance = round(run.distance * tuning.DistancePerStud)
	local height = round(run.height * tuning.HeightPerStud)

	local trickPoints: { number } = {}
	local done: { [string]: number } = {}
	local different = 0
	local trickTotal = 0
	for _, trick in run.tricks do
		local key = `{trick.kind}{trick.direction}`
		local repeats = done[key] or 0
		if repeats == 0 then
			different += 1
		end
		done[key] = repeats + 1
		local fraction = math.max(tuning.RepeatFalloff ^ repeats, tuning.RepeatFloor)
		local points = round(trickBase(trick.kind, tuning) * fraction)
		table.insert(trickPoints, points)
		trickTotal += points
	end

	local smash = (smashes or 0) * tuning.SmashPoints
	local base = airtime + distance + height + trickTotal + smash
	local landed = run.ending == "landed"
	local combo = if landed then math.min(1 + tuning.ComboStep * math.max(different - 1, 0), tuning.ComboMax) else 1
	local clean = if landed and run.clean then tuning.CleanMultiplier else 1

	return {
		airtime = airtime,
		distance = distance,
		height = height,
		trickPoints = trickPoints,
		smash = smash,
		base = base,
		combo = combo,
		clean = clean,
		total = round(base * combo * clean),
	}
end

return Scoring
