--!strict
-- DinoDress (ModuleScript) -> ReplicatedStorage.DinoDress
-- Builds the code-made parts shared by the dino car looks from DinoStyle's
-- shapes, each flat triangle as two thin wedges: for now the tail that
-- replaces a mesh's own. Parts go through the look's `place`, which puts them
-- in hull space, sets them up like the rest of the look, and parents them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DinoStyle = require(ReplicatedStorage.DinoStyle)

local DinoDress = {}

-- Puts a part at `at` in hull space, in damage group `group` if given.
export type Place = (part: BasePart, at: CFrame, group: string?) -> ()

local SURFACE = 0.012

local function facet(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	name: string,
	group: string,
	color: Color3,
	place: Place,
	made: { BasePart }
)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd >= acd and abd >= bcd then
		c, a = a, c
	elseif acd >= bcd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local normal = ac:Cross(ab)
	if normal.Magnitude < 1e-6 then
		return
	end
	local right, back = normal.Unit, bc.Unit
	local up = back:Cross(right).Unit
	local height = math.abs(ab:Dot(up))
	local function wedge(length: number, at: CFrame)
		if length < 1e-6 then
			return
		end
		local part = Instance.new("WedgePart")
		part.Name = name
		part.Size = Vector3.new(SURFACE, height, length)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		place(part, at, group)
		table.insert(made, part)
	end
	wedge(math.abs(ab:Dot(back)), CFrame.fromMatrix((a + b) / 2, right, up, back))
	wedge(math.abs(ac:Dot(back)), CFrame.fromMatrix((a + c) / 2, -right, up, -back))
end

-- A DinoStyle mesh as wedge parts named `name`, in damage group `group`.
function DinoDress.surface(
	shape: DinoStyle.Mesh,
	name: string,
	group: string,
	color: Color3,
	place: Place
): { BasePart }
	local vertices: { Vector3 } = {}
	for _, v in shape.vertices do
		table.insert(vertices, Vector3.new(v.x, v.y, v.z))
	end
	local made: { BasePart } = {}
	for _, face in shape.faces do
		facet(vertices[face[1]], vertices[face[2]], vertices[face[3]], name, group, color, place, made)
	end
	return made
end

-- The tail in place of the mesh's own (DinoStyle.tail), in damage group
-- "tail". Each part carries a TailRoot attribute, the point in hull space it
-- sways about (DinoStyle.tailSway).
function DinoDress.tail(
	tail: DinoStyle.Bounds,
	bodyWidth: number,
	shape: DinoStyle.Tail,
	color: Color3,
	place: Place
): { BasePart }
	local parts = DinoDress.surface(DinoStyle.tail(tail, bodyWidth, shape), "tail", "tail", color, place)
	local root = DinoStyle.tailRoot(tail)
	for _, part in parts do
		part:SetAttribute("TailRoot", Vector3.new(root.x, root.y, root.z))
	end
	return parts
end

return DinoDress
