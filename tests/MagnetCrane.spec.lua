--!strict
local Check = require("./Check")
local MagnetCrane = require("../src/shared/MagnetCrane")

local CONFIG: MagnetCrane.Config = {
	Radius = 100,
	PadAngle = 180,
	DropAngle = 270,
	IdleHeight = 40,
	GrabHeight = 6,
	LiftHeight = 200,
	Lower = 1,
	Lift = 3,
	Swing = 4,
	Hold = 1,
	Return = 4,
	Settle = 2,
	PadRadius = 15,
	CatchHeight = 8,
}

Check.test("a cycle grabs after lowering and drops after lifting, swinging, and holding", function()
	Check.near(MagnetCrane.grabAt(CONFIG), 1)
	Check.near(MagnetCrane.dropAt(CONFIG), 9)
	Check.near(MagnetCrane.cycleLength(CONFIG), 15)
end)

Check.test("the phases follow each other", function()
	Check.eq(MagnetCrane.phase(CONFIG, -1), "idle", "before it starts")
	Check.eq(MagnetCrane.phase(CONFIG, 0.5), "lowering")
	Check.eq(MagnetCrane.phase(CONFIG, 2), "lifting")
	Check.eq(MagnetCrane.phase(CONFIG, 6), "swinging")
	Check.eq(MagnetCrane.phase(CONFIG, 8.5), "holding")
	Check.eq(MagnetCrane.phase(CONFIG, 11), "returning")
	Check.eq(MagnetCrane.phase(CONFIG, 14), "settling")
	Check.eq(MagnetCrane.phase(CONFIG, 16), "idle", "after it ends")
end)

Check.test("the magnet waits over the pad, comes down, lifts, swings out, and comes back", function()
	local function pose(t: number): string
		local angle, height = MagnetCrane.pose(CONFIG, t)
		return `{math.floor(angle + 0.5)} {math.floor(height + 0.5)}`
	end
	Check.eq(pose(-1), "180 40", "waiting")
	Check.eq(pose(1), "180 6", "down on the car's roof")
	Check.eq(pose(4), "180 200", "lifted")
	Check.eq(pose(6), "225 200", "halfway round")
	Check.eq(pose(8), "270 200", "over the drop")
	Check.eq(pose(9), "270 200", "letting go")
	Check.eq(pose(13), "180 200", "back over the pad")
	Check.eq(pose(15), "180 40", "waiting again")
end)

Check.test("it clamps on as it reaches the roof and lets go after the hold", function()
	local function cues(from: number, to: number): string
		return table.concat(MagnetCrane.cues(CONFIG, from, to), ",")
	end
	Check.eq(cues(0.9, 1.1), "clamp")
	Check.eq(cues(8.9, 9.1), "release")
	Check.eq(cues(0, 15), "clamp,release")
	Check.eq(cues(2, 8), "")
	Check.eq(cues(9.1, 8.9), "", "going back")
end)

Check.test("where the magnet is round the tower, 0 degrees along +Z and 90 along +X", function()
	local x, z = MagnetCrane.spot(CONFIG, 0)
	Check.near(x, 0)
	Check.near(z, 100)
	x, z = MagnetCrane.spot(CONFIG, 90)
	Check.near(x, 100)
	Check.near(z, 0)
end)

Check.test("a car is on the pad inside its radius, low down", function()
	Check.eq(MagnetCrane.onPad(CONFIG, 10, 10, 3), true)
	Check.eq(MagnetCrane.onPad(CONFIG, 12, 12, 3), false, "outside")
	Check.eq(MagnetCrane.onPad(CONFIG, 0, 0, 12), false, "too high")
end)

Check.finish("MagnetCrane")
