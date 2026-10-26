--!strict
-- GlobeRide (ModuleScript) -> ReplicatedStorage.GlobeRide
-- The Corkscrew park's face (Globe, Tunnel.face, Tuning.Corkscrew.Globe) put
-- in the world: where its two eyes are, and the tube forking up into them
-- in a smile.
--
-- Parks.CorkscrewGlobe builds it, CarController asks how its tube pulls a
-- car, GlobeHatch opens the eyes' hatches for a car coming up the tube, and
-- ScoreService asks whether a car is in an eye.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Globe = require(ReplicatedStorage.Globe)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tunnel = require(ReplicatedStorage.Tunnel)
local Tuning = require(ReplicatedStorage.Tuning)

local G = Tuning.Corkscrew.Globe
local area = MapLayout.find(Tuning.Map.Areas :: any, "Corkscrew")

local GlobeRide = {}

GlobeRide.shape = G :: Globe.Shape

-- The CollectionService tag on the hatches' planks.
GlobeRide.HATCH_TAG = "GlobeHatch"

-- The face's ground space: on the floor under its middle, the mouth out
-- along -X and the eyes Span either side along Z. Nil when the park is
-- missing.
GlobeRide.ground = if area
	then CFrame.new(area.X + G.X, Tuning.Map.FloorTop, area.Z + G.Z) * CFrame.Angles(0, math.rad(G.Heading), 0)
	else nil

GlobeRide.face = Tunnel.face({
	Span = G.Radius + G.Thickness + G.EyeGap / 2,
	TurnRadius = G.Smile.TurnRadius,
	ExitAngle = G.Smile.ExitAngle,
	Stem = G.Smile.Stem,
}, Tuning.City.Tunnels :: any)

-- At each eye's middle, turned like the ground space, so each eye's -X, its
-- front, faces the mouth: the left branch's, then the right's.
GlobeRide.eyes = {} :: { CFrame }
-- Each branch as a gravitron strand from the mouth, its climb as the twist,
-- so the gravitron's funnel and launch pads fit it.
GlobeRide.strands = {} :: { Tunnel.GravitronStrand }
do
	local face = GlobeRide.face
	local span = G.Radius + G.Thickness + G.EyeGap / 2
	for _, branch in { { side = -1, pieces = face.left }, { side = 1, pieces = face.right } } do
		if GlobeRide.ground then
			table.insert(
				GlobeRide.eyes,
				GlobeRide.ground * CFrame.new(0, face.cut + G.Thickness + G.Radius, branch.side * span)
			)
		end
		table.insert(GlobeRide.strands, {
			side = branch.side,
			approach = face.stem,
			twist = branch.pieces,
			mouth = face.mouth,
			heading = face.heading,
			roll = 0,
			top = face.cut,
		})
	end
end

-- Whether `position` is in either eye.
function GlobeRide.inside(position: Vector3): boolean
	for _, eye in GlobeRide.eyes do
		local p = eye:PointToObjectSpace(position)
		if Globe.inside(GlobeRide.shape, p.X, p.Y, p.Z, G.Margin) then
			return true
		end
	end
	return false
end

-- The funnel's open end, and the way in from there.
local function funnelEntry(ground: CFrame): (Vector3, Vector3)
	local face = GlobeRide.face
	local inward = ground:VectorToWorldSpace(Vector3.new(face.heading, 0, 0))
	local mouth = ground:PointToWorldSpace(Vector3.new(face.mouth.x, Tuning.TestPark.SpawnHeight, face.mouth.z))
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

-- Where a reset in an eye puts a car: at the funnel's open end, facing out.
function GlobeRide.exit(): CFrame?
	local ground = GlobeRide.ground
	if not ground then
		return nil
	end
	local entry, inward = funnelEntry(ground)
	return CFrame.lookAt(entry, entry - inward)
end

-- Whether a car at `position` is over the middle of either eye's hatch,
-- where dropping through it lands in the tube (Globe.overHatch).
function GlobeRide.overHatch(position: Vector3): boolean
	for _, eye in GlobeRide.eyes do
		local p = eye:PointToObjectSpace(position)
		if Globe.overHatch(GlobeRide.shape, p.X, p.Y, p.Z, G.Exit.Reach, G.Exit.Height) then
			return true
		end
	end
	return false
end

-- Which way the tube pulls a car at `position` (Tunnel.pull), or nil outside
-- it: toward the nearest wall of whichever of the stem and branches has its
-- middle line nearest, so through the fork it is the one the car is
-- heading into. Above the cut under the eyes the branches have been cut
-- off, so they pull nothing there.
function GlobeRide.pull(position: Vector3): Vector3?
	local ground = GlobeRide.ground
	if not ground then
		return nil
	end
	local radius = Tuning.City.Tunnels.Radius
	local p = ground:PointToObjectSpace(position)
	local face = GlobeRide.face
	local lines = { face.stem }
	if p.Y < face.cut then
		table.insert(lines, face.left)
		table.insert(lines, face.right)
	end
	local nearest: { Tunnel.Piece }? = nil
	local best = radius
	for _, pieces in lines do
		local distance = Tunnel.distance(pieces, p.X, p.Y, p.Z)
		if distance and distance <= best then
			nearest, best = pieces, distance
		end
	end
	if not nearest then
		return nil
	end
	local px, py, pz = Tunnel.pull(nearest, radius, p.X, p.Y, p.Z)
	if px and py and pz then
		return ground:VectorToWorldSpace(Vector3.new(px, py, pz))
	end
	return nil
end

-- The sideways push on a car at `position` moving at `velocity` where the
-- branches still overlap past the fork, as an acceleration toward the
-- branch it goes (Globe.forkSide): the left one turns to -Z, the right to
-- +Z. Only for a car heading in from the mouth (the stem runs along X, in
-- along face.heading), so one driving down a branch from an eye can turn
-- into the stem. Zero anywhere else.
function GlobeRide.forkPush(position: Vector3, velocity: Vector3): Vector3
	local ground = GlobeRide.ground
	if not ground then
		return Vector3.zero
	end
	local radius = Tuning.City.Tunnels.Radius
	local p = ground:PointToObjectSpace(position)
	local v = ground:VectorToObjectSpace(velocity)
	local face = GlobeRide.face
	if v.X * face.heading <= 0 then
		return Vector3.zero
	end
	local left = Tunnel.distance(face.left, p.X, p.Y, p.Z)
	local right = Tunnel.distance(face.right, p.X, p.Y, p.Z)
	if not (left and right) or left > radius or right > radius then
		return Vector3.zero
	end
	local sideways = v.Z
	local side = Globe.forkSide(left, right, sideways, G.Smile.ForkLevel)
	return ground:VectorToWorldSpace(Vector3.new(0, 0, side * G.Smile.ForkPush))
end

return GlobeRide
