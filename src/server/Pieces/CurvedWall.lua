--!strict
-- CurvedWall (ModuleScript) -> ServerScriptService.Pieces.CurvedWall
-- Reusable curved wall pieces for building parks: quarter pipes, lean-back
-- walls, half pipes, swept corners, and bowls. The cross section comes from
-- CurveProfile; this module builds it from anchored planks inside a Model whose
-- pivot is the piece's base, so a piece moves as one.
--
-- A `base` CFrame sits on the ground on the line where the curve starts, with
-- its LookVector pointing the way the wall rises. Its RightVector runs along
-- the wall.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurveProfile = require(ReplicatedStorage.CurveProfile)

local CurvedWall = {}

-- Engine limit on a part's size along any axis.
local MAX_PART = 2048
-- Planks are this much longer than their chord so the seams stay closed.
local OVERLAP = 0.4

local DEFAULT_COLOR = Color3.fromRGB(150, 154, 162)

export type Options = {
	radius: number,
	endAngle: number, -- degrees: 90 is a quarter pipe, past 90 leans back
	steps: number, -- planks from bottom to top
	thickness: number,
	color: Color3?,
	material: Enum.Material?,
}

local function newModel(parent: Instance, name: string, pivot: CFrame): Model
	local model = Instance.new("Model")
	model.Name = name
	model.WorldPivot = pivot
	model.Parent = parent
	return model
end

local function buildPlank(parent: Instance, base: CFrame, plank: CurveProfile.Plank, width: number, options: Options)
	local part = Instance.new("Part")
	part.Name = "Plank"
	part.Anchored = true
	part.Size = Vector3.new(width, options.thickness, plank.length + OVERLAP)
	-- Tilting about X lifts the plank's far end; then drop it half its
	-- thickness so its top face lies on the curve.
	part.CFrame = base
		* CFrame.new(0, plank.up, -plank.out)
		* CFrame.Angles(plank.tilt, 0, 0)
		* CFrame.new(0, -options.thickness / 2, 0)
	part.Color = options.color or DEFAULT_COLOR
	part.Material = options.material or Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

-- A straight run of wall `length` studs long, centered on `base`. Longer than
-- one part can be, it is split into equal pieces.
function CurvedWall.straight(parent: Instance, base: CFrame, length: number, options: Options): Model
	local model = newModel(parent, "CurvedWall", base)
	local planks = CurveProfile.planks(options.radius, options.endAngle, options.steps)
	local pieces = math.ceil(length / MAX_PART)
	local pieceLength = length / pieces
	for i = 1, pieces do
		local pieceBase = base * CFrame.new((i - 0.5) * pieceLength - length / 2, 0, 0)
		for _, plank in planks do
			buildPlank(model, pieceBase, plank, pieceLength, options)
		end
	end
	return model
end

-- The wall swept around `pivot`'s up axis, `turnRadius` studs from the pivot
-- to the base line. It starts rising along the pivot's LookVector and turns
-- left (counterclockwise seen from above) by `turnAngle` degrees in `slices`
-- slices. The wall rises away from the pivot, as on the inside of a bowl.
function CurvedWall.corner(
	parent: Instance,
	pivot: CFrame,
	turnRadius: number,
	turnAngle: number,
	slices: number,
	options: Options
): Model
	local model = newModel(parent, "CurvedCorner", pivot)
	local planks = CurveProfile.planks(options.radius, options.endAngle, options.steps)
	local sliceAngle = turnAngle / slices
	for i = 1, slices do
		local base = pivot * CFrame.Angles(0, math.rad(sliceAngle * (i - 0.5)), 0) * CFrame.new(0, 0, -turnRadius)
		for _, plank in planks do
			buildPlank(model, base, plank, CurveProfile.sliceLength(turnRadius + plank.out, sliceAngle), options)
		end
	end
	return model
end

-- Two straight walls facing each other across `width` studs of flat floor,
-- one rising along `center`'s LookVector and one behind it. They run
-- `length` studs along its RightVector.
function CurvedWall.halfPipe(parent: Instance, center: CFrame, width: number, length: number, options: Options): Model
	local model = newModel(parent, "HalfPipe", center)
	for _, turn in { 0, math.pi } do
		CurvedWall.straight(model, center * CFrame.Angles(0, turn, 0) * CFrame.new(0, 0, -width / 2), length, options)
	end
	return model
end

-- A full ring of wall around `center`, with a flat floor `floorRadius` studs
-- across from the center to where the curve starts.
function CurvedWall.bowl(parent: Instance, center: CFrame, floorRadius: number, slices: number, options: Options): Model
	local model = CurvedWall.corner(parent, center, floorRadius, 360, slices, options)
	model.Name = "Bowl"
	return model
end

return CurvedWall
