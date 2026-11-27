--!strict
local Check = require("./Check")
local ParkVisits = require("../src/shared/ParkVisits")

local T: ParkVisits.Tuning = { MinSeconds = 20, Grace = 10 }

-- Feeds `park` once a second from `from` to `to` seconds, returning the
-- visits that ended.
local function feed(state: ParkVisits.State, park: string, from: number, to: number): { ParkVisits.Visit }
	local ended = {}
	for now = from, to do
		local visit = ParkVisits.step(state, park, now, T)
		if visit then
			table.insert(ended, visit)
		end
	end
	return ended
end

Check.test("staying in one park ends no visit", function()
	local state = ParkVisits.new()
	Check.eq(#feed(state, "Dino", 0, 300), 0)
end)

Check.test("moving to another park ends the visit at the last time seen", function()
	local state = ParkVisits.new()
	feed(state, "Dino", 0, 60)
	local ended = feed(state, "City", 61, 61)
	Check.eq(#ended, 1)
	Check.eq(ended[1].park, "Dino")
	Check.eq(ended[1].seconds, 60)
end)

Check.test("between parks, the visit ends only after Grace seconds", function()
	local state = ParkVisits.new()
	feed(state, "Dino", 0, 60)
	Check.eq(#feed(state, "", 61, 69), 0, "inside the grace")
	local ended = feed(state, "", 70, 70)
	Check.eq(#ended, 1, "past the grace")
	Check.eq(ended[1].seconds, 60, "counted to the last time seen")
end)

Check.test("coming back inside the grace keeps one visit going", function()
	local state = ParkVisits.new()
	feed(state, "Dino", 0, 60)
	feed(state, "", 61, 65)
	Check.eq(#feed(state, "Dino", 66, 120), 0)
	local ended = ParkVisits.finish(state, T)
	Check.eq(ended and ended.seconds, 120)
end)

Check.test("visits shorter than MinSeconds are dropped", function()
	local state = ParkVisits.new()
	feed(state, "Skate", 0, 15)
	Check.eq(#feed(state, "City", 16, 40), 0, "15 s in Skate")
	local ended = feed(state, "Dino", 41, 41)
	Check.eq(ended[1] and ended[1].park, "City", "24 s in City counts")
end)

Check.test("finish ends the visit in progress, and only once", function()
	local state = ParkVisits.new()
	feed(state, "Plant", 0, 45)
	local ended = ParkVisits.finish(state, T)
	Check.eq(ended and ended.park, "Plant")
	Check.eq(ended and ended.seconds, 45)
	Check.eq(ParkVisits.finish(state, T), nil, "nothing left")
end)

Check.test("nothing is in progress before the first park", function()
	local state = ParkVisits.new()
	feed(state, "", 0, 30)
	Check.eq(ParkVisits.finish(state, T), nil)
end)

Check.finish("ParkVisits")
