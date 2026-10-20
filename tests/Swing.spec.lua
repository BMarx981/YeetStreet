--!strict
local Check = require("./Check")
local Swing = require("../src/shared/Swing")

local TUNING: Swing.Tuning = {
	Gravity = 130,
	Length = 70,
	BaseAngle = 35,
	BaseDrive = 0.5,
	PumpAccel = 0.35,
	Damping = 0.02,
	MaxSpeed = 230,
	SeatWidth = 40,
	SeatDepth = 40,
	HoldHeight = 6,
}

local DT = 1 / 60

-- The widest angle either way over `seconds` of steps with this pump.
local function widest(s: Swing.State, seconds: number, pump: (s: Swing.State) -> number): number
	local most = 0
	for _ = 1, math.floor(seconds / DT) do
		Swing.step(s, pump(s), DT, TUNING)
		most = math.max(most, math.abs(s.angle))
	end
	return most
end

local function none(_: Swing.State): number
	return 0
end

-- Pushes along the way the seat is moving.
local function inTime(s: Swing.State): number
	return if s.speed >= 0 then 1 else -1
end

Check.test("left alone, a still swing starts swinging up to the base angle", function()
	local s = Swing.new(0)
	widest(s, 30, none)
	local most = widest(s, 10, none)
	Check.near(math.deg(most), TUNING.BaseAngle, "angle", 3)
end)

Check.test("a high swing left alone settles back down toward the base angle", function()
	local s = Swing.new(math.rad(80))
	local first = widest(s, 5, none)
	widest(s, 60, none)
	local later = widest(s, 5, none)
	Check.eq(later < first, true, "lower")
	Check.eq(math.deg(later) >= TUNING.BaseAngle - 3, true, "still swinging")
end)

Check.test("pumping in time takes it over the top", function()
	local s = Swing.new(0)
	widest(s, 10, none)
	local over = false
	for _ = 1, math.floor(20 / DT) do
		Swing.step(s, inTime(s), DT, TUNING)
		if math.abs(s.angle) > math.rad(179) then
			over = true
			break
		end
	end
	Check.eq(over, true)
end)

Check.test("pumping against the swing slows it", function()
	local s = Swing.new(math.rad(90))
	local before = widest(s, 5, none)
	local after = widest(s, 5, function(state: Swing.State): number
		return -inTime(state)
	end)
	Check.eq(after < before, true)
end)

Check.test("the seat never goes faster than MaxSpeed and the angle stays wrapped", function()
	local s = Swing.new(0)
	for _ = 1, math.floor(60 / DT) do
		Swing.step(s, inTime(s), DT, TUNING)
		Check.eq(math.abs(s.speed) * TUNING.Length <= TUNING.MaxSpeed + 1e-6, true, "speed")
		Check.eq(s.angle >= -math.pi and s.angle <= math.pi, true, "angle")
	end
end)

Check.test("limit caps a state that is going too fast", function()
	local s = Swing.new(0)
	s.speed = 100
	Swing.limit(s, TUNING)
	Check.near(math.abs(s.speed) * TUNING.Length, TUNING.MaxSpeed, "speed", 1e-6)
end)

Check.test("seatPoint is Length below the pivot, swung toward -Z for a positive angle", function()
	local y, z = Swing.seatPoint(0, TUNING)
	Check.near(y, -70)
	Check.near(z, 0)
	local y2, z2 = Swing.seatPoint(math.rad(90), TUNING)
	Check.near(y2, 0)
	Check.near(z2, -70)
end)

Check.test("a hull just above the hanging seat is on it", function()
	local s = Swing.new(0)
	Check.eq(Swing.onSeat(s, 0, -70 + 2.6, 0, 0, TUNING), true, "middle")
	Check.eq(Swing.onSeat(s, 19, -70 + 2.6, -19, 0, TUNING), true, "corner")
	Check.eq(Swing.onSeat(s, 0, -70 + 10, 0, 0, TUNING), false, "too high")
	Check.eq(Swing.onSeat(s, 0, -70 - 2, 0, 0, TUNING), false, "under it")
	Check.eq(Swing.onSeat(s, 25, -70 + 2.6, 0, 0, TUNING), false, "past the side")
	Check.eq(Swing.onSeat(s, 0, -70 + 2.6, 25, 0, TUNING), false, "past the back")
end)

Check.test("the seat's footprint swings with it, even upside down", function()
	local s = Swing.new(math.pi)
	-- Over the top, the seat is 70 above the pivot and the hull hangs under it.
	Check.eq(Swing.onSeat(s, 0, 70 - 2.6, 0, 0, TUNING), true, "upside down")
	Check.eq(Swing.onSeat(s, 0, -70 + 2.6, 0, 0, TUNING), false, "where it hangs at rest")
end)

Check.test("slack widens the footprint", function()
	local s = Swing.new(0)
	Check.eq(Swing.onSeat(s, 0, -70 + 2.6, 25, 0, TUNING), false)
	Check.eq(Swing.onSeat(s, 0, -70 + 2.6, 25, 10, TUNING), true)
end)

Check.finish("Swing")
