--!strict
-- Triangle (ModuleScript) -> ServerScriptService.Pieces.Triangle
-- A flat triangle of any shape, built from two wedges, for surfaces that
-- twist, such as a runway that blends from flat ground into a sloped edge.
-- Its top face lies on the triangle a, b, c, on the side `up` points to, and
-- it is `thickness` deep below that.

local Triangle = {}

local function wedge(parent: Instance, size: Vector3, cframe: CFrame, color: Color3): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = "Triangle"
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Splits the triangle along the line from its widest corner square to the
-- longest side, into two right triangles, one per wedge.
function Triangle.make(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	up: Vector3,
	thickness: number,
	color: Color3
): { WedgePart }
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	-- Make bc the longest side, so a is the widest corner.
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b

	local right = ac:Cross(ab).Unit
	local upward = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(upward))
	-- Each wedge is centered on the triangle's plane; drop it half its
	-- thickness so its top face is the triangle.
	local below = (if right:Dot(up) > 0 then -right else right) * thickness / 2
	return {
		wedge(
			parent,
			Vector3.new(thickness, height, math.abs(ab:Dot(back))),
			CFrame.fromMatrix((a + b) / 2 + below, right, upward, back),
			color
		),
		wedge(
			parent,
			Vector3.new(thickness, height, math.abs(ac:Dot(back))),
			CFrame.fromMatrix((a + c) / 2 + below, -right, upward, -back),
			color
		),
	}
end

return Triangle
