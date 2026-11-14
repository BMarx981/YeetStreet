--!strict
-- DinoCars (ModuleScript) -> ReplicatedStorage.DinoCars
-- The fixed looks of the Tier "Dino" ladder cars: chunky low-poly dinosaurs
-- with the driver riding on their backs. A look is named by the ladder car's
-- Look, and its meshes live in the place file as a Model at
-- ReplicatedStorage.<Look>Mesh, because Rojo can't hold meshes. See
-- VelociraptorCar for how those Models are laid out.
--
-- Fit and Lift put a dino's feet on the ground and its back near the driver's
-- seat. A look with Tail swaps the mesh's own tail for one DinoDress builds,
-- tapering to a point and swaying. Parts come out anchored, with no
-- collisions, touches, or mass, like CarParts. Leg parts, and the claws that ride on them, carry the attributes
-- DinoLeg, the leg's name, and LegHip, the point in hull space it swings about.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VelociraptorCar = require(ReplicatedStorage.VelociraptorCar)
local TriceratopsCar = require(ReplicatedStorage.TriceratopsCar)
local DinoStyle = require(ReplicatedStorage.DinoStyle)
local DinoDress = require(ReplicatedStorage.DinoDress)
local DinoLegs = require(ReplicatedStorage.DinoLegs)

local DinoCars = {}

export type Look = {
	Fit: Vector3, -- stretch from the raw mesh
	Lift: number, -- studs the stretched mesh sits above the hull's center
	jetCFrame: CFrame, -- where the jet flame comes from
	jetSize: Vector3,
	BreakOrder: { string }, -- the pieces that fly off in a crash, first to last (AxolotlMoves.Breaks)
	Tail: DinoStyle.Tail?, -- a built tail in place of the mesh's own
	Skin: Color3?, -- color of built parts; a mesh part's Color is grey, its paint is in the texture
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
		Fit = Vector3.new(1.7, 1.1, 2.1),
		Lift = 0.475,
		jetCFrame = CFrame.new(0, 0.2, 3.75) * JET_TURN,
		jetSize = JET_SIZE,
		BreakOrder = { "tail", "backrightleg", "head" },
		Tail = { Length = 2, Width = 0.28 },
	},
	Brachiosaurus = {
		Fit = Vector3.new(1.5, 0.9, 1.1),
		Lift = 2.03,
		jetCFrame = CFrame.new(0, 1, 4.05) * JET_TURN,
		jetSize = JET_SIZE,
		BreakOrder = { "tail", "head", "neck" },
		Tail = { Length = 2, Width = 0.4 },
		Skin = Color3.fromRGB(28, 96, 232),
	},
	Spinosaurus = {
		Fit = Vector3.new(1.9, 0.9, 1.55),
		Lift = 0.925,
		jetCFrame = CFrame.new(0, 0.2, 4.45) * JET_TURN,
		jetSize = JET_SIZE,
		BreakOrder = { "tail", "sail", "head" },
	},
	TRex = {
		Fit = Vector3.new(1.6, 0.9, 1.7),
		Lift = 0.925,
		jetCFrame = CFrame.new(0, 0.7, 3.4) * JET_TURN,
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

-- How far a part with a TailRoot attribute has turned about that root at
-- `time` seconds.
function DinoCars.tailTurn(time: number): CFrame
	return CFrame.Angles(0, DinoStyle.tailSway(time), 0)
end

local function buildLook(look: string, mesh: Model, hullCFrame: CFrame, parent: Instance): { BasePart }
	if look == "Velociraptor" then
		return VelociraptorCar.build(mesh, hullCFrame, parent)
	end
	local info = DinoCars.Looks[look]
	if look == "Triceratops" then
		return TriceratopsCar.build(mesh, info.Fit, info.Lift, info.Tail :: DinoStyle.Tail, hullCFrame, parent)
	end
	local parts: { BasePart } = {}
	local function place(part: BasePart, at: CFrame, group: string?)
		part.CFrame = hullCFrame * at
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		if group then
			part:SetAttribute("DinoPiece", group)
		end
		part.Parent = parent
		table.insert(parts, part)
	end
	local function fitted(piece: BasePart): DinoStyle.Bounds
		local at = piece.Position * info.Fit + Vector3.new(0, info.Lift, 0)
		local size = piece.Size * info.Fit
		return { x = at.X, y = at.Y, z = at.Z, sx = size.X, sy = size.Y, sz = size.Z }
	end
	local tail = mesh:FindFirstChild("tail")
	local replaced: BasePart? = if info.Tail and tail and tail:IsA("BasePart") then tail else nil
	for _, piece in mesh:GetChildren() do
		if piece:IsA("BasePart") and piece ~= replaced then
			local part = piece:Clone()
			part.Size = piece.Size * info.Fit
			place(part, CFrame.new(piece.Position * info.Fit + Vector3.new(0, info.Lift, 0)))
		end
	end
	if replaced and info.Tail then
		local body = mesh:FindFirstChild("body")
		local width = if body and body:IsA("BasePart") then fitted(body).sx else fitted(replaced).sx
		DinoDress.tail(fitted(replaced), width, info.Tail, info.Skin or replaced.Color, place)
	end
	return parts
end

function DinoCars.build(look: string, mesh: Model, hullCFrame: CFrame, parent: Instance): { BasePart }
	local parts = buildLook(look, mesh, hullCFrame, parent)
	local function side(part: BasePart): number
		return math.sign(hullCFrame:PointToObjectSpace(part.Position).X)
	end
	for _, leg in parts do
		if DinoLegs.isLeg(leg.Name) then
			local at = hullCFrame:PointToObjectSpace(leg.Position)
			local hip = at + Vector3.new(0, leg.Size.Y / 2, 0)
			leg:SetAttribute("DinoLeg", leg.Name)
			leg:SetAttribute("LegHip", hip)
			for _, part in parts do
				if part.Name == "Claw" and side(part) == side(leg) then
					part:SetAttribute("DinoLeg", leg.Name)
					part:SetAttribute("LegHip", hip)
				end
			end
		end
	end
	return parts
end

return DinoCars
