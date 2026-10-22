--!strict
-- Dino (ModuleScript) -> ServerScriptService.Parks.Dino
-- Dino Valley, the prehistoric park, built by ParkService into
-- workspace.Parks.Dino on top of the park's floor, which it turns to grass.
-- The brontosaurus is a ride: a car drives up its tail from the ground, over
-- its back and up its neck, and launches off the top of its head. Along the
-- path (Bronto) its skin is a flat strip down the middle, with rounded sides
-- rolling down to its edges, but only for looks: cars drive on an invisible
-- track under the flat strip, whose edges rise into lips that keep them on,
-- built from triangles between the planks' ends so they have no steps. A
-- blocky body hangs under the skin on four legs. Spots, wrinkles, scales,
-- eyes and a mouth never touch a car either. The tail's swishing tip is
-- built on each client (DinoTail). Boosters run up the track, and the skin
-- above them shows it. Numbers are in Tuning.Dino.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Bronto = require(ReplicatedStorage.Bronto)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)
local Triangle = require(ServerScriptService.Pieces.Triangle)

local D = Tuning.Dino
local FLOOR = Tuning.Map.FloorTop
local HULL_HEIGHT = Tuning.TestPark.SpawnHeight

local GRASS_COLOR = Color3.fromRGB(86, 125, 60)
local SKIN_COLOR = Color3.fromRGB(104, 150, 86)
local WRINKLE_COLOR = Color3.fromRGB(78, 116, 66)
local SPOT_COLOR = Color3.fromRGB(66, 98, 56)
local SCALE_COLOR = Color3.fromRGB(214, 150, 64)
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

-- How far below the flat middle the rounded back's edges are, `width` across.
local function dropOf(width: number): number
	return D.Bronto.Crown.Drop * width
end

-- On the path `along` studs from the tail tip, lying on it, facing up it.
local function onPath(base: CFrame, planks: { Bronto.Plank }, along: number): CFrame
	local out, up, tilt = Bronto.pointAt(planks, along)
	return base * CFrame.new(0, up, -out) * CFrame.Angles(tilt, 0, 0)
end

local function sectionFrame(base: CFrame, section: Bronto.Section): CFrame
	return base * CFrame.new(0, section.up, -section.out) * CFrame.Angles(section.tilt, 0, 0)
end

-- Both rounded sides of the skin over one plank, a strip of the crown each.
local function buildSkinSides(parent: Instance, frame: CFrame, plank: Bronto.Plank, color: Color3): { BasePart }
	local C = D.Bronto.Crown
	local points = Bronto.crown(plank.width, C.Flat, C.Drop, C.Strips)
	local parts: { BasePart } = {}
	for _, side in { -1, 1 } do
		for k = 1, C.Strips do
			local a, b = points[k], points[k + 1]
			local across = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
			local roll = math.atan2(b.y - a.y, b.x - a.x)
			table.insert(
				parts,
				decoration(
					parent,
					"Skin",
					Vector3.new(across + OVERLAP, D.Thickness, plank.length + OVERLAP),
					frame
						* CFrame.new(side * (a.x + b.x) / 2, (a.y + b.y) / 2, 0)
						* CFrame.Angles(0, 0, side * roll)
						* CFrame.new(0, -D.Thickness / 2, 0),
					color
				)
			)
		end
	end
	return parts
end

-- Both invisible lips of the track between two sections, as triangles.
local function buildLips(parent: Instance, base: CFrame, back: Bronto.Section, front: Bronto.Section): { BasePart }
	local L = D.Bronto.Lip
	local backFrame, frontFrame = sectionFrame(base, back), sectionFrame(base, front)
	local backPoints = Bronto.crown(back.width, L.Flat, -L.Height, L.Strips)
	local frontPoints = Bronto.crown(front.width, L.Flat, -L.Height, L.Strips)
	local up = backFrame.UpVector + frontFrame.UpVector
	local parts: { BasePart } = {}
	for _, side in { -1, 1 } do
		local function corner(frame: CFrame, point: Bronto.CrownPoint): Vector3
			return frame:PointToWorldSpace(Vector3.new(side * point.x, point.y, 0))
		end
		for k = 1, L.Strips do
			local a, b = corner(backFrame, backPoints[k]), corner(backFrame, backPoints[k + 1])
			local c, d = corner(frontFrame, frontPoints[k]), corner(frontFrame, frontPoints[k + 1])
			for _, part in Triangle.make(parent, a, b, d, up, D.Thickness, SKIN_COLOR) do
				table.insert(parts, part)
			end
			for _, part in Triangle.make(parent, a, d, c, up, D.Thickness, SKIN_COLOR) do
				table.insert(parts, part)
			end
		end
	end
	for _, part in parts do
		part.Name = "Track"
		part.Transparency = 1
	end
	return parts
end

local function buildLeg(parent: Instance, base: CFrame, planks: { Bronto.Plank }, along: number, side: number)
	local B = D.Bronto
	local out, up = Bronto.pointAt(planks, along)
	local plank = Bronto.plankAt(planks, along)
	-- Up into the middle of the body, from the floor.
	local top = up - D.Thickness - dropOf(plank.width) - plank.depth / 2
	local x = side * (plank.width / 2 - BODY_INSET - B.LegSize / 2)
	local foot = base * CFrame.new(x, 0, -out)
	block(parent, "Leg", Vector3.new(B.LegSize, top, B.LegSize), foot * CFrame.new(0, top / 2, 0), BODY_COLOR)
	for i = -1, 1 do
		decoration(parent, "Claw", Vector3.new(5, 4, 3), foot * CFrame.new(i * 7, 2, -B.LegSize / 2 - 1.5), CLAW_COLOR)
	end
end

-- Dark patches on the flat middle, from the tail to the neck.
local function buildSpots(parent: Instance, base: CFrame, planks: { Bronto.Plank })
	local S = D.Bronto.Spots
	local random = Random.new(S.Seed)
	for _ = 1, S.Count do
		local along = random:NextNumber(S.From, S.To)
		local half = Bronto.plankAt(planks, along).width * D.Bronto.Crown.Flat / 2
		local size = math.min(random:NextNumber(S.MinSize, S.MaxSize), half)
		local x = random:NextNumber(-(half - size / 2), half - size / 2)
		decoration(
			parent,
			"Spot",
			Vector3.new(size, 0.1, size * random:NextNumber(0.6, 1)),
			onPath(base, planks, along) * CFrame.new(x, 0.06, 0) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0),
			SPOT_COLOR
		)
	end
end

-- A row of round scales along each edge, from the tail to the head.
local function buildScales(parent: Instance, base: CFrame, planks: { Bronto.Plank }, headStart: number)
	local along = D.Bronto.ScaleEvery
	while along < headStart do
		local width = Bronto.plankAt(planks, along).width
		local size = math.clamp(width * 0.12, 3, 7)
		local frame = onPath(base, planks, along)
		for _, side in { -1, 1 } do
			local scale = decoration(
				parent,
				"Scale",
				Vector3.one * size,
				frame * CFrame.new(side * width / 2, -dropOf(width), 0),
				SCALE_COLOR
			)
			scale.Shape = Enum.PartType.Ball
		end
		along += D.Bronto.ScaleEvery
	end
end

-- Eyes beside the back of the head, standing up past its edges so they show
-- over the top of the neck on the way up, and a mouth along each side.
local function buildFace(parent: Instance, base: CFrame, planks: { Bronto.Plank }, headStart: number, headEnd: number)
	local head = planks[#planks]
	local edge = head.width / 2
	local eye = onPath(base, planks, headStart + 10)
	local mouth = onPath(base, planks, (headStart + headEnd) / 2 + 6)
		* CFrame.new(0, -D.Thickness - dropOf(head.width) - head.depth * 0.6, 0)
	for _, s in { -1, 1 } do
		decoration(parent, "Eye", Vector3.new(6, 9, 9), eye * CFrame.new(s * (edge + 2), 1.5, 0), EYE_COLOR)
		decoration(parent, "Pupil", Vector3.new(1.5, 5, 5), eye * CFrame.new(s * (edge + 5.2), 2.5, -1.5), DARK_COLOR)
		decoration(parent, "Brow", Vector3.new(7, 2, 11), eye * CFrame.new(s * (edge + 2), 7, 0), BODY_COLOR)
		decoration(
			parent,
			"Mouth",
			Vector3.new(1, 1.5, headEnd - headStart - 12),
			mouth * CFrame.new(s * (edge - BODY_INSET + 0.5), 0, 0),
			DARK_COLOR
		)
	end
end

local function buildBronto(parent: Instance, area: MapLayout.Area)
	local B = D.Bronto
	local model = Instance.new("Model")
	model.Name = "Brontosaurus"
	model.Parent = parent

	local base = at(area, B.X, 0, B.StartZ) * CFrame.Angles(0, math.rad(B.Heading), 0)
	local respawn = base * CFrame.new(0, HULL_HEIGHT, 40)
	local planks = Bronto.planks(B.Start, B.Segments, B.Step)
	local sections = Bronto.sections(planks)
	local last = planks[#planks]
	local headEnd = last.along + last.length / 2
	local headStart = headEnd - B.Segments[#B.Segments].Length

	for i, p in planks do
		local frame = base * CFrame.new(0, p.up, -p.out) * CFrame.Angles(p.tilt, 0, 0)
		local wrinkle = p.along > B.WrinklesFrom and i % B.WrinkleEvery == 0
		local color = if wrinkle then WRINKLE_COLOR else SKIN_COLOR
		local top = frame * CFrame.new(0, -D.Thickness / 2, 0)
		local skin = buildSkinSides(model, frame, p, color)
		table.insert(
			skin,
			decoration(
				model,
				"Skin",
				Vector3.new(p.width * B.Crown.Flat + OVERLAP, D.Thickness, p.length + OVERLAP),
				top,
				color
			)
		)
		local track = buildLips(model, base, sections[i], sections[i + 1])
		local middle = block(
			model,
			"Track",
			Vector3.new(p.width * B.Lip.Flat + OVERLAP, D.Thickness, p.length + OVERLAP),
			top,
			SKIN_COLOR
		)
		middle.Material = Enum.Material.Concrete
		middle.Transparency = 1
		table.insert(track, middle)
		local speed = if p.along > headStart then B.LaunchSpeed elseif i % B.BoostEvery == 0 then B.BoostSpeed else nil
		if speed then
			for _, part in skin do
				LaunchPad.paint(part)
			end
			for _, part in track do
				LaunchPad.make(part, speed, respawn, D.PayScale, frame.LookVector)
			end
		end
		local drop = dropOf(p.width)
		block(
			model,
			"Body",
			Vector3.new(p.width - 2 * BODY_INSET, p.depth, p.length + OVERLAP),
			frame * CFrame.new(0, -D.Thickness - drop - p.depth / 2, 0),
			BODY_COLOR
		)
	end

	for _, along in { B.Hips, B.Shoulders } do
		for _, side in { -1, 1 } do
			buildLeg(model, base, planks, along, side)
		end
	end
	buildSpots(model, base, planks)
	buildScales(model, base, planks, headStart)
	buildFace(model, base, planks, headStart, headEnd)
end

function DinoPark.build(folder: Folder, area: MapLayout.Area)
	grassFloor(folder)
	buildBronto(folder, area)
end

return DinoPark
