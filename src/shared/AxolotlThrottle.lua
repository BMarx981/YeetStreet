--!strict
-- AxolotlThrottle (ModuleScript) -> ReplicatedStorage.AxolotlThrottle
-- A fixed car look: a smooth pink axolotl with the driver riding on its back.
-- The meshes were generated in Studio and live in the place file, as a Model
-- at ReplicatedStorage.AxolotlThrottleMesh, because Rojo can't hold meshes.
-- That Model's pieces are at the raw generated scale in car space, with the
-- nose toward -z. They get stretched here to sit over the car's hull.
--
-- Parts come out anchored, with no collisions, touches, or mass, like
-- CarParts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AxolotlThrottle = {}

AxolotlThrottle.Fit = Vector3.new(2.2, 1.6, 2.8) -- stretch from the raw mesh
AxolotlThrottle.Lift = 1.4 -- studs the stretched mesh sits above the hull's center

-- Where the jet flame comes from: the back of the body, over the tail.
AxolotlThrottle.jetCFrame = CFrame.new(0, 1.2, 4.5) * CFrame.Angles(0, math.rad(90), 0)
AxolotlThrottle.jetSize = Vector3.new(0.6, 1.2, 1.2)

function AxolotlThrottle.mesh(): Model?
	local mesh = ReplicatedStorage:FindFirstChild("AxolotlThrottleMesh")
	return if mesh and mesh:IsA("Model") then mesh else nil
end

function AxolotlThrottle.build(mesh: Model, hullCFrame: CFrame, parent: Instance): { BasePart }
	local parts: { BasePart } = {}
	local fit = AxolotlThrottle.Fit
	for _, piece in mesh:GetChildren() do
		if piece:IsA("BasePart") then
			local part = piece:Clone()
			part.Size = piece.Size * fit
			part.CFrame = hullCFrame * CFrame.new(piece.Position * fit + Vector3.new(0, AxolotlThrottle.Lift, 0))
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

return AxolotlThrottle
