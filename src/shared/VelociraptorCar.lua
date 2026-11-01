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

-- Where the jet flame comes from: the back of the body, over the tail.
VelociraptorCar.jetCFrame = CFrame.new(0, 2.2, 4) * CFrame.Angles(0, math.rad(90), 0)
VelociraptorCar.jetSize = Vector3.new(0.6, 1.2, 1.2)

-- Which pieces fly off in a crash, first to last (AxolotlMoves.Breaks). The
-- legs stay on, since they are what the car stands on.
VelociraptorCar.BreakOrder = { "leftarm", "rightarm", "tail" }

function VelociraptorCar.mesh(): Model?
	local mesh = ReplicatedStorage:FindFirstChild("VelociraptorMesh")
	return if mesh and mesh:IsA("Model") then mesh else nil
end

function VelociraptorCar.build(mesh: Model, hullCFrame: CFrame, parent: Instance): { BasePart }
	local parts: { BasePart } = {}
	local fit = VelociraptorCar.Fit
	for _, piece in mesh:GetChildren() do
		if piece:IsA("BasePart") then
			local part = piece:Clone()
			part.Size = piece.Size * fit
			part.CFrame = hullCFrame * CFrame.new(piece.Position * fit + Vector3.new(0, VelociraptorCar.Lift, 0))
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			part.Parent = parent
			table.insert(parts, part)
		end
	end
	return parts
end

return VelociraptorCar
