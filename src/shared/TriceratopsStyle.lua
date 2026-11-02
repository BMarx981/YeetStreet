--!strict
-- Pure proportions for the mesh triceratops, in hull space (-z forward).
-- Details follow the fitted head and tail, so they also fit garage previews.

local Style = {}

export type Vec = { x: number, y: number, z: number }
export type Bounds = { x: number, y: number, z: number, sx: number, sy: number, sz: number }
export type Mesh = { vertices: { Vec }, faces: { { number } } }
export type Horn = { x: number, y: number, z: number, length: number, girth: number, tilt: number, splay: number }
export type Eye = { socket: Bounds, ball: Bounds, pupil: Bounds, glint: Bounds, brow: Bounds, browRoll: number }

-- Diamond cross sections and one shared point make a faceted, curved spike.
-- The section planes follow the spike's slope.
local function spike(root: Vec, middle: Vec, tip: Vec, width: number, depth: number): Mesh
	local vertices: { Vec } = {}
	local faces: { { number } } = {}
	local dy, dz = tip.y - root.y, tip.z - root.z
	local length = math.sqrt(dy * dy + dz * dz)
	local upY, upZ = math.abs(dz) / length, -dy * math.sign(dz) / length
	local sections = { root, middle }
	for i, center in sections do
		local scale = if i == #sections then 0.6 else 1
		for _, offset in { { width, 0 }, { 0, depth }, { -width, 0 }, { 0, -depth } } do
			table.insert(vertices, {
				x = center.x + offset[1] * scale,
				y = center.y + upY * offset[2] * scale,
				z = center.z + upZ * offset[2] * scale,
			})
		end
	end
	table.insert(vertices, tip)
	for section = 0, #sections - 2 do
		local offset = section * 4
		for i = 1, 4 do
			local a, b = offset + i, offset + i % 4 + 1
			table.insert(faces, { a, b, b + 4 })
			table.insert(faces, { a, b + 4, a + 4 })
		end
	end
	local offset = (#sections - 1) * 4
	for i = 1, 4 do
		table.insert(faces, { offset + i, offset + i % 4 + 1, #vertices })
	end
	table.insert(faces, { 1, 3, 2 })
	table.insert(faces, { 1, 4, 3 })
	return { vertices = vertices, faces = faces }
end

-- How far the tail reaches back, in lengths of the mesh's own tail.
Style.TailLength = 2

function Style.tail(tail: Bounds, bodyWidth: number): Mesh
	local root = { x = tail.x, y = tail.y + tail.sy * 0.15, z = tail.z - tail.sz / 2 }
	local width = math.min(tail.sx * 0.28, bodyWidth * 0.3)
	local reach = tail.sz * Style.TailLength
	return spike(
		root,
		{ x = root.x, y = root.y - reach * 0.06, z = root.z + reach * 0.55 },
		{ x = root.x, y = root.y - reach * 0.18, z = root.z + reach },
		width,
		math.min(tail.sy * 0.4, width * 0.9)
	)
end

-- Where the horn mesh goes. The root is its foot, buried in the head so only
-- the taper shows; girth widens it, tilt leans its tip toward the nose and splay
-- toward +x, both in degrees.
function Style.horns(head: Bounds): { Horn }
	local horns: { Horn } = {}
	for _, side in { -1, 1 } do
		table.insert(horns, {
			x = head.x + side * head.sx * 0.08,
			y = head.y - head.sy * 0.17,
			z = head.z - head.sz * 0.02,
			length = head.sy * 0.95,
			girth = 0.82,
			tilt = 42,
			splay = side * 10,
		})
	end
	table.insert(horns, {
		x = head.x,
		y = head.y - head.sy * 0.288,
		z = head.z - head.sz * 0.356,
		length = head.sy * 0.42,
		girth = 1.6,
		tilt = 5,
		splay = 0,
	})
	return horns
end

-- Skin over the hole left by the old nose horn.
function Style.noseCap(head: Bounds): Bounds
	return {
		x = head.x,
		y = head.y - head.sy * 0.31,
		z = head.z - head.sz * 0.38,
		sx = head.sx * 0.206,
		sy = head.sy * 0.18,
		sz = head.sz * 0.225,
	}
end

-- A socket over the hole left by the old eye, then the eye on top of it.
function Style.eyes(head: Bounds): { Eye }
	local eyes: { Eye } = {}
	for _, side in { -1, 1 } do
		local x = head.x + side * head.sx * 0.115
		local y = head.y - head.sy * 0.177
		local z = head.z - head.sz * 0.207
		local socket = { x = x, y = y, z = z, sx = head.sx * 0.17, sy = head.sy * 0.22, sz = head.sz * 0.015 }
		local size = head.sy * 0.19
		local ball = { x = x, y = y, z = z - head.sz * 0.01, sx = size, sy = size, sz = size * 0.55 }
		local pupil = {
			x = x,
			y = y,
			z = ball.z - ball.sz * 0.36,
			sx = size * 0.5,
			sy = size * 0.62,
			sz = ball.sz * 0.4,
		}
		table.insert(eyes, {
			socket = socket,
			ball = ball,
			pupil = pupil,
			glint = {
				x = x + size * 0.13,
				y = y + size * 0.17,
				z = pupil.z - pupil.sz * 0.42,
				sx = size * 0.16,
				sy = size * 0.16,
				sz = size * 0.08,
			},
			brow = {
				x = x,
				y = y + socket.sy * 0.52,
				z = z - head.sz * 0.005,
				sx = socket.sx,
				sy = head.sy * 0.05,
				sz = head.sz * 0.03,
			},
			browRoll = side * 8,
		})
	end
	return eyes
end

return Style
