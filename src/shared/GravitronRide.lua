--!strict
-- GravitronRide (ModuleScript) -> ReplicatedStorage.GravitronRide
-- The Corkscrew park's gravitron (Gravitron, Tuning.Corkscrew.Gravitron) put
-- in the world: where its bowl and tubes are, and how it spins. Nothing is
-- sent while it spins: every machine reads the speed off the server's clock.
--
-- Parks.CorkscrewGravitron builds it, each client draws it spinning
-- (GravitronLook), CarController asks how it moves a car, and ScoreService
-- asks whether a car is in it, armed, or over its rim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gravitron = require(ReplicatedStorage.Gravitron)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tunnel = require(ReplicatedStorage.Tunnel)
local Tuning = require(ReplicatedStorage.Tuning)

local G = Tuning.Corkscrew.Gravitron
local area = MapLayout.find(Tuning.Map.Areas :: any, "Corkscrew")

local GravitronRide = {}

GravitronRide.shape = G :: Gravitron.Shape
GravitronRide.spin = G.Spin :: Gravitron.Spin
GravitronRide.centerHeight = Gravitron.centerHeight(GravitronRide.shape)

-- The ride's ground space: on the floor under the bowl's middle, its -Z
-- toward the bowl's high side. Nil when the park is missing.
GravitronRide.ground = if area
	then CFrame.new(area.X + G.X, Tuning.Map.FloorTop, area.Z + G.Z) * CFrame.Angles(0, math.rad(G.Heading), 0)
	else nil
-- The bowl's space: at its floor's middle, Y up its axis.
GravitronRide.bowl = if GravitronRide.ground
	then GravitronRide.ground * CFrame.new(0, GravitronRide.centerHeight, 0) * CFrame.Angles(math.rad(G.Tilt), 0, 0)
	else nil

local strands, warning = Tunnel.gravitron(G.Tubes :: any, {
	Tilt = G.Tilt,
	CenterHeight = GravitronRide.centerHeight,
	FloorThickness = G.Thickness,
}, Tuning.City.Tunnels :: any)
GravitronRide.strands = strands
GravitronRide.warning = warning

-- `position` in the bowl's space, and how far it is from the axis.
local function inBowl(position: Vector3): (Vector3?, number)
	local bowl = GravitronRide.bowl
	if not bowl then
		return nil, 0
	end
	local p = bowl:PointToObjectSpace(position)
	return p, math.sqrt(p.X * p.X + p.Z * p.Z)
end

function GravitronRide.speed(time: number): number
	return Gravitron.speed(GravitronRide.spin, time)
end

-- Times the tyres' grip at `time`.
function GravitronRide.grip(time: number): number
	return Gravitron.grip(GravitronRide.spin, GravitronRide.speed(time))
end

-- Radians the bowl has turned round its axis by `time`, the way
-- CFrame.Angles(0, angle, 0) turns, within a whole turn: CFrames keep too
-- few digits for a turn counted from time 0.
function GravitronRide.angle(time: number): number
	local footR = Gravitron.foot(GravitronRide.shape)
	return (GravitronRide.spin.Direction * Gravitron.travel(GravitronRide.spin, time) / footR) % (2 * math.pi)
end

-- Whether `position` is in the bowl, over its surface and under its rim.
function GravitronRide.inside(position: Vector3): boolean
	local p, r = inBowl(position)
	return p ~= nil and Gravitron.inside(GravitronRide.shape, r, p.Y, G.Margin)
end

-- Whether a car on the surface at `position` is armed: in the bowl and
-- ArmHeight up it.
function GravitronRide.arms(position: Vector3): boolean
	local p = inBowl(position)
	return p ~= nil and p.Y >= G.ArmHeight and GravitronRide.inside(position)
end

-- Whether `position` is over the rim: past it up the bowl's axis, and no
-- more than RimReach further out from the axis than the rim.
function GravitronRide.overRim(position: Vector3): boolean
	local p, r = inBowl(position)
	return p ~= nil and p.Y > G.Height and r < Gravitron.rimRadius(GravitronRide.shape) + G.RimReach
end

-- The target a run pays for leaving over the rim at `time`.
function GravitronRide.target(time: number): string
	local level = Gravitron.level(GravitronRide.spin, GravitronRide.speed(time))
	for _, entry in G.Targets do
		if level >= entry.Level then
			return entry.Target
		end
	end
	return G.Targets[#G.Targets].Target
end

-- The way out of the surface nearest `position`, into the bowl.
function GravitronRide.up(position: Vector3): Vector3
	local p, r = inBowl(position)
	local bowl = GravitronRide.bowl
	if not p or not bowl then
		return Vector3.yAxis
	end
	local nr, ny = Gravitron.normal(GravitronRide.shape, r, p.Y)
	local out = if r > 1e-6 then Vector3.new(p.X / r, 0, p.Z / r) else Vector3.zero
	return bowl:VectorToWorldSpace(out * nr + Vector3.yAxis * ny).Unit
end

-- How fast the surface moves at `position` at `time`.
function GravitronRide.surfaceVelocity(position: Vector3, time: number): Vector3
	local p = inBowl(position)
	local bowl = GravitronRide.bowl
	if not p or not bowl then
		return Vector3.zero
	end
	local vx, vz =
		Gravitron.surfaceVelocity(GravitronRide.spin, GravitronRide.shape, GravitronRide.speed(time), p.X, p.Z)
	return bowl:VectorToWorldSpace(Vector3.new(vx, 0, vz))
end

-- The push from the surface on a car at `position` moving at `velocity` at
-- `time`, as an acceleration.
function GravitronRide.carry(position: Vector3, velocity: Vector3, time: number): Vector3
	local p = inBowl(position)
	local bowl = GravitronRide.bowl
	if not p or not bowl then
		return Vector3.zero
	end
	local v = bowl:VectorToObjectSpace(velocity)
	local ax, az =
		Gravitron.carry(GravitronRide.spin, GravitronRide.shape, GravitronRide.speed(time), p.X, p.Z, v.X, v.Z)
	return bowl:VectorToWorldSpace(Vector3.new(ax, 0, az))
end

-- Where a reset after a strand's launch pads puts a car: at its funnel's
-- open end, facing in.
function GravitronRide.respawnFor(strand: Tunnel.GravitronStrand): CFrame
	local ground = GravitronRide.ground :: CFrame
	local inward = ground:VectorToWorldSpace(Vector3.new(strand.heading, 0, 0))
	local mouth = ground:PointToWorldSpace(Vector3.new(strand.mouth.x, Tuning.TestPark.SpawnHeight, strand.mouth.z))
	local entry = mouth - inward * G.Tubes.FunnelLength
	return CFrame.lookAt(entry, entry + inward)
end

-- The funnel entry (respawnFor) nearest `position`.
function GravitronRide.respawn(position: Vector3): CFrame?
	if not GravitronRide.ground then
		return nil
	end
	local best: CFrame? = nil
	for _, strand in strands do
		local cframe = GravitronRide.respawnFor(strand)
		if not best or (cframe.Position - position).Magnitude < (best.Position - position).Magnitude then
			best = cframe
		end
	end
	return best
end

-- Which way the tubes pull a car at `position` (Tunnel.pull), or nil outside
-- them. Over the floor they have been cut off, so they pull nothing there.
function GravitronRide.pull(position: Vector3): Vector3?
	local ground, bowl = GravitronRide.ground, GravitronRide.bowl
	if not ground or not bowl then
		return nil
	end
	local radius = Tuning.City.Tunnels.Radius
	local g = ground:PointToObjectSpace(position)
	local b = bowl:PointToObjectSpace(position)
	for _, strand in strands do
		local px, py, pz = Tunnel.pull(strand.approach, radius, g.X, g.Y, g.Z)
		if px and py and pz then
			return ground:VectorToWorldSpace(Vector3.new(px, py, pz))
		end
		if b.Y < 0 then
			px, py, pz = Tunnel.pull(strand.twist, radius, b.X, b.Y, b.Z)
			if px and py and pz then
				return bowl:VectorToWorldSpace(Vector3.new(px, py, pz))
			end
		end
	end
	return nil
end

return GravitronRide
