--!strict
local Check = require("./Check")
local PipeCatch = require("../src/shared/PipeCatch")

local GRAVITY = 130

local PIPE = {
	FlatWidth = 60,
	Radius = 70,
	Angle = 94,
	Length = 800,
	Catch = { Inset = 3, Reach = 12, MinRise = 20 },
}

local LIP_ACROSS = 30 + 70 * math.sin(math.rad(94))
local LIP_HEIGHT = 70 * (1 - math.cos(math.rad(94)))

-- Where a car thrown across at `speed` is when it falls back to `toHeight`.
local function landsAt(across: number, height: number, up: number, speed: number, toHeight: number): number
	local time = (up + math.sqrt(up * up + 2 * GRAVITY * (height - toHeight))) / GRAVITY
	return across + speed * time
end

Check.test("the lip is the top of the curve, out from the flat middle", function()
	local across, height = PipeCatch.lip(PIPE)
	Check.near(across, LIP_ACROSS, "across")
	Check.near(height, LIP_HEIGHT, "height")
end)

Check.test("aim brings a rising car down on the target at the target's height", function()
	local speed = PipeCatch.aim(90, 80, 150, 95, 75, GRAVITY) :: number
	Check.near(landsAt(90, 80, 150, speed, 75), 95, "lands at")
end)

Check.test("a car with no way back up to the target can't be aimed", function()
	Check.eq(PipeCatch.aim(90, 50, 5, 95, 75, GRAVITY), nil)
end)

Check.test("a car off the top of the far wall comes down just inside its lip", function()
	local across = LIP_ACROSS - 1
	local speed = PipeCatch.catch(PIPE, across, 100, LIP_HEIGHT + 4, 160, GRAVITY) :: number
	Check.eq(speed < 0, true, "pulled back in")
	Check.near(landsAt(across, LIP_HEIGHT + 4, 160, speed, LIP_HEIGHT), LIP_ACROSS - 3, "lands at")
end)

Check.test("a car drifting in over the pipe is sent back out to the lip", function()
	local across = LIP_ACROSS - 8
	local speed = PipeCatch.catch(PIPE, across, 0, LIP_HEIGHT + 20, 120, GRAVITY) :: number
	Check.eq(speed > 0, true, "pushed back out")
	Check.near(landsAt(across, LIP_HEIGHT + 20, 120, speed, LIP_HEIGHT), LIP_ACROSS - 3, "lands at")
end)

Check.test("the near wall is the same, mirrored", function()
	local across = -(LIP_ACROSS - 1)
	local speed = PipeCatch.catch(PIPE, across, -100, LIP_HEIGHT + 4, 160, GRAVITY) :: number
	Check.eq(speed > 0, true, "pulled back in")
	Check.near(landsAt(across, LIP_HEIGHT + 4, 160, speed, LIP_HEIGHT), -(LIP_ACROSS - 3), "lands at")
end)

Check.test("a car rising slower than MinRise is left alone", function()
	Check.eq(PipeCatch.catch(PIPE, LIP_ACROSS - 1, 0, LIP_HEIGHT + 4, 10, GRAVITY), nil, "slow")
	Check.eq(PipeCatch.catch(PIPE, LIP_ACROSS - 1, 0, LIP_HEIGHT + 4, -50, GRAVITY), nil, "falling")
end)

Check.test("a car still below the lip is left alone", function()
	Check.eq(PipeCatch.catch(PIPE, LIP_ACROSS - 1, 0, LIP_HEIGHT - 1, 160, GRAVITY), nil)
end)

Check.test("a car away from the lips is left alone", function()
	Check.eq(PipeCatch.catch(PIPE, 0, 0, LIP_HEIGHT + 4, 160, GRAVITY), nil, "middle")
	Check.eq(PipeCatch.catch(PIPE, LIP_ACROSS - 13, 0, LIP_HEIGHT + 4, 160, GRAVITY), nil, "inside")
	Check.eq(PipeCatch.catch(PIPE, LIP_ACROSS + 13, 0, LIP_HEIGHT + 4, 160, GRAVITY), nil, "over the deck")
end)

Check.test("a car past either end of the pipe is left alone", function()
	Check.eq(PipeCatch.catch(PIPE, LIP_ACROSS - 1, 401, LIP_HEIGHT + 4, 160, GRAVITY), nil, "far end")
	Check.eq(PipeCatch.catch(PIPE, LIP_ACROSS - 1, -401, LIP_HEIGHT + 4, 160, GRAVITY), nil, "near end")
end)

Check.finish("PipeCatch")
