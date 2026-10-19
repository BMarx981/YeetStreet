--!strict
-- MapLayout (ModuleScript) -> ReplicatedStorage.MapLayout
-- Where the hub and stunt parks sit on the map, seen from above. Each area is
-- a rectangle on the ground (X and Z are its center, Width runs along X and
-- Depth along Z) with an arrival point where the teleport menu puts a car.
-- Heading is the arriving car's facing in degrees: 0 faces -Z, positive turns
-- left. The layout itself lives in Tuning.Map. Pure, see InputAxes.

local MapLayout = {}

-- "Hub" and "Park" areas are teleport stops; "Open" keeps ground clear, such
-- as the long jump's landing field.
export type Kind = "Hub" | "Park" | "Open"

export type Area = {
	Id: string,
	Name: string,
	Kind: Kind,
	X: number,
	Z: number,
	Width: number,
	Depth: number,
	ArriveX: number,
	ArriveZ: number,
	Heading: number,
}

export type Bounds = {
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
}

-- Whether the two areas come closer than `gap` studs.
function MapLayout.overlaps(a: Area, b: Area, gap: number): boolean
	local apartX = math.abs(a.X - b.X) - (a.Width + b.Width) / 2
	local apartZ = math.abs(a.Z - b.Z) - (a.Depth + b.Depth) / 2
	return apartX < gap and apartZ < gap
end

-- Whether the point is inside the area or on its edge.
function MapLayout.contains(a: Area, x: number, z: number): boolean
	return math.abs(x - a.X) <= a.Width / 2 and math.abs(z - a.Z) <= a.Depth / 2
end

-- The teleport menu's places: every hub and park, in layout order.
function MapLayout.stops(areas: { Area }): { Area }
	local stops = {}
	for _, a in areas do
		if a.Kind ~= "Open" then
			table.insert(stops, a)
		end
	end
	return stops
end

function MapLayout.find(areas: { Area }, id: string): Area?
	for _, a in areas do
		if a.Id == id then
			return a
		end
	end
	return nil
end

-- Everything wrong with the layout, one line each: repeated ids, areas
-- closer than `gap`, areas past the bounds, and arrivals outside their area.
function MapLayout.problems(areas: { Area }, bounds: Bounds, gap: number): { string }
	local problems = {}
	local seen: { [string]: boolean } = {}
	for i, a in areas do
		if seen[a.Id] then
			table.insert(problems, `{a.Id} is used by more than one area`)
		end
		seen[a.Id] = true
		if
			a.X - a.Width / 2 < bounds.MinX
			or a.X + a.Width / 2 > bounds.MaxX
			or a.Z - a.Depth / 2 < bounds.MinZ
			or a.Z + a.Depth / 2 > bounds.MaxZ
		then
			table.insert(problems, `{a.Id} reaches past the edge of the map`)
		end
		if not MapLayout.contains(a, a.ArriveX, a.ArriveZ) then
			table.insert(problems, `{a.Id} has its arrival point outside the area`)
		end
		for j = i + 1, #areas do
			local b = areas[j]
			if MapLayout.overlaps(a, b, gap) then
				table.insert(problems, `{a.Id} and {b.Id} are closer than {gap} studs`)
			end
		end
	end
	return problems
end

return MapLayout
