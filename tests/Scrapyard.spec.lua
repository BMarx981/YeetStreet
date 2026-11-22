--!strict
local Check = require("./Check")
local Scrapyard = require("../src/shared/Scrapyard")

Check.test("a gap in the middle leaves a piece on each side", function()
	local pieces = Scrapyard.cutSpan(-100, 100, -20, 30)
	Check.eq(#pieces, 2)
	Check.eq(pieces[1].from, -100)
	Check.eq(pieces[1].to, -20)
	Check.eq(pieces[2].from, 30)
	Check.eq(pieces[2].to, 100)
end)

Check.test("a gap that misses leaves the span whole", function()
	local pieces = Scrapyard.cutSpan(-100, 100, 150, 200)
	Check.eq(#pieces, 1)
	Check.eq(pieces[1].from, -100)
	Check.eq(pieces[1].to, 100)
end)

Check.test("a gap over one end leaves the other side", function()
	local pieces = Scrapyard.cutSpan(-100, 100, 60, 300)
	Check.eq(#pieces, 1)
	Check.eq(pieces[1].from, -100)
	Check.eq(pieces[1].to, 60)
end)

Check.test("a gap over the whole span leaves nothing", function()
	Check.eq(#Scrapyard.cutSpan(-100, 100, -200, 200), 0)
end)

Check.test("the spans can be given either way round", function()
	local pieces = Scrapyard.cutSpan(100, -100, 30, -20)
	Check.eq(#pieces, 2)
	Check.eq(pieces[1].from, -100)
	Check.eq(pieces[2].to, 100)
end)

Check.finish("Scrapyard")
