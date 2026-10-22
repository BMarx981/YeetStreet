--!strict
-- Dino (ModuleScript) -> ServerScriptService.Parks.Dino
-- Dino Valley, the prehistoric park, built by ParkService into
-- workspace.Parks.Dino on top of the park's floor, which it turns to grass.
-- The brontosaurus is a ride: a car drives up its tail from the ground, over
-- its back and up its neck, and launches off the top of its head. The path's
-- planks are its skin (Bronto); a blocky body hangs under them on four legs,
-- and the head has eyes and a mouth that never touch a car. Boosters run up
-- the path. Numbers are in Tuning.Dino.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Bronto = require(ReplicatedStorage.Bronto)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)

local D = Tuning.Dino
local FLOOR = Tuning.Map.FloorTop
local HULL_HEIGHT = Tuning.TestPark.SpawnHeight

local GRASS_COLOR = Color3.fromRGB(86, 125, 60)
local SKIN_COLOR = Color3.fromRGB(104, 150, 86)
local BODY_COLOR = Color3.fromRGB(88, 128, 74)
local CLAW_COLOR = Color3.fromRGB(235, 225, 200)
local EYE_COLOR = Color3.fromRGB(250, 250, 240)
local DARK_COLOR = Color3.fromRGB(25, 25, 25)

-- Planks are this much longer than their chord so the seams stay closed.
local OVERLAP = 0.4
-- How far the body sits in from each edge of the path, so a car sliding off
-- the side drops clear instead of catching a ledge.
local BODY_INSET = 1

local DinoPark = {}

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
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A part only for looks: cars and their sensors pass through it.
local function decoration(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = block(parent, name, size, cframe, color)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

local function grassFloor(folder: Folder)
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Floor" then
			part.Color = GRASS_COLOR
			part.Material = Enum.Material.Grass
		end
	end
end

-- On the path `along` studs from the tail tip, lying on it, facing up it.
local function onPath(base: CFrame, planks: { Bronto.Plank }, along: number): CFrame
	local out, up, tilt = Bronto.pointAt(planks, along)
	return base * CFrame.new(0, up, -out) * CFrame.Angles(tilt, 0, 0)
end

local function buildLeg(parent: Instance, base: CFrame, planks: { Bronto.Plank }, along: number, side: number)
	local B = D.Bronto
	local out, up = Bronto.pointAt(planks, along)
	local plank = Bronto.plankAt(planks, along)
	-- Up into the middle of the body, from the floor.
	local top = up - D.Thickness - plank.depth / 2
	local x = side * (plank.width / 2 - BODY_INSET - B.LegSize / 2)
	local foot = base * CFrame.new(x, 0, -out)
	block(parent, "Leg", Vector3.new(B.LegSize, top, B.LegSize), foot * CFrame.new(0, top / 2, 0), BODY_COLOR)
	for i = -1, 1 do
		decoration(parent, "Claw", Vector3.new(5, 4, 3), foot * CFrame.new(i * 7, 2, -B.LegSize / 2 - 1.5), CLAW_COLOR)
	end
end

-- Eyes near the back of the head and a mouth along each side of it.
local function buildFace(parent: Instance, base: CFrame, planks: { Bronto.Plank }, headStart: number, headEnd: number)
	local head = planks[#planks]
	local side = head.width / 2 - BODY_INSET
	local eye = onPath(base, planks, headStart + 9) * CFrame.new(0, -D.Thickness - 6, 0)
	local mouth = onPath(base, planks, (headStart + headEnd) / 2 + 6)
		* CFrame.new(0, -D.Thickness - head.depth * 0.7, 0)
	for _, s in { -1, 1 } do
		decoration(parent, "Eye", Vector3.new(3, 7, 7), eye * CFrame.new(s * (side + 1), 0, 0), EYE_COLOR)
		decoration(parent, "Pupil", Vector3.new(1, 4, 4), eye * CFrame.new(s * (side + 2.5), 0, -1), DARK_COLOR)
		decoration(
			parent,
			"Mouth",
			Vector3.new(1, 1.5, headEnd - headStart - 12),
			mouth * CFrame.new(s * (side + 0.5), 0, 0),
			DARK_COLOR
		)
	end
end

local function buildBronto(parent: Instance, area: MapLayout.Area)
	local B = D.Bronto
	local model = Instance.new("Model")
	model.Name = "Brontosaurus"
	model.Parent = parent

	local base = at(area, B.X, 0, B.StartZ)
	local respawn = at(area, B.X, HULL_HEIGHT, B.StartZ + 40)
	local planks = Bronto.planks(B.Start, B.Segments, B.Step)
	local last = planks[#planks]
	local headEnd = last.along + last.length / 2
	local headStart = headEnd - B.Segments[#B.Segments].Length

	for i, p in planks do
		local frame = base * CFrame.new(0, p.up, -p.out) * CFrame.Angles(p.tilt, 0, 0)
		local plank = block(
			model,
			"Plank",
			Vector3.new(p.width, D.Thickness, p.length + OVERLAP),
			frame * CFrame.new(0, -D.Thickness / 2, 0),
			SKIN_COLOR
		)
		plank.Material = Enum.Material.Concrete
		if p.along > headStart then
			LaunchPad.make(plank, B.LaunchSpeed, respawn, D.PayScale)
		elseif i % B.BoostEvery == 0 then
			LaunchPad.make(plank, B.BoostSpeed, respawn, D.PayScale)
		end
		block(
			model,
			"Body",
			Vector3.new(p.width - 2 * BODY_INSET, p.depth, p.length + OVERLAP),
			frame * CFrame.new(0, -D.Thickness - p.depth / 2, 0),
			BODY_COLOR
		)
	end

	for _, along in { B.Hips, B.Shoulders } do
		for _, side in { -1, 1 } do
			buildLeg(model, base, planks, along, side)
		end
	end
	buildFace(model, base, planks, headStart, headEnd)
end

function DinoPark.build(folder: Folder, area: MapLayout.Area)
	grassFloor(folder)
	buildBronto(folder, area)
end

return DinoPark
