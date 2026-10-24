--!strict
-- Trains (ModuleScript) -> ReplicatedStorage.Trains
-- Where the city's trains are on their line (Railway) at a time on the
-- server's clock, the same on every machine, with nothing sent. Each
-- client draws them (TrainSet) and asks `push` how one pushes its car.
-- ScoreService asks `touching` whether one could have, so a push is never
-- measured as a hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Railway = require(ReplicatedStorage.Railway)
local Tuning = require(ReplicatedStorage.Tuning)
local Tunnel = require(ReplicatedStorage.Tunnel)

local Trains = {}

local R = Tuning.City.Railway
local T = R.Trains
local FLOOR = Tuning.Map.FloorTop
local SAMPLE = 1 / 30

local area = MapLayout.find(Tuning.Map.Areas :: any, "City")
local line: Railway.Line = R :: any
local start = Railway.start(line)
local pieces = Tunnel.path(start.x, start.z, start.headingX, start.headingZ, Railway.segments(line) :: any, start.y)
local lengths: { number } = {}
local total = 0
for _, piece in pieces do
	local length = Tunnel.length(piece)
	table.insert(lengths, length)
	total += length
end

-- The middle of the deck's top `distance` round the loop.
local function pointOn(distance: number): Vector3
	local index, t = Railway.locate(lengths, distance)
	local x, y, z = Tunnel.pointAt(pieces[index], t)
	local a = area :: MapLayout.Area
	return Vector3.new(a.X + x, FLOOR + y, a.Z + z)
end

-- A carriage's middle, facing the way it goes.
local function frameOf(span: Railway.Span): CFrame
	local front, back = pointOn(span.front), pointOn(span.back)
	return CFrame.lookAt((front + back) / 2, front, Vector3.yAxis) * CFrame.new(0, T.Height / 2 + 0.5, 0)
end

-- Every carriage at `time`, each train's in turn from its first, which has
-- the nose. None without the city.
function Trains.frames(time: number): { CFrame }
	local frames: { CFrame } = {}
	if area then
		for _, span in Railway.carriages(total, time, T) do
			table.insert(frames, frameOf(span))
		end
	end
	return frames
end

-- Whether the carriage at this index in `frames` is a train's first.
function Trains.isNose(index: number): boolean
	return (index - 1) % T.Carriages == 0
end

-- The velocity a train's nose gives a car at `position` moving at
-- `velocity`, with the carriages at `frames`, or nil when no train's nose
-- is touching it (Railway.push).
function Trains.push(frames: { CFrame }, position: Vector3, velocity: Vector3): Vector3?
	for i, frame in frames do
		if not Trains.isNose(i) then
			continue
		end
		local p = frame:PointToObjectSpace(position)
		local v = frame:VectorToObjectSpace(velocity)
		local va, vc, vu =
			Railway.push(-p.Z, p.X, p.Y, -v.Z, v.X, v.Y, T.Length / 2, T.Width / 2, T.Height / 2, T.Speed, R.Push)
		if va and vc and vu then
			return frame:VectorToWorldSpace(Vector3.new(vc, vu, -va))
		end
	end
	return nil
end

-- Whether a train's nose was where it pushes a car at `position`, `slack`
-- further out, at any time from `from` to `to`.
function Trains.touching(position: Vector3, from: number, to: number, slack: number): boolean
	local a = area
	if not a then
		return false
	end
	local reach = T.Length + slack
	if math.abs(position.X - a.X) > a.Width / 2 + reach or math.abs(position.Z - a.Z) > a.Depth / 2 + reach then
		return false
	end
	local steps = math.max(math.ceil((to - from) / SAMPLE), 1)
	for i = 0, steps do
		for _, span in Railway.carriages(total, from + (to - from) * i / steps, T) do
			if span.carriage == 1 then
				local p = frameOf(span):PointToObjectSpace(position)
				if Railway.touches(-p.Z, p.X, p.Y, T.Length / 2, T.Width / 2, T.Height / 2, R.Push, slack) then
					return true
				end
			end
		end
	end
	return false
end

return Trains
