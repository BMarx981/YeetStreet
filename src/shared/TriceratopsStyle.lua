--!strict
-- Pure proportions for the mesh triceratops, in hull space (-z forward).
-- Details follow the fitted head, so they also fit garage previews. The tail
-- is DinoStyle's.

local Style = {}

export type Bounds = { x: number, y: number, z: number, sx: number, sy: number, sz: number }
export type Horn = { x: number, y: number, z: number, length: number, girth: number, tilt: number, splay: number }
export type Eye = { socket: Bounds, ball: Bounds, pupil: Bounds, glint: Bounds, brow: Bounds, browRoll: number }

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
