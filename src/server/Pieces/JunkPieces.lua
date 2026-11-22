--!strict
-- JunkPieces (ModuleScript) -> ServerScriptService.Pieces.JunkPieces
-- One piece of loose junk (Junk, Tuning.Scrapyard.Junk) as a single
-- anchored part: a crushed car, a panel, a tire, or a drum. `at` is where its
-- bottom middle sits, turned as the piece should lie; the part is raised by
-- half its height from there. Its paint comes from the Rng.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local J = Tuning.Scrapyard.Junk

local JunkPieces = {}

-- Same as Rng.Rng.
type Rng = {
	next: () -> number,
	range: (low: number, high: number) -> number,
	int: (low: number, high: number) -> number,
}

function JunkPieces.make(parent: Instance, kind: string, at: CFrame, rng: Rng): Part
	local part = Instance.new("Part")
	part.Name = kind
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local paint = J.Paints[rng.int(1, #J.Paints)]
	if kind == "Tire" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = J.Tire
		part.Color = J.TireColor
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = at * CFrame.new(0, J.Tire.Y / 2, 0)
	elseif kind == "Drum" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = J.Drum
		part.Color = paint
		part.Material = Enum.Material.CorrodedMetal
		part.CFrame = at * CFrame.new(0, J.Drum.X / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	else
		local size = if kind == "Panel" then J.Panel else J.Car
		part.Size = size
		part.Color = paint
		part.Material = Enum.Material.CorrodedMetal
		part.CFrame = at * CFrame.new(0, size.Y / 2, 0)
	end
	part.Parent = parent
	return part
end

return JunkPieces
