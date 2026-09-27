--!strict
local Check = require("./Check")
local Drive = require("../src/shared/Drive")

local tuning = {
	DriveTorque = 100,
	BrakeTorque = 300,
	CoastTorque = 10,
	ReverseFraction = 0.4,
	BrakeSpeed = 2,
}

Check.test("no throttle coasts", function()
	local speed, torque = Drive.motor(0, 50, 100, 2, tuning)
	Check.eq(speed, 0)
	Check.eq(torque, 10)
end)

Check.test("full gas targets top speed as wheel spin", function()
	local speed, torque = Drive.motor(1, 0, 100, 2, tuning)
	Check.eq(speed, 50)
	Check.eq(torque, 100)
end)

Check.test("half gas targets half top speed", function()
	local speed = Drive.motor(0.5, 0, 100, 2, tuning)
	Check.eq(speed, 25)
end)

Check.test("brake while rolling forward brakes hard", function()
	local speed, torque = Drive.motor(-1, 30, 100, 2, tuning)
	Check.eq(speed, 0)
	Check.eq(torque, 300)
end)

Check.test("gas while rolling backward brakes hard", function()
	local speed, torque = Drive.motor(1, -30, 100, 2, tuning)
	Check.eq(speed, 0)
	Check.eq(torque, 300)
end)

Check.test("brake when nearly stopped reverses at the reverse cap", function()
	local speed, torque = Drive.motor(-1, 1, 100, 2, tuning)
	Check.eq(speed, -20)
	Check.eq(torque, 100)
end)

Check.test("steering is full lock when slow", function()
	Check.near(Drive.steerAngle(1, 0, 100, 30, 0.3), 30)
	Check.near(Drive.steerAngle(-1, 0, 100, 30, 0.3), -30)
end)

Check.test("steering narrows with speed", function()
	Check.near(Drive.steerAngle(1, 100, 100, 30, 0.3), 9)
	Check.near(Drive.steerAngle(1, 50, 100, 30, 0.3), 19.5)
	Check.near(Drive.steerAngle(1, 500, 100, 30, 0.3), 9, "caps past top speed")
	Check.near(Drive.steerAngle(1, -100, 100, 30, 0.3), 9, "same in reverse")
end)

Check.test("free roll matches wheel spin to ground speed", function()
	Check.near(Drive.freeRoll(70, 1.4), 50)
	Check.near(Drive.freeRoll(-14, 1.4), -10)
end)

Check.finish("Drive")
