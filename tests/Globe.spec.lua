--!strict
local Check = require("./Check")
local Globe = require("../src/shared/Globe")

local SHAPE: Globe.Shape = {
	Radius = 250,
	Thickness = 4,
	Slices = 96,
	Bands = 48,
	EquatorBands = 2,
	MeridianSlices = 2,
	HatchBands = 3,
	Windows = { Count = 8, Slices = 3, Bands = 3, Above = 5 },
}

Check.test("band 0 starts at the bottom pole and band Bands ends at the top", function()
	local x, y, z = Globe.point(SHAPE, 0, 17)
	Check.near(x, 0, "x", 1e-9)
	Check.near(y, -250, "y")
	Check.near(z, 0, "z", 1e-9)
	local _, top = Globe.point(SHAPE, 48, 5)
	Check.near(top, 250, "top")
end)

Check.test("slices go round from +X toward +Z on the equator", function()
	local x, y, z = Globe.point(SHAPE, 24, 0)
	Check.near(x, 250)
	Check.near(y, 0, "y", 1e-9)
	Check.near(z, 0, "z", 1e-9)
	x, _, z = Globe.point(SHAPE, 24, 24)
	Check.near(x, 0, "a quarter round x", 1e-9)
	Check.near(z, 250, "a quarter round z")
end)

Check.test("the equator stripe is the bands either side of the middle", function()
	for _, band in { 23, 24 } do
		Check.eq(Globe.kind(SHAPE, band, 10), "equator", `band {band}`)
	end
	Check.eq(Globe.kind(SHAPE, 22, 10), "plain")
	Check.eq(Globe.kind(SHAPE, 25, 10), "plain")
end)

Check.test("the meridian stripe is the slices either side of a quarter and three quarters round", function()
	for _, slice in { 23, 24, 71, 72 } do
		Check.eq(Globe.kind(SHAPE, 10, slice), "meridian", `slice {slice}`)
		Check.eq(Globe.kind(SHAPE, 40, slice), "meridian", `slice {slice} up top`)
	end
	for _, slice in { 22, 25, 70, 73, 0, 47, 48 } do
		Check.eq(Globe.kind(SHAPE, 10, slice), "plain", `slice {slice}`)
	end
	Check.eq(Globe.kind(SHAPE, 24, 24), "equator", "the equator crosses over it")
end)

Check.test("the hatch is the bottom HatchBands bands all the way round", function()
	for _, slice in { 0, 23, 50, 95 } do
		for band = 0, 2 do
			Check.eq(Globe.kind(SHAPE, band, slice), "hatch", `band {band} slice {slice}`)
		end
		Check.eq(Globe.kind(SHAPE, 3, slice) == "hatch", false, `band 3 slice {slice}`)
	end
	Check.near(Globe.hatchRadius(SHAPE), 250 * math.sin(math.rad(11.25)))
end)

Check.test("windows are Count blocks of Slices by Bands, Above bands over the equator, off the meridian", function()
	local count = 0
	local bands: { [number]: boolean } = {}
	for band = 0, 47 do
		for slice = 0, 95 do
			if Globe.kind(SHAPE, band, slice) == "window" then
				count += 1
				bands[band] = true
			end
		end
	end
	Check.eq(count, 8 * 3 * 3)
	Check.eq(bands[29] and bands[30] and bands[31], true, "bands 29 to 31")
	Check.eq(bands[28] or bands[32], nil, "no others")
	-- Evenly round: the first is centered on slice 6, an eighth of the way.
	Check.eq(Globe.kind(SHAPE, 30, 5), "window")
	Check.eq(Globe.kind(SHAPE, 30, 7), "window")
	Check.eq(Globe.kind(SHAPE, 30, 8), "plain")
	Check.eq(Globe.kind(SHAPE, 30, 17), "window", "the next, 12 slices on")
end)

local function dot(ax: number, ay: number, az: number, bx: number, by: number, bz: number): number
	return ax * bx + ay * by + az * bz
end

Check.test("a plank's inner face holds its four corners and faces in", function()
	for _, at in { { 0, 0 }, { 1, 30 }, { 23, 7 }, { 24, 7 }, { 40, 90 }, { 47, 50 } } do
		local band, slice = at[1], at[2]
		local plank = Globe.plank(SHAPE, band, slice)
		local label = `band {band} slice {slice}`
		-- Square, unit axes, right x up pointing out.
		Check.near(dot(plank.rx, plank.ry, plank.rz, plank.ux, plank.uy, plank.uz), 0, label .. " square", 1e-9)
		Check.near(dot(plank.rx, plank.ry, plank.rz, plank.rx, plank.ry, plank.rz), 1, label .. " unit", 1e-9)
		local ox = plank.ry * plank.uz - plank.rz * plank.uy
		local oy = plank.rz * plank.ux - plank.rx * plank.uz
		local oz = plank.rx * plank.uy - plank.ry * plank.ux
		Check.eq(dot(ox, oy, oz, plank.x, plank.y, plank.z) > 0, true, label .. " out")
		for _, corner in { { 0, 0 }, { 0, 1 }, { 1, 0 }, { 1, 1 } } do
			local cx, cy, cz = Globe.point(SHAPE, band + corner[1], slice + corner[2])
			local dx, dy, dz = cx - plank.x, cy - plank.y, cz - plank.z
			Check.near(dot(dx, dy, dz, ox, oy, oz), 0, label .. " corner on the face", 1e-6)
			Check.eq(
				math.abs(dot(dx, dy, dz, plank.rx, plank.ry, plank.rz)) <= plank.width / 2 + 1e-6,
				true,
				label .. " across"
			)
			Check.eq(
				math.abs(dot(dx, dy, dz, plank.ux, plank.uy, plank.uz)) <= plank.height / 2 + 1e-6,
				true,
				label .. " up"
			)
		end
	end
end)

Check.test("a plank is as wide as its wider edge and as tall as from edge to edge", function()
	local plank = Globe.plank(SHAPE, 30, 0)
	local step = 2 * math.pi / 96
	local lower = math.cos(math.rad(-90 + 30 * 3.75))
	Check.near(plank.width, 2 * 250 * lower * math.sin(step / 2), "the edge nearer the equator")
	local x0, y0, z0 = Globe.point(SHAPE, 30, 0)
	local x1, y1, z1 = Globe.point(SHAPE, 31, 0)
	local edge = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2 + (z1 - z0) ^ 2)
	Check.eq(
		plank.height > edge * math.cos(step / 2) - 1e-6 and plank.height < edge,
		true,
		"between the edge midpoints"
	)
end)

Check.test("inside is within Radius and the margin of the middle", function()
	Check.eq(Globe.inside(SHAPE, 0, 0, 0, 4), true)
	Check.eq(Globe.inside(SHAPE, 0, -253, 0, 4), true)
	Check.eq(Globe.inside(SHAPE, 175, 175, 0, 4), true)
	Check.eq(Globe.inside(SHAPE, 0, 0, 255, 4), false)
	Check.eq(Globe.inside(SHAPE, 190, 190, 0, 4), false)
end)

Check.finish("Globe")
