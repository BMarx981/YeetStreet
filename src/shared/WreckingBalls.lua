--!strict
-- WreckingBalls (ModuleScript) -> ReplicatedStorage.WreckingBalls
-- Every part tagged WreckingBall: the tip of one of Downtown's crane jibs,
-- which a ball swings from (WreckingBall). The part's CFrame is the pivot,
-- its X across the street (the way the ball swings), and its Length,
-- Amplitude and Phase attributes are the ball's. Nothing is sent while
-- they swing: every machine places them from the server's clock.
--
-- Each client draws its own balls (WreckingBallSet) and CarController asks
-- `push` how one smacks its car. ScoreService asks `smacked` whether one
-- could have.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)
local WreckingBall = require(ReplicatedStorage.WreckingBall)

local WreckingBalls = {}

WreckingBalls.TAG = "WreckingBall"

export type Entry = {
	part: BasePart,
	pivot: CFrame,
	ball: WreckingBall.Ball,
}

local entries: { [BasePart]: Entry } = {}

local function add(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local length = instance:GetAttribute("Length")
	local amplitude = instance:GetAttribute("Amplitude")
	local phase = instance:GetAttribute("Phase")
	if typeof(length) ~= "number" or typeof(amplitude) ~= "number" or typeof(phase) ~= "number" then
		warn(`WreckingBalls: {instance:GetFullName()} has no Length, Amplitude or Phase`)
		return
	end
	entries[instance] = {
		part = instance,
		pivot = instance.CFrame,
		ball = { length = length, amplitude = amplitude, phase = phase },
	}
end

local function remove(instance: Instance)
	if instance:IsA("BasePart") then
		entries[instance] = nil
	end
end

for _, instance in CollectionService:GetTagged(WreckingBalls.TAG) do
	add(instance)
end
CollectionService:GetInstanceAddedSignal(WreckingBalls.TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(WreckingBalls.TAG):Connect(remove)

function WreckingBalls.all(): { [BasePart]: Entry }
	return entries
end

-- The ball's middle at `time`, its down vector pointing away from the pivot.
function WreckingBalls.center(entry: Entry, time: number): CFrame
	local x, y = WreckingBall.center(entry.ball, time, Tuning.City.Cranes.Ball.Period)
	return entry.pivot * CFrame.Angles(0, 0, math.atan2(x, -y)) * CFrame.new(0, -entry.ball.length, 0)
end

-- The velocity a ball gives a car at `position` moving at `velocity` at
-- `time`, or nil when no ball is touching it.
function WreckingBalls.push(position: Vector3, velocity: Vector3, time: number): Vector3?
	local B = Tuning.City.Cranes.Ball
	for _, entry in entries do
		local p = entry.pivot:PointToObjectSpace(position)
		if p.Magnitude > entry.ball.length + B.Radius + B.Reach then
			continue
		end
		local v = entry.pivot:VectorToObjectSpace(velocity)
		local vx, vy, vz = WreckingBall.push(entry.ball, time, p.X, p.Y, p.Z, v.X, v.Y, v.Z, B :: any)
		if vx and vy and vz then
			return entry.pivot:VectorToWorldSpace(Vector3.new(vx, vy, vz))
		end
	end
	return nil
end

-- Whether any ball came within reach of a car at `position`, `slack`
-- further out, at any time from `from` to `to`.
function WreckingBalls.smacked(position: Vector3, from: number, to: number, slack: number): boolean
	local B = Tuning.City.Cranes.Ball
	local reach = B.Radius + B.Reach + slack
	for _, entry in entries do
		local p = entry.pivot:PointToObjectSpace(position)
		if
			p.Magnitude <= entry.ball.length + reach
			and WreckingBall.reaches(entry.ball, from, to, p.X, p.Y, p.Z, reach, B.Period)
		then
			return true
		end
	end
	return false
end

return WreckingBalls
