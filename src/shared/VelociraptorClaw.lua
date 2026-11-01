--!strict
-- Pure geometry for the car's raised sickle claws, in hull space (-z forward).
-- The outline forms the cutting edge; a ridge on each side gives the blade
-- thickness, tapering to one shared tip instead of a flat extruded end.

local Claw = {}

export type Vec = { x: number, y: number, z: number }
export type Foot = { x: number, y: number, z: number, sx: number, sy: number, sz: number }
export type Mesh = { vertices: { Vec }, faces: { { number } } }

Claw.Side = 2.6
Claw.Width = 0.5
Claw.Outer = { { -0.7, -1.0 }, { -0.35, -1.7 }, { -0.45, -2.5 } }
Claw.Inner = { { -1.7, -1.3 }, { -1.1, -1.7 }, { -0.95, -2.3 } }
Claw.Tip = { -1.35, -3.15 }
Claw.Scale = 0.85
Claw.Root = { -1.2, -1.15 }
Claw.Back = 0.32

-- Prefer the actual foot bounds, with the root buried in its outside toe.
-- The original position remains the fallback for meshes with unnamed legs.
function Claw.root(side: number, foot: Foot?): Vec
	if foot then
		local rootDrop = (Claw.Root[1] - Claw.Inner[1][1]) * Claw.Scale
		return {
			x = foot.x + side * foot.sx * 0.35,
			y = foot.y - foot.sy / 2 + rootDrop + math.min(0.175, foot.sy * 0.3),
			z = foot.z - foot.sz / 2 + math.min(0.65, foot.sz * 0.3),
		}
	end
	return { x = side * Claw.Side, y = Claw.Root[1], z = Claw.Root[2] + Claw.Back }
end

function Claw.shape(root: Vec): Mesh
	local vertices: { Vec } = {}
	local faces: { { number } } = {}
	local function point(at: { number }): Vec
		return {
			x = root.x,
			y = root.y + (at[1] - Claw.Root[1]) * Claw.Scale,
			z = root.z + (at[2] - Claw.Root[2]) * Claw.Scale,
		}
	end
	local function triangle(a: number, b: number, c: number)
		table.insert(faces, { a, b, c })
	end
	local function quad(a: number, b: number, c: number, d: number)
		triangle(a, b, c)
		triangle(a, c, d)
	end
	for i, outer in Claw.Outer do
		local o, n = point(outer), point(Claw.Inner[i])
		local halfWidth = Claw.Width * Claw.Scale / 2 * (1 - (i - 1) / #Claw.Outer * 0.8)
		table.insert(vertices, o)
		table.insert(vertices, n)
		table.insert(vertices, { x = root.x + halfWidth, y = (o.y + n.y) / 2, z = (o.z + n.z) / 2 })
		table.insert(vertices, { x = root.x - halfWidth, y = (o.y + n.y) / 2, z = (o.z + n.z) / 2 })
		if i > 1 then
			local a, b = (i - 2) * 4, (i - 1) * 4
			quad(a + 1, b + 1, b + 3, a + 3)
			quad(a + 3, b + 3, b + 2, a + 2)
			quad(a + 4, b + 4, b + 1, a + 1)
			quad(a + 2, b + 2, b + 4, a + 4)
		end
	end
	triangle(1, 3, 2)
	triangle(1, 2, 4)
	local a = #vertices - 4
	table.insert(vertices, point(Claw.Tip))
	local tip = #vertices
	triangle(a + 1, tip, a + 3)
	triangle(a + 3, tip, a + 2)
	triangle(a + 4, tip, a + 1)
	triangle(a + 2, tip, a + 4)
	return { vertices = vertices, faces = faces }
end

return Claw
