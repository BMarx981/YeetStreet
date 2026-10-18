--!strict
-- CarParts (ModuleScript) -> ReplicatedStorage.CarParts
-- Turns a CarDesign into Parts. It makes Instances, so it isn't pure, but it
-- lives in shared because the car gallery (edit mode), the server, and every
-- client use it.
--
-- Each part goes at origin * its position, turned about the origin's up axis.
-- It keeps its index in design.parts as the PartIndex attribute, so damage can
-- find parts by index. Parts come out anchored, with no collisions, touches,
-- or mass; a caller that welds them to a hull unanchors them.
--
-- A car's looks travel as attributes on its model, set by the server: Seed,
-- Archetype, Tier, and the levels it shows (LevelSpeed, LevelJets,
-- LevelToughness, LevelGrip). Broken<Slot> (BrokenNose, BrokenTail, ...)
-- counts the parts knocked off each slot (CarDamage).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarDesign = require(ReplicatedStorage.CarDesign)
local CarKit = require(ReplicatedStorage.CarKit)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)

local CarParts = {}

-- Every slot, in the order damage that names no slot breaks them.
local SLOTS: { CarDesign.Slot } = { "nose", "tail", "roof", "sides", "underside" }
CarParts.Slots = SLOTS

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

-- The attribute counting broken parts in a slot, like BrokenNose.
function CarParts.brokenAttribute(slot: CarDesign.Slot): string
	return `Broken{string.upper(string.sub(slot, 1, 1))}{string.sub(slot, 2)}`
end

-- Writes a car's looks onto its model.
function CarParts.setLook(car: Model, seed: number, archetype: string, tier: string, levels: CarDesign.Levels)
	car:SetAttribute("Seed", seed)
	car:SetAttribute("Archetype", archetype)
	car:SetAttribute("Tier", tier)
	car:SetAttribute("LevelSpeed", levels.Speed)
	car:SetAttribute("LevelJets", levels.Jets)
	car:SetAttribute("LevelToughness", levels.Toughness)
	car:SetAttribute("LevelGrip", levels.Grip)
end

local function number(car: Model, key: string): number?
	local value = car:GetAttribute(key)
	return if typeof(value) == "number" then value else nil
end

-- The car's design from its look attributes, or nil if any is missing.
function CarParts.designFor(car: Model): CarDesign.Design?
	local seed = number(car, "Seed")
	local archetype = car:GetAttribute("Archetype")
	local tier = car:GetAttribute("Tier")
	local speed = number(car, "LevelSpeed")
	local jets = number(car, "LevelJets")
	local toughness = number(car, "LevelToughness")
	local grip = number(car, "LevelGrip")
	if
		not (seed and speed and jets and toughness and grip)
		or typeof(archetype) ~= "string"
		or typeof(tier) ~= "string"
	then
		return nil
	end
	local levels = { Speed = speed, Jets = jets, Toughness = toughness, Grip = grip }
	local input = { archetype = archetype, tier = tier, levels = levels }
	return CarDesign.design(Rng.new(seed), input, CarKit, Tuning.CarLooks)
end

return CarParts
