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

Check.finish("Volcano")
