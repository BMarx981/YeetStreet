--!strict
-- ScrapyardMountain (ModuleScript) -> ServerScriptService.Parks.ScrapyardMountain
-- Scrap Mountain (Tuning.Scrapyard.Mountain), the Scrapyard's big launcher:
-- a ramp up a hill of junk, built like the Corkscrew's middle ramp. A
-- curved wall up each side keeps cars on it, boosters on the way up keep a
-- slow car climbing, and a kicker at the top, every plank a booster, throws
-- cars out over the yard toward the TNT field. Under the ramp is a solid
-- wedge, the front slopes down from the top, and each side slopes down to
-- the ground (a flank, Junk.flankHeight); junk lies on the flanks and down
-- the front (Junk.onSlope). Resets and
-- wrecks after a launch come back to the foot, under a SCRAP MOUNTAIN sign.
-- Its record sign is Tuning.LaunchRecords' (RecordService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Junk = require(ReplicatedStorage.Junk)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)
local ArchSign = require(ServerScriptService.Pieces.ArchSign)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local JunkPieces = require(ServerScriptService.Pieces.JunkPieces)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)
local Triangle = require(ServerScriptService.Pieces.Triangle)

local M = Tuning.Scrapyard.Mountain
local FLOOR = Tuning.Map.FloorTop

local ScrapyardMountain = {}

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.DiamondPlate
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function ScrapyardMountain.build(folder: Folder, area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "ScrapMountain"

	-- The foot, on the floor in the middle, facing up the ramp.
	local foot = CFrame.new(area.X + M.X, FLOOR, area.Z + M.Z) * CFrame.Angles(0, math.rad(M.Turn), 0)
	local top = foot * Vector3.new(0, M.Rise, -M.Run)
	local axis = CFrame.lookAt(foot.Position, top, Vector3.yAxis)
	local length = (top - foot.Position).Magnitude
	local respawn = foot * CFrame.new(0, Tuning.TestPark.SpawnHeight, M.RespawnBack)
	local edge = M.Width / 2 + M.WallRadius

	block(
		model,
		"Ramp",
		Vector3.new(M.Width, M.Thickness, length),
		axis * CFrame.new(0, -M.Thickness / 2, -length / 2),
		M.RampColor
	)

	-- Solid under the ramp, walls and all: a wedge whose tall end is at the top.
	local core = Instance.new("WedgePart")
	core.Name = "Core"
	core.Anchored = true
	core.Size = Vector3.new(2 * edge, M.Rise, M.Run)
	core.CFrame = foot * CFrame.new(0, M.Rise / 2 - M.Thickness, -M.Run / 2) * CFrame.Angles(0, math.pi, 0)
	core.Color = M.FlankColor
	core.Material = Enum.Material.Ground
	core.Parent = model
	-- The front, sloping down from the top under the kicker.
	local front = core:Clone()
	front.Name = "Front"
	front.Size = Vector3.new(2 * edge, M.Rise, M.FrontRun)
	front.CFrame = foot * CFrame.new(0, M.Rise / 2, -(M.Run + M.FrontRun / 2))
	front.Parent = model

	-- A curved wall up each side, as on the Corkscrew's middle ramp.
	local wallOptions: CurvedWall.Options = {
		radius = M.WallRadius,
		endAngle = 90,
		steps = M.WallSteps,
		thickness = M.Thickness,
		color = M.RampColor,
		material = Enum.Material.CorrodedMetal,
	}
	for _, side in { -1, 1 } do
		local line = axis * CFrame.new(side * M.Width / 2, 0, -length / 2)
		local out = line.RightVector * side
		CurvedWall.straight(
			model,
			CFrame.fromMatrix(line.Position, out:Cross(line.UpVector), line.UpVector),
			length,
			wallOptions
		)
	end

	-- Boosters 0.1 above the ramp that cars pass through, as on the
	-- Corkscrew's, so the ramp stays one smooth block.
	local d = M.BoostLength / 2 + 5
	while d < length - M.BoostLength / 2 do
		local pad = LaunchPad.flat(
			model,
			axis * CFrame.new(0, 0.1, -d),
			M.Width,
			M.BoostLength,
			M.BoostSpeed,
			respawn,
			M.Kicker.PayScale
		)
		pad.CanCollide = false
		d += M.BoostEvery
	end

	local kickOptions: CurvedWall.Options = {
		radius = M.Kicker.Radius,
		endAngle = M.Kicker.Angle,
		steps = M.Kicker.Steps,
		thickness = M.Thickness,
		color = M.RampColor,
		material = Enum.Material.CorrodedMetal,
	}
	ArchSign.make(model, foot, {
		across = edge + 2, -- the posts just outside the walls
		bottom = M.SignHeight,
		text = "SCRAP MOUNTAIN",
		textColor = M.SignColor,
		postColor = M.SteelColor,
	})

	local kicker = CurvedWall.straight(model, axis * CFrame.new(0, 0, -length), 2 * edge, kickOptions)
	kicker.Name = "Kicker"
	CurvedWall.fill(kicker, FLOOR, kickOptions)
	LaunchPad.top(kicker, M.Kicker.Steps, M.Kicker.LaunchSpeed, respawn, M.Kicker.PayScale)

	-- Each flank slopes from the wall's outside down to the ground, a corner
	-- slopes down to meet the front, and junk lies on the flank.
	local rng = Rng.new(M.Seed)
	local kinds = { "Car", "Car", "Tire", "Drum", "Panel" }
	for _, side in { -1, 1 } do
		local function point(out: number, up: number, along: number): Vector3
			return foot * Vector3.new(side * (edge + out), up, -along)
		end
		local slope = Triangle.make(
			model,
			point(0, 0, 0),
			point(0, M.Rise, M.Run),
			point(M.FlankWidth, 0, M.Run),
			Vector3.yAxis + foot.RightVector * side,
			M.Thickness,
			M.FlankColor
		)
		local face = Triangle.make(
			model,
			point(0, M.Rise, M.Run),
			point(M.FlankWidth, 0, M.Run),
			point(0, 0, M.Run + M.FrontRun),
			Vector3.yAxis + foot.LookVector + foot.RightVector * side,
			M.Thickness,
			M.FlankColor
		)
		for _, parts in { slope, face } do
			for _, part in parts do
				part.Material = Enum.Material.Ground
			end
		end
		for _, piece in Junk.onFlank(kinds, rng, M.Decor, M.Run, M.FlankWidth, M.Rise) do
			local at = CFrame.new(point(piece.x, piece.y, piece.z))
				* CFrame.Angles(0, math.rad(piece.yaw), 0)
				* CFrame.Angles(math.rad(piece.tilt), 0, 0)
			local part = JunkPieces.make(model, piece.kind, at, rng)
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	-- And down the front, below the kicker.
	for _, piece in Junk.onSlope(kinds, rng, M.FrontDecor, 2 * edge, M.FrontRun, M.Rise, M.FrontClear) do
		local at = CFrame.new(foot * Vector3.new(piece.x, piece.y, -(M.Run + piece.z)))
			* CFrame.Angles(0, math.rad(piece.yaw), 0)
			* CFrame.Angles(math.rad(piece.tilt), 0, 0)
		local part = JunkPieces.make(model, piece.kind, at, rng)
		part.CanCollide = false
		part.CanQuery = false
	end

	model.Parent = folder
end

return ScrapyardMountain
