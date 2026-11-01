--!strict
-- DinoCars (ModuleScript) -> ReplicatedStorage.DinoCars
-- The fixed looks of the Tier "Dino" ladder cars: chunky low-poly dinosaurs
-- with the driver riding on their backs. A look is named by the ladder car's
-- Look, and its meshes live in the place file as a Model at
-- ReplicatedStorage.<Look>Mesh, because Rojo can't hold meshes. See
-- VelociraptorCar for how those Models are laid out.
--
-- Fit and Lift put a dino's feet on the ground and its back near the driver's
-- seat. Parts come out anchored, with no collisions, touches, or mass, like
-- CarParts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VelociraptorCar = require(ReplicatedStorage.VelociraptorCar)

local DinoCars = {}

export type Look = {
	Fit: Vector3, -- stretch from the raw mesh
	Lift: number, -- studs the stretched mesh sits above the hull's center
	jetCFrame: CFrame, -- where the jet flame comes from
	jetSize: Vector3,
	BreakOrder: { string }, -- the pieces that fly off in a crash, first to last (AxolotlMoves.Breaks)
}

local JET_SIZE = VelociraptorCar.jetSize
local JET_TURN = CFrame.Angles(0, math.rad(90), 0)

DinoCars.Looks = {
	Velociraptor = {
		Fit = VelociraptorCar.Fit,
		Lift = VelociraptorCar.Lift,
		jetCFrame = VelociraptorCar.jetCFrame,
		jetSize = JET_SIZE,
		BreakOrder = VelociraptorCar.BreakOrder,
	},
	Triceratops = {
		Fit = Vector3.new(1.6, 1.1, 1.8),
		Lift = 0.475,
		jetCFrame = CFrame.new(0, 0.6, 4) * JET_TURN,
		jetSize = JET_SIZE,
		BreakOrder = { "tail", "backrightleg", "head" },
	},
	Brachiosaurus = {
		Fit = Vector3.new(1.5, 0.85, 1.1),
		Lift = 2.25,
		jetCFrame = CFrame.new(0, 1.4, 3.2) * JET_TURN,
		jetSize = JET_SIZE,
		BreakOrder = { "tail", "head", "neck" },
	},
	Spinosaurus = {
		Fit = Vector3.new(1.5, 1.2, 1.6),
		Lift = 0.89,
		jetCFrame = CFrame.new(0, 0.8, 3.5) * JET_TURN,
		jetSize = JET_SIZE,
		BreakOrder = { "leftarm", "sail", "tail" },
	},
	TRex = {
		Fit = Vector3.new(1.5, 0.9, 1.6),
		Lift = 0.85,
		jetCFrame = CFrame.new(0, 1.7, 4) * JET_TURN,
		jetSize = JET_SIZE,
		BreakOrder = { "leftarm", "rightarm", "tail" },
	},
} :: { [string]: Look }

-- The meshes of a look, or nil if it isn't a dino or the place has lost them,
-- in which case the car keeps its generated look.
function DinoCars.mesh(look: string?): Model?
	if not look or not DinoCars.Looks[look] then
		return nil
	end
	local mesh = ReplicatedStorage:FindFirstChild(`{look}Mesh`)
	return if mesh and mesh:IsA("Model") then mesh else nil
end

function DinoCars.build(look: string, mesh: Model, hullCFrame: CFrame, parent: Instance): { BasePart }
	if look == "Velociraptor" then
		return VelociraptorCar.build(mesh, hullCFrame, parent)
	end
	local info = DinoCars.Looks[look]
	local parts: { BasePart } = {}
	for _, piece in mesh:GetChildren() do
		if piece:IsA("BasePart") then
			local part = piece:Clone()
			part.Size = piece.Size * info.Fit
			part.CFrame = hullCFrame * CFrame.new(piece.Position * info.Fit + Vector3.new(0, info.Lift, 0))
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

return DinoCars
