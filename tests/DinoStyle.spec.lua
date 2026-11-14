--!strict
local Check = require("./Check")
local DinoStyle = require("../src/shared/DinoStyle")

local TAIL = { x = 0, y = 0.3, z = 4.5, sx = 2.1, sy = 1.1, sz = 3.2 }

local function widthAt(mesh: DinoStyle.Mesh, z: number): number
	local minX, maxX = math.huge, -math.huge
	for _, v in mesh.vertices do
		if math.abs(v.z - z) < 0.6 then
			minX, maxX = math.min(minX, v.x), math.max(maxX, v.x)
		end
	end
	return maxX - minX
end

Check.test("the tail tapers from its root to one point at the back", function()
	local mesh = DinoStyle.tail(TAIL, 4, { Length = 2, Width = 0.4 })
	local root = DinoStyle.tailRoot(TAIL)
	local tip = mesh.vertices[#mesh.vertices]
	Check.near(tip.z, root.z + TAIL.sz * 2, "reaches back Length tails")
	Check.near(tip.x, TAIL.x, "tip on the center line")
	local count = 0
	for _, v in mesh.vertices do
		if math.abs(v.z - tip.z) < 1e-6 and math.abs(v.y - tip.y) < 1e-6 then
			count += 1
		end
	end
	Check.eq(count, 1, "a single tip, not a blunt end")
	local rootWidth = widthAt(mesh, root.z)
	local middleWidth = widthAt(mesh, root.z + TAIL.sz * 2 * 0.55)
	Check.eq(middleWidth < rootWidth, true, "narrower halfway back")
end)

Check.test("Width sets the root's width as a share of the mesh tail's", function()
	local slim = DinoStyle.tail(TAIL, 10, { Length = 1, Width = 0.25 })
	local wide = DinoStyle.tail(TAIL, 10, { Length = 1, Width = 0.4 })
	local root = DinoStyle.tailRoot(TAIL).z
	Check.near(widthAt(slim, root), TAIL.sx * 0.25 * 2)
	Check.near(widthAt(wide, root), TAIL.sx * 0.4 * 2)
end)

Check.test("the root is never wider than the body allows", function()
	local mesh = DinoStyle.tail(TAIL, 2, { Length = 1, Width = 0.4 })
	Check.near(widthAt(mesh, DinoStyle.tailRoot(TAIL).z), 2 * 0.3 * 2)
end)

Check.test("the tail starts at the front of the mesh's tail, where it meets the body", function()
	local mesh = DinoStyle.tail(TAIL, 4, { Length = 2, Width = 0.4 })
	local root = DinoStyle.tailRoot(TAIL)
	Check.near(root.z, TAIL.z - TAIL.sz / 2)
	Check.near(mesh.vertices[1].z, root.z)
end)

Check.test("the tail sways to both sides and repeats, within its angle", function()
	local period = DinoStyle.TailSway.Period
	local most = math.rad(DinoStyle.TailSway.Degrees)
	Check.near(DinoStyle.tailSway(0), 0, "starts centered")
	Check.near(DinoStyle.tailSway(period / 4), most, "full swing one way")
	Check.near(DinoStyle.tailSway(period * 3 / 4), -most, "full swing the other way")
	Check.near(DinoStyle.tailSway(1.3), DinoStyle.tailSway(1.3 + period), "repeats")
end)

Check.test("every tail has a closed surface without zero-area faces", function()
	for _, mesh in
		{ DinoStyle.tail(TAIL, 6, { Length = 2, Width = 0.28 }), DinoStyle.tail(TAIL, 4, { Length = 2, Width = 0.4 }) }
	do
		local edges: { [string]: number } = {}
		for _, face in mesh.faces do
			local a, b, c = mesh.vertices[face[1]], mesh.vertices[face[2]], mesh.vertices[face[3]]
			local ux, uy, uz = b.x - a.x, b.y - a.y, b.z - a.z
			local vx, vy, vz = c.x - a.x, c.y - a.y, c.z - a.z
			local area = (uy * vz - uz * vy) ^ 2 + (uz * vx - ux * vz) ^ 2 + (ux * vy - uy * vx) ^ 2
			Check.eq(area > 1e-10, true, "nonzero area")
			for i = 1, 3 do
				local p, q = face[i], face[i % 3 + 1]
				local key = `{math.min(p, q)},{math.max(p, q)}`
				edges[key] = (edges[key] or 0) + 1
			end
		end
		for _, count in edges do
			Check.eq(count, 2, "each edge belongs to two faces")
		end
	end
end)

Check.finish("DinoStyle")
