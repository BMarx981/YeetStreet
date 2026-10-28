--!strict
-- ReplayTape (ModuleScript) -> ReplicatedStorage.ReplayTape
-- Records the last few seconds of a car so a run can be watched again. Pure,
-- see InputAxes.
--
-- The tape keeps one pose per step (record) and a mark for every part that
-- breaks off (mark), forgetting anything older than MaxLength. When a run is
-- over, window says which stretch of the tape shows it, and cut copies that
-- stretch into a clip whose time starts at zero, so the tape can record on.
--
-- The tape also follows whether the car is in the air (fly), so any flight
-- gets a clip, not only scored runs: driving off a roof counts too. A flight
-- of at least MinAirtime waits Tail seconds after it lands, then due hands
-- out its window. Lifting off again before then carries on the same flight,
-- so a bounce or a scrape along a wall doesn't split a jump in two.
--
-- A pose is whatever the caller records; the client records the hull's
-- CFrame. sample gives the two poses around a time and how far between them
-- it is, for the caller to blend.

local ReplayTape = {}

-- Same fields as Tuning.Replay, declared here so this module needs no require.
export type Tuning = {
	LeadIn: number, -- seconds of the clip before liftoff
	Tail: number, -- seconds of the clip after the run ends
	MaxLength: number, -- longest clip, in seconds; also how much the tape keeps
	BigScore: number, -- run total from which a replay plays on its own
	MinAirtime: number, -- seconds from liftoff a run lasts to replace the last clip
}

export type Frame<P> = {
	t: number,
	pose: P,
}

export type Mark = {
	t: number,
	slot: string, -- the CarDesign slot a part broke off
}

-- A finished flight waiting for its tail to be recorded.
export type Window = {
	start: number, -- liftoff
	from: number,
	to: number,
}

export type Tape<P> = {
	frames: { Frame<P> },
	marks: { Mark },
	liftoff: number?, -- when the flight under way lifted off, nil on the ground
	waiting: Window?,
}

export type Clip<P> = {
	frames: { Frame<P> }, -- at least two, the first at t = 0
	marks: { Mark },
	duration: number,
}

-- Old frames are dropped in batches about this many seconds long, so the
-- tape is not shifted every step.
local TRIM_SLACK = 1

function ReplayTape.new<P>(): Tape<P>
	return { frames = {}, marks = {} }
end

-- Adds the pose at time `t`, which is after every time recorded before.
function ReplayTape.record<P>(tape: Tape<P>, t: number, pose: P, tuning: Tuning)
	table.insert(tape.frames, { t = t, pose = pose })
	local oldest = t - tuning.MaxLength
	local frames = tape.frames
	if frames[1].t >= oldest - TRIM_SLACK then
		return
	end
	local first = 1
	while frames[first].t < oldest do
		first += 1
	end
	tape.frames = table.move(frames, first, #frames, 1, {})
	local marks = {}
	for _, mark in tape.marks do
		if mark.t >= oldest then
			table.insert(marks, mark)
		end
	end
	tape.marks = marks
end

-- Notes that a part broke off `slot` at time `t`.
function ReplayTape.mark<P>(tape: Tape<P>, t: number, slot: string)
	table.insert(tape.marks, { t = t, slot = slot })
end

-- The stretch of tape that shows a run which lifted off at `startT` and
-- ended at `endT`: from LeadIn before to Tail after, cut to MaxLength by
-- dropping the start, since the end is the landing or the crash.
function ReplayTape.window(startT: number, endT: number, tuning: Tuning): (number, number)
	local to = endT + tuning.Tail
	return math.max(startT - tuning.LeadIn, to - tuning.MaxLength), to
end

-- A copy of the frames and marks from `from` to `to`, with times counted
-- from its first frame. Nil if fewer than two frames fall in it.
function ReplayTape.cut<P>(tape: Tape<P>, from: number, to: number): Clip<P>?
	local frames: { Frame<P> } = {}
	for _, frame in tape.frames do
		if frame.t >= from and frame.t <= to then
			table.insert(frames, frame)
		end
	end
	if #frames < 2 then
		return nil
	end
	local zero = frames[1].t
	local shifted: { Frame<P> } = {}
	for i, frame in frames do
		shifted[i] = { t = frame.t - zero, pose = frame.pose }
	end
	local marks: { Mark } = {}
	for _, mark in tape.marks do
		if mark.t >= from and mark.t <= to then
			table.insert(marks, { t = mark.t - zero, slot = mark.slot })
		end
	end
	return { frames = shifted, marks = marks, duration = shifted[#shifted].t }
end

-- The poses just before and after `t` in the clip, and how far between them
-- it is (0 to 1). Before the start or after the end it holds that frame.
function ReplayTape.sample<P>(clip: Clip<P>, t: number): (P, P, number)
	local frames = clip.frames
	local time = math.clamp(t, 0, clip.duration)
	-- The last frame at or before `time`.
	local low, high = 1, #frames
	while low < high do
		local middle = (low + high + 1) // 2
		if frames[middle].t <= time then
			low = middle
		else
			high = middle - 1
		end
	end
	local a = frames[low]
	local b = frames[low + 1]
	if not b then
		return a.pose, a.pose, 0
	end
	return a.pose, b.pose, (time - a.t) / (b.t - a.t)
end

-- How many parts have broken off each slot by time `t` in the clip.
function ReplayTape.broken<P>(clip: Clip<P>, t: number): { [string]: number }
	local counts: { [string]: number } = {}
	for _, mark in clip.marks do
		if mark.t <= t then
			counts[mark.slot] = (counts[mark.slot] or 0) + 1
		end
	end
	return counts
end

-- Whether a run that lifted off at `startT` and ended at `endT` is worth a
-- clip, so a hop while rolling after a landing doesn't replace the jump.
function ReplayTape.keeps(startT: number, endT: number, tuning: Tuning): boolean
	return endT - startT >= tuning.MinAirtime
end

-- Notes whether the car is in the air at time `t`.
function ReplayTape.fly<P>(tape: Tape<P>, t: number, inAir: boolean, tuning: Tuning)
	if inAir then
		if not tape.liftoff then
			local waiting = tape.waiting
			tape.liftoff = if waiting then waiting.start else t
			tape.waiting = nil
		end
		return
	end
	local start = tape.liftoff
	if not start then
		return
	end
	tape.liftoff = nil
	if ReplayTape.keeps(start, t, tuning) then
		local from, to = ReplayTape.window(start, t, tuning)
		tape.waiting = { start = start, from = from, to = to }
	end
end

-- The window of the last flight once its tail is recorded by time `t`, or
-- at once if `force` (the car is gone). Each window is handed out once.
function ReplayTape.due<P>(tape: Tape<P>, t: number, force: boolean): Window?
	local waiting = tape.waiting
	if waiting and (force or t >= waiting.to) then
		tape.waiting = nil
		return waiting
	end
	return nil
end

-- Whether a run with this total plays its replay without being asked.
function ReplayTape.isBig(total: number, tuning: Tuning): boolean
	return total >= tuning.BigScore
end

return ReplayTape
