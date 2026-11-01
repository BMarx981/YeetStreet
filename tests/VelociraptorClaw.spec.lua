--!strict
local Check = require("./Check")
local Claw = require("../src/shared/VelociraptorClaw")

local FOOT = { x = 2.2, y = -1, z = -0.5, sx = 1.2, sy = 2, sz = 2.4 }

Check.test("the root sits inside the outside front of each foot", function()
	for _, side in { -1, 1 } do
		local foot = table.clone(FOOT)
		foot.x *= side
		local root = Claw.root(side, foot)
		Check.eq(math.abs(root.x - foot.x) < foot.sx / 2, true, "inside the foot")
		Check.eq(root.x * side > foot.x * side, true, "outside toe")
		Check.eq(root.y > foot.y - foot.sy / 2, true, "above the sole")
		Check.eq(root.z > foot.z - foot.sz / 2 and root.z < foot.z, true, "embedded behind the toes")
	end
end)

Check.test("the claw stays above the sole and hooks forward and down", function()
	local root = Claw.root(1, FOOT)
	local mesh = Claw.shape(root)
	local highest = -math.huge
	for _, p in mesh.vertices do
		Check.eq(p.y > FOOT.y - FOOT.sy / 2, true, "clear of the ground")
		highest = math.max(highest, p.y)
	end
	local tip = mesh.vertices[#mesh.vertices]
	Check.eq(tip.z < root.z - 1, true, "hooks forward")
	Check.eq(tip.y < highest - 0.5, true, "hooks down")
	Check.near(tip.x, root.x, "tip narrows to a point")
end)

Check.test("the blade tapers in thickness toward a single tip", function()
	local mesh = Claw.shape(Claw.root(1))
	local lastWidth = math.huge
	for i = 1, #mesh.vertices - 1, 4 do
		local width = mesh.vertices[i + 2].x - mesh.vertices[i + 3].x
		Check.eq(width > 0 and width < lastWidth, true, "each section is thinner")
		lastWidth = width
	end
end)

Check.test("shallow feet still have an embedded root and ground clearance", function()
	for _, height in { 0.2, 0.4, 0.8 } do
		local foot = table.clone(FOOT)
		foot.sy = height
		local mesh = Claw.shape(Claw.root(1, foot))
		local bottom = math.huge
		for _, p in mesh.vertices do
			bottom = math.min(bottom, p.y)
		end
		Check.eq(bottom > foot.y - height / 2, true, "above the sole")
		Check.eq(mesh.vertices[2].y < foot.y + height / 2, true, "root overlaps the foot")
	end
end)

Check.test("unnamed feet retain the original root as a fallback", function()
	local root = Claw.root(-1)
	Check.near(root.x, -Claw.Side)
	Check.near(root.y, Claw.Root[1])
	Check.near(root.z, Claw.Root[2] + Claw.Back)
end)

Check.test("the blade is a closed surface with no degenerate triangles", function()
	local mesh = Claw.shape(Claw.root(1))
	local edges: { [string]: number } = {}
	local winding: { [string]: number } = {}
	for _, face in mesh.faces do
		local a, b, c = mesh.vertices[face[1]], mesh.vertices[face[2]], mesh.vertices[face[3]]
		local ux, uy, uz = b.x - a.x, b.y - a.y, b.z - a.z
		local vx, vy, vz = c.x - a.x, c.y - a.y, c.z - a.z
		local area = (uy * vz - uz * vy) ^ 2 + (uz * vx - ux * vz) ^ 2 + (ux * vy - uy * vx) ^ 2
		Check.eq(area > 1e-10, true, "nonzero triangle area")
		for i = 1, 3 do
			local p, q = face[i], face[i % 3 + 1]
			local key = `{math.min(p, q)},{math.max(p, q)}`
			edges[key] = (edges[key] or 0) + 1
			winding[key] = (winding[key] or 0) + if p < q then 1 else -1
		end
	end
	for key, count in edges do
		Check.eq(count, 2, `closed edge {key}`)
		Check.eq(winding[key], 0, `consistent winding {key}`)
	end
end)

Check.test("both claws mirror one another", function()
	local left = Claw.shape(Claw.root(-1))
	local right = Claw.shape(Claw.root(1))
	local function key(x: number, y: number, z: number): string
		return string.format("%.5f,%.5f,%.5f", x, y, z)
	end
	local mirrored: { [string]: boolean } = {}
	for _, p in right.vertices do
		mirrored[key(-p.x, p.y, p.z)] = true
	end
	for _, p in left.vertices do
		Check.eq(mirrored[key(p.x, p.y, p.z)], true, "matching mirrored vertex")
	end
end)

Check.finish("VelociraptorClaw")
