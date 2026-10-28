--!strict
local Check = require("./Check")
local ReplayTape = require("../src/shared/ReplayTape")

local TUNING: ReplayTape.Tuning = {
	LeadIn = 1,
	Tail = 2,
	MaxLength = 10,
	BigScore = 5000,
}

-- A tape with one pose every `step` seconds from `from` to `to`, each pose
-- being its own time, so a sample's pose says which frame it came from.
local function filled(from: number, to: number, step: number): ReplayTape.Tape<number>
	local tape = ReplayTape.new()
	local t = from
	while t <= to + 1e-9 do
		ReplayTape.record(tape, t, t, TUNING)
		t += step
	end
	return tape
end

Check.test("a window starts LeadIn before liftoff and ends Tail after the run", function()
	local from, to = ReplayTape.window(20, 24, TUNING)
	Check.eq(from, 19, "from")
	Check.eq(to, 26, "to")
end)

Check.test("a long run's window keeps its end and drops its start", function()
	local from, to = ReplayTape.window(20, 40, TUNING)
	Check.eq(from, 32, "from")
	Check.eq(to, 42, "to")
end)

Check.test("a clip starts at zero and lasts from its first frame to its last", function()
	local tape = filled(0, 30, 0.5)
	local clip = ReplayTape.cut(tape, 22, 29)
	assert(clip, "clip")
	Check.eq(clip.frames[1].pose, 22, "first pose")
	Check.eq(clip.frames[1].t, 0, "first time")
	Check.eq(clip.frames[#clip.frames].pose, 29, "last pose")
	Check.eq(clip.duration, 7, "duration")
end)

Check.test("a clip keeps its frames when the tape records on", function()
	local tape = filled(0, 10, 1)
	local clip = ReplayTape.cut(tape, 2, 5)
	assert(clip, "clip")
	for t = 11, 30 do
		ReplayTape.record(tape, t, t, TUNING)
	end
	Check.eq(#clip.frames, 4, "frames")
	Check.eq(clip.frames[1].pose, 2, "first pose")
end)

Check.test("the tape forgets frames older than MaxLength", function()
	local tape = filled(0, 30, 0.5)
	Check.eq(ReplayTape.cut(tape, 0, 15), nil, "long gone")
	local clip = ReplayTape.cut(tape, 20, 30)
	assert(clip, "recent clip")
	Check.eq(clip.frames[1].pose, 20, "recent first pose")
end)

Check.test("a window with fewer than two frames makes no clip", function()
	local tape = filled(0, 5, 1)
	Check.eq(ReplayTape.cut(tape, 2.2, 2.8), nil, "no frames")
	Check.eq(ReplayTape.cut(tape, 2.5, 3.5), nil, "one frame")
	Check.eq(ReplayTape.cut(ReplayTape.new(), 0, 5), nil, "empty tape")
end)

Check.test("sampling between frames gives both and how far between", function()
	local clip = ReplayTape.cut(filled(0, 4, 1), 0, 4)
	assert(clip, "clip")
	local a, b, alpha = ReplayTape.sample(clip, 1.25)
	Check.eq(a, 1, "before")
	Check.eq(b, 2, "after")
	Check.near(alpha, 0.25, "alpha")
end)

Check.test("sampling on a frame gives that frame", function()
	local clip = ReplayTape.cut(filled(0, 4, 1), 0, 4)
	assert(clip, "clip")
	local a, _, alpha = ReplayTape.sample(clip, 2)
	Check.eq(a, 2, "frame")
	Check.near(alpha, 0, "alpha")
end)

Check.test("sampling outside the clip holds its first or last frame", function()
	local clip = ReplayTape.cut(filled(0, 4, 1), 0, 4)
	assert(clip, "clip")
	local a, b, alpha = ReplayTape.sample(clip, -3)
	Check.eq(a, 0, "early before")
	Check.eq(b, 1, "early after")
	Check.near(alpha, 0, "early alpha")
	a, b, alpha = ReplayTape.sample(clip, 99)
	Check.eq(a, 4, "late before")
	Check.eq(b, 4, "late after")
	Check.near(alpha, 0, "late alpha")
end)

Check.test("sampling finds frames with uneven gaps", function()
	local tape = ReplayTape.new()
	for _, t in { 0, 0.1, 0.15, 0.4, 1, 1.05 } do
		ReplayTape.record(tape, t, t, TUNING)
	end
	local clip = ReplayTape.cut(tape, 0, 2)
	assert(clip, "clip")
	local a, b, alpha = ReplayTape.sample(clip, 0.7)
	Check.eq(a, 0.4, "before")
	Check.eq(b, 1, "after")
	Check.near(alpha, 0.5, "alpha")
end)

Check.test("breaks count by slot up to the time asked", function()
	local tape = filled(0, 10, 0.5)
	ReplayTape.mark(tape, 1, "nose")
	ReplayTape.mark(tape, 4, "nose")
	ReplayTape.mark(tape, 4.5, "roof")
	ReplayTape.mark(tape, 9, "tail")
	local clip = ReplayTape.cut(tape, 2, 8)
	assert(clip, "clip")
	local early = ReplayTape.broken(clip, 1.9)
	Check.eq(early.nose, nil, "nothing broken yet")
	local mid = ReplayTape.broken(clip, 2)
	Check.eq(mid.nose, 1, "nose at its break")
	Check.eq(mid.roof, nil, "roof not yet")
	local late = ReplayTape.broken(clip, clip.duration)
	Check.eq(late.nose, 1, "nose broken before the clip is not counted")
	Check.eq(late.roof, 1, "roof")
	Check.eq(late.tail, nil, "tail broke after the clip")
end)

Check.test("the tape forgets breaks older than MaxLength", function()
	local tape = ReplayTape.new()
	ReplayTape.record(tape, 0, 0, TUNING)
	ReplayTape.mark(tape, 0, "nose")
	for t = 1, 30 do
		ReplayTape.record(tape, t, t, TUNING)
	end
	Check.eq(#tape.marks, 0, "marks")
end)

Check.test("a run is big from BigScore up", function()
	Check.eq(ReplayTape.isBig(4999, TUNING), false, "just under")
	Check.eq(ReplayTape.isBig(5000, TUNING), true, "at")
	Check.eq(ReplayTape.isBig(12000, TUNING), true, "over")
end)

Check.finish("ReplayTape")
