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
	Check.near(Drive.steerAngle(1, -100, 100, 30, 0.3), 9, "same in reverse")
end)

Check.test("past top speed, steering shrinks with the square of speed", function()
	Check.near(Drive.steerAngle(1, 200, 100, 30, 0.3), 2.25)
	Check.near(Drive.steerAngle(1, 500, 100, 30, 0.3), 0.36)
	Check.near(Drive.steerAngle(-1, -200, 100, 30, 0.3), -2.25, "same in reverse")
end)

Check.test("gas lets the wheels roll when the car is already faster", function()
	local speed, torque = Drive.motor(1, 300, 100, 2, tuning)
	Check.eq(speed, 150, "free roll at 300")
	Check.eq(torque, 10, "coast torque, not drive torque")
	speed = Drive.motor(0.5, 80, 100, 2, tuning)
	Check.eq(speed, 40, "faster than half gas asks for")
end)

Check.test("reverse past the reverse cap also rolls", function()
	local speed, torque = Drive.motor(-1, -60, 100, 2, tuning)
	Check.eq(speed, -30)
	Check.eq(torque, 10)
end)

Check.test("gas below the target still drives", function()
	local speed, torque = Drive.motor(1, 60, 100, 2, tuning)
	Check.eq(speed, 50)
	Check.eq(torque, 100)
end)

Check.test("free roll matches wheel spin to ground speed", function()
	Check.near(Drive.freeRoll(70, 1.4), 50)
	Check.near(Drive.freeRoll(-14, 1.4), -10)
end)

Check.finish("Drive")
