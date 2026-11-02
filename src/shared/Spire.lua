--!strict
-- Spire (ModuleScript) -> ReplicatedStorage.Spire
-- The shape of the ledge that winds up Dino Valley's rock spire, from the
-- ground to the top. Pure, see InputAxes; Parks.Dino builds it.
--
-- `along` is radians round the ledge from its start, on the side Start
-- radians round from +X toward -Z. It climbs Pitch studs a turn up to `top`,
-- where a flat platform PlatformRadius from the middle carries on round for
-- PlatformTurn of a turn. The rest of the turn is left open, a notch for the
-- end of the climb to rise through. The lane is the part a car drives:
-- its inner edge stays clear of the corners of the rock beside it (the tiers
-- are square and turned), and it narrows from StartWidth to EndWidth over the
-- climb. The deck carries on inward past the lane to Into from the middle,
-- inside the rock, so no hole opens between the corners.

local Spire = {}

export type Ledge = {
	Pitch: number,
	StartWidth: number,
	EndWidth: number,
	StepsPerTurn: number,
	Thickness: number,
	Clear: number, -- how far the lane stays off the rock's corners
	Into: number,
	PlatformRadius: number,
	PlatformTurn: number,
	Start: number,
}

export type Shape = {
	Height: number,
	Tiers: number,
	BaseWidth: number,
	TopWidth: number,
	Ledge: Ledge,
}

local TAU = 2 * math.pi

-- Radians the ledge turns getting up to `top`.
function Spire.climbSweep(shape: Shape, top: number): number
	return TAU * top / shape.Ledge.Pitch
end

-- Radians the whole ledge turns, with its platform.
function Spire.sweep(shape: Shape, top: number): number
	return Spire.climbSweep(shape, top) + TAU * shape.Ledge.PlatformTurn
end

function Spire.heightAt(shape: Shape, top: number, along: number): number
	return math.min(shape.Ledge.Pitch * along / TAU, top)
end

-- How wide the lane is `along` radians round.
function Spire.widthAt(shape: Shape, top: number, along: number): number
	local L = shape.Ledge
	local t = math.clamp(along / Spire.climbSweep(shape, top), 0, 1)
	return L.StartWidth + (L.EndWidth - L.StartWidth) * t
end

-- How far the lane's inner edge is from the middle. Rock is widest at the
-- bottom of the tier below, so reading the tiers one lower keeps a smooth
-- edge outside the corners of the tier beside it.
function Spire.innerAt(shape: Shape, top: number, along: number): number
	local tier = math.clamp(Spire.heightAt(shape, top, along) * shape.Tiers / shape.Height - 1, 0, shape.Tiers - 1)
	local width = shape.BaseWidth + (shape.TopWidth - shape.BaseWidth) * tier / (shape.Tiers - 1)
	return width / 2 * math.sqrt(2) + shape.Ledge.Clear
end

-- The radii where the deck's rows of planks meet, from inside the rock,
-- across the lane, to the open edge.
function Spire.rowsAt(shape: Shape, top: number, along: number): { number }
	local inner = Spire.innerAt(shape, top, along)
	local width = Spire.widthAt(shape, top, along)
	return { shape.Ledge.Into, inner, inner + width / 2, inner + width }
end

-- The radii the platform's planks run between.
function Spire.platformRows(shape: Shape): { number }
	return { shape.Ledge.Into, shape.Ledge.PlatformRadius }
end

-- A point on the deck, `radius` from the middle, as x, y, z from the foot.
function Spire.point(shape: Shape, top: number, radius: number, along: number): (number, number, number)
	local angle = shape.Ledge.Start + along
	return radius * math.cos(angle), Spire.heightAt(shape, top, along), -radius * math.sin(angle)
end

return Spire
