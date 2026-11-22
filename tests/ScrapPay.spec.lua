--!strict
local Check = require("./Check")
local ScrapPay = require("../src/shared/ScrapPay")

local CRUSHER: ScrapPay.Crusher = { TonsPerSecond = 20, PayPerTon = 3 }
local LANE: ScrapPay.Lane = { Width = 40, Length = 560, StartZone = 60 }

Check.test("a crush pays by the tons it reached", function()
	Check.eq(ScrapPay.crush(CRUSHER, 2.7), 162, "a starter car")
	Check.eq(ScrapPay.crush(CRUSHER, 4.62), 277, "a tougher one, rounded")
end)

Check.test("pay is due the first time, then only once the gap has passed", function()
	Check.eq(ScrapPay.due(nil, 100, 60), true)
	Check.eq(ScrapPay.due(100, 130, 60), false)
	Check.eq(ScrapPay.due(100, 160, 60), true)
end)

Check.test("a car runs the alley once it is in the lane near the start", function()
	Check.eq(ScrapPay.alleyRun(LANE, false, 0, 30), true)
	Check.eq(ScrapPay.alleyRun(LANE, false, 0, 200), false, "came in further along")
	Check.eq(ScrapPay.alleyRun(LANE, true, 5, 400), true, "still going")
end)

Check.test("leaving the lane ends the alley run, except over the end", function()
	Check.eq(ScrapPay.alleyRun(LANE, true, 0, -10), false, "backed out of the start")
	Check.eq(ScrapPay.alleyRun(LANE, true, 30, 300), false, "over a wall")
	Check.eq(ScrapPay.alleyRun(LANE, true, 0, 590), true, "on the kicker")
	Check.eq(ScrapPay.alleyRun(LANE, false, 0, 590), false, "on the kicker without running it")
end)

Check.finish("ScrapPay")
