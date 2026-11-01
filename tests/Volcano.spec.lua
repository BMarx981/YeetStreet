--!strict
local Check = require("./Check")
local Volcano = require("../src/shared/Volcano")

local CONE: Volcano.Cone = { BaseRadius = 400, TopRadius = 230, Height = 270, TierHeight = 18, Shell = 40 }

-- The point a block's corner sits at, `a` and `b` each -1 or 1 across and out.
local function corner(block: Volcano.Block, a: number, b: number): (number, number)
	local c, s = math.cos(block.yaw), math.sin(block.yaw)
	local across, out = a * block.width / 2, b * block.depth / 2
	return block.x + across * c + out * s, block.z - across * s + out * c
end

Check.test("tiers stack from the ground to the rim with no gaps", function()
	local tiers = Volcano.tiers(CONE)
	Check.eq(#tiers, 15, "270 over 18-high tiers")
	Check.near(tiers[1].bottom, 0, "first on the ground")
	for i = 2, #tiers do
		Check.near(tiers[i].bottom, tiers[i - 1].bottom + tiers[i - 1].height, `tier {i} on the last`)
	end
	local top = tiers[#tiers]
	Check.near(top.bottom + top.height, 270, "last reaches the rim")
end)

Check.test("tiers step in evenly from the base radius to the top radius, Shell thick", function()
	local tiers = Volcano.tiers(CONE)
	Check.near(tiers[1].outer, 400, "bottom")
	Check.near(tiers[#tiers].outer, 230, "top")
	for i, tier in tiers do
		Check.near(tier.inner, tier.outer - 40, `tier {i} inner`)
		if i > 1 then
			Check.near(tiers[i - 1].outer - tier.outer, 170 / 14, `tier {i} steps in`)
		end
	end
end)

Check.test("a part tier height rounds the count up and evens them out", function()
	local tiers = Volcano.tiers({ BaseRadius = 100, TopRadius = 50, Height = 100, TierHeight = 30, Shell = 10 })
	Check.eq(#tiers, 4)
	Check.near(tiers[1].height, 25)
end)

Check.test("a ring's blocks are no wider than asked and meet at their outside corners", function()
	local blocks = Volcano.ring(400, 360, 50)
	Check.eq(#blocks, math.ceil(2 * math.pi * 400 / 50), "count")
	for k, block in blocks do
		Check.eq(block.width <= 50, true, `block {k} width {block.width}`)
		local nextBlock = blocks[k % #blocks + 1]
		local ax, az = corner(block, 1, 1)
		local bx, bz = corner(nextBlock, -1, 1)
		Check.near(ax, bx, `block {k} corner x`, 1e-6)
		Check.near(az, bz, `block {k} corner z`, 1e-6)
		Check.near(math.sqrt(ax * ax + az * az), 400, `block {k} corner on the circle`, 1e-6)
	end
end)

Check.test("a ring's blocks' inside faces lie on its inner radius", function()
	for k, block in Volcano.ring(300, 240, 45) do
		local c, s = math.cos(block.yaw), math.sin(block.yaw)
		local inside = (block.x * s + block.z * c) - block.depth / 2
		Check.near(inside, 240, `block {k} inside face`, 1e-6)
	end
end)

Check.test("a block is in the slot only in front, across its line and under its top", function()
	local slot: Volcano.Slot = { X = 80, Half = 56, Top = 72 }
	local low: Volcano.Tier = { bottom = 0, height = 18, outer = 400, inner = 360 }
	local high: Volcano.Tier = { bottom = 72, height = 18, outer = 380, inner = 340 }
	local front, back, aside = nil, nil, nil
	for _, block in Volcano.ring(400, 360, 50) do
		local z = block.z
		if z < 0 and math.abs(block.x - 80) < 20 then
			front = block
		elseif z > 0 and math.abs(block.x - 80) < 20 then
			back = block
		elseif z < 0 and block.x < -150 then
			aside = block
		end
	end
	assert(front and back and aside, "found test blocks")
	Check.eq(Volcano.inSlot(front, low, slot), true, "front, low")
	Check.eq(Volcano.inSlot(front, high, slot), false, "front, above the top")
	Check.eq(Volcano.inSlot(back, low, slot), false, "behind")
	Check.eq(Volcano.inSlot(aside, low, slot), false, "off the line")
end)

Check.test("a block whose corner just reaches the slot's edge is in it", function()
	local slot: Volcano.Slot = { X = 0, Half = 10, Top = 50 }
	local tier: Volcano.Tier = { bottom = 0, height = 10, outer = 100, inner = 90 }
	local block: Volcano.Block = { yaw = math.pi, x = 0, z = -95, width = 40, depth = 10 }
	Check.eq(Volcano.inSlot(block, tier, slot), true, "straddles the line")
	local beside: Volcano.Block = { yaw = math.pi, x = 29.9, z = -95, width = 40, depth = 10 }
	Check.eq(Volcano.inSlot(beside, tier, slot), true, "corner 0.1 inside the edge")
	local clear: Volcano.Block = { yaw = math.pi, x = 30.1, z = -95, width = 40, depth = 10 }
	Check.eq(Volcano.inSlot(clear, tier, slot), false, "corner 0.1 past the edge")
end)

Check.test("columns split a span evenly, none wider than asked", function()
	local columns = Volcano.columns(10, 45, 10)
	Check.eq(#columns, 4)
	Check.near(columns[1].x1, 10)
	Check.near(columns[4].x2, 45)
	for i, column in columns do
		Check.near(column.x2 - column.x1, 8.75, `column {i}`)
		if i > 1 then
			Check.near(column.x1, columns[i - 1].x2, `column {i} meets the last`)
		end
	end
	Check.eq(#Volcano.columns(5, 5, 10), 0, "an empty span")
	Check.eq(#Volcano.columns(6, 5, 10), 0, "a backward span")
end)

Check.test("a boost zone starts clear of the mouth and reaches past the lip", function()
	local vent = { Run = 4, Radius = 12, Angle = 70, ZoneFrom = 10, ZonePast = 10, ZoneWidth = 120, ZoneHeight = 120 }
	local zone = Volcano.boostZone(-100, -80, 200, vent)
	Check.near(zone.z2, -90, "starts ZoneFrom past the mouth")
	local lipZ = Volcano.lip(-84, 12, 70)
	Check.near(zone.z1, lipZ - 10, "ends ZonePast past the lip")
	Check.near(zone.x1, -160)
	Check.near(zone.x2, -40)
	Check.near(zone.y1, 200)
	Check.near(zone.y2, 320)
end)

Check.test("the point inside a boost zone is inside, the mouth is not", function()
	local zone = { x1 = -160, x2 = -40, y1 = 200, y2 = 320, z1 = -115, z2 = -90 }
	Check.eq(Volcano.inZone(zone, -100, 210, -100), true, "on the ramp")
	Check.eq(Volcano.inZone(zone, -100, 300, -100), true, "up in the air")
	Check.eq(Volcano.inZone(zone, -100, 210, -85), false, "still at the mouth")
	Check.eq(Volcano.inZone(zone, -100, 330, -100), false, "above it")
	Check.eq(Volcano.inZone(zone, -30, 210, -100), false, "beside it")
end)

Check.test("the eruption view eases in, holds, and eases out", function()
	local W = { EaseIn = 0.5, Hold = 3, EaseOut = 1 }
	Check.near(Volcano.watchWeight(W, 0), 0, "at launch")
	Check.near(Volcano.watchWeight(W, 0.25), 0.5, "easing in")
	Check.near(Volcano.watchWeight(W, 1), 1, "holding")
	Check.near(Volcano.watchWeight(W, 4), 0.5, "easing out")
	Check.near(Volcano.watchWeight(W, 5), 0, "over")
end)

Check.test("a lightning bolt runs between its ends, wandering most in the middle", function()
	local top = { x = 0, y = 600, z = 0 }
	local bottom = { x = 100, y = 200, z = 0 }
	local straight = Volcano.bolt(top, bottom, 4, 50, function()
		return 0
	end)
	Check.eq(#straight, 5, "one more point than segments")
	Check.near(straight[3].x, 50, "no wander goes straight")
	Check.near(straight[3].y, 400)

	local wild = Volcano.bolt(top, bottom, 4, 50, function()
		return 1
	end)
	Check.near(wild[1].x, 0, "starts on the top")
	Check.near(wild[1].y, 600)
	Check.near(wild[5].x, 100, "ends on the bottom")
	Check.near(wild[5].y, 200)
	Check.near(wild[3].x, 100, "wanders the whole reach in the middle")
	Check.near(wild[3].z, 50)
	Check.near(wild[3].y, 400, "only sideways")
	Check.eq(wild[2].x - 25 < 50, true, "less near the ends")
end)

Check.test("the eruption view looks halfway between the car and the crater", function()
	-- The car straight ahead along +X, the crater straight down.
	local x, y, z = Volcano.watchLook(10, 0, 0, 0, -300, 0)
	Check.near(x, math.sqrt(0.5))
	Check.near(y, -math.sqrt(0.5))
	Check.near(z, 0)
end)

Check.test("a vent's lip is its radius's arc on from its foot, toward the front", function()
	local z, up = Volcano.lip(-95, 30, 70)
	Check.near(z, -95 - 30 * math.sin(math.rad(70)))
	Check.near(up, 30 * (1 - math.cos(math.rad(70))))
	local flatZ, flatUp = Volcano.lip(-95, 30, 0)
	Check.near(flatZ, -95, "no curve stays at the foot")
	Check.near(flatUp, 0)
end)

Check.test("a block is in a wedge when its yaw is within half the wedge of the middle, either way round", function()
	local function at(degrees: number): Volcano.Block
		return { yaw = math.rad(degrees), x = 0, z = 0, width = 10, depth = 10 }
	end
	local middle, half = math.rad(212), math.rad(30)
	Check.eq(Volcano.inWedge(at(212), middle, half), true, "the middle")
	Check.eq(Volcano.inWedge(at(240), middle, half), true, "near one edge")
	Check.eq(Volcano.inWedge(at(184), middle, half), true, "near the other")
	Check.eq(Volcano.inWedge(at(245), middle, half), false, "past an edge")
	Check.eq(Volcano.inWedge(at(10), math.rad(350), half), true, "across the turn from 360 to 0")
	Check.eq(Volcano.inWedge(at(-10), math.rad(10), half), true, "a negative yaw")
	Check.eq(Volcano.inWedge(at(90), math.rad(10), half), false, "far round")
end)

local HATCH: Volcano.Rect = { x1 = -133, x2 = 133, z1 = 0, z2 = 133 }
local PATH: Volcano.Rect = { x1 = -140, x2 = -60, z1 = -300, z2 = 0 }

local function inRect(rect: Volcano.Rect, x: number, z: number): boolean
	return x > rect.x1 and x < rect.x2 and z > rect.z1 and z < rect.z2
end

Check.test("the crater floor is strips no wider than asked, none in the hatch", function()
	for k, piece in Volcano.floor(238, 12, HATCH, PATH) do
		Check.eq(piece.x2 - piece.x1 <= 12 + 1e-9, true, `piece {k} width {piece.x2 - piece.x1}`)
		local overlapX = piece.x1 < HATCH.x2 and piece.x2 > HATCH.x1
		local overlapZ = piece.z1 < HATCH.z2 and piece.z2 > HATCH.z1
		Check.eq(overlapX and overlapZ, false, `piece {k} in the hatch`)
	end
end)

Check.test(
	"every spot on the crater floor but the hatch is covered once, rock on the path and lava elsewhere",
	function()
		local pieces = Volcano.floor(238, 12, HATCH, PATH)
		for x = -235.5, 235.5, 7 do
			for z = -235.5, 235.5, 7 do
				if x * x + z * z < 238 * 238 and not inRect(HATCH, x, z) then
					local found = {}
					for _, piece in pieces do
						if x > piece.x1 and x < piece.x2 and z > piece.z1 and z < piece.z2 then
							table.insert(found, piece)
						end
					end
					Check.eq(#found, 1, `pieces over {x}, {z}`)
					Check.eq(found[1].rock, inRect(PATH, x, z), `rock at {x}, {z}`)
				end
			end
		end
	end
)

Check.test("the crater floor reaches only a little past its circle", function()
	for k, piece in Volcano.floor(238, 12, HATCH, PATH) do
		for _, x in { piece.x1, piece.x2 } do
			for _, z in { piece.z1, piece.z2 } do
				local r = math.sqrt(x * x + z * z)
				Check.eq(r < 238 + 12, true, `piece {k} corner at {r}`)
			end
		end
	end
end)

Check.finish("Volcano")
