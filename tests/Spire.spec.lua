--!strict
local Check = require("./Check")
local Spire = require("../src/shared/Spire")

local SHAPE: Spire.Shape = {
	Height = 250,
	Tiers = 10,
	BaseWidth = 90,
	TopWidth = 40,
	Ledge = {
		Pitch = 50,
		StartWidth = 20,
		EndWidth = 11,
		StepsPerTurn = 60,
		Thickness = 2,
		Clear = 1,
		Into = 18,
		LevelTurn = 0.25,
		Start = math.pi,
	},
}

local TOP = 250.2

-- The tier of rock at height `y`, and how far its corners reach.
local function cornerAt(y: number): number
	local k = math.clamp(math.floor(y / (SHAPE.Height / SHAPE.Tiers)), 0, SHAPE.Tiers - 1)
	local width = SHAPE.BaseWidth + (SHAPE.TopWidth - SHAPE.BaseWidth) * k / (SHAPE.Tiers - 1)
	return width / 2 * math.sqrt(2)
end

Check.test("the ledge starts on the ground and climbs to the top in Pitch a turn", function()
	Check.near(Spire.heightAt(SHAPE, TOP, 0), 0, "start")
	Check.near(Spire.heightAt(SHAPE, TOP, 2 * math.pi), 50, "one turn up")
	Check.near(Spire.heightAt(SHAPE, TOP, Spire.climbSweep(SHAPE, TOP)), TOP, "top")
end)

Check.test("it runs level round the top for its last LevelTurn", function()
	local climb = Spire.climbSweep(SHAPE, TOP)
	Check.near(Spire.sweep(SHAPE, TOP), climb + 2 * math.pi * 0.25, "sweep")
	Check.near(Spire.heightAt(SHAPE, TOP, Spire.sweep(SHAPE, TOP)), TOP, "end")
end)

Check.test("it narrows from StartWidth to EndWidth, holding that on the level", function()
	Check.near(Spire.widthAt(SHAPE, TOP, 0), 20, "start")
	Check.near(Spire.widthAt(SHAPE, TOP, Spire.climbSweep(SHAPE, TOP) / 2), 15.5, "halfway")
	Check.near(Spire.widthAt(SHAPE, TOP, Spire.climbSweep(SHAPE, TOP)), 11, "top")
	Check.near(Spire.widthAt(SHAPE, TOP, Spire.sweep(SHAPE, TOP)), 11, "on the level")
end)

Check.test("the lane clears the corners of the rock beside it all the way up", function()
	local sweep = Spire.sweep(SHAPE, TOP)
	for i = 0, 1000 do
		local along = sweep * i / 1000
		local y = Spire.heightAt(SHAPE, TOP, along)
		Check.eq(Spire.innerAt(SHAPE, TOP, along) >= cornerAt(y), true, `at {along}`)
	end
end)

Check.test("the lane's inner edge never moves outward, so it never jogs", function()
	local sweep = Spire.sweep(SHAPE, TOP)
	local last = math.huge
	for i = 0, 1000 do
		local inner = Spire.innerAt(SHAPE, TOP, sweep * i / 1000)
		Check.eq(inner <= last + 1e-9, true, `at {i}`)
		last = inner
	end
end)

Check.test("each turn leaves room over the car under the turn above", function()
	Check.eq(SHAPE.Ledge.Pitch - SHAPE.Ledge.Thickness >= 30, true)
end)

Check.test("the deck reaches inside the rock at every height", function()
	Check.eq(SHAPE.Ledge.Into < SHAPE.TopWidth / 2, true)
end)

Check.test("rows run from inside the rock, across the lane, to the open edge", function()
	local along = 3
	local rows = Spire.rowsAt(SHAPE, TOP, along)
	local inner = Spire.innerAt(SHAPE, TOP, along)
	local width = Spire.widthAt(SHAPE, TOP, along)
	Check.eq(#rows, 4)
	Check.near(rows[1], 18, "in the rock")
	Check.near(rows[2], inner, "lane's inside")
	Check.near(rows[3], inner + width / 2, "lane's middle")
	Check.near(rows[4], inner + width, "open edge")
end)

Check.test("a point goes round from Start, the way the sweep turns", function()
	local x, y, z = Spire.point(SHAPE, TOP, 50, 0)
	Check.near(x, -50, "x at the start")
	Check.near(y, 0, "y at the start")
	Check.near(z, 0, "z at the start")
	x, y, z = Spire.point(SHAPE, TOP, 50, math.pi / 2)
	Check.near(x, 0, "x a quarter on", 1e-6)
	Check.near(y, 12.5, "y a quarter on")
	Check.near(z, 50, "z a quarter on", 1e-6)
end)

Check.finish("Spire")
