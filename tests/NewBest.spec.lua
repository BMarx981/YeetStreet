--!strict
local Check = require("./Check")
local NewBest = require("../src/shared/NewBest")

local T: NewBest.Tuning = { ShoutFrom = 2500 }

Check.test("beating the best shows the banner", function()
	local banner = NewBest.check(1000, 1200, T)
	Check.eq(banner, true)
end)

Check.test("matching or missing the best shows nothing", function()
	local banner, shout = NewBest.check(1000, 1000, T)
	Check.eq(banner, false)
	Check.eq(shout, false)
	banner, shout = NewBest.check(1000, 400, T)
	Check.eq(banner, false)
	Check.eq(shout, false)
end)

Check.test("the very first run is not a new best", function()
	local banner, shout = NewBest.check(0, 5000, T)
	Check.eq(banner, false)
	Check.eq(shout, false)
end)

Check.test("only a new best of ShoutFrom or more tells the server", function()
	local _, shout = NewBest.check(1000, 2499, T)
	Check.eq(shout, false)
	_, shout = NewBest.check(1000, 2500, T)
	Check.eq(shout, true)
end)

Check.finish("NewBest")
