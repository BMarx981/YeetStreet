--!strict
-- Hammers (ModuleScript) -> ReplicatedStorage.Hammers
-- Hammer Alley in the world: where the Scrapyard's lane is, and HammerAlley's
-- lane math for world places and velocities. Nothing is sent while the
-- hammers move: every machine places them from the server's clock.
--
-- Each client draws its own hammers (HammerAlleyLook), CarController asks
-- `push` how one knocks its car, and ScoreService asks `smacked` whether
-- one could have.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HammerAlley = require(ReplicatedStorage.HammerAlley)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)

local A = Tuning.Scrapyard.Alley
local CONFIG: HammerAlley.Config = A :: any
local HAMMERS: { HammerAlley.Hammer } = A.Hammers :: any

local Hammers = {}

local area = MapLayout.find(Tuning.Map.Areas :: any, "Scrapyard")

-- The lane's start, on the floor in the middle, facing along it.
Hammers.frame = if area
	then CFrame.new(area.X + A.X, Tuning.Map.FloorTop, area.Z + A.Z) * CFrame.Angles(0, math.rad(A.Turn), 0)
	else CFrame.identity

-- Where wrecks and resets in the lane come back to.
Hammers.respawn = Hammers.frame * CFrame.new(0, Tuning.TestPark.SpawnHeight, A.RespawnBack)

-- A world position in the lane's own studs: across, up, along.
function Hammers.toLane(position: Vector3): (number, number, number)
	local p = Hammers.frame:PointToObjectSpace(position)
	return p.X, p.Y, -p.Z
end

-- Whether a world position is in the lane, between its walls.
function Hammers.inLane(position: Vector3): boolean
	if not area then
		return false
	end
	local x, _, a = Hammers.toLane(position)
	return math.abs(x) <= A.Width / 2 and a >= 0 and a <= A.Length
end

-- The velocity a hammer gives a car at `position` moving at `velocity` at
-- `time`, or nil when none reaches it.
function Hammers.push(position: Vector3, velocity: Vector3, time: number): Vector3?
	if not area then
		return nil
	end
	local x, y, a = Hammers.toLane(position)
	local v = Hammers.frame:VectorToObjectSpace(velocity)
	local vx, vy, va = HammerAlley.push(CONFIG, HAMMERS, time, x, y, a, v.X, v.Y, -v.Z)
	if not (vx and vy and va) then
		return nil
	end
	return Hammers.frame:VectorToWorldSpace(Vector3.new(vx, vy, -va))
end

-- Whether any hammer could have knocked a car at `position` at any time from
-- `from` to `to`, `slack` studs further out.
function Hammers.smacked(position: Vector3, from: number, to: number, slack: number): boolean
	if not area then
		return false
	end
	local x, y, a = Hammers.toLane(position)
	if a < -slack - A.Reach or a > A.Length + slack + A.Reach then
		return false
	end
	return HammerAlley.smacked(CONFIG, HAMMERS, from, to, x, y, a, slack)
end

return Hammers
