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

Check.test("pieces fly off one at a time as the car takes damage", function()
	Check.eq(M.piecesOff(0, 20), 0, "whole")
	Check.eq(M.piecesOff(20, 20), #M.Breaks, "all off")
	local last = 0
	for broken = 0, 20 do
		local off = M.piecesOff(broken, 20)
		Check.eq(off >= last, true, "never comes back")
		Check.eq(off - last <= 1, true, "one at a time on a long list")
		last = off
	end
	Check.eq(M.piecesOff(1, 20), 0, "a scratch breaks nothing")
end)

Check.test("a car with no breakable parts keeps its pieces", function()
	Check.eq(M.piecesOff(0, 0), 0, "none")
	Check.eq(M.piecesOff(3, 0), 0, "still none")
end)

Check.test("a step swims the tail and beats the gills, and a stopped clock freezes them", function()
	local moves = M.newMoves()
	for _ = 1, 30 do
		M.step(moves, 0, M.TopSpeed, true, 1 / 30)
	end
	Check.eq(moves.gillSize > M.Gills.DriveSize, true, "gills open wide in the air")
	Check.eq(moves.sweep > 0, true, "gills lie back at speed")
	Check.eq(moves.tailYaw ~= 0, true, "tail swims")
	local tail, flap = moves.tailYaw, moves.flap
	M.step(moves, 0, M.TopSpeed, true, 0)
	Check.near(moves.tailYaw, tail, "paused tail")
	Check.near(moves.flap, flap, "paused gills")
end)

Check.test("a step swings the tail out of the turn", function()
	local left, right = M.newMoves(), M.newMoves()
	for _ = 1, 60 do
		M.step(left, 0.3, 0, false, 1 / 30)
		M.step(right, -0.3, 0, false, 1 / 30)
	end
	Check.eq(left.tailYaw > right.tailYaw, true, "left swings further right")
end)

Check.test("a turn on the tape reads back as a steer angle", function()
	Check.eq(M.steerFromTurn(1, 40, 8) > 0, true, "left")
	Check.near(M.steerFromTurn(1, 40, 8), -M.steerFromTurn(-1, 40, 8), "even")
	Check.near(M.steerFromTurn(1, 40, 8), math.atan(8 / 40), "same turn as wheels at that angle")
	Check.eq(M.steerFromTurn(1, 0, 8), 0, "spinning on the spot isn't steering")
end)

Check.test("recorded breaks give when each piece flies off", function()
	local gone, at = M.pieceBreaks(0, { 1, 2, 3, 4, 5 }, 10)
	Check.eq(gone, 0, "none before the clip")
	Check.eq(at[1], 2, "share 0.2 passes the first break")
	Check.eq(at[2], 4, "share 0.4 reaches the second")
	Check.eq(at[3], nil, "the tail stays on")
end)

Check.test("pieces lost before the clip don't fly again", function()
	local gone, at = M.pieceBreaks(5, { 7, 8 }, 10)
	Check.eq(gone, 2, "both gills went before")
	Check.eq(at[1], nil, "first")
	Check.eq(at[2], nil, "second")
	Check.eq(at[3], 8, "share 0.7 takes the tail")
end)

Check.test("the same break can take off several pieces", function()
	local gone, at = M.pieceBreaks(0, { 1, 2 }, 2)
	Check.eq(gone, 0, "none before")
	Check.eq(at[1], 1, "first at share 0.5")
	Check.eq(at[2], 1, "second at share 0.5")
	Check.eq(at[3], 2, "third at share 1")
end)

Check.test("the laugh follows the last hit before this moment", function()
	Check.eq(M.sinceHit({}, 3), nil, "no hits")
	Check.eq(M.sinceHit({ 5 }, 3), nil, "not yet")
	Check.near(M.sinceHit({ 1, 2, 5 }, 3) :: number, 1, "the latest so far")
	Check.eq(M.sinceHit({ 1, 3 }, 3), 0, "right on it")
end)

Check.finish("AxolotlMoves")
