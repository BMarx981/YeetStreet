--!strict
local Check = require("./Check")
local AxolotlMoves = require("../src/shared/AxolotlMoves")

local M = AxolotlMoves

Check.test("a turn left swings the tail right, and a turn right swings it left", function()
	local peak = math.pi / 2
	local still = M.tailAngle(0, 0, 0)
	Check.eq(still, 0, "no steer, no swim at phase 0")
	Check.eq(M.tailAngle(0.3, 0, 0) > 0, true, "left")
	Check.eq(M.tailAngle(-0.3, 0, 0) < 0, true, "right")
	Check.near(M.tailAngle(0.1, 0, 0), -M.tailAngle(-0.1, 0, 0), "even")
	Check.eq(M.tailAngle(0, 0, peak) > 0, true, "it sways with no steer")
end)

Check.test("the tail swims harder with speed, up to top speed", function()
	local peak = math.pi / 2
	local parked = M.tailAngle(0, 0, peak)
	local fast = M.tailAngle(0, M.TopSpeed, peak)
	Check.eq(fast > parked, true, "bigger at speed")
	Check.near(M.tailAngle(0, M.TopSpeed * 5, peak), fast, "stops growing at top speed")
	Check.eq(M.swimRate(M.TopSpeed) > M.swimRate(0), true, "faster at speed")
end)

Check.test("the tail never swings past its limit", function()
	local peak = math.pi / 2
	Check.near(M.tailAngle(10, M.TopSpeed, peak), M.Tail.MaxAngle, "left")
	Check.near(M.tailAngle(-10, M.TopSpeed, -peak), -M.Tail.MaxAngle, "right")
end)

Check.test("gills beat faster and wider driving, and most in the air", function()
	local parkedRate, parkedSize = M.gillBeat(0, false)
	local drivingRate, drivingSize = M.gillBeat(M.TopSpeed, false)
	local airRate, airSize = M.gillBeat(0, true)
	Check.eq(drivingRate > parkedRate, true, "driving rate")
	Check.eq(drivingSize > parkedSize, true, "driving size")
	Check.eq(airRate > drivingRate, true, "air rate")
	Check.eq(airSize > drivingSize, true, "air size")
end)

Check.test("gills sweep back with speed", function()
	Check.eq(M.gillSweep(0), 0, "parked")
	Check.eq(M.gillSweep(M.TopSpeed), M.Gills.MaxSweep, "top speed")
	Check.near(M.gillSweep(M.TopSpeed * 5), M.Gills.MaxSweep, "stops at the limit")
end)

Check.test("approach closes on the target without passing it, even on a long frame", function()
	local after = M.approach(0, 1, 8, 0.1)
	Check.eq(after > 0 and after < 1, true, "partway")
	Check.eq(M.approach(0, 1, 8, 100) <= 1, true, "no overshoot")
	Check.near(M.approach(0, 1, 8, 100), 1, "gets there")
end)

Check.test("the mouth stays shut with no hit, pops open, holds, then shuts", function()
	local S = M.Smile
	Check.eq(M.smileOpen(nil), 0, "no hit yet")
	Check.eq(M.smileOpen(0), 0, "just hit")
	Check.eq(M.smileOpen(S.OpenTime), 1, "open")
	Check.eq(M.smileOpen(S.OpenTime + S.Hold), 1, "still open")
	local closing = M.smileOpen(S.OpenTime + S.Hold + S.CloseTime / 2)
	Check.eq(closing > 0 and closing < 1, true, "closing")
	Check.near(M.smileOpen(S.OpenTime + S.Hold + S.CloseTime), 0, "shut")
	Check.eq(M.smileOpen(S.OpenTime + S.Hold + S.CloseTime + 1), 0, "stays shut")
end)

Check.test("the smile curves up at both ends and lies on the head", function()
	local S = M.Smile
	local dots = M.smileDots()
	Check.eq(#dots, S.Count, "count")
	local first, middle, last = dots[1], dots[(S.Count + 1) / 2], dots[S.Count]
	Check.near(first.x, -last.x, "even sides")
	Check.near(middle.x, 0, "centered")
	Check.near(first.y, last.y, "even ends")
	Check.eq(first.y > middle.y, true, "ends up")
	local H = S.Head
	for _, dot in dots do
		local x = dot.x / H.RadiusX
		local y = (dot.y - H.Y) / H.RadiusY
		local z = (dot.z - H.Z) / H.RadiusZ
		Check.near(x * x + y * y + z * z, 1, "on the head")
		Check.eq(dot.z < H.Z, true, "on the front")
	end
end)

Check.finish("AxolotlMoves")
