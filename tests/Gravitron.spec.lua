--!strict
local Check = require("./Check")
local Gravitron = require("../src/shared/Gravitron")

local SPIN: Gravitron.Spin = {
	Direction = 1,
	Stops = {
		{ Speed = 80, Hold = 20 },
		{ Speed = 180, Hold = 10 },
		{ Speed = 320, Hold = 8 },
	},
	Ramp = 6,
	MinGrip = 0.3,
	Carry = 1.5,
}

local SHAPE: Gravitron.Shape = {
	FloorRadius = 200,
	CurveRadius = 40,
	Lean = 15,
	Height = 300,
	Tilt = 20,
	Thickness = 2,
	Clearance = 1,
}

local LEAN = math.rad(15)
local TILT = math.rad(20)
-- Where the curve meets the leaning wall: 75 degrees round it.
local FOOT_R = 200 + 40 * math.sin(math.rad(75))
local FOOT_Y = 40 * (1 - math.cos(math.rad(75)))

Check.test("the cycle is every hold and a ramp after each", function()
	Check.near(Gravitron.period(SPIN), 20 + 10 + 8 + 3 * 6)
end)

Check.test("the speed holds at each stop", function()
	Check.near(Gravitron.speed(SPIN, 0), 80)
	Check.near(Gravitron.speed(SPIN, 19.9), 80)
	Check.near(Gravitron.speed(SPIN, 26.5), 180, "after the first ramp")
	Check.near(Gravitron.speed(SPIN, 45), 320, "after the second")
end)

Check.test("it eases from one stop to the next, and from the last back to the first", function()
	Check.near(Gravitron.speed(SPIN, 23), 130, "halfway up the first ramp")
	Check.near(Gravitron.speed(SPIN, 20.001), 80, "level as it leaves the stop", 0.01)
	Check.near(Gravitron.speed(SPIN, 25.999), 180, "and as it arrives", 0.01)
	Check.near(Gravitron.speed(SPIN, 50 + 3), 200, "halfway down the last ramp")
end)

Check.test("the cycle repeats", function()
	local period = Gravitron.period(SPIN)
	for _, t in { 3, 23, 31, 45, 57 } do
		Check.near(Gravitron.speed(SPIN, t + 2 * period), Gravitron.speed(SPIN, t), `at {t}`, 1e-6)
	end
end)

Check.test("travel adds up the speed over time", function()
	local step = 0.001
	local sum = 0
	local t = 0
	while t < 130 do
		sum += Gravitron.speed(SPIN, t + step / 2) * step
		t += step
		if math.abs(t - 7) < step / 2 or math.abs(t - 23) < step / 2 or math.abs(t - 129.5) < step / 2 then
			Check.near(Gravitron.travel(SPIN, t), sum, `at {t}`, 0.5)
		end
	end
end)

Check.test("grip is full at the slowest stop and MinGrip at the fastest", function()
	Check.near(Gravitron.grip(SPIN, 80), 1)
	Check.near(Gravitron.grip(SPIN, 320), 0.3)
	Check.near(Gravitron.grip(SPIN, 200), 0.65, "halfway")
	Check.near(Gravitron.grip(SPIN, 400), 0.3, "never below MinGrip")
end)

Check.test("level runs from 0 at the slowest stop to 1 at the fastest", function()
	Check.near(Gravitron.level(SPIN, 80), 0)
	Check.near(Gravitron.level(SPIN, 320), 1)
	Check.near(Gravitron.level(SPIN, 140), 0.25)
end)

Check.test("the wall leans out from the top of the curve to the rim", function()
	local r, y = Gravitron.foot(SHAPE)
	Check.near(r, FOOT_R)
	Check.near(y, FOOT_Y)
	Check.near(Gravitron.rimRadius(SHAPE), FOOT_R + (300 - FOOT_Y) * math.tan(LEAN))
end)

Check.test("the surface is the floor, then the curve, then the wall", function()
	Check.near(Gravitron.surfaceHeight(SHAPE, 0) :: number, 0)
	Check.near(Gravitron.surfaceHeight(SHAPE, 200) :: number, 0, "the curve starts at the floor's edge")
	local r = 200 + 40 * math.sin(math.rad(30))
	Check.near(Gravitron.surfaceHeight(SHAPE, r) :: number, 40 * (1 - math.cos(math.rad(30))), "on the curve")
	Check.near(Gravitron.surfaceHeight(SHAPE, FOOT_R) :: number, FOOT_Y, "the wall starts at the curve's top")
	Check.near(Gravitron.surfaceHeight(SHAPE, Gravitron.rimRadius(SHAPE)) :: number, 300, "the rim")
	Check.eq(Gravitron.surfaceHeight(SHAPE, Gravitron.rimRadius(SHAPE) + 1), nil, "nothing beyond it")
end)

Check.test("inside is above the surface and below the rim", function()
	Check.eq(Gravitron.inside(SHAPE, 0, 5, 2), true, "over the floor's middle")
	Check.eq(Gravitron.inside(SHAPE, 0, -5, 2), false, "under the floor")
	Check.eq(Gravitron.inside(SHAPE, 0, -1, 2), true, "within the margin")
	Check.eq(Gravitron.inside(SHAPE, FOOT_R + 20, 150, 2), true, "in front of the wall")
	Check.eq(Gravitron.inside(SHAPE, Gravitron.rimRadius(SHAPE), 100, 2), false, "behind the wall")
	Check.eq(Gravitron.inside(SHAPE, 100, 310, 2), false, "over the rim")
end)

Check.test("the normal points into the bowl from the nearest part of the surface", function()
	local nr, ny = Gravitron.normal(SHAPE, 50, 3)
	Check.near(nr, 0, "the floor's points up")
	Check.near(ny, 1)
	nr, ny = Gravitron.normal(SHAPE, FOOT_R + (150 - FOOT_Y) * math.tan(LEAN) - 3, 150)
	Check.near(nr, -math.cos(LEAN), "the wall's points in and a little up")
	Check.near(ny, math.sin(LEAN))
	-- Halfway round the curve, toward the curve's middle.
	local a = math.rad(40)
	nr, ny = Gravitron.normal(SHAPE, 200 + 38 * math.sin(a), 40 - 38 * math.cos(a))
	Check.near(nr, -math.sin(a), "the curve's points to its middle", 1e-6)
	Check.near(ny, math.cos(a), nil, 1e-6)
end)

Check.test("local +Y tips toward +Z, so the floor's -Z edge is the high side", function()
	local h = Gravitron.centerHeight(SHAPE)
	local x, y, z = Gravitron.fromLocal(SHAPE, 0, 1, 0)
	Check.near(x, 0)
	Check.near(y, h + math.cos(TILT))
	Check.near(z, math.sin(TILT))
	local _, high = Gravitron.fromLocal(SHAPE, 0, 0, -200)
	local _, low = Gravitron.fromLocal(SHAPE, 0, 0, 200)
	Check.eq(high > low, true, "-Z is higher")
end)

Check.test("toLocal undoes fromLocal", function()
	local x, y, z = Gravitron.fromLocal(SHAPE, 12, -40, 75)
	local a, b, c = Gravitron.toLocal(SHAPE, x, y, z)
	Check.near(a, 12, nil, 1e-9)
	Check.near(b, -40, nil, 1e-9)
	Check.near(c, 75, nil, 1e-9)
end)

Check.test("the bowl's underside clears the ground by Clearance at its lowest", function()
	local lowest = math.huge
	for i = 0, 360 do
		local around = math.rad(i)
		for j = 0, 100 do
			local a = math.rad(75) * j / 100
			local r, y = 200 + 40 * math.sin(a), 40 * (1 - math.cos(a))
			local _, wy = Gravitron.fromLocal(SHAPE, r * math.sin(around), y, r * math.cos(around))
			lowest = math.min(lowest, wy)
		end
	end
	Check.near(lowest - 2, 1, "Thickness below the surface, Clearance above the ground", 0.01)
end)

Check.test("the surface moves round the axis, Speed at the wall's foot", function()
	local vx, vz = Gravitron.surfaceVelocity(SPIN, SHAPE, 100, FOOT_R, 0)
	Check.near(vx, 0, nil, 1e-9)
	Check.near(vz, -100, "counterclockwise from above, the way CFrame.Angles(0, a, 0) turns")
	vx, vz = Gravitron.surfaceVelocity(SPIN, SHAPE, 100, 0, FOOT_R / 2)
	Check.near(vx, 50, "half as fast halfway in")
	Check.near(vz, 0, nil, 1e-9)
	local back = table.clone(SPIN)
	back.Direction = -1
	vx, vz = Gravitron.surfaceVelocity(back, SHAPE, 100, FOOT_R, 0)
	Check.near(vz, 100, "the other way")
end)

Check.test("the surface carries a car round toward its speed, Carry times the difference", function()
	local ax, az = Gravitron.carry(SPIN, SHAPE, 100, FOOT_R, 0, 0, 0)
	Check.near(ax, 0, nil, 1e-9)
	Check.near(az, -150, "a car at rest is pushed round")
	ax, az = Gravitron.carry(SPIN, SHAPE, 100, FOOT_R, 0, 0, -100)
	Check.near(az, 0, "one going round as fast is left alone", 1e-9)
	ax, az = Gravitron.carry(SPIN, SHAPE, 100, FOOT_R, 0, 70, -100)
	Check.near(ax, 0, "moving in or out is left alone", 1e-9)
	Check.near(az, 0, nil, 1e-9)
	ax, az = Gravitron.carry(SPIN, SHAPE, 100, 0, 0, 30, 0)
	Check.near(ax, 0, "nothing at the middle")
	Check.near(az, 0)
end)

Check.finish("Gravitron")
