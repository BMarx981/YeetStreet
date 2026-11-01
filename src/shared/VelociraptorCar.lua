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

-- The big sickle claw on each foot, held up off the ground with its point
-- hooking forward and down. On the outside of the foot, where it can be seen.
-- Its side view is a crescent: the Outer and Inner curves run from the foot
-- toward the Tip, as { y, z } in car space.
VelociraptorCar.Claw = {
	Side = 2.6, -- studs out from the car's middle
	Color = Color3.fromRGB(200, 120, 40),
	Width = 0.5,
	Outer = { { -0.7, -1.0 }, { -0.35, -1.7 }, { -0.45, -2.5 } },
	Inner = { { -1.7, -1.3 }, { -1.1, -1.7 }, { -0.95, -2.3 } },
	Tip = { -1.35, -3.15 },
	Scale = 0.85, -- of all the above but Side, about Root, where it meets the foot
	Root = { -1.2, -1.15 },
	Back = 0.32, -- studs the whole claw sits toward the tail, into the foot
}

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

-- One flat triangle of the claw, from two wedges (the same split as
-- Pieces.Triangle, which only the server can reach).
local function addTriangle(a: Vector3, b: Vector3, c: Vector3, hullCFrame: CFrame, parent: Instance, parts: { BasePart })
	local C = VelociraptorCar.Claw
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
	local function wedge(length: number, cframe: CFrame)
		local part = Instance.new("WedgePart")
		part.Name = "Claw"
		part.Size = Vector3.new(C.Width * C.Scale, height, length)
		part.Color = C.Color
		part.Material = Enum.Material.SmoothPlastic
		settle(part, hullCFrame * cframe, parent)
		table.insert(parts, part)
	end
	wedge(math.abs(ab:Dot(back)), CFrame.fromMatrix((a + b) / 2, right, upward, back))
	wedge(math.abs(ac:Dot(back)), CFrame.fromMatrix((a + c) / 2, -right, upward, -back))
end

local function addClaw(side: number, hullCFrame: CFrame, parent: Instance, parts: { BasePart })
	local C = VelociraptorCar.Claw
	local function point(at: { number }): Vector3
		local y = C.Root[1] + (at[1] - C.Root[1]) * C.Scale
		local z = C.Root[2] + (at[2] - C.Root[2]) * C.Scale + C.Back
		return Vector3.new(side * C.Side, y, z)
	end
	for i = 1, #C.Outer - 1 do
		local outer, inner = point(C.Outer[i]), point(C.Inner[i])
		local nextOuter, nextInner = point(C.Outer[i + 1]), point(C.Inner[i + 1])
		addTriangle(outer, inner, nextOuter, hullCFrame, parent, parts)
		addTriangle(inner, nextInner, nextOuter, hullCFrame, parent, parts)
	end
	addTriangle(point(C.Outer[#C.Outer]), point(C.Inner[#C.Inner]), point(C.Tip), hullCFrame, parent, parts)
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
	addClaw(-1, hullCFrame, parent, parts)
	addClaw(1, hullCFrame, parent, parts)
	return parts
end

return VelociraptorCar
