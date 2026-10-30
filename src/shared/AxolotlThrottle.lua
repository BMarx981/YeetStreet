--!strict
-- AxolotlThrottle (ModuleScript) -> ReplicatedStorage.AxolotlThrottle
-- A fixed car look: a smooth pink axolotl with the driver riding on its back.
-- The meshes were generated in Studio and live in the place file, as a Model
-- at ReplicatedStorage.AxolotlThrottleMesh, because Rojo can't hold meshes.
-- That Model's pieces are at the raw generated scale in car space, with the
-- nose toward -z. They get stretched here to sit over the car's hull.
--
-- The mesh's own mouth is too small to read at speed, so it's left out for a
-- smile laid on the head, with a dark mouth inside for laughing (AxolotlMoves).
--
-- Parts come out anchored, with no collisions, touches, or mass, like
-- CarParts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AxolotlMoves = require(ReplicatedStorage.AxolotlMoves)

local AxolotlThrottle = {}

AxolotlThrottle.Fit = Vector3.new(2.2, 1.6, 2.8) -- stretch from the raw mesh
AxolotlThrottle.Lift = 1.4 -- studs the stretched mesh sits above the hull's center

-- Where the jet flame comes from: the back of the body, over the tail.
AxolotlThrottle.jetCFrame = CFrame.new(0, 1.2, 4.5) * CFrame.Angles(0, math.rad(90), 0)
AxolotlThrottle.jetSize = Vector3.new(0.6, 1.2, 1.2)

-- What the moving pieces turn about, in car space: where each meets the body.
AxolotlThrottle.tailRoot = CFrame.new(0, 0, 3.5)
AxolotlThrottle.leftGillRoot = CFrame.new(-1.6, 2.2, -2.2)
AxolotlThrottle.rightGillRoot = CFrame.new(1.6, 2.2, -2.2)

local SMILE_COLOR = Color3.fromRGB(150, 40, 70)
local MOUTH_COLOR = Color3.fromRGB(70, 15, 35)

function AxolotlThrottle.mesh(): Model?
	local mesh = ReplicatedStorage:FindFirstChild("AxolotlThrottleMesh")
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

-- The mesh pieces by name, plus the smile's dots in order and the mouth, named
-- Smile and Mouth.
function AxolotlThrottle.build(mesh: Model, hullCFrame: CFrame, parent: Instance): { BasePart }
	local parts: { BasePart } = {}
	local fit = AxolotlThrottle.Fit
	for _, piece in mesh:GetChildren() do
		if piece:IsA("BasePart") and piece.Name ~= "mouth" then
			local part = piece:Clone()
			part.Size = piece.Size * fit
			settle(
				part,
				hullCFrame * CFrame.new(piece.Position * fit + Vector3.new(0, AxolotlThrottle.Lift, 0)),
				parent
			)
			table.insert(parts, part)
		end
	end
	local S = AxolotlMoves.Smile
	for _, dot in AxolotlMoves.smileDots() do
		local part = Instance.new("Part")
		part.Name = "Smile"
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * S.DotSize
		part.Color = SMILE_COLOR
		part.Material = Enum.Material.SmoothPlastic
		settle(part, hullCFrame * CFrame.new(dot.x, dot.y, dot.z), parent)
		table.insert(parts, part)
	end
	local mouth = Instance.new("Part")
	mouth.Name = "Mouth"
	mouth.Size = Vector3.new(S.MouthSize.X, S.MouthSize.Y, S.MouthSize.Z)
	mouth.Color = MOUTH_COLOR
	mouth.Material = Enum.Material.SmoothPlastic
	local round = Instance.new("SpecialMesh")
	round.MeshType = Enum.MeshType.Sphere
	round.Parent = mouth
	local at = AxolotlMoves.mouthAt(0)
	settle(mouth, hullCFrame * CFrame.new(at.x, at.y, at.z), parent)
	table.insert(parts, mouth)
	return parts
end

return AxolotlThrottle
