--!strict
-- CarParts (ModuleScript) -> ReplicatedStorage.CarParts
-- Turns a CarDesign into Parts. It makes Instances, so it isn't pure, but it
-- lives in shared because the car gallery (edit mode) and the client both use it.
--
-- Each part goes at origin * its position, turned about the origin's up axis.
-- It keeps its index in design.parts as the PartIndex attribute, so damage can
-- find parts by index. Parts come out anchored, with no collisions, touches,
-- or mass; a caller that welds them to a hull unanchors them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarDesign = require(ReplicatedStorage.CarDesign)

local CarParts = {}

-- Added to every wedge's turn, in degrees, so a WedgePart at turn 0 rises
-- toward the back as CarDesign expects. Use 180 if Roblox wedges rise the
-- other way.
local WEDGE_TURN = 0

local function newPart(spec: CarDesign.PartSpec): BasePart
	if spec.shape == "wedge" then
		return Instance.new("WedgePart")
	end
	local part = Instance.new("Part")
	if spec.shape == "cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	return part
end

-- Builds every part of the design under parent and returns them in
-- design.parts order.
function CarParts.build(design: CarDesign.Design, origin: CFrame, parent: Instance): { BasePart }
	local built = {}
	for index, spec in design.parts do
		local part = newPart(spec)
		local turn = spec.turn + if spec.shape == "wedge" then WEDGE_TURN else 0
		local p = spec.position
		part.Name = spec.name
		part.Size = Vector3.new(spec.size.x, spec.size.y, spec.size.z)
		part.CFrame = origin * CFrame.new(p.x, p.y, p.z) * CFrame.Angles(0, math.rad(turn), 0)
		part.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
		part.Material = (Enum.Material :: any)[spec.material]
		part.Reflectance = spec.reflectance
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = true
		part:SetAttribute("PartIndex", index)
		part.Parent = parent
		built[index] = part
	end
	return built
end

return CarParts
