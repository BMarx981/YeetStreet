--!strict
-- Volcano (ModuleScript) -> ReplicatedStorage.Volcano
-- The shape of Dino Valley's volcano: a hollow cone of stacked tiers, each a
-- ring of straight blocks round its middle, stepping in from the base to the
-- rim. Each ring is a polygon whose blocks meet at their outside corners, so
-- the outside is closed; inside they overlap, hidden. The tube that climbs
-- inside comes in at the foot through a slot: blocks of the lower tiers on
-- its line in front are left out. Pure, see InputAxes.
--
-- Coordinates are from the volcano's middle on the ground, with its front
-- toward -Z. A block's yaw turns it like CFrame.Angles(0, yaw, 0), so its
-- local Z points out from the middle: a block at yaw 0 sits on +Z.

local Volcano = {}

export type Cone = {
	BaseRadius: number, -- outside of the bottom tier
	TopRadius: number, -- outside of the top tier
	Height: number, -- to the rim
	TierHeight: number, -- at most
	Shell: number, -- thickness of each tier, in from its outside
}

export type Tier = {
	bottom: number,
	height: number,
	outer: number,
	inner: number,
}

export type Block = {
	yaw: number, -- radians
	x: number, -- middle
	z: number,
	width: number, -- across, along its local X
	depth: number, -- out from the middle, along its local Z
}

-- Where the tube comes in: a band X along local X, Half each side, in front
-- (local Z below 0), up to Top.
export type Slot = {
	X: number,
	Half: number,
	Top: number,
}

-- A footprint seen from above (x1 < x2, z1 < z2).
export type Rect = { x1: number, x2: number, z1: number, z2: number }

-- A piece of the crater floor, rock or lava.
export type FloorPiece = {
	x1: number,
	x2: number,
	z1: number,
	z2: number,
	rock: boolean,
}

-- The tiers from the ground up, all the same height, at most TierHeight.
function Volcano.tiers(cone: Cone): { Tier }
	local count = math.ceil(cone.Height / cone.TierHeight)
	local height = cone.Height / count
	local tiers: { Tier } = {}
	for i = 1, count do
		local t = if count > 1 then (i - 1) / (count - 1) else 0
		local outer = cone.BaseRadius + (cone.TopRadius - cone.BaseRadius) * t
		table.insert(tiers, { bottom = (i - 1) * height, height = height, outer = outer, inner = outer - cone.Shell })
	end
	return tiers
end

-- A ring of blocks at most `blockWidth` across, whose outside corners lie on
-- `outer` and inside faces on `inner`, going round with yaw.
function Volcano.ring(outer: number, inner: number, blockWidth: number): { Block }
	local count = math.max(3, math.ceil(2 * math.pi * outer / blockWidth))
	local half = math.pi / count
	local face = outer * math.cos(half)
	local width = 2 * outer * math.sin(half)
	local depth = face - inner
	local middle = (face + inner) / 2
	local blocks: { Block } = {}
	for k = 1, count do
		local yaw = (k - 1) * 2 * half
		table.insert(blocks, {
			yaw = yaw,
			x = middle * math.sin(yaw),
			z = middle * math.cos(yaw),
			width = width,
			depth = depth,
		})
	end
	return blocks
end

-- How far across (along X) a block reaches, from and to.
function Volcano.spanX(block: Block): (number, number)
	local c, s = math.cos(block.yaw), math.sin(block.yaw)
	local reach = math.abs(block.width / 2 * c) + math.abs(block.depth / 2 * s)
	return block.x - reach, block.x + reach
end

-- Whether a block of `tier` reaches into the slot, so it is left out.
function Volcano.inSlot(block: Block, tier: Tier, slot: Slot): boolean
	if tier.bottom >= slot.Top or block.z >= 0 then
		return false
	end
	local from, to = Volcano.spanX(block)
	return to > slot.X - slot.Half and from < slot.X + slot.Half
end

-- Whether a block's yaw is within `half` radians of `middle`, either way.
function Volcano.inWedge(block: Block, middle: number, half: number): boolean
	local off = (block.yaw - middle + math.pi) % (2 * math.pi) - math.pi
	return math.abs(off) <= half
end

-- The lip of a vent: a ramp rising toward the front (-Z) from its foot at
-- `footZ`, round `radius` up to `angle` degrees. Returns the lip's z and
-- how far it is above the foot.
function Volcano.lip(footZ: number, radius: number, angle: number): (number, number)
	local a = math.rad(angle)
	return footZ - radius * math.sin(a), radius * (1 - math.cos(a))
end

-- From x1 to x2 in equal columns at most `width` wide, left to right.
function Volcano.columns(x1: number, x2: number, width: number): { { x1: number, x2: number } }
	local columns = {}
	if x2 - x1 <= 1e-9 then
		return columns
	end
	local count = math.ceil((x2 - x1) / width - 1e-9)
	for i = 1, count do
		table.insert(columns, { x1 = x1 + (x2 - x1) * (i - 1) / count, x2 = x1 + (x2 - x1) * i / count })
	end
	return columns
end

-- The crater floor inside the circle `radius` round the middle: strips
-- along Z at most `stripWidth` wide, each out to where the circle crosses
-- its edge nearer the middle, so none leaves a gap at the wall, split where
-- they meet `hatch` (left open for the tube) and `path` (rock; the rest is
-- lava).
function Volcano.floor(radius: number, stripWidth: number, hatch: Rect, path: Rect): { FloorPiece }
	-- Strip edges: the circle's sides, and the hatch's and path's sides.
	local edges = { -radius, radius }
	for _, x in { hatch.x1, hatch.x2, path.x1, path.x2 } do
		if x > -radius and x < radius then
			table.insert(edges, x)
		end
	end
	table.sort(edges)
	local pieces: { FloorPiece } = {}
	for i = 1, #edges - 1 do
		local from, to = edges[i], edges[i + 1]
		local count = math.ceil((to - from) / stripWidth - 1e-9)
		for j = 1, count do
			local x1 = from + (to - from) * (j - 1) / count
			local x2 = from + (to - from) * j / count
			local x = (x1 + x2) / 2
			local nearest = if x1 < 0 and x2 > 0 then 0 else math.min(math.abs(x1), math.abs(x2))
			local reach = math.sqrt(radius * radius - nearest * nearest)
			local inHatch = x > hatch.x1 and x < hatch.x2
			local inPath = x > path.x1 and x < path.x2
			-- Cuts along the strip, from front to back.
			local cuts = { -reach, reach }
			for _, z in { inHatch and hatch.z1, inHatch and hatch.z2, inPath and path.z1, inPath and path.z2 } do
				if z and z > -reach and z < reach then
					table.insert(cuts, z)
				end
			end
			table.sort(cuts)
			for k = 1, #cuts - 1 do
				local z1, z2 = cuts[k], cuts[k + 1]
				local z = (z1 + z2) / 2
				if z2 - z1 > 1e-9 and not (inHatch and z > hatch.z1 and z < hatch.z2) then
					table.insert(pieces, {
						x1 = x1,
						x2 = x2,
						z1 = z1,
						z2 = z2,
						rock = inPath and z > path.z1 and z < path.z2,
					})
				end
			end
		end
	end
	return pieces
end

return Volcano
