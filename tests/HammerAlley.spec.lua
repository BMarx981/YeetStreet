--!strict
local Check = require("./Check")
local HammerAlley = require("../src/shared/HammerAlley")

local CONFIG: HammerAlley.Config = {
	Width = 40,
	Reach = 3,
	Swing = {
		Height = 56,
		Length = 50,
		Amplitude = 60,
		Period = 4,
		HeadSize = 12,
		HeadLength = 16,
		SideKick = 90,
		Lift = 40,
	},
	Slam = {
		Height = 12,
		Length = 36,
		PivotOut = 4,
		Period = 4,
		Slam = 0.25,
		Hold = 0.5,
		Rise = 1.25,
		HeadSize = 14,
		HeadLength = 16,
		Up = 30,
		Back = 70,
	},
}

local SWING: HammerAlley.Hammer = { Kind = "Swing", At = 100, Side = 1, Phase = 0 }
local SLAM: HammerAlley.Hammer = { Kind = "Slam", At = 200, Side = -1, Phase = 0 }

Check.test("a swinging hammer hangs low mid-swing and reaches out at full swing", function()
	local x, y = HammerAlley.head(CONFIG, SWING, 0)
	Check.near(x, 0)
	Check.near(y, 6)
	x, y = HammerAlley.head(CONFIG, SWING, 1)
	Check.near(x, 50 * math.sin(math.rad(60)))
	Check.near(y, 56 - 50 * 0.5)
end)

Check.test("a slam hammer waits straight up, then slams flat across the lane", function()
	local x, y = HammerAlley.head(CONFIG, SLAM, 0)
	Check.near(x, -24, "pivot just outside the left wall")
	Check.near(y, 12 + 36, "straight up")
	x, y = HammerAlley.head(CONFIG, SLAM, 0.25)
	Check.near(x, -24 + 36, "flat")
	Check.near(y, 12)
	x, y = HammerAlley.head(CONFIG, SLAM, 0.6)
	Check.near(x, 12, "held flat")
	x, y = HammerAlley.head(CONFIG, SLAM, 3)
	Check.near(y, 48, "back up and waiting")
end)

Check.test("a slam hammer on the right side slams toward the left", function()
	local right: HammerAlley.Hammer = { Kind = "Slam", At = 200, Side = 1, Phase = 0 }
	local x = HammerAlley.head(CONFIG, right, 0.25)
	Check.near(x, 24 - 36)
end)

Check.test("the slam speeds up as it falls", function()
	local _, quarter = HammerAlley.head(CONFIG, SLAM, 0.0625)
	local _, half = HammerAlley.head(CONFIG, SLAM, 0.125)
	Check.eq(48 - half > 2 * (48 - quarter), true)
end)

Check.test("phase shifts a hammer's timing", function()
	local late: HammerAlley.Hammer = { Kind = "Slam", At = 200, Side = -1, Phase = 0.5 }
	local _, y = HammerAlley.head(CONFIG, late, 2.25)
	Check.near(y, 12, "slammed half a period later")
end)

Check.test("a car touches a hammer only near its head and along the lane", function()
	Check.eq(HammerAlley.touching(CONFIG, SWING, 0, 0, 3, 100, 0), true)
	Check.eq(HammerAlley.touching(CONFIG, SWING, 0, 0, 3, 115, 0), false, "past it along the lane")
	Check.eq(HammerAlley.touching(CONFIG, SWING, 1, 0, 3, 100, 0), false, "swung away")
	Check.eq(HammerAlley.touching(CONFIG, SLAM, 0.3, 0, 3, 200, 0), true, "under the held handle")
	Check.eq(HammerAlley.touching(CONFIG, SLAM, 3, 0, 3, 200, 0), false, "raised")
	Check.eq(HammerAlley.touching(CONFIG, SLAM, 3, 0, 3, 200, 100), true, "slack reaches further")
end)

Check.test("a swinging hammer bats a car the way it swings, and up", function()
	local vx, vy, va = HammerAlley.push(CONFIG, { SWING }, 0, 0, 3, 100, 0, 0, 50)
	Check.near(vx :: number, 90)
	Check.near(vy :: number, 40)
	Check.near(va :: number, 50, "keeps going along the lane")
	vx = HammerAlley.push(CONFIG, { SWING }, 2, 0, 3, 100, 0, 0, 50)
	Check.near(vx :: number, -90, "swinging back the other way")
end)

Check.test("a slam hammer knocks a car back and bounces it", function()
	local vx, vy, va = HammerAlley.push(CONFIG, { SLAM }, 0.3, 0, 3, 200, 5, 0, 60)
	Check.near(vx :: number, 5)
	Check.near(vy :: number, 30)
	Check.near(va :: number, -70)
end)

Check.test("no push away from the hammers, or from a slam hammer going back up", function()
	Check.eq(HammerAlley.push(CONFIG, { SWING, SLAM }, 0, 0, 3, 150, 0, 0, 50), nil)
	Check.eq(HammerAlley.push(CONFIG, { SLAM }, 3, 0, 3, 200, 0, 0, 50), nil)
end)

Check.test("the server sees a hammer reach a car any time in a window", function()
	Check.eq(HammerAlley.smacked(CONFIG, { SLAM }, 2, 2.5, 0, 3, 200, 0), false, "raised the whole time")
	Check.eq(HammerAlley.smacked(CONFIG, { SLAM }, 3.9, 4.4, 0, 3, 200, 0), true, "the next slam")
end)

Check.finish("HammerAlley")
