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
-- above them shows it.
--
-- The volcano in the southwest corner is a hollow cone of rocky blocks
-- (Volcano) with lava running down its sides, on a lava lake ringed by
-- boulders that only a fast car smashes through. A causeway crosses the
-- lake to the mouth of a round tube (Tunnel.volcano, Pieces.Tube) set into
-- the foot, which climbs round inside the cone and comes up through the
-- crater floor under a stepped rock dome, out onto a rock path across the
-- crater's lava to the vent, a ramp curving up to nearly straight up whose
-- pads erupt the car out over the rim. Lava is tagged Lava; it burns cars (ScoreService).
--
-- Palm trees stand about the park (Scatter), clear of the brontosaurus and
-- the volcano. A T-Rex roams among them hunting cars (DinoRex).
-- Their trunks are solid; their coconuts, and invisible boxes round each
-- trunk and its fronds, are knockable props in one Shatter model, so a car
-- hitting any of them shakes all the coconuts down, a Palm tree target
-- (PropService). Numbers are in Tuning.Dino.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Bronto = require(ReplicatedStorage.Bronto)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Rng = require(ReplicatedStorage.Rng)
local Scatter = require(ReplicatedStorage.Scatter)
local Tuning = require(ReplicatedStorage.Tuning)
local Tunnel = require(ReplicatedStorage.Tunnel)
local Volcano = require(ReplicatedStorage.Volcano)
local CollisionGroups = require(ServerScriptService.CollisionGroups)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)
local Triangle = require(ServerScriptService.Pieces.Triangle)
local Tube = require(ServerScriptService.Pieces.Tube)
local DinoRex = require(script.Parent.DinoRex)

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
local BARK_COLORS = { Color3.fromRGB(120, 88, 56), Color3.fromRGB(98, 70, 44) }
local FROND_COLORS = { Color3.fromRGB(62, 140, 52), Color3.fromRGB(80, 160, 60), Color3.fromRGB(50, 120, 46) }
local COCONUT_COLOR = Color3.fromRGB(105, 72, 40)
local ROCK_COLORS = { Color3.fromRGB(62, 56, 54), Color3.fromRGB(78, 68, 62), Color3.fromRGB(92, 74, 60) }
local CAUSEWAY_COLOR = Color3.fromRGB(110, 96, 84)
local LAVA_COLOR = Color3.fromRGB(255, 96, 24)

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
	local backHeight = L.Height * Bronto.growIn(back.along, L.From, L.Grow)
	local frontHeight = L.Height * Bronto.growIn(front.along, L.From, L.Grow)
	local backPoints = Bronto.crown(back.width, L.Flat, -backHeight, L.Strips)
	local frontPoints = Bronto.crown(front.width, L.Flat, -frontHeight, L.Strips)
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

-- Returns the line it stands on, for keeping trees out of its way.
local function buildBronto(parent: Instance, area: MapLayout.Area): Scatter.Line
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

	-- Seen from above, from the end of the tail's tip to the head.
	local tail = base:PointToWorldSpace(Vector3.new(0, 0, B.Tail.Length))
	local head = base:PointToWorldSpace(Vector3.new(0, 0, -(last.out + last.length / 2 * math.cos(last.tilt))))
	return { AX = tail.X, AZ = tail.Z, BX = head.X, BZ = head.Z, Radius = D.Palms.BrontoClear }
end

-- Marks `part` as lava.
local function lava(part: BasePart)
	part.Color = LAVA_COLOR
	part.Material = Enum.Material.Neon
	CollectionService:AddTag(part, "Lava")
end

-- A rock box in `base`'s space, from x1 to x2, y1 to y2 and z1 to z2.
local function slab(
	parent: Instance,
	name: string,
	base: CFrame,
	x1: number,
	x2: number,
	y1: number,
	y2: number,
	z1: number,
	z2: number
)
	block(
		parent,
		name,
		Vector3.new(x2 - x1, y2 - y1, z2 - z1),
		base * CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2),
		ROCK_COLORS[1]
	)
end

-- How far a rock face or ledge stays from a tube's outline.
local CLEAR = 0.5
-- How high each row of a face round a tube is, and how deep each step of a
-- ledge round one.
local ROW = 2

-- The widest a tube's outline reaches either side of its middle between
-- y1 and y2 up from its ground, or nil when it misses those heights.
local function widest(section: Tunnel.Section, y1: number, y2: number): number?
	return Tunnel.halfWidth(section, math.clamp(section.middle, y1, y2))
end

-- How far either side of its middle the tube whose outline at z is
-- `sectionAt(z)` reaches, from z1 to z2 and y1 to y2 up from `ground`, plus
-- CLEAR, or nil when it is not there.
local function reachOf(
	sectionAt: (number) -> Tunnel.Section,
	ground: number,
	y1: number,
	y2: number,
	z1: number,
	z2: number
): number?
	local most: number? = nil
	for _, z in { z1, z2 } do
		local half = widest(sectionAt(z), y1 - ground, y2 - ground)
		if half and (most == nil or half > most) then
			most = half
		end
	end
	return if most then most + CLEAR else nil
end

-- A rock box from x1 to x2, left out round the tube whose middle is at x =
-- `holeX` and reaches `half` either side, if it is there.
local function slabRound(
	parent: Instance,
	name: string,
	base: CFrame,
	x1: number,
	x2: number,
	y1: number,
	y2: number,
	z1: number,
	z2: number,
	holeX: number,
	half: number?
)
	if not half then
		slab(parent, name, base, x1, x2, y1, y2, z1, z2)
		return
	end
	if holeX - half > x1 then
		slab(parent, name, base, x1, holeX - half, y1, y2, z1, z2)
	end
	if holeX + half < x2 then
		slab(parent, name, base, holeX + half, x2, y1, y2, z1, z2)
	end
end

-- A rock face in `base`'s space facing -Z, from x1 to x2 and y1 to y2, its
-- front at z, in rows ROW high, each stopping short of the tube through it
-- (its outline at z is `sectionAt(z)`, its ground at `ground`).
local function faceRound(
	parent: Instance,
	name: string,
	base: CFrame,
	x1: number,
	x2: number,
	y1: number,
	y2: number,
	z: number,
	holeX: number,
	sectionAt: (number) -> Tunnel.Section,
	ground: number
)
	local y = y1
	while y < y2 - 1e-6 do
		local top = math.min(y + ROW, y2)
		local half = reachOf(sectionAt, ground, y, top, z, z + D.Thickness)
		slabRound(parent, name, base, x1, x2, y, top, z, z + D.Thickness, holeX, half)
		y = top
	end
end

-- A rock ledge in `base`'s space, from x1 to x2 and y1 to y2, from z1 back
-- to z2, in steps ROW deep, each stopping short of the tube through it.
local function ledgeRound(
	parent: Instance,
	name: string,
	base: CFrame,
	x1: number,
	x2: number,
	y1: number,
	y2: number,
	z1: number,
	z2: number,
	holeX: number,
	sectionAt: (number) -> Tunnel.Section,
	ground: number
)
	local steps = math.max(1, math.ceil((z2 - z1) / ROW))
	for i = 1, steps do
		local from, to = z1 + (z2 - z1) * (i - 1) / steps, z1 + (z2 - z1) * i / steps
		slabRound(parent, name, base, x1, x2, y1, y2, from, to, holeX, reachOf(sectionAt, ground, y1, y2, from, to))
	end
end

-- The tube's mouth set into the cone's foot. On each tier the slot was cut
-- through (from spans[i].x1 to spans[i].x2), the blocks beside the slot
-- are rebuilt as columns at most Slot.Column wide, out to the tier's
-- outside and in to its inside. The slot itself gets a face on the tier's
-- step, where the slot's far edge meets its outside (the first tier's at
-- the mouth), fitting round the tube, and over the tier a ledge round the
-- tube back to the next tier's face, or into the uncut tier above, so
-- nothing gets in beside the tube.
local function buildCaveMouth(
	parent: Instance,
	base: CFrame,
	tiers: { Volcano.Tier },
	spans: { [number]: { x1: number, x2: number } },
	random: Random
)
	local V = D.Volcano
	local R, W = V.Climb.Radius, V.Slot.Half
	local mouth = -V.Climb.Inset
	local function sectionAt(z: number): Tunnel.Section
		return Tunnel.section(Tuning.City.Tunnels :: any, z - mouth)
	end
	local cut: { number } = {}
	for i in tiers do
		if spans[i] then
			table.insert(cut, i)
		end
	end
	table.sort(cut)
	local faces: { number } = {}
	for n, i in cut do
		faces[n] = if n == 1 then mouth else -math.sqrt(math.max(tiers[i].outer ^ 2 - (R + W) ^ 2, 0))
	end
	for n, i in cut do
		local tier = tiers[i]
		local top = tier.bottom + tier.height
		local span = spans[i]
		for _, side in { { span.x1, R - W }, { R + W, span.x2 } } do
			for _, column in Volcano.columns(side[1], side[2], V.Slot.Column) do
				local x = (column.x1 + column.x2) / 2
				local front = -math.sqrt(math.max(tier.outer ^ 2 - x ^ 2, 0))
				local back = -math.sqrt(math.max(tier.inner ^ 2 - x ^ 2, 0))
				local height = tier.height + random:NextNumber(0, V.Cone.Jitter)
				block(
					parent,
					"Rock",
					Vector3.new(column.x2 - column.x1, height, back - front),
					base * CFrame.new(x, tier.bottom + height / 2, (front + back) / 2),
					ROCK_COLORS[random:NextInteger(1, #ROCK_COLORS)]
				)
			end
		end
		faceRound(parent, "Cave", base, R - W, R + W, tier.bottom, top, faces[n], R, sectionAt, 0)
		local ledgeTo = faces[n + 1] or faces[n] + V.Cone.Shell
		ledgeRound(
			parent,
			"Cave",
			base,
			R - W,
			R + W,
			top - D.Thickness,
			top,
			faces[n] + D.Thickness,
			ledgeTo,
			R,
			sectionAt,
			0
		)
	end
end

-- The dome over the hatch where the tube comes up through the crater floor:
-- hollow, in steps DomeStep high, each as wide and deep as the tube inside
-- reaches above its bottom (Tunnel.above), the first the whole hatch. Each
-- step has a front face round the tube where it comes out, sides, a back,
-- and a ledge over the part the next step leaves; the last has a roof just
-- over the tube.
local function buildDome(parent: Instance, base: CFrame, climb: Tunnel.VolcanoTube)
	local V = D.Volcano
	local T = Tuning.City.Tunnels
	local floor, hatch = climb.floor, climb.hatch
	local rise = climb.pieces[#climb.pieces - 1]
	local round = Tunnel.section(T :: any, math.huge)
	local function sectionAt(_: number): Tunnel.Section
		return round
	end
	local top = floor + round.middle + round.outside + CLEAR + D.Thickness
	local function stepAt(y: number, first: boolean): Volcano.Rect?
		if first then
			return hatch
		end
		local reach = Tunnel.above(rise, V.Climb.Outside, y - D.Thickness - CLEAR)
		if not reach then
			return nil
		end
		return {
			x1 = math.max(reach.x1, hatch.x1),
			x2 = math.min(reach.x2, hatch.x2),
			z1 = hatch.z1,
			z2 = math.min(reach.z2, hatch.z2),
		}
	end
	local z1 = hatch.z1
	local y = floor
	local step = stepAt(y, true)
	while step and y < top - 1e-6 do
		local to = math.min(y + V.Crater.DomeStep, top)
		local nextStep = if to < top - 1e-6 then stepAt(to, false) else nil
		local x1, x2, z2 = step.x1 - 2, step.x2 + 2, step.z2 + 2
		faceRound(parent, "Dome", base, x1, x2, y, to, z1 - 2, climb.exit.x, sectionAt, floor)
		slab(parent, "Dome", base, x1, step.x1, y, to, z1, z2)
		slab(parent, "Dome", base, step.x2, x2, y, to, z1, z2)
		slab(parent, "Dome", base, step.x1, step.x2, y, to, step.z2, z2)
		-- Over this step, all but where the next one stands.
		local ledge = to - D.Thickness
		if nextStep then
			local nx1, nx2, nz2 = nextStep.x1 - 2, nextStep.x2 + 2, nextStep.z2 + 2
			if nx1 > x1 then
				slab(parent, "Dome", base, x1, nx1, ledge, to, z1 - 2, z2)
			end
			if nx2 < x2 then
				slab(parent, "Dome", base, nx2, x2, ledge, to, z1 - 2, z2)
			end
			if nz2 < z2 then
				slab(parent, "Dome", base, math.max(nx1, x1), math.min(nx2, x2), ledge, to, nz2, z2)
			end
		else
			slab(parent, "Dome", base, x1, x2, ledge, to, z1 - 2, z2)
		end
		y, step = to, nextStep
	end
end

-- The vent: a ramp on the path Run past the tube's mouth, as wide as the
-- path, curving up to Angle degrees. Its planks steeper than PadFrom are
-- pads pushing the car up the curve to LaunchSpeed, so it leaves the lip
-- nearly straight up and out over the rim like an eruption. A wreck after
-- it comes back on the causeway, facing the mouth.
local function buildVent(parent: Instance, base: CFrame, climb: Tunnel.VolcanoTube)
	local V = D.Volcano
	local E = V.Crater.Vent
	local front = base.LookVector
	local foot = base:PointToWorldSpace(Vector3.new(climb.mouth.x, climb.floor, climb.mouth.z - E.Run))
	local ramp = CurvedWall.straight(parent, CFrame.lookAt(foot, foot + front), V.Crater.PathWidth, {
		radius = E.Radius,
		endAngle = E.Angle,
		steps = E.Steps,
		thickness = D.Thickness,
		color = CAUSEWAY_COLOR,
	})
	ramp.Name = "Vent"
	local respawn = base * CFrame.new(V.Climb.Radius, HULL_HEIGHT, -V.Climb.Inset - 60) * CFrame.Angles(0, math.pi, 0)
	local pads = math.ceil(E.Steps * (E.Angle - E.PadFrom) / E.Angle)
	LaunchPad.top(ramp, pads, E.LaunchSpeed, respawn, D.PayScale)
end

-- The crater floor at the tube's floor: lava strips, a rock path from the
-- tube's exit to the front wall with the vent on it, and the dome over the
-- hatch where the tube comes up. The floor reaches into the tier it is
-- level with.
local function buildCrater(parent: Instance, base: CFrame, climb: Tunnel.VolcanoTube, tiers: { Volcano.Tier })
	local V = D.Volcano
	local C = V.Crater
	local floor = climb.floor
	local radius = tiers[1].inner
	for _, tier in tiers do
		if tier.bottom <= floor then
			radius = tier.inner
		end
	end
	local hatch = climb.hatch
	local path: Volcano.Rect = {
		x1 = climb.exit.x - C.PathWidth / 2,
		x2 = climb.exit.x + C.PathWidth / 2,
		z1 = -radius - 1,
		z2 = climb.exit.z,
	}
	for _, piece in Volcano.floor(radius, C.StripWidth, hatch, path) do
		local part = block(
			parent,
			if piece.rock then "Path" else "CraterLava",
			Vector3.new(piece.x2 - piece.x1, D.Thickness, piece.z2 - piece.z1),
			base * CFrame.new((piece.x1 + piece.x2) / 2, floor - D.Thickness / 2, (piece.z1 + piece.z2) / 2),
			CAUSEWAY_COLOR
		)
		if not piece.rock then
			lava(part)
		end
	end

	buildDome(parent, base, climb)
	buildVent(parent, base, climb)
end

-- Boulders round the lake's outside edge, each a knockable prop that only a
-- car faster than BreakSpeed smashes (PropService). Side by side with their
-- inside corners on the edge, so none overlap, as a knocked one would be
-- shoved out by its neighbours, and the gaps are far too thin for a car.
-- None across the causeway.
local function buildBoulders(parent: Instance, base: CFrame, random: Random)
	local V = D.Volcano
	local B = V.Boulders
	local inner = V.Lake.Radius
	local count = math.ceil(2 * math.pi * inner / B.Width)
	local half = math.pi / count
	local width = 2 * inner * math.sin(half) - 0.05
	local middle = inner * math.cos(half) + B.Depth / 2
	local causeway: Volcano.Slot = { X = V.Climb.Radius, Half = V.Causeway.Width / 2, Top = 1 }
	local ground: Volcano.Tier = { bottom = 0, height = 0, outer = inner + B.Depth, inner = inner }
	for k = 1, count do
		local yaw = (k - 1) * 2 * half
		local b: Volcano.Block = {
			yaw = yaw,
			x = middle * math.sin(yaw),
			z = middle * math.cos(yaw),
			width = width,
			depth = B.Depth,
		}
		if not Volcano.inSlot(b, ground, causeway) then
			local height = random:NextNumber(B.MinHeight, B.MaxHeight)
			local boulder = block(
				parent,
				"Boulder",
				Vector3.new(width, height, B.Depth),
				base * CFrame.new(b.x, height / 2, b.z) * CFrame.Angles(0, yaw, 0),
				ROCK_COLORS[random:NextInteger(1, #ROCK_COLORS)]
			)
			boulder:SetAttribute("BreakSpeed", B.BreakSpeed)
			boulder:SetAttribute("ResetTime", B.ResetTime)
			CollectionService:AddTag(boulder, "Knockable")
		end
	end
end

-- Returns the circle it stands in, lava lake and all, for keeping trees out.
local function buildVolcano(parent: Instance, area: MapLayout.Area): Scatter.Line
	local V = D.Volcano
	local model = Instance.new("Model")
	model.Name = "Volcano"

	local base = at(area, V.X, 0, V.Z) * CFrame.Angles(0, math.rad(V.Heading), 0)
	local random = Random.new(V.Seed)
	local climb = Tunnel.volcano(V.Climb :: any, Tuning.City.Tunnels :: any)
	if climb.warning then
		warn(`Dino: {climb.warning}`)
	end
	local slot: Volcano.Slot = { X = V.Climb.Radius, Half = V.Slot.Half, Top = V.Slot.Top }
	-- How far across the blocks left out for the slot reach, on each tier.
	local spans: { [number]: { x1: number, x2: number } } = {}
	-- In front of the vent, the crater wall above the floor is only
	-- Breach.Shell thick, so it stands back from a car erupting off it: a
	-- wedge Breach.Half degrees either side of where the vent's line meets
	-- the rim.
	local rim = V.Cone.TopRadius - V.Cone.Shell
	local ventX = climb.mouth.x
	local breach = math.atan2(ventX, -math.sqrt(math.max(rim ^ 2 - ventX ^ 2, 0)))
	local tiers = Volcano.tiers(V.Cone)
	for i, tier in tiers do
		local blocks = Volcano.ring(tier.outer, tier.inner, V.Cone.BlockWidth)
		local thin = if tier.bottom >= climb.floor
			then Volcano.ring(tier.outer, tier.outer - V.Breach.Shell, V.Cone.BlockWidth)
			else nil
		-- The block each river runs down, if it reaches this tier.
		local rivers: { [number]: boolean } = {}
		for _, river in V.Rivers do
			if i > #tiers - river.Down then
				rivers[math.round(math.rad(river.Yaw) / (2 * math.pi) * #blocks) % #blocks + 1] = true
			end
		end
		for k, b in blocks do
			if thin and Volcano.inWedge(b, breach, math.rad(V.Breach.Half)) then
				b = thin[k]
			end
			if Volcano.inSlot(b, tier, slot) then
				local from, to = Volcano.spanX(b)
				local span = spans[i] or { x1 = math.huge, x2 = -math.huge }
				span.x1, span.x2 = math.min(span.x1, from), math.max(span.x2, to)
				spans[i] = span
			else
				local height = tier.height + random:NextNumber(0, V.Cone.Jitter)
				local rock = block(
					model,
					"Rock",
					Vector3.new(b.width, height, b.depth),
					base * CFrame.new(b.x, tier.bottom + height / 2, b.z) * CFrame.Angles(0, b.yaw, 0),
					ROCK_COLORS[random:NextInteger(1, #ROCK_COLORS)]
				)
				if rivers[k] then
					lava(rock)
				end
			end
		end
	end

	local R = V.Climb.Radius
	if V.Climb.Inset > math.sqrt(V.Cone.BaseRadius ^ 2 - (R + V.Slot.Half) ^ 2) + 0.5 then
		warn("Dino: the volcano's mouth stands out in front of the cone; lower Climb.Inset")
	end
	Tube.build(model, base, climb.pieces, V.Climb.SliceAngle, Tuning.City.Tunnels)
	buildCaveMouth(model, base, tiers, spans, random)
	buildCrater(model, base, climb, tiers)

	-- The lake round the foot, tucked under the bottom tier, and the
	-- causeway across it to the mouth. Both lie on the floor: cars drive on
	-- the floor under them, but CarSensor's rays find them. No lava lies
	-- under the causeway or the mouth: the lake's pieces across it are left
	-- out, and strips of lava fill in either side of it.
	local inner = V.Cone.BaseRadius - V.Cone.Shell / 2
	local half = V.Causeway.Width / 2
	local band: Volcano.Slot = { X = R, Half = half, Top = 1 }
	local ground: Volcano.Tier = { bottom = 0, height = 0, outer = V.Lake.Radius, inner = inner }
	local gapX1, gapX2 = math.huge, -math.huge
	local function lakePiece(size: Vector3, cframe: CFrame)
		local part = decoration(model, "LakeLava", size, cframe, LAVA_COLOR)
		lava(part)
		part.CanQuery = true
	end
	for _, b in Volcano.ring(V.Lake.Radius, inner, V.Lake.BlockWidth) do
		if Volcano.inSlot(b, ground, band) then
			local from, to = Volcano.spanX(b)
			gapX1, gapX2 = math.min(gapX1, from), math.max(gapX2, to)
		else
			lakePiece(Vector3.new(b.width, 0.4, b.depth), base * CFrame.new(b.x, 0.1, b.z) * CFrame.Angles(0, b.yaw, 0))
		end
	end
	for _, side in { { gapX1, R - half }, { R + half, gapX2 } } do
		for _, column in Volcano.columns(side[1], side[2], V.Slot.Column) do
			local x = (column.x1 + column.x2) / 2
			local near = -math.sqrt(math.max(inner ^ 2 - x ^ 2, 0))
			local far = -math.sqrt(math.max(V.Lake.Radius ^ 2 - x ^ 2, 0))
			lakePiece(Vector3.new(column.x2 - column.x1, 0.4, near - far), base * CFrame.new(x, 0.1, (near + far) / 2))
		end
	end
	local near = V.Climb.Inset
	local far = V.Lake.Radius + 20
	local causeway = decoration(
		model,
		"Causeway",
		Vector3.new(V.Causeway.Width, 0.4, far - near),
		base * CFrame.new(R, 0.2, -(near + far) / 2),
		CAUSEWAY_COLOR
	)
	causeway.CanQuery = true
	buildBoulders(model, base, random)
	model.Parent = parent

	local middle = base.Position
	return {
		AX = middle.X,
		AZ = middle.Z,
		BX = middle.X,
		BZ = middle.Z,
		Radius = V.Lake.Radius + D.Palms.VolcanoClear,
	}
end

-- A knockable part of a palm tree: hitting it shakes down the coconuts.
local function knockable(part: BasePart)
	local P = D.Palms
	part:SetAttribute("Target", "Palm tree")
	part:SetAttribute("ResetTime", P.ResetTime)
	part:SetAttribute("CarSpeedShare", 0)
	CollectionService:AddTag(part, "Knockable")
end

-- An invisible box that counts as hitting the tree.
local function hitBox(parent: Instance, size: Vector3, cframe: CFrame)
	local box = block(parent, "HitBox", size, cframe, BODY_COLOR)
	box.Transparency = 1
	box.CanCollide = false
	box.CanQuery = false
	knockable(box)
	box:SetAttribute("Trigger", true)
end

local function buildPalm(parent: Instance, x: number, z: number, rng: Rng.Rng)
	local P = D.Palms
	local model = Instance.new("Model")
	model.Name = "PalmTree"
	model:SetAttribute("Shatter", true)

	local height = rng.range(P.MinHeight, P.MaxHeight)
	local heading = rng.range(0, 2 * math.pi)
	local lean = Vector3.new(math.cos(heading), 0, math.sin(heading)) * P.Lean * rng.range(0.3, 1)
	local ground = Vector3.new(x, FLOOR, z)
	-- Up the trunk, bending over more toward the top.
	local function trunkAt(t: number): Vector3
		return ground + Vector3.new(0, height * t, 0) + lean * t * t
	end

	for i = 1, P.TrunkSegments do
		local from, to = trunkAt((i - 1) / P.TrunkSegments), trunkAt(i / P.TrunkSegments)
		local size = P.TrunkSize * (1 - 0.3 * i / P.TrunkSegments)
		local segment = block(
			model,
			"Trunk",
			Vector3.new(size, size, (to - from).Magnitude + 0.6),
			CFrame.lookAt((from + to) / 2, to),
			BARK_COLORS[i % 2 + 1]
		)
		segment.Material = Enum.Material.Wood
		segment.CollisionGroup = CollisionGroups.Trunks
	end

	local top = trunkAt(1)
	decoration(model, "Tuft", Vector3.new(5, 3, 5), CFrame.new(top), FROND_COLORS[1])
	for j = 1, P.Fronds do
		local angle = (j + rng.range(-0.3, 0.3)) * 2 * math.pi / P.Fronds
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local color = FROND_COLORS[rng.int(1, #FROND_COLORS)]
		-- Out and a little up, then drooping down.
		local bend = top + out * P.FrondLength * 0.5 + Vector3.new(0, 2, 0)
		local tip = bend + out * P.FrondLength * 0.5 - Vector3.new(0, P.FrondLength * 0.4, 0)
		for _, piece in { { top, bend, 4 }, { bend, tip, 3 } } do
			local from, to, width = piece[1] :: Vector3, piece[2] :: Vector3, piece[3] :: number
			decoration(
				model,
				"Frond",
				Vector3.new(width, 0.5, (to - from).Magnitude + 0.5),
				CFrame.lookAt((from + to) / 2, to),
				color
			)
		end
	end

	-- In a ring round the trunk just under the fronds, clear of the trunk's
	-- corners, so none starts inside it and gets shoved out when it drops.
	local hang = trunkAt(1 - 2 / height)
	local ring = 0.7 * P.TrunkSize * 0.75 + P.CoconutSize / 2 + 0.8
	for k = 1, P.Coconuts do
		local angle = k * 2 * math.pi / P.Coconuts
		local offset = Vector3.new(math.cos(angle) * ring, 0, math.sin(angle) * ring)
		local coconut = block(model, "Coconut", Vector3.one * P.CoconutSize, CFrame.new(hang + offset), COCONUT_COLOR)
		coconut.Shape = Enum.PartType.Ball
		knockable(coconut)
		-- They land round the car in the same ring they hang in.
		coconut:SetAttribute("FallOnCar", true)
		coconut:SetAttribute("FallOffset", offset)
	end

	local reach = P.FrondLength * 0.9
	hitBox(model, Vector3.new(P.Hit + lean.Magnitude, height, P.Hit + lean.Magnitude), CFrame.new((ground + top) / 2))
	hitBox(model, Vector3.new(2 * reach, 14, 2 * reach), CFrame.new(top - Vector3.new(0, 3, 0)))
	model.Parent = parent
end

-- Adds the arrival point to `keepOut` and returns the rectangle the trees
-- stand in.
local function buildPalms(parent: Instance, area: MapLayout.Area, keepOut: { Scatter.Line }): Scatter.Rect
	local P = D.Palms
	local folder = Instance.new("Folder")
	folder.Name = "PalmTrees"
	folder.Parent = parent
	local rng = Rng.new(P.Seed)
	local rect: Scatter.Rect = {
		MinX = area.X - area.Width / 2 + P.Edge,
		MaxX = area.X + area.Width / 2 - P.Edge,
		MinZ = area.Z - area.Depth / 2 + P.Edge,
		MaxZ = area.Z + area.Depth / 2 - P.Edge,
	}
	local arrival: Scatter.Line = {
		AX = area.ArriveX,
		AZ = area.ArriveZ,
		BX = area.ArriveX,
		BZ = area.ArriveZ,
		Radius = P.ArrivalClear,
	}
	table.insert(keepOut, arrival)
	for _, spot in Scatter.points(rng, P.Count, rect, P.Gap, keepOut) do
		buildPalm(folder, spot.x, spot.z, rng)
	end
	return rect
end

-- The T-Rex roams wherever the trees may stand (DinoRex runs it).
local function buildRex(parent: Instance, area: MapLayout.Area, rect: Scatter.Rect, keepOut: { Scatter.Line })
	local R = D.Rex
	local model = Instance.new("Model")
	model.Name = "TRex"
	-- Persistent, so streaming never takes it from a client.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	local territory = { rect = rect, keepOut = keepOut, floor = FLOOR }
	DinoRex.start(model, territory, area.X + R.X, area.Z + R.Z, math.rad(R.Heading))
end

function DinoPark.build(folder: Folder, area: MapLayout.Area)
	grassFloor(folder)
	local bronto = buildBronto(folder, area)
	local volcano = buildVolcano(folder, area)
	local keepOut = { bronto, volcano }
	local trees = buildPalms(folder, area, keepOut)
	buildRex(folder, area, trees, keepOut)
end

return DinoPark
