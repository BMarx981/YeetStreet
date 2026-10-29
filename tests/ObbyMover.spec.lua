--!strict
local Check = require("./Check")
local ObbyMover = require("../src/shared/ObbyMover")

-- Holds 2 s in line, moves out 10 over 1 s, holds 2 s, moves back over 1 s.
local M: ObbyMover.Mover = { Axis = "Side", Travel = 10, Move = 1, Hold = 2, Phase = 0 }

Check.test("a cycle is two holds and two moves", function()
	Check.near(ObbyMover.cycle(M), 6)
end)

Check.test("it starts its cycle in line and still", function()
	local out, speed = ObbyMover.offset(M, 0)
	Check.near(out, 0)
	Check.near(speed, 0)
	out, speed = ObbyMover.offset(M, 1.5)
	Check.near(out, 0)
	Check.near(speed, 0)
end)

Check.test("halfway through moving out it is halfway, at its fastest", function()
	local out, speed = ObbyMover.offset(M, 2.5)
	Check.near(out, 5)
	Check.near(speed, 15) -- an eased move peaks at 1.5 times Travel / Move
end)

Check.test("it holds out at Travel", function()
	local out, speed = ObbyMover.offset(M, 4)
	Check.near(out, 10)
	Check.near(speed, 0)
end)

Check.test("it comes back the other way", function()
	local out, speed = ObbyMover.offset(M, 5.5)
	Check.near(out, 5)
	Check.near(speed, -15)
end)

Check.test("it repeats every cycle", function()
	local a = ObbyMover.offset(M, 2.3)
	local b = ObbyMover.offset(M, 2.3 + 6 * 1000)
	Check.near(b, a, "offset", 1e-6)
end)

Check.test("Phase starts it that far through its cycle", function()
	local m = table.clone(M)
	m.Phase = 0.5
	local out = ObbyMover.offset(m, 0)
	Check.near(out, 10)
end)

Check.test("a negative Travel moves it the other way", function()
	local m = table.clone(M)
	m.Travel = -10
	local out, speed = ObbyMover.offset(m, 2.5)
	Check.near(out, -5)
	Check.near(speed, -15)
end)

Check.finish("ObbyMover")
