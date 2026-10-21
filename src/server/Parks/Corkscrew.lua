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
local CurveProfile = require(ReplicatedStorage.CurveProfile)
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

-- The bottom EntryLength of one side wall of the middle ramp (`side` -1 left,
-- 1 right), curling up from flat on the floor at the ramp's foot to the
-- wall's full curve, in EntryRows rows of triangles. The curl eases in and
-- out, so it meets the floor and the wall above it without a fold.
local function buildEntry(parent: Instance, axis: CFrame, side: number)
	local R = C.Ramp
	local function corners(row: number): { Vector3 }
		local t = row / R.EntryRows
		local along = R.EntryLength * t
		local points: { Vector3 } = {}
		for _, p in CurveProfile.curl(R.WallRadius, 90, R.WallSteps, t * t * (3 - 2 * t)) do
			table.insert(points, axis:PointToWorldSpace(Vector3.new(side * (R.Width / 2 + p.out), p.up, -along)))
		end
		return points
	end
	local inward = axis.UpVector - axis.RightVector * side
	local back = corners(0)
	for row = 1, R.EntryRows do
		local front = corners(row)
		for k = 1, #front - 1 do
			Triangle.make(parent, back[k], back[k + 1], front[k + 1], inward, C.Thickness, RAMP_COLOR)
			Triangle.make(parent, back[k], front[k + 1], front[k], inward, C.Thickness, RAMP_COLOR)
		end
		back = front
	end
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
	-- A curved wall up each side, so a car steering into one rides up it and
	-- comes back down to the middle. Over the first EntryLength each wall
	-- curls up from lying flat on the floor, so the bottom is a wide mouth a
	-- car can drive into at an angle.
	local wallOptions: CurvedWall.Options = {
		radius = R.WallRadius,
		endAngle = 90,
		steps = R.WallSteps,
		thickness = C.Thickness,
		color = RAMP_COLOR,
	}
	local wallLength = length - R.EntryLength
	for _, side in { -1, 1 } do
		local edge = axis * CFrame.new(side * R.Width / 2, 0, -(R.EntryLength + wallLength / 2))
		local out = edge.RightVector * side
		CurvedWall.straight(
			model,
			CFrame.fromMatrix(edge.Position, out:Cross(edge.UpVector), edge.UpVector),
			wallLength,
			wallOptions
		)
		buildEntry(model, axis, side)
	end
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
-- RunwayRows rows of triangles into the track's starting edge, the line
-- through `edge` (its lips and flat middle). Its last RunwayBoostRows rows
-- are boosters.
local function buildRunway(parent: Instance, edge: { Vector3 }, heading: Vector3, respawn: CFrame)
	local T = C.Track
	local back: { Vector3 } = {}
	for k, p in edge do
		local behind = p - heading * T.RunwayLength
		back[k] = Vector3.new(behind.X, FLOOR, behind.Z)
	end
	for row = 1, T.RunwayRows do
		local t0, t1 = (row - 1) / T.RunwayRows, row / T.RunwayRows
		local boost = row > T.RunwayRows - T.RunwayBoostRows
		for k = 1, #edge - 1 do
			local a, b = back[k]:Lerp(edge[k], t0), back[k + 1]:Lerp(edge[k + 1], t0)
			local c, d = back[k]:Lerp(edge[k], t1), back[k + 1]:Lerp(edge[k + 1], t1)
			local parts = Triangle.make(parent, a, b, d, Vector3.yAxis, C.Thickness, RUNWAY_COLOR)
			for _, part in Triangle.make(parent, a, d, c, Vector3.yAxis, C.Thickness, RUNWAY_COLOR) do
				table.insert(parts, part)
			end
			if boost then
				local direction = ((c + d) / 2 - (a + b) / 2).Unit
				for _, part in parts do
					LaunchPad.make(part, T.BoostSpeed, respawn, C.PayScale, direction)
				end
			end
		end
	end
end

-- One lip of a plank, on `side` (-1 back down the ramp, 1 up it): from the
-- flat middle's edge out to the track's edge, LipHeight nearer the axis, so
-- a car drifting onto it is pushed back toward the middle. Its corners follow
-- the track's line from the plank's start (`a0`, `along0`) to its end, so
-- neighboring lips meet with no step; two triangles, as it twists a little.
local function lip(parent: Instance, axis: CFrame, side: number, a0: number, a1: number, along0: number, along1: number)
	local T = C.Track
	local flat = T.Width / 2 - T.LipWidth
	local lipRadius = T.Radius - T.LipHeight
	local a = onCircle(axis, T.Radius, a0, along0 + side * flat)
	local b = onCircle(axis, lipRadius, a0, along0 + side * T.Width / 2)
	local c = onCircle(axis, T.Radius, a1, along1 + side * flat)
	local d = onCircle(axis, lipRadius, a1, along1 + side * T.Width / 2)
	local inward = axis:PointToWorldSpace(Vector3.new(0, 0, -(along0 + along1) / 2)) - (a + d) / 2
	Triangle.make(parent, a, b, d, inward, C.Thickness, TRACK_COLOR)
	Triangle.make(parent, a, d, c, inward, C.Thickness, TRACK_COLOR)
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
	-- The edge is where the track's line starts, at `entry`, which is where
	-- the first lips start too.
	local first = planks[1]
	local firstAlong = entry + first.along
	local flat = T.Width / 2 - T.LipWidth -- from the track's line to each lip
	local lipRadius = T.Radius - T.LipHeight
	local inLow = onCircle(axis, T.Radius, 0, entry - flat)
	local inHigh = onCircle(axis, T.Radius, 0, entry + flat)
	local edge = {
		onCircle(axis, lipRadius, 0, entry - T.Width / 2),
		inLow,
		inHigh,
		onCircle(axis, lipRadius, 0, entry + T.Width / 2),
	}
	local firstAround = (onCircle(axis, T.Radius, first.step, firstAlong) - onCircle(axis, T.Radius, 0, firstAlong)).Unit
	local into = firstAround * first.length + axis.LookVector * first.shift
	local heading = Vector3.new(into.X, 0, into.Z).Unit
	local start = (inLow + inHigh) / 2 - heading * (T.RunwayLength - 20)
	local respawn = CFrame.lookAt(start, start + heading) * CFrame.new(0, FLOOR - start.Y + HULL_HEIGHT, 0)
	buildRunway(model, edge, heading, respawn)

	for i, plank in planks do
		-- The chord of the plank's slice of the circle, square to the axis,
		-- with its top face on the chord and its width along the axis, then a
		-- lip on each side. The flat middle reaches a little under each lip,
		-- since the lips follow the track's line and the middle does not.
		local along = entry + plank.along
		local a0, a1 = plank.angle - plank.step / 2, plank.angle + plank.step / 2
		local from = onCircle(axis, T.Radius, a0, along)
		local to = onCircle(axis, T.Radius, a1, along)
		local middle = (from + to) / 2
		local around = (to - from).Unit
		local inward = (axis:PointToWorldSpace(Vector3.new(0, 0, -along)) - middle).Unit
		local part = block(
			model,
			"Plank",
			Vector3.new(2 * flat + plank.shift, C.Thickness, plank.length + OVERLAP),
			CFrame.fromMatrix(middle - inward * C.Thickness / 2, around:Cross(inward), inward),
			TRACK_COLOR
		)
		for _, side in { -1, 1 } do
			lip(model, axis, side, a0, a1, along - plank.shift / 2, along + plank.shift / 2)
		end
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
