--!strict
local Check = require("./Check")
local Style = require("../src/shared/TriceratopsStyle")

local HEAD = { x = 0, y = 1.5, z = -4, sx = 3.5, sy = 2.4, sz = 3.2 }
local TAIL = { x = 0, y = 0.8, z = 5, sx = 4, sy = 1.2, sz = 4 }

Check.test("the tail has a narrow root and a single tapered tip", function()
	local mesh = Style.tail(TAIL, 6)
	local minX, maxX = math.huge, -math.huge
	for _, v in mesh.vertices do
		minX, maxX = math.min(minX, v.x), math.max(maxX, v.x)
	end
	Check.eq(maxX - minX < TAIL.sx * 0.65, true, "slimmer than the original tail")
	Check.near(mesh.vertices[#mesh.vertices].z, TAIL.z - TAIL.sz / 2 + TAIL.sz * Style.TailLength, "reaches back")
	Check.eq(Style.TailLength > 1, true, "longer than the mesh's tail")
	Check.near(mesh.vertices[1].z, TAIL.z - TAIL.sz / 2, "keeps its attachment")
end)

Check.test("the tail's root is thick enough to meet a narrow body", function()
	local bodyWidth = 2
	local mesh = Style.tail(TAIL, bodyWidth)
	local minX, maxX = math.huge, -math.huge
	for _, v in mesh.vertices do
		minX, maxX = math.min(minX, v.x), math.max(maxX, v.x)
	end
	Check.eq(maxX - minX > bodyWidth * 0.5, true)
end)

Check.test("three forward-leaning horns, with long mirrored brow horns and a short nose horn", function()
	local horns = Style.horns(HEAD)
	Check.eq(#horns, 3)
	for _, horn in horns do
		Check.eq(horn.tilt > 0, true, "leans toward the nose")
		Check.eq(horn.length > 0, true)
	end
	local left, right, nose = horns[1], horns[2], horns[3]
	Check.near(left.x - HEAD.x, -(right.x - HEAD.x), "mirrored roots")
	Check.near(left.y, right.y)
	Check.near(left.z, right.z)
	Check.near(left.length, right.length)
	Check.near(left.splay, -right.splay, "mirrored splay")
	Check.eq(left.x < HEAD.x, true, "left horn on the left")
	Check.near(nose.x, HEAD.x, "nose horn on the center line")
	Check.near(nose.splay, 0)
	Check.eq(nose.length < left.length * 0.6, true, "much shorter nose horn")
	Check.eq(nose.girth > left.girth, true, "stouter nose horn")
	Check.eq(nose.z < left.z, true, "nose horn ahead of the brow horns")
	Check.eq(nose.y < left.y, true, "nose horn on the low snout")
end)

Check.test("the nose cap sits on the center line under the nose horn's root", function()
	local cap = Style.noseCap(HEAD)
	local nose = Style.horns(HEAD)[3]
	Check.near(cap.x, HEAD.x)
	Check.eq(math.abs(nose.z - cap.z) < cap.sz / 2, true, "root within the cap's length")
	Check.eq(nose.y < cap.y + cap.sy / 2, true, "root below the cap's top")
	Check.eq(cap.z - cap.sz / 2 > HEAD.z - HEAD.sz / 2, true, "stays behind the nose tip")
end)

Check.test("horn roots sit inside the head", function()
	for _, horn in Style.horns(HEAD) do
		Check.eq(math.abs(horn.x - HEAD.x) < HEAD.sx / 2, true)
		Check.eq(math.abs(horn.y - HEAD.y) < HEAD.sy / 2, true)
		Check.eq(math.abs(horn.z - HEAD.z) < HEAD.sz / 2, true)
	end
end)

Check.test("horns and eyes grow with the head, so they fit garage previews", function()
	local big = { x = 0, y = 3, z = -8, sx = 7, sy = 4.8, sz = 6.4 }
	local a, b = Style.horns(HEAD)[1], Style.horns(big)[1]
	Check.near(b.length, a.length * 2)
	Check.near(b.x, a.x * 2)
	Check.near(Style.eyes(big)[1].socket.x, Style.eyes(HEAD)[1].socket.x * 2)
end)

Check.test("eyes are mirrored, on the upper face, each ball in front of its socket", function()
	local eyes = Style.eyes(HEAD)
	Check.eq(#eyes, 2)
	Check.near(eyes[1].ball.x - HEAD.x, -(eyes[2].ball.x - HEAD.x), "mirrored")
	for _, eye in eyes do
		Check.eq(eye.ball.z < eye.socket.z, true, "ball pokes out of the socket")
		Check.eq(eye.pupil.z < eye.ball.z, true, "pupil on the ball's front")
		Check.eq(eye.pupil.sy < eye.ball.sy, true, "pupil smaller than the ball")
		Check.eq(eye.ball.sy < eye.socket.sy, true, "socket frames the ball")
		Check.eq(eye.brow.y > eye.ball.y, true, "brow above the ball")
		Check.eq(eye.socket.z < HEAD.z, true, "on the face")
	end
end)

Check.test("the tail has a closed surface without zero-area faces", function()
	for _, mesh in { Style.tail(TAIL, 6) } do
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

Check.finish("TriceratopsStyle")
