--!strict
-- DinoStyle (ModuleScript) -> ReplicatedStorage.DinoStyle
-- Pure shapes shared by the dino car looks, in hull space (-z forward): a
-- tail built in place of a mesh's own, tapering to one point, and its side to
-- side sway. Each look sets its tail's Tail numbers (DinoCars.Looks).

local DinoStyle = {}

export type Vec = { x: number, y: number, z: number }
export type Bounds = { x: number, y: number, z: number, sx: number, sy: number, sz: number }
export type Mesh = { vertices: { Vec }, faces: { { number } } }
export type Tail = {
	Length: number, -- how far back it reaches, in lengths of the mesh's own tail
	Width: number, -- half its width at the root, as a share of the mesh tail's width
}

-- Diamond cross sections and one shared point make a faceted, curved spike.
-- The section planes follow the spike's slope.
function DinoStyle.spike(root: Vec, middle: Vec, tip: Vec, width: number, depth: number): Mesh
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

-- The tail's side to side swing.
DinoStyle.TailSway = {
	Degrees = 14, -- to each side
	Period = 1.8, -- seconds for one full swing there and back
}

-- The tail's angle about its root at `time` seconds, in radians.
function DinoStyle.tailSway(time: number): number
	local sway = DinoStyle.TailSway
	return math.rad(sway.Degrees) * math.sin(2 * math.pi * time / sway.Period)
end

-- Where the tail meets the body: the front of the mesh's own tail.
function DinoStyle.tailRoot(tail: Bounds): Vec
	return { x = tail.x, y = tail.y + tail.sy * 0.15, z = tail.z - tail.sz / 2 }
end

-- The tail in place of the mesh's own `tail`, never wider at the root than
-- the body allows.
function DinoStyle.tail(tail: Bounds, bodyWidth: number, shape: Tail): Mesh
	local root = DinoStyle.tailRoot(tail)
	local width = math.min(tail.sx * shape.Width, bodyWidth * 0.3)
	local reach = tail.sz * shape.Length
	return DinoStyle.spike(
		root,
		{ x = root.x, y = root.y - reach * 0.06, z = root.z + reach * 0.55 },
		{ x = root.x, y = root.y - reach * 0.18, z = root.z + reach },
		width,
		math.min(tail.sy * 0.4, width * 0.9)
	)
end

return DinoStyle
