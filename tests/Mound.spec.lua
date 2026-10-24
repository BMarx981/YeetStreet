--!strict
local Check = require("./Check")
local Mound = require("../src/shared/Mound")

Check.test("the mound runs from its top down to the grass", function()
	Check.near(Mound.height(0, 5, 8), 8, "top ring at the top's edge")
	Check.near(Mound.height(5, 5, 8), 0, "last ring on the grass")
	for i = 1, 5 do
		Check.eq(Mound.height(i, 5, 8) < Mound.height(i - 1, 5, 8), true, `ring {i} lower`)
	end
end)

Check.test("the mound eases in at the grass and at the top, steepest between", function()
	local drops = {}
	for i = 1, 6 do
		drops[i] = Mound.height(i - 1, 6, 8) - Mound.height(i, 6, 8)
	end
	Check.eq(drops[1] < drops[3], true, "gentle at the top")
	Check.eq(drops[6] < drops[4], true, "gentle at the grass")
	Check.near(drops[1], drops[6], "the same both ends")
end)

-- How far a point is from the rectangle halfX by halfZ round the middle.
local function fromRect(p: Mound.Point, halfX: number, halfZ: number): number
	local dx = math.max(math.abs(p.x) - halfX, 0)
	local dz = math.max(math.abs(p.z) - halfZ, 0)
	return math.sqrt(dx * dx + dz * dz)
end

Check.test("a ring goes round the top the same distance out all the way", function()
	local ring = Mound.ring(7, 22, 12, 2)
	Check.eq(#ring, 12, "steps + 1 points round each corner")
	for i, p in ring do
		Check.near(fromRect(p, 7, 22), 12, `point {i}`, 1e-6)
	end
end)

Check.test("the first ring is the top's own corners", function()
	local ring = Mound.ring(7, 22, 0, 2)
	for i, p in ring do
		Check.near(math.abs(p.x), 7, `x {i}`)
		Check.near(math.abs(p.z), 22, `z {i}`)
	end
end)

Check.test("rings go round the same way, so their points line up ring to ring", function()
	local inner, outer = Mound.ring(7, 22, 0, 2), Mound.ring(7, 22, 10, 2)
	local area = 0
	for i = 1, #outer do
		local a, b = outer[i], outer[i % #outer + 1]
		area += a.x * b.z - b.x * a.z
	end
	Check.eq(area > 0, true, "counterclockwise in x, z")
	for i = 1, #outer do
		local dx, dz = outer[i].x - inner[i].x, outer[i].z - inner[i].z
		Check.near(math.sqrt(dx * dx + dz * dz), 10, `point {i} straight out from the one inside it`)
	end
end)

Check.finish("Mound")
