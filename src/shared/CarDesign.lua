--!strict
-- CarDesign (ModuleScript) -> ReplicatedStorage.CarDesign
-- The car generator: turns a seed, archetype, tier, and stat levels into a
-- list of cosmetic parts. Pure, see InputAxes. The caller passes Rng.new(seed)
-- and the kit (CarKit), so the same inputs give the same car everywhere.
--
-- Parts are in car space: studs from the hull's center, x to the right, y up,
-- the nose toward -z. A wedge with turn 0 rises toward the back; turn 180
-- rises toward the front. A cylinder's length is its size.x, along its axis,
-- which turn 90 points lengthways.
--
-- The body comes only from the seed: 5 to 8 slices nose to tail, in nose,
-- cabin, and rear zones, sized from the archetype's ranges. Stat levels add
-- parts on top through look steps (Looks.StatSteps) and use no randomness, so
-- upgrading never changes the body:
--   Speed      spoiler, exhausts, hood scoop, a second wing
--   Jets       more and bigger thrusters, hotter flame
--   Toughness  bull bar, side armor, roll cage, roof armor
--   Grip       fender flares front then back, side skirts, front splitter
--
-- Parts with a slot can break off (Toughness hits that slot); thrusters,
-- seats, and the like never do. CarDesign.breakable lists a slot's parts in a
-- fixed order, so the server and every client break the same ones.

local CarDesign = {}

export type Slot = "nose" | "tail" | "roof" | "sides" | "underside"
export type Shape = "block" | "wedge" | "cylinder"
export type Role = "body" | "glass" | "trim" | "glow" | "thruster"
export type Vec = { x: number, y: number, z: number }
export type Color = { number }

export type PartSpec = {
	name: string,
	slot: Slot?, -- breakable when set
	shape: Shape,
	size: Vec,
	position: Vec,
	turn: number, -- degrees about the car's up axis
	color: Color,
	material: string,
	reflectance: number,
	role: Role,
}

export type Design = {
	name: string,
	parts: { PartSpec },
	hideWheels: boolean,
	flameColor: Color,
	length: number,
	width: number,
}

export type Levels = {
	Speed: number,
	Jets: number,
	Toughness: number,
	Grip: number,
}

export type Input = {
	archetype: string,
	tier: string,
	levels: Levels,
}

export type Looks = {
	BodyBottom: number, -- y of the body's underside
	TrackHalf: number, -- wheel centers from the middle, sideways
	WheelbaseHalf: number, -- wheel centers from the middle, lengthways
	WheelRadius: number,
	StatSteps: { number }, -- levels where each look step starts
}

-- Same as Rng.Rng, declared here so this module needs no require.
type Rng = {
	next: () -> number,
	range: (low: number, high: number) -> number,
	int: (low: number, high: number) -> number,
}

-- Same as CarKit's types, for the same reason.
type Range = { number }
type Archetype = {
	Length: Range,
	Slices: Range,
	Width: Range,
	Nose: Range,
	CabinEnd: Range,
	NoseHeight: Range,
	BodyHeight: Range,
	CabinHeight: Range,
	RearSlope: boolean,
	Bed: boolean?,
	Open: boolean?,
	Hover: boolean?,
}
type Tier = {
	Paints: { Color },
	Mismatched: boolean?,
	Accents: { Color }?,
	Stripes: boolean?,
	Glows: { Color }?,
	Material: string,
	Gloss: number,
	Trim: Color,
	Glass: Color,
}
export type Kit = {
	Archetypes: { [string]: Archetype },
	Tiers: { [string]: Tier },
	FlameColors: { Color },
	Names: { [string]: { string } },
	NameSuffixes: { string },
}

-- How a part is painted.
type Paint = { color: Color, material: string, reflectance: number, role: Role }

local HEADLIGHT: Color = { 255, 250, 220 }
local TAILLIGHT: Color = { 220, 30, 30 }
local HOVER_GLOW: Color = { 80, 200, 255 }

local THRUSTER_COUNTS = { 1, 2, 2, 3, 4 } -- by Jets look step, from 0
local THRUSTER_RADII = { 0.45, 0.5, 0.6, 0.65, 0.75 }

local function vec(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end

local function range(rng: Rng, r: Range): number
	return rng.range(r[1], r[2])
end

local function pick<T>(rng: Rng, list: { T }): T
	return list[rng.int(1, #list)]
end

-- How many of `steps` the level has reached: 0 below the first.
function CarDesign.step(level: number, steps: { number }): number
	local reached = 0
	for _, threshold in steps do
		if level >= threshold then
			reached += 1
		end
	end
	return reached
end

-- Indexes into design.parts of the parts in `slot`, in order.
function CarDesign.breakable(design: Design, slot: Slot): { number }
	local indexes = {}
	for i, part in design.parts do
		if part.slot == slot then
			table.insert(indexes, i)
		end
	end
	return indexes
end

function CarDesign.design(rng: Rng, input: Input, kit: Kit, looks: Looks): Design
	local shape = kit.Archetypes[input.archetype]
	local tier = kit.Tiers[input.tier]
	assert(shape, `CarDesign: no archetype {input.archetype}`)
	assert(tier, `CarDesign: no tier {input.tier}`)

	local parts: { PartSpec } = {}
	local function add(kind: Shape, name: string, slot: Slot?, size: Vec, position: Vec, paint: Paint, turn: number?)
		table.insert(parts, {
			name = name,
			slot = slot,
			shape = kind,
			size = size,
			position = position,
			turn = turn or 0,
			color = paint.color,
			material = paint.material,
			reflectance = paint.reflectance,
			role = paint.role,
		})
	end

	-- The body, all from the seed.
	local length = range(rng, shape.Length)
	local width = range(rng, shape.Width)
	local count = rng.int(shape.Slices[1], shape.Slices[2])
	local noseEnd = range(rng, shape.Nose)
	local cabinEnd = range(rng, shape.CabinEnd)
	local noseHeight = range(rng, shape.NoseHeight)
	local bodyHeight = range(rng, shape.BodyHeight)
	local cabinHeight = range(rng, shape.CabinHeight)

	local noseCount = math.max(1, math.floor(noseEnd * count + 0.5))
	local cabinCount = math.max(1, math.floor((cabinEnd - noseEnd) * count + 0.5))
	noseCount = math.min(noseCount, count - 1)
	cabinCount = math.min(cabinCount, count - noseCount)
	local sliceLength = length / count
	local bottom = looks.BodyBottom

	local mainPaint = pick(rng, tier.Paints)
	local accent = if tier.Accents then pick(rng, tier.Accents) else tier.Trim
	local glow = if tier.Glows then pick(rng, tier.Glows) else HOVER_GLOW

	-- Each slice's tub height and paint. Nose and rear slices vary a little.
	local heights: { number } = {}
	local sliceColors: { Color } = {}
	for i = 1, count do
		local zoneHeight = if i <= noseCount then noseHeight else bodyHeight
		local jitter = if i <= noseCount or i > noseCount + cabinCount then rng.range(-0.08, 0.08) else 0
		heights[i] = zoneHeight + jitter
		sliceColors[i] = if tier.Mismatched then pick(rng, tier.Paints) else mainPaint
	end

	local name = pick(rng, kit.Names[input.tier])
	if rng.next() < 0.5 then
		name = `{name} {pick(rng, kit.NameSuffixes)}`
	end

	local function bodyPaint(color: Color): Paint
		return { color = color, material = tier.Material, reflectance = tier.Gloss, role = "body" }
	end
	local trimPaint: Paint = { color = tier.Trim, material = "Metal", reflectance = 0, role = "trim" }
	local paintedTrim: Paint = { color = mainPaint, material = tier.Material, reflectance = tier.Gloss, role = "trim" }
	local glassPaint: Paint = { color = tier.Glass, material = "Glass", reflectance = 0.2, role = "glass" }
	local roofPaint = bodyPaint(if tier.Accents then accent else mainPaint)

	local function sliceZ(i: number): number
		return -length / 2 + (i - 0.5) * sliceLength
	end
	local function isCabin(i: number): boolean
		return i > noseCount and i <= noseCount + cabinCount
	end
	local function isBed(i: number): boolean
		return shape.Bed == true and i > noseCount + cabinCount
	end
	local function sliceSlot(i: number): Slot
		return if i == 1 then "nose" elseif i == count then "tail" else "sides"
	end
	-- The top of slice i, counting its cabin or cage.
	local function topAt(i: number): number
		local top = bottom + heights[i]
		return if isCabin(i) then top + cabinHeight else top
	end

	for i = 1, count do
		local z = sliceZ(i)
		local h = heights[i]
		local paint = bodyPaint(sliceColors[i])
		if i == 1 then
			-- The nose tip: a lower block with a sloped hood on top.
			local low = h * 0.6
			add("block", "Tub", "nose", vec(width, low, sliceLength), vec(0, bottom + low / 2, z), paint)
			add(
				"wedge",
				"NoseSlope",
				"nose",
				vec(width, h - low, sliceLength),
				vec(0, bottom + low + (h - low) / 2, z),
				paint
			)
		elseif isBed(i) then
			-- An open bed: a low floor between two walls, and a tailgate at the back.
			local floor = h * 0.45
			local wall = h - floor
			add("block", "BedFloor", sliceSlot(i), vec(width, floor, sliceLength), vec(0, bottom + floor / 2, z), paint)
			for _, side in { -1, 1 } do
				local x = side * (width / 2 - 0.15)
				add(
					"block",
					"BedWall",
					"sides",
					vec(0.3, wall, sliceLength),
					vec(x, bottom + floor + wall / 2, z),
					paint
				)
			end
			if i == count then
				local gateZ = z + sliceLength / 2 - 0.15
				add(
					"block",
					"Tailgate",
					"tail",
					vec(width - 0.6, wall, 0.3),
					vec(0, bottom + floor + wall / 2, gateZ),
					paint
				)
			end
		else
			add("block", "Tub", sliceSlot(i), vec(width, h, sliceLength), vec(0, bottom + h / 2, z), paint)
		end
	end

	-- The cabin: glass with a roof, a windshield wedge in front, and a sloped or
	-- straight back. Open cars get a roll cage and a seat instead.
	local cabinFirst = noseCount + 1
	local cabinLast = noseCount + cabinCount
	local cabinBase = bottom + bodyHeight
	if shape.Open then
		local frontZ = sliceZ(cabinFirst) - sliceLength / 2
		local backZ = sliceZ(cabinLast) + sliceLength / 2
		local postY = cabinBase + cabinHeight / 2
		for _, side in { -1, 1 } do
			local x = side * (width / 2 - 0.3)
			add("block", "CagePost", "roof", vec(0.25, cabinHeight, 0.25), vec(x, postY, frontZ + 0.2), trimPaint)
			add("block", "CagePost", "roof", vec(0.25, cabinHeight, 0.25), vec(x, postY, backZ - 0.2), trimPaint)
			local barLength = backZ - frontZ - 0.4
			local barZ = (frontZ + backZ) / 2
			add(
				"block",
				"CageBar",
				"roof",
				vec(0.25, 0.25, barLength),
				vec(x, cabinBase + cabinHeight, barZ),
				trimPaint
			)
		end
		local seatZ = (frontZ + backZ) / 2
		add("block", "Seat", nil, vec(2, 1, 1.6), vec(0, cabinBase + 0.5, seatZ), trimPaint)
	else
		local glassWidth = width - 0.8
		local glassY = cabinBase + cabinHeight / 2
		for i = cabinFirst, cabinLast do
			local z = sliceZ(i)
			local size = vec(glassWidth, cabinHeight, sliceLength)
			local position = vec(0, glassY, z)
			local single = cabinFirst == cabinLast
			if i == cabinFirst and not single then
				add("wedge", "Windshield", "roof", size, position, glassPaint, 0)
			elseif i == cabinLast and not single and shape.RearSlope then
				add("wedge", "RearWindow", "roof", size, position, glassPaint, 180)
			else
				add("block", "Cabin", "roof", size, position, glassPaint)
				add(
					"block",
					"Roof",
					"roof",
					vec(width - 0.6, 0.2, sliceLength),
					vec(0, cabinBase + cabinHeight + 0.1, z),
					roofPaint
				)
			end
		end
	end

	-- Lights.
	local lightY = bottom + heights[1] * 0.35
	local tailY = bottom + heights[count] * 0.6
	for _, side in { -1, 1 } do
		local x = side * (width / 2 - 0.8)
		local headPaint: Paint = { color = HEADLIGHT, material = "Neon", reflectance = 0, role = "trim" }
		local tailPaint: Paint = { color = TAILLIGHT, material = "Neon", reflectance = 0, role = "trim" }
		add("block", "Headlight", "nose", vec(1, 0.35, 0.1), vec(x, lightY, -length / 2 - 0.05), headPaint)
		add("block", "Taillight", "tail", vec(1, 0.3, 0.1), vec(x, tailY, length / 2 + 0.05), tailPaint)
	end

	-- Tier trim: stripes for two tone cars, glowing strips for the top tiers.
	if tier.Stripes then
		local stripePaint = bodyPaint(accent)
		stripePaint.role = "trim"
		for i = 1, noseCount do
			local z = sliceZ(i)
			add(
				"block",
				"Stripe",
				"nose",
				vec(0.8, 0.05, sliceLength),
				vec(0, bottom + heights[i] + 0.025, z),
				stripePaint
			)
		end
	end
	if tier.Glows then
		local glowPaint: Paint = { color = glow, material = "Neon", reflectance = 0, role = "glow" }
		for _, side in { -1, 1 } do
			local x = side * (width / 2 + 0.05)
			add("block", "Glow", "sides", vec(0.1, 0.15, length * 0.8), vec(x, bottom + 0.25, 0), glowPaint)
		end
	end
	if shape.Hover then
		local padPaint: Paint = { color = glow, material = "Neon", reflectance = 0, role = "trim" }
		for _, side in { -1, 1 } do
			for _, ends in { -1, 1 } do
				local position = vec(side * (width / 2 - 0.8), bottom - 0.25, ends * looks.WheelbaseHalf)
				add("block", "HoverPad", "underside", vec(1.6, 0.5, 2.4), position, padPaint)
			end
		end
	end

	-- Stat parts. No randomness from here on.
	local levels = input.levels
	local speed = CarDesign.step(levels.Speed, looks.StatSteps)
	local jets = CarDesign.step(levels.Jets, looks.StatSteps)
	local toughness = CarDesign.step(levels.Toughness, looks.StatSteps)
	local grip = CarDesign.step(levels.Grip, looks.StatSteps)
	local back = length / 2
	local front = -length / 2
	local accentTrim: Paint = { color = accent, material = tier.Material, reflectance = tier.Gloss, role = "trim" }

	-- Jets: thrusters out the back, always at least one.
	local thrusters = THRUSTER_COUNTS[jets + 1]
	local radius = THRUSTER_RADII[jets + 1]
	local thrusterLength = 1 + 0.15 * jets
	local thrusterY = bottom + heights[count] * 0.4
	local spread = math.min(width - 2 * radius - 0.6, (thrusters - 1) * (2 * radius + 0.3))
	local thrusterPaint: Paint = { color = tier.Trim, material = "Metal", reflectance = 0.1, role = "thruster" }
	for k = 1, thrusters do
		local x = if thrusters == 1 then 0 else -spread / 2 + (k - 1) * spread / (thrusters - 1)
		local position = vec(x, thrusterY, back + thrusterLength / 2 - 0.2)
		add("cylinder", "Thruster", nil, vec(thrusterLength, 2 * radius, 2 * radius), position, thrusterPaint, 90)
	end

	-- Speed.
	if speed >= 1 then
		local top = topAt(count)
		add("block", "Spoiler", "tail", vec(width - 0.4, 0.2, 1), vec(0, top + 0.9, back - 0.6), accentTrim)
		for _, side in { -1, 1 } do
			local x = side * (width / 2 - 0.8)
			add("block", "SpoilerPost", "tail", vec(0.2, 0.9, 0.3), vec(x, top + 0.45, back - 0.6), trimPaint)
		end
	end
	if speed >= 2 then
		local pipes = if speed >= 4 then { -1.6, -1, 1, 1.6 } else { -1, 1 }
		for _, offset in pipes do
			local x = offset * (width / 2 - 1) / 1.6
			add("cylinder", "Exhaust", "tail", vec(0.8, 0.35, 0.35), vec(x, bottom + 0.15, back + 0.2), trimPaint, 90)
		end
	end
	if speed >= 3 then
		local i = math.min(2, noseCount)
		local scoopY = bottom + heights[i] + 0.2
		add("block", "Scoop", "nose", vec(1.4, 0.4, sliceLength * 0.8), vec(0, scoopY, sliceZ(i)), paintedTrim)
	end
	if speed >= 4 then
		local top = topAt(count)
		add("block", "Spoiler", "tail", vec(width, 0.25, 1.2), vec(0, top + 1.4, back - 0.7), accentTrim)
	end

	-- Toughness.
	local guardLength = 2 * (looks.WheelbaseHalf - looks.WheelRadius - 0.2)
	if toughness >= 1 then
		local h = heights[1]
		add("block", "BullBar", "nose", vec(width * 0.8, 0.3, 0.3), vec(0, bottom + h * 0.5, front - 0.35), trimPaint)
		for _, side in { -1, 1 } do
			local x = side * width * 0.3
			add(
				"block",
				"BullBarPost",
				"nose",
				vec(0.25, h * 0.8, 0.25),
				vec(x, bottom + h * 0.4, front - 0.35),
				trimPaint
			)
		end
	end
	if toughness >= 2 then
		for _, side in { -1, 1 } do
			local x = side * (width / 2 + 0.125)
			local plate = vec(0.25, bodyHeight * 0.6, guardLength)
			add("block", "Armor", "sides", plate, vec(x, bottom + bodyHeight * 0.5, 0), trimPaint)
		end
	end
	if toughness >= 3 then
		local frontZ = sliceZ(cabinFirst) - sliceLength / 2 + 0.2
		local backZ = sliceZ(cabinLast) + sliceLength / 2 - 0.2
		local cageY = cabinBase + cabinHeight + 0.35
		add("block", "RollCage", "roof", vec(width - 0.6, 0.25, 0.25), vec(0, cageY, frontZ), trimPaint)
		add("block", "RollCage", "roof", vec(width - 0.6, 0.25, 0.25), vec(0, cageY, backZ), trimPaint)
		for _, side in { -1, 1 } do
			local x = side * (width / 2 - 0.4)
			local bar = vec(0.25, 0.25, backZ - frontZ)
			add("block", "RollCage", "roof", bar, vec(x, cageY, (frontZ + backZ) / 2), trimPaint)
		end
	end
	if toughness >= 4 then
		local roofLength = cabinCount * sliceLength * 0.8
		local roofZ = (sliceZ(cabinFirst) + sliceZ(cabinLast)) / 2
		add(
			"block",
			"RoofArmor",
			"roof",
			vec(width - 1, 0.3, roofLength),
			vec(0, cabinBase + cabinHeight + 0.6, roofZ),
			trimPaint
		)
		local h = heights[1]
		add("block", "BullBar", "nose", vec(width * 0.9, 0.3, 0.3), vec(0, bottom + h * 0.2, front - 0.45), trimPaint)
	end

	-- Grip.
	local flareY = bottom + looks.WheelRadius + 0.3
	local flareSize = vec(1.3 + 0.1 * grip, 0.3, 2 * looks.WheelRadius + 0.4)
	local function flares(ends: number)
		for _, side in { -1, 1 } do
			local position = vec(side * looks.TrackHalf, flareY, ends * looks.WheelbaseHalf)
			add("block", "Flare", "sides", flareSize, position, paintedTrim)
		end
	end
	if grip >= 1 then
		flares(-1)
	end
	if grip >= 2 then
		flares(1)
	end
	if grip >= 3 then
		for _, side in { -1, 1 } do
			local x = side * (width / 2 + 0.15)
			add("block", "Skirt", "sides", vec(0.3, 0.3, guardLength), vec(x, bottom + 0.15, 0), paintedTrim)
		end
	end
	if grip >= 4 then
		add("block", "Splitter", "nose", vec(width, 0.15, 0.6), vec(0, bottom + 0.05, front - 0.3), trimPaint)
	end

	return {
		name = name,
		parts = parts,
		hideWheels = shape.Hover == true,
		flameColor = kit.FlameColors[jets + 1],
		length = length,
		width = width,
	}
end

return CarDesign
