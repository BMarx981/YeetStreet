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

-- Whether a block of `tier` reaches into the slot, so it is left out.
function Volcano.inSlot(block: Block, tier: Tier, slot: Slot): boolean
	if tier.bottom >= slot.Top or block.z >= 0 then
		return false
	end
	local c, s = math.cos(block.yaw), math.sin(block.yaw)
	local reach = math.abs(block.width / 2 * c) + math.abs(block.depth / 2 * s)
	return block.x + reach > slot.X - slot.Half and block.x - reach < slot.X + slot.Half
end

return Volcano
