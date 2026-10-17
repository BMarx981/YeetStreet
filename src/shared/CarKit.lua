--!strict
-- CarKit (ModuleScript) -> ReplicatedStorage.CarKit
-- The hand made side of the car generator, read by CarDesign: body shape
-- ranges for each archetype, a palette for each tier, flame colors for Jets,
-- and words for names. Plain data with no Roblox types, so tests can load it.
--
-- Shapes run nose to tail. Lengths and widths are studs; Nose and CabinEnd are
-- fractions of the body length; heights are studs above the body's bottom.
-- Every range is { low, high } and CarDesign picks within it from the seed.
-- Colors are { r, g, b } from 0 to 255. Materials are Enum.Material names.

local CarKit = {}

export type Range = { number }
export type Color = { number }

export type Archetype = {
	Length: Range,
	Slices: Range,
	Width: Range,
	Nose: Range,
	CabinEnd: Range,
	NoseHeight: Range,
	BodyHeight: Range,
	CabinHeight: Range,
	RearSlope: boolean, -- the cabin's back slopes down instead of standing straight
	Bed: boolean?, -- behind the cabin is an open bed
	Open: boolean?, -- a roll cage instead of a cabin
	Hover: boolean?, -- hover pads instead of wheels
}

export type Tier = {
	Paints: { Color },
	Mismatched: boolean?, -- every slice picks its own paint
	Accents: { Color }?, -- a second color, for two tone and stripes
	Stripes: boolean?,
	Glows: { Color }?, -- neon trim colors
	Material: string,
	Gloss: number, -- reflectance of painted parts
	Trim: Color,
	Glass: Color,
}

CarKit.Archetypes = (
	{
		-- A boxy little car with a tall cabin running nearly to the back.
		hatch = {
			Length = { 11.6, 12.2 },
			Slices = { 5, 7 },
			Width = { 5.4, 6 },
			Nose = { 0.22, 0.3 },
			CabinEnd = { 0.85, 0.95 },
			NoseHeight = { 1.3, 1.6 },
			BodyHeight = { 1.6, 1.9 },
			CabinHeight = { 1.5, 1.9 },
			RearSlope = false,
		},
		-- Tall hood and cab, then an open bed with low walls.
		pickup = {
			Length = { 12.4, 13.2 },
			Slices = { 6, 8 },
			Width = { 5.8, 6 },
			Nose = { 0.25, 0.32 },
			CabinEnd = { 0.5, 0.58 },
			NoseHeight = { 1.7, 2 },
			BodyHeight = { 1.7, 2 },
			CabinHeight = { 1.6, 1.9 },
			RearSlope = false,
			Bed = true,
		},
		-- Long hood, low roof, sloped fastback.
		muscle = {
			Length = { 12.4, 13 },
			Slices = { 6, 8 },
			Width = { 5.8, 6 },
			Nose = { 0.38, 0.48 },
			CabinEnd = { 0.75, 0.85 },
			NoseHeight = { 1.3, 1.5 },
			BodyHeight = { 1.4, 1.6 },
			CabinHeight = { 1.2, 1.5 },
			RearSlope = true,
		},
		-- A thin floor and an open roll cage, no cabin.
		buggy = {
			Length = { 10.8, 11.6 },
			Slices = { 5, 6 },
			Width = { 5, 5.6 },
			Nose = { 0.2, 0.28 },
			CabinEnd = { 0.8, 0.9 },
			NoseHeight = { 0.9, 1.2 },
			BodyHeight = { 0.7, 0.9 },
			CabinHeight = { 1.8, 2.2 }, -- height of the cage
			RearSlope = false,
			Open = true,
		},
		-- Very low and wide, with a long nose and a short glass canopy.
		wedge = {
			Length = { 12, 12.8 },
			Slices = { 6, 8 },
			Width = { 5.9, 6 },
			Nose = { 0.35, 0.45 },
			CabinEnd = { 0.7, 0.8 },
			NoseHeight = { 0.9, 1.1 },
			BodyHeight = { 1.2, 1.4 },
			CabinHeight = { 0.9, 1.2 },
			RearSlope = true,
		},
		-- Smooth body and a bubble canopy, riding on hover pads instead of wheels.
		hover = {
			Length = { 11.6, 12.4 },
			Slices = { 5, 7 },
			Width = { 5.4, 6 },
			Nose = { 0.25, 0.35 },
			CabinEnd = { 0.6, 0.8 },
			NoseHeight = { 1.1, 1.4 },
			BodyHeight = { 1.3, 1.6 },
			CabinHeight = { 1.2, 1.5 },
			RearSlope = true,
			Hover = true,
		},
	}
) :: { [string]: Archetype }

CarKit.Tiers = (
	{
		-- Mismatched panels, corroded metal, dull colors.
		Junker = {
			Paints = {
				{ 140, 80, 50 },
				{ 105, 120, 80 },
				{ 130, 130, 125 },
				{ 80, 95, 120 },
				{ 175, 160, 120 },
			},
			Mismatched = true,
			Material = "CorrodedMetal",
			Gloss = 0,
			Trim = { 60, 58, 55 },
			Glass = { 70, 80, 85 },
		},
		-- Clean single color, basic trim.
		Street = {
			Paints = {
				{ 235, 235, 235 },
				{ 200, 45, 40 },
				{ 40, 90, 190 },
				{ 170, 175, 180 },
				{ 240, 200, 50 },
				{ 50, 140, 80 },
			},
			Material = "SmoothPlastic",
			Gloss = 0.05,
			Trim = { 35, 35, 40 },
			Glass = { 40, 55, 70 },
		},
		-- Glossy two tone with racing stripes.
		Sports = {
			Paints = {
				{ 210, 30, 30 },
				{ 255, 130, 20 },
				{ 250, 210, 30 },
				{ 30, 80, 210 },
				{ 25, 25, 30 },
				{ 240, 240, 240 },
			},
			Accents = {
				{ 245, 245, 245 },
				{ 20, 20, 24 },
				{ 220, 180, 60 },
			},
			Stripes = true,
			Material = "SmoothPlastic",
			Gloss = 0.15,
			Trim = { 25, 25, 30 },
			Glass = { 30, 40, 55 },
		},
		-- Neon trim, bold colors.
		Supercar = {
			Paints = {
				{ 120, 230, 40 },
				{ 230, 40, 160 },
				{ 30, 210, 230 },
				{ 140, 50, 220 },
				{ 255, 110, 0 },
			},
			Glows = {
				{ 0, 255, 255 },
				{ 255, 60, 220 },
				{ 255, 230, 60 },
			},
			Material = "SmoothPlastic",
			Gloss = 0.2,
			Trim = { 20, 20, 24 },
			Glass = { 20, 25, 35 },
		},
		-- Dark metal with glowing parts.
		Rebirth = {
			Paints = {
				{ 20, 20, 26 },
				{ 50, 20, 70 },
				{ 15, 30, 60 },
			},
			Glows = {
				{ 0, 230, 255 },
				{ 255, 40, 200 },
				{ 255, 200, 40 },
			},
			Material = "Metal",
			Gloss = 0.1,
			Trim = { 10, 10, 14 },
			Glass = { 15, 20, 30 },
		},
	}
) :: { [string]: Tier }

-- Jet flame color for each Jets look step, from none to the top step.
CarKit.FlameColors = {
	{ 255, 170, 40 },
	{ 255, 110, 30 },
	{ 255, 60, 60 },
	{ 80, 170, 255 },
	{ 200, 120, 255 },
}

-- Names are a word for the tier, sometimes with a suffix.
CarKit.Names = {
	Junker = { "Rustbucket", "Clunker", "Rattletrap", "Tin Can", "Old Faithful", "Scrapheap" },
	Street = { "Runabout", "Pocket Rocket", "Bean", "Hopper", "Daily", "Scooter" },
	Sports = { "Thunderbolt", "Red Line", "Streak", "Burnout", "Fury", "Afterburner" },
	Supercar = { "Zenith", "Vortex", "Apex", "Nova", "Razor", "Hyperdrive" },
	Rebirth = { "Phoenix", "Comet", "Eclipse", "Singularity", "Starfall", "Reborn" },
}
CarKit.NameSuffixes = { "Mk II", "Mk III", "GT", "X", "Turbo", "Deluxe" }

return CarKit
