--!strict
-- VelociraptorCar (ModuleScript) -> ReplicatedStorage.VelociraptorCar
-- A fixed car look: a chunky low-poly raptor with the driver riding on its back.
-- The meshes were generated in Studio and live in the place file, as a Model
-- at ReplicatedStorage.VelociraptorMesh, because Rojo can't hold meshes. That
-- Model's pieces are at the raw generated scale, centered on the origin, with
-- the nose toward -z. They get stretched here to sit over the car's hull.
--
-- Parts come out anchored, with no collisions, touches, or mass, like
-- CarParts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Claw = require(ReplicatedStorage.VelociraptorClaw)

local VelociraptorCar = {}

VelociraptorCar.Fit = Vector3.new(1.5, 1, 1.4) -- stretch from the raw mesh
VelociraptorCar.Lift = 1 -- studs the stretched mesh sits above the hull's center
VelociraptorCar.ArmLength = 1.25 -- how much longer the arms are, down and forward from the shoulder

-- Where the jet flame comes from: the back of the body, over the tail.
VelociraptorCar.jetCFrame = CFrame.new(0, 2.2, 4) * CFrame.Angles(0, math.rad(90), 0)
VelociraptorCar.jetSize = Vector3.new(0.6, 1.2, 1.2)

-- Which pieces fly off in a crash, first to last (AxolotlMoves.Breaks). The
-- legs stay on, since they are what the car stands on.
VelociraptorCar.BreakOrder = { "leftarm", "rightarm", "tail" }

VelociraptorCar.Claw = Claw
local CLAW_COLOR = Color3.fromRGB(200, 120, 40)
local CLAW_SURFACE = 0.015 -- thin facets meet at the blade's cutting edge

function VelociraptorCar.mesh(): Model?
	local mesh = ReplicatedStorage:FindFirstChild("VelociraptorMesh")
	return if mesh and mesh:IsA("Model") then mesh else nil
end

local function settle(part: BasePart, cframe: CFrame, parent: Instance)
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Parent = parent
end

-- One beveled surface of the claw, from two thin wedges (the same split as
-- Pieces.Triangle, which only the server can reach).
local function addTriangle(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	hullCFrame: CFrame,
	parent: Instance,
	parts: { BasePart }
)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	-- Make bc the longest side, so a is the widest corner.
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
	local right = normal.Unit
	local upward = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(upward))
	local function wedge(length: number, cframe: CFrame)
		if length < 1e-6 then
			return
		end
		local part = Instance.new("WedgePart")
		part.Name = "Claw"
		part.Size = Vector3.new(CLAW_SURFACE, height, length)
		part.Color = CLAW_COLOR
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		settle(part, hullCFrame * cframe, parent)
		table.insert(parts, part)
	end
	wedge(math.abs(ab:Dot(back)), CFrame.fromMatrix((a + b) / 2, right, upward, back))
	wedge(math.abs(ac:Dot(back)), CFrame.fromMatrix((a + c) / 2, -right, upward, -back))
end

-- Explicit foot pieces take precedence over a combined leg-and-foot mesh.
local function footBounds(side: number, hullCFrame: CFrame, parts: { BasePart }): Claw.Foot?
	local found: Claw.Foot? = nil
	local priority = 0
	for _, part in parts do
		local name = string.lower(part.Name)
		local rank = if string.find(name, "foot", 1, true) then 2 elseif string.find(name, "leg", 1, true) then 1 else 0
		local at = hullCFrame:PointToObjectSpace(part.Position)
		if at.X * side > 0 and rank > priority then
			found = { x = at.X, y = at.Y, z = at.Z, sx = part.Size.X, sy = part.Size.Y, sz = part.Size.Z }
			priority = rank
		end
	end
	return found
end

local function addClaw(root: Claw.Vec, hullCFrame: CFrame, parent: Instance, parts: { BasePart })
	local shape = Claw.shape(root)
	local vertices: { Vector3 } = {}
	for _, p in shape.vertices do
		table.insert(vertices, Vector3.new(p.x, p.y, p.z))
	end
	for _, face in shape.faces do
		addTriangle(vertices[face[1]], vertices[face[2]], vertices[face[3]], hullCFrame, parent, parts)
	end
end

function VelociraptorCar.build(mesh: Model, hullCFrame: CFrame, parent: Instance): { BasePart }
	local parts: { BasePart } = {}
	local fit = VelociraptorCar.Fit
	for _, piece in mesh:GetChildren() do
		if piece:IsA("BasePart") then
			local part = piece:Clone()
			part.Size = piece.Size * fit
			local at = piece.Position * fit + Vector3.new(0, VelociraptorCar.Lift, 0)
			if piece.Name == "leftarm" or piece.Name == "rightarm" then
				-- The top back corner, the shoulder, stays where it is.
				local grow = VelociraptorCar.ArmLength - 1
				at -= Vector3.new(0, part.Size.Y, part.Size.Z) * grow / 2
				part.Size *= Vector3.new(1, 1 + grow, 1 + grow)
			end
			settle(part, hullCFrame * CFrame.new(at), parent)
			table.insert(parts, part)
		end
	end
	local left = Claw.root(-1, footBounds(-1, hullCFrame, parts))
	local right = Claw.root(1, footBounds(1, hullCFrame, parts))
	addClaw(left, hullCFrame, parent, parts)
	addClaw(right, hullCFrame, parent, parts)
	return parts
end

return VelociraptorCar
