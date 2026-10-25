--!strict
-- Globe (ModuleScript) -> ReplicatedStorage.Globe
-- The Corkscrew park's globe: a huge closed ball that cars drive round the
-- inside of, with ordinary gravity, so going over the top takes jets. Pure,
-- see InputAxes.
--
-- The shell is flat planks on a grid of Bands from the bottom pole to the
-- top and Slices round. Each plank's inner face is the flat four-cornered
-- piece between its grid points, so the inside is smooth but for folds of
-- one grid step, and each plank is as wide as its wider edge: the extra
-- reaches past its neighbors' faces, outside the ball, out of sight. Paint
-- is which planks are which: the bottom HatchBands are the hatch the tube
-- comes up through, an equator stripe, a meridian stripe through both
-- poles, and windows.
--
-- Points are from the ball's middle, Y up; slices go round from +X toward
-- +Z.

local Globe = {}

export type Windows = {
	Count: number, -- evenly round
	Slices: number, -- each window's width
	Bands: number, -- and height
	Above: number, -- bands from the equator up to the windows' bottom
}

export type Shape = {
	Radius: number, -- to the inside
	Thickness: number,
	Slices: number, -- round; a multiple of 4
	Bands: number, -- bottom to top; even
	EquatorBands: number, -- even
	MeridianSlices: number, -- even
	HatchBands: number,
	Windows: Windows,
}

-- A plank: the middle of its inner face, its axes across (r) and up the
-- band (u), whose cross product points out of the ball, and its size.
export type Plank = {
	x: number,
	y: number,
	z: number,
	rx: number,
	ry: number,
	rz: number,
	ux: number,
	uy: number,
	uz: number,
	width: number,
	height: number,
}

export type Kind = "hatch" | "equator" | "meridian" | "window" | "plain"

-- The grid point at the bottom of `band` and the start of `slice`, on the
-- inside.
function Globe.point(shape: Shape, band: number, slice: number): (number, number, number)
	local lat = -math.pi / 2 + band / shape.Bands * math.pi
	local lon = slice / shape.Slices * 2 * math.pi
	local r = shape.Radius * math.cos(lat)
	return r * math.cos(lon), shape.Radius * math.sin(lat), r * math.sin(lon)
end

function Globe.kind(shape: Shape, band: number, slice: number): Kind
	if band < shape.HatchBands then
		return "hatch"
	end
	local half = shape.Bands // 2
	local equator = shape.EquatorBands // 2
	if band >= half - equator and band < half + equator then
		return "equator"
	end
	local S = shape.Slices
	local meridian = shape.MeridianSlices // 2
	for _, quarter in { S // 4, 3 * S // 4 } do
		if slice >= quarter - meridian and slice < quarter + meridian then
			return "meridian"
		end
	end
	local W = shape.Windows
	local first = half + W.Above
	if band >= first and band < first + W.Bands then
		for k = 0, W.Count - 1 do
			local start = math.floor((k + 0.5) * S / W.Count) - W.Slices // 2
			if (slice - start) % S < W.Slices then
				return "window"
			end
		end
	end
	return "plain"
end

function Globe.plank(shape: Shape, band: number, slice: number): Plank
	local x00, y00, z00 = Globe.point(shape, band, slice)
	local x01, y01, z01 = Globe.point(shape, band, slice + 1)
	local x10, y10, z10 = Globe.point(shape, band + 1, slice)
	local x11, y11, z11 = Globe.point(shape, band + 1, slice + 1)
	local bottom = math.sqrt((x01 - x00) ^ 2 + (y01 - y00) ^ 2 + (z01 - z00) ^ 2)
	local top = math.sqrt((x11 - x10) ^ 2 + (y11 - y10) ^ 2 + (z11 - z10) ^ 2)
	-- Across along the wider edge; at a pole the other one is a point.
	local rx, ry, rz
	if bottom >= top then
		rx, ry, rz = (x01 - x00) / bottom, (y01 - y00) / bottom, (z01 - z00) / bottom
	else
		rx, ry, rz = (x11 - x10) / top, (y11 - y10) / top, (z11 - z10) / top
	end
	-- Up from the bottom edge's middle to the top edge's.
	local bx, by, bz = (x00 + x01) / 2, (y00 + y01) / 2, (z00 + z01) / 2
	local tx, ty, tz = (x10 + x11) / 2, (y10 + y11) / 2, (z10 + z11) / 2
	local height = math.sqrt((tx - bx) ^ 2 + (ty - by) ^ 2 + (tz - bz) ^ 2)
	local ux, uy, uz = (tx - bx) / height, (ty - by) / height, (tz - bz) / height
	local x, y, z = (bx + tx) / 2, (by + ty) / 2, (bz + tz) / 2
	local ox, oy, oz = ry * uz - rz * uy, rz * ux - rx * uz, rx * uy - ry * ux
	if ox * x + oy * y + oz * z < 0 then
		rx, ry, rz = -rx, -ry, -rz
	end
	return {
		x = x,
		y = y,
		z = z,
		rx = rx,
		ry = ry,
		rz = rz,
		ux = ux,
		uy = uy,
		uz = uz,
		width = math.max(bottom, top),
		height = height,
	}
end

-- How far out from under the middle the hatch reaches.
function Globe.hatchRadius(shape: Shape): number
	return shape.Radius * math.sin(shape.HatchBands / shape.Bands * math.pi)
end

-- Whether (x, y, z) from the middle is over the middle of the hatch: within
-- `reach` of under the middle, and under `height` up from the inside's
-- bottom.
function Globe.overHatch(shape: Shape, x: number, y: number, z: number, reach: number, height: number): boolean
	return x * x + z * z < reach * reach and y < -shape.Radius + height
end

-- Whether (x, y, z) from the middle is in the ball, or within `margin` of
-- its inside.
function Globe.inside(shape: Shape, x: number, y: number, z: number, margin: number): boolean
	return x * x + y * y + z * z < (shape.Radius + margin) ^ 2
end

return Globe
