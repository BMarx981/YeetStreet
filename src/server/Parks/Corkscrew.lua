--!strict
-- Corkscrew (ModuleScript) -> ServerScriptService.Parks.Corkscrew
-- The corkscrew park, built by ParkService into workspace.Parks.Corkscrew on
-- top of the park's floor. Two ways up one long climb: a straight ramp up
-- the middle to a kicker at the top, and a corkscrew track looping around
-- that ramp (Corkscrew), ridden on the inside, upside down at the top of each
-- loop. The track's edges are open, so a car that drifts off falls. Boosters
-- run all the way up both. Numbers are in Tuning.Corkscrew.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Corkscrew = require(ReplicatedStorage.Corkscrew)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)

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

local function buildTrack(parent: Instance, axis: CFrame, length: number)
	local T = C.Track
	local model = Instance.new("Model")
	model.Name = "Corkscrew"
	model.Parent = parent

	local entry = Corkscrew.entry(T.Radius, C.Rise, C.Run)
	local pitch = (length - entry - T.EndGap) / (T.Loops + T.ExitAngle / 360)
	local planks = Corkscrew.planks(T.Radius, pitch, T.Loops, T.StepsPerLoop, T.ExitAngle)

	-- Where the track meets the floor, and the way in along the floor.
	local start = axis * CFrame.new(0, 0, -entry) * CFrame.new(0, -T.Radius, 0)
	local first = planks[1]
	local look = (start * CFrame.Angles(0, TURN * (first.slope - math.pi / 2), 0)).LookVector
	look = Vector3.new(look.X, 0, look.Z).Unit
	local enter = Vector3.new(start.Position.X, FLOOR, start.Position.Z)
	local runwayMid = enter - look * T.ApproachLength / 2
	block(
		model,
		"Runway",
		Vector3.new(T.Width, 0.2, T.ApproachLength),
		CFrame.lookAt(runwayMid, runwayMid + look) * CFrame.new(0, -0.05, 0),
		RUNWAY_COLOR
	)
	local back = enter - look * (T.ApproachLength - 20)
	local respawn = CFrame.lookAt(back, back + look) * CFrame.new(0, HULL_HEIGHT, 0)

	for i, plank in planks do
		-- Out from the axis to the plank's angle, turned from straight around
		-- toward straight along by its slope, then down half its thickness so
		-- its top face lies on the helix.
		local cframe = axis
			* CFrame.new(0, 0, -(entry + plank.along))
			* CFrame.Angles(0, 0, TURN * plank.angle)
			* CFrame.new(0, -(T.Radius - plank.inset), 0)
			* CFrame.Angles(0, TURN * (plank.slope - math.pi / 2), 0)
			* CFrame.new(0, -C.Thickness / 2, 0)
		local part =
			block(model, "Plank", Vector3.new(T.Width, C.Thickness, plank.length + OVERLAP), cframe, TRACK_COLOR)
		if i > #planks - T.ExitPlanks then
			LaunchPad.make(part, T.ExitSpeed, respawn, C.PayScale)
		elseif i % T.BoostEvery == 0 then
			LaunchPad.make(part, T.BoostSpeed, respawn, C.PayScale)
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
