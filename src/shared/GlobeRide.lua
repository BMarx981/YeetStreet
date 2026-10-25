--!strict
-- GlobeRide (ModuleScript) -> ReplicatedStorage.GlobeRide
-- The Corkscrew park's globe (Globe, Tuning.Corkscrew.Globe) put in the
-- world: where its shell and tube are.
--
-- Parks.CorkscrewGlobe builds it, CarController asks how its tube pulls a
-- car, GlobeHatch opens its hatch for a car coming up the tube, and
-- ScoreService asks whether a car is in it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Globe = require(ReplicatedStorage.Globe)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tunnel = require(ReplicatedStorage.Tunnel)
local Tuning = require(ReplicatedStorage.Tuning)

local G = Tuning.Corkscrew.Globe
local area = MapLayout.find(Tuning.Map.Areas :: any, "Corkscrew")

local GlobeRide = {}

GlobeRide.shape = G :: Globe.Shape

-- The CollectionService tag on the hatch's planks.
GlobeRide.HATCH_TAG = "GlobeHatch"

-- The globe's ground space: on the floor under its bottom, the tube coming
-- in along +X. Nil when the park is missing.
GlobeRide.ground = if area
	then CFrame.new(area.X + G.X, Tuning.Map.FloorTop, area.Z + G.Z) * CFrame.Angles(0, math.rad(G.Heading), 0)
	else nil
-- At the globe's middle, turned like the ground space.
GlobeRide.center = if GlobeRide.ground
	then GlobeRide.ground * CFrame.new(0, G.Clearance + G.Thickness + G.Radius, 0)
	else nil

GlobeRide.strand = Tunnel.globe(G.Tube :: any, G.Clearance, Tuning.City.Tunnels :: any)

-- Whether `position` is in the globe.
function GlobeRide.inside(position: Vector3): boolean
	local center = GlobeRide.center
	if not center then
		return false
	end
	local p = center:PointToObjectSpace(position)
	return Globe.inside(GlobeRide.shape, p.X, p.Y, p.Z, G.Margin)
end

-- The funnel's open end, and the way in from there.
local function funnelEntry(ground: CFrame): (Vector3, Vector3)
	local strand = GlobeRide.strand
	local inward = ground:VectorToWorldSpace(Vector3.new(strand.heading, 0, 0))
	local mouth = ground:PointToWorldSpace(Vector3.new(strand.mouth.x, Tuning.TestPark.SpawnHeight, strand.mouth.z))
	return mouth - inward * Tuning.Corkscrew.Gravitron.Tubes.FunnelLength, inward
end

-- Where a reset in the tube on the way in puts a car: at its funnel's open
-- end, facing in.
function GlobeRide.respawn(): CFrame?
	local ground = GlobeRide.ground
	if not ground then
		return nil
	end
	local entry, inward = funnelEntry(ground)
	return CFrame.lookAt(entry, entry + inward)
end

-- Where a reset in the globe, or leaving through the hatch, puts a car: at
-- the funnel's open end, facing out.
function GlobeRide.exit(): CFrame?
	local ground = GlobeRide.ground
	if not ground then
		return nil
	end
	local entry, inward = funnelEntry(ground)
	return CFrame.lookAt(entry, entry - inward)
end

-- Whether a car at `position` is over the hatch's middle, where dropping
-- through it lands in the tube (Globe.overHatch).
function GlobeRide.overHatch(position: Vector3): boolean
	local center = GlobeRide.center
	if not center then
		return false
	end
	local p = center:PointToObjectSpace(position)
	return Globe.overHatch(GlobeRide.shape, p.X, p.Y, p.Z, G.Exit.Reach, G.Exit.Height)
end

-- Which way the tube pulls a car at `position` (Tunnel.pull), or nil outside
-- it. Over the cut under the globe it has been cut off, so it pulls nothing
-- there.
function GlobeRide.pull(position: Vector3): Vector3?
	local ground = GlobeRide.ground
	if not ground then
		return nil
	end
	local radius = Tuning.City.Tunnels.Radius
	local p = ground:PointToObjectSpace(position)
	local strand = GlobeRide.strand
	local px, py, pz = Tunnel.pull(strand.approach, radius, p.X, p.Y, p.Z)
	if not (px and py and pz) and p.Y < G.Clearance then
		px, py, pz = Tunnel.pull(strand.twist, radius, p.X, p.Y, p.Z)
	end
	if px and py and pz then
		return ground:VectorToWorldSpace(Vector3.new(px, py, pz))
	end
	return nil
end

return GlobeRide
