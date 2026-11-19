--!strict
local Check = require("./Check")
local TimedEvents = require("../src/shared/TimedEvents")

local T: TimedEvents.Tuning = {
	Every = 1200,
	Duration = 180,
	Rotation = { "Mega", "BoneRain" },
}

Check.test("an event is on at the start of its slot", function()
	local now = TimedEvents.at(0, T)
	Check.eq(now.current, "Mega")
	Check.eq(now.endsIn, 180)
end)

Check.test("an event counts down while it runs", function()
	local now = TimedEvents.at(100, T)
	Check.eq(now.current, "Mega")
	Check.eq(now.endsIn, 80)
end)

Check.test("an event is over once Duration has passed", function()
	local now = TimedEvents.at(180, T)
	Check.eq(now.current, nil)
	Check.eq(now.endsIn, 0)
end)

Check.test("between events, the next one and its wait are given", function()
	local now = TimedEvents.at(200, T)
	Check.eq(now.next, "BoneRain")
	Check.eq(now.startsIn, 1000)
end)

Check.test("during an event, next is the one after it", function()
	local now = TimedEvents.at(50, T)
	Check.eq(now.next, "BoneRain")
	Check.eq(now.startsIn, 1150)
end)

Check.test("the rotation takes turns and wraps", function()
	Check.eq(TimedEvents.at(1200, T).current, "BoneRain", "slot 1")
	Check.eq(TimedEvents.at(2400, T).current, "Mega", "slot 2")
	Check.eq(TimedEvents.at(3600 + 10, T).current, "BoneRain", "slot 3")
	Check.eq(TimedEvents.at(3600 + 10, T).next, "Mega", "after slot 3")
end)

Check.test("real clock times land on the same slots in every server", function()
	-- 2026-11-19 12:00:00 UTC is a whole multiple of 1200 seconds.
	local noon = 1795089600
	Check.eq(noon % 1200, 0, "noon is a slot start")
	local a = TimedEvents.at(noon + 30, T)
	local b = TimedEvents.at(noon + 30, T)
	Check.eq(a.current, b.current)
	Check.eq(a.endsIn, 150)
end)

Check.test("fractional times count down smoothly", function()
	local now = TimedEvents.at(10.5, T)
	Check.near(now.endsIn, 169.5)
	Check.near(TimedEvents.at(300.25, T).startsIn, 899.75)
end)

Check.test("an override puts its event on until it ends", function()
	local now = TimedEvents.at(500, T, { name = "BoneRain", untilTime = 680 })
	Check.eq(now.current, "BoneRain")
	Check.eq(now.endsIn, 180)
	Check.eq(now.next, "BoneRain", "the schedule's next is unchanged")
	Check.eq(now.startsIn, 700)
end)

Check.test("an override with no name stops the event on now", function()
	local now = TimedEvents.at(60, T, { name = nil, untilTime = 180 })
	Check.eq(now.current, nil)
	Check.eq(now.endsIn, 0)
end)

Check.test("an override that has run out is ignored", function()
	local now = TimedEvents.at(1300, T, { name = "Mega", untilTime = 680 })
	Check.eq(now.current, "BoneRain")
end)

Check.test("clock shows minutes and seconds, rounding up", function()
	Check.eq(TimedEvents.clock(252), "4:12")
	Check.eq(TimedEvents.clock(59.2), "1:00")
	Check.eq(TimedEvents.clock(5), "0:05")
	Check.eq(TimedEvents.clock(0), "0:00")
	Check.eq(TimedEvents.clock(-3), "0:00")
	Check.eq(TimedEvents.clock(1200), "20:00")
end)

Check.test("isEvent knows the rotation's names", function()
	Check.eq(TimedEvents.isEvent("Mega", T), true)
	Check.eq(TimedEvents.isEvent("BoneRain", T), true)
	Check.eq(TimedEvents.isEvent("CoinRain", T), false)
end)

Check.finish("TimedEvents")
