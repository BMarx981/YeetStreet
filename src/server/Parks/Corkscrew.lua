--!strict
-- Corkscrew (ModuleScript) -> ServerScriptService.Parks.Corkscrew
-- The corkscrew park, built by ParkService into workspace.Parks.Corkscrew on
-- top of the park's floor. Two ways up one long climb: a straight ramp up
-- the middle to a kicker at the top, and a corkscrew track looping around
-- that ramp (Corkscrew), ridden on the inside, upside down at the top of each
-- loop. The track's edges are open, so a car that drifts off falls. A runway
-- leads into the track from the floor. Boosters run all the way up both.
-- Numbers are in Tuning.Corkscrew.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Corkscrew = require(ReplicatedStorage.Corkscrew)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)
local Triangle = require(ServerScriptService.Pieces.Triangle)

local C = Tuning.Corkscrew
local FLOOR = Tuning.Map.FloorTop
local HULL_HEIGHT = Tuning.TestPark.SpawnHeight

local RAMP_COLOR = Color3.fromRGB(196, 196, 190)
local TRACK_COLOR = Color3.fromRGB(70, 130, 200)
local RUNWAY_COLOR = Color3.fromRGB(120, 120, 126)

-- Planks are this much longer than their chord so the seams stay closed.
local OVERLAP = 0.4
-- The corkscrew turns left, toward -X, at the bottom of each loop.
local TURN = -1

local CorkscrewPark = {}

-- A point in the park, `y` above the floor. Faces -Z.
local function at(area: MapLayout.Area, x: number, y: number, z: number): CFrame
	return CFrame.new(area.X + x, FLOOR + y, area.Z + z)
end

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- The middle ramp's line, from where it leaves the floor: LookVector up the
-- climb, UpVector square to it.
local function axisFrame(area: MapLayout.Area): CFrame
	local start = at(area, C.X, 0, C.StartZ).Position
	return CFrame.lookAt(start, start + Vector3.new(0, C.Rise, -C.Run), Vector3.yAxis)
end

local function buildRamp(parent: Instance, area: MapLayout.Area, axis: CFrame, length: number)
	local R = C.Ramp
	local model = Instance.new("Model")
	model.Name = "MiddleRamp"
	model.Parent = parent
	local respawn = at(area, C.X, HULL_HEIGHT, C.StartZ + 40)

	block(
		model,
		"Ramp",
		Vector3.new(R.Width, C.Thickness, length),
		axis * CFrame.new(0, -C.Thickness / 2, -length / 2),
		RAMP_COLOR
	)
	local d = R.BoostLength / 2 + 5
	while d < length - R.BoostLength / 2 do
		LaunchPad.flat(model, axis * CFrame.new(0, 0.1, -d), R.Width, R.BoostLength, R.BoostSpeed, respawn, C.PayScale)
		d += R.BoostEvery
	end

	local options: CurvedWall.Options = {
		radius = R.KickRadius,
		endAngle = R.KickAngle,
		steps = R.KickSteps,
		thickness = C.Thickness,
		color = RAMP_COLOR,
	}
	local kicker = CurvedWall.straight(model, axis * CFrame.new(0, 0, -length), R.Width, options)
	LaunchPad.top(kicker, R.KickSteps, R.LaunchSpeed, respawn, C.PayScale)
end

-- A point on the track's circle, `angle` around from the bottom and `along`
-- up the axis.
local function onCircle(axis: CFrame, radius: number, angle: number, along: number): Vector3
	return axis:PointToWorldSpace(
		Vector3.new(radius * math.sin(TURN * angle), -radius * math.cos(TURN * angle), -along)
	)
end

-- A runway from flat floor RunwayLength back along `heading`, blending in
-- RunwayRows rows of triangles into the sloped edge from `low` to `high`
-- where the track starts. Its last RunwayBoostRows rows are boosters.
local function buildRunway(parent: Instance, low: Vector3, high: Vector3, heading: Vector3, respawn: CFrame)
	local T = C.Track
	local function floorPoint(p: Vector3): Vector3
		local back = p - heading * T.RunwayLength
		return Vector3.new(back.X, FLOOR, back.Z)
	end
	local backLow, backHigh = floorPoint(low), floorPoint(high)
	for row = 1, T.RunwayRows do
		local t0, t1 = (row - 1) / T.RunwayRows, row / T.RunwayRows
		local a, b = backLow:Lerp(low, t0), backHigh:Lerp(high, t0)
		local c, d = backLow:Lerp(low, t1), backHigh:Lerp(high, t1)
		local parts = Triangle.make(parent, a, b, d, Vector3.yAxis, C.Thickness, RUNWAY_COLOR)
		for _, part in Triangle.make(parent, a, d, c, Vector3.yAxis, C.Thickness, RUNWAY_COLOR) do
			table.insert(parts, part)
		end
		if row > T.RunwayRows - T.RunwayBoostRows then
			local direction = ((c + d) / 2 - (a + b) / 2).Unit
			for _, part in parts do
				LaunchPad.make(part, T.BoostSpeed, respawn, C.PayScale, direction)
			end
		end
	end
end

local function buildTrack(parent: Instance, axis: CFrame, length: number)
	local T = C.Track
	local model = Instance.new("Model")
	model.Name = "Corkscrew"
	model.Parent = parent

	local entry = Corkscrew.entry(T.Radius, C.Rise, C.Run, T.Width)
	local pitch = (length - entry - T.Width / 2 - T.EndGap) / (T.Loops + T.ExitAngle / 360)
	local planks = Corkscrew.planks(T.Radius, pitch, T.Loops, T.StepsPerLoop, T.ExitAngle)

	-- The first plank's back edge, where the runway meets the track, and the
	-- way along the floor into it: around the loop and up the ramp the way
	-- the track runs, so a car driving straight in keeps up with the track.
	local first = planks[1]
	local firstAlong = entry + first.along
	local low = onCircle(axis, T.Radius, 0, firstAlong - T.Width / 2)
	local high = onCircle(axis, T.Radius, 0, firstAlong + T.Width / 2)
	local firstAround = (onCircle(axis, T.Radius, first.step, firstAlong) - onCircle(axis, T.Radius, 0, firstAlong)).Unit
	local into = firstAround * first.length + axis.LookVector * first.shift
	local heading = Vector3.new(into.X, 0, into.Z).Unit
	local start = (low + high) / 2 - heading * (T.RunwayLength - 20)
	local respawn = CFrame.lookAt(start, start + heading) * CFrame.new(0, FLOOR - start.Y + HULL_HEIGHT, 0)
	buildRunway(model, low, high, heading, respawn)

	for i, plank in planks do
		-- The chord of the plank's slice of the circle, square to the axis,
		-- with its top face on the chord and its width along the axis.
		local along = entry + plank.along
		local from = onCircle(axis, T.Radius, plank.angle - plank.step / 2, along)
		local to = onCircle(axis, T.Radius, plank.angle + plank.step / 2, along)
		local middle = (from + to) / 2
		local around = (to - from).Unit
		local inward = (axis:PointToWorldSpace(Vector3.new(0, 0, -along)) - middle).Unit
		local part = block(
			model,
			"Plank",
			Vector3.new(T.Width, C.Thickness, plank.length + OVERLAP),
			CFrame.fromMatrix(middle - inward * C.Thickness / 2, around:Cross(inward), inward),
			TRACK_COLOR
		)
		-- Boosters push the way the track runs, not straight around.
		local direction = (around * plank.length + axis.LookVector * plank.shift).Unit
		if i > #planks - T.ExitPlanks then
			LaunchPad.make(part, T.ExitSpeed, respawn, C.PayScale, direction)
		elseif i % T.BoostEvery == 0 then
			LaunchPad.make(part, T.BoostSpeed, respawn, C.PayScale, direction)
		end
	end
end

function CorkscrewPark.build(folder: Folder, area: MapLayout.Area)
	local axis = axisFrame(area)
	local length = math.sqrt(C.Rise ^ 2 + C.Run ^ 2)
	buildRamp(folder, area, axis, length)
	buildTrack(folder, axis, length)
end

return CorkscrewPark
