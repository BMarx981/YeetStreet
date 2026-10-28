--!strict
local Check = require("./Check")
local CarDesign = require("../src/shared/CarDesign")
local CarKit = require("../src/shared/CarKit")
local Rng = require("../src/shared/Rng")

local LOOKS: CarDesign.Looks = {
	BodyBottom = -0.6,
	TrackHalf = 3.6,
	WheelbaseHalf = 3.8,
	WheelRadius = 1.4,
	WheelY = -0.5,
	WheelWidth = 1.1,
	StatSteps = { 5, 12, 20, 30 },
}

local ARCHETYPES = { "hatch", "pickup", "muscle", "buggy", "wedge", "hover", "jeep", "bus" }
local TIERS = { "Junker", "Street", "Sports", "Supercar", "Rebirth" }

local function levels(speed: number, jets: number, toughness: number, grip: number, brakes: number?): CarDesign.Levels
	return { Speed = speed, Jets = jets, Toughness = toughness, Grip = grip, Brakes = brakes or 0 }
end

local ZERO = levels(0, 0, 0, 0)
local MAX = levels(40, 40, 40, 40, 40)

local function design(seed: number, archetype: string, tier: string, lv: CarDesign.Levels?): CarDesign.Design
	return CarDesign.design(Rng.new(seed), { archetype = archetype, tier = tier, levels = lv or ZERO }, CarKit, LOOKS)
end

local function describe(part: CarDesign.PartSpec): string
	local function v(x: CarDesign.Vec): string
		return string.format("%.4f,%.4f,%.4f", x.x, x.y, x.z)
	end
	return `{part.name}|{part.slot or "-"}|{part.wheel or "-"}|{part.shape}|{v(part.size)}|{v(part.position)}|{part.turn}|`
		.. `{part.color[1]},{part.color[2]},{part.color[3]}|{part.material}|{part.role}`
end

local function named(d: CarDesign.Design, name: string): { CarDesign.PartSpec }
	local found = {}
	for _, part in d.parts do
		if part.name == name then
			table.insert(found, part)
		end
	end
	return found
end

local function withRole(d: CarDesign.Design, role: string): { CarDesign.PartSpec }
	local found = {}
	for _, part in d.parts do
		if part.role == role then
			table.insert(found, part)
		end
	end
	return found
end

Check.test("the same seed and inputs give the same car", function()
	for _, archetype in ARCHETYPES do
		local a = design(77, archetype, "Sports", levels(3, 14, 21, 8))
		local b = design(77, archetype, "Sports", levels(3, 14, 21, 8))
		Check.eq(#a.parts, #b.parts, `{archetype} part count`)
		for i, part in a.parts do
			Check.eq(describe(part), describe(b.parts[i]), `{archetype} part {i}`)
		end
		Check.eq(a.name, b.name, `{archetype} name`)
	end
end)

Check.test("different seeds give different cars", function()
	local seen: { [string]: boolean } = {}
	local distinct = 0
	for seed = 1, 10 do
		local d = design(seed, "hatch", "Street")
		local key = describe(d.parts[1]) .. #d.parts
		if not seen[key] then
			seen[key] = true
			distinct += 1
		end
	end
	Check.eq(distinct >= 8, true, `only {distinct} of 10 differ`)
end)

Check.test("every archetype and tier builds a named car with real parts", function()
	for _, archetype in ARCHETYPES do
		for _, tier in TIERS do
			local d = design(5, archetype, tier, levels(10, 10, 10, 10))
			local label = `{archetype} {tier}`
			Check.eq(#d.parts > 5, true, `{label} has parts`)
			Check.eq(#d.name > 0, true, `{label} has a name`)
			for _, part in d.parts do
				local ok = part.size.x > 0 and part.size.y > 0 and part.size.z > 0
				Check.eq(ok, true, `{label} {part.name} has a size`)
				Check.eq(part.position.x == part.position.x, true, `{label} {part.name} position is a number`)
			end
		end
	end
end)

Check.test("the body stays inside the wheels and above the bottom", function()
	for _, archetype in ARCHETYPES do
		for seed = 1, 20 do
			local d = design(seed, archetype, "Street")
			for _, part in d.parts do
				if part.role == "body" or part.role == "glass" then
					local label = `{archetype} seed {seed} {part.name}`
					Check.eq(math.abs(part.position.x) + part.size.x / 2 <= 3.0001, true, `{label} too wide`)
					Check.eq(part.position.y - part.size.y / 2 >= LOOKS.BodyBottom - 1e-4, true, `{label} too low`)
				end
			end
		end
	end
end)

local function top(part: CarDesign.PartSpec): number
	return part.position.y + part.size.y / 2
end

local function bottomOf(part: CarDesign.PartSpec): number
	return part.position.y - part.size.y / 2
end

local CLOSED = { "hatch", "pickup", "muscle", "wedge", "hover", "bus" }

Check.test("the roof sits on the cabin glass, level with the windshield, and no wider", function()
	for _, archetype in CLOSED do
		for seed = 1, 20 do
			local d = design(seed, archetype, "Street")
			local cabins = named(d, "Cabin")
			local roofs = named(d, "Roof")
			local windshield = named(d, "Windshield")[1]
			Check.eq(#roofs, #cabins, `{archetype} seed {seed} a roof on every cabin block`)
			for i, roof in roofs do
				local label = `{archetype} seed {seed} roof {i}`
				local cabin = cabins[i]
				Check.near(bottomOf(roof), top(cabin), `{label} sits on the glass`)
				Check.eq(roof.size.x <= cabin.size.x + 1e-6, true, `{label} no wider than the glass`)
				if windshield then
					Check.near(top(roof), top(windshield), `{label} level with the windshield`)
				end
			end
		end
	end
end)

Check.test("the roll cage rests on the roof, and roof armor on the cage", function()
	for _, archetype in CLOSED do
		for seed = 1, 10 do
			local d = design(seed, archetype, "Street", MAX)
			-- Some cabins are only a windshield and a rear window, with no flat roof.
			local roofTop = -math.huge
			for _, part in d.parts do
				if part.slot == "roof" and part.name ~= "RollCage" and part.name ~= "RoofArmor" then
					roofTop = math.max(roofTop, top(part))
				end
			end
			local cageTop = -math.huge
			for _, bar in named(d, "RollCage") do
				local gap = bottomOf(bar) - roofTop
				Check.eq(gap >= -1e-6 and gap <= 0.05, true, `{archetype} seed {seed} cage gap {gap}`)
				cageTop = math.max(cageTop, top(bar))
			end
			local armor = named(d, "RoofArmor")[1]
			local gap = bottomOf(armor) - cageTop
			Check.eq(gap >= -1e-6 and gap <= 0.05, true, `{archetype} seed {seed} armor gap {gap}`)
		end
	end
end)

Check.test("the body is the same at every stat level; only stat parts change", function()
	for _, archetype in ARCHETYPES do
		local low = withRole(design(31, archetype, "Sports", ZERO), "body")
		local high = withRole(design(31, archetype, "Sports", MAX), "body")
		Check.eq(#low, #high, `{archetype} body part count`)
		for i, part in low do
			Check.eq(describe(part), describe(high[i]), `{archetype} body part {i}`)
		end
	end
end)

Check.test("a look step is how many StatSteps thresholds the level has reached", function()
	Check.eq(CarDesign.step(0, LOOKS.StatSteps), 0)
	Check.eq(CarDesign.step(4, LOOKS.StatSteps), 0)
	Check.eq(CarDesign.step(5, LOOKS.StatSteps), 1)
	Check.eq(CarDesign.step(19, LOOKS.StatSteps), 2)
	Check.eq(CarDesign.step(30, LOOKS.StatSteps), 4)
	Check.eq(CarDesign.step(99, LOOKS.StatSteps), 4)
end)

Check.test("every car has a thruster, and more Jets adds more and changes the flame", function()
	local counts = {}
	local flames = {}
	for _, jets in { 0, 5, 12, 20, 30 } do
		local d = design(8, "muscle", "Street", levels(0, jets, 0, 0))
		table.insert(counts, #withRole(d, "thruster"))
		table.insert(flames, table.concat(d.flameColor, ","))
	end
	Check.eq(counts[1] >= 1, true, "a thruster at level 0")
	Check.eq(counts[5] > counts[1], true, "more thrusters at the top")
	for i = 2, 5 do
		Check.eq(counts[i] >= counts[i - 1], true, `never fewer at step {i - 1}`)
	end
	Check.eq(flames[1] ~= flames[5], true, "the flame color steps up")
end)

Check.test("thrusters never break off", function()
	local d = design(8, "hatch", "Street", MAX)
	for _, part in withRole(d, "thruster") do
		Check.eq(part.slot, nil)
	end
end)

Check.test("each stat adds its own parts in the right slots", function()
	local base = design(12, "hatch", "Street", ZERO)
	Check.eq(#named(base, "Spoiler"), 0, "no spoiler at 0")
	Check.eq(#named(base, "BullBar"), 0, "no bull bar at 0")
	Check.eq(#named(base, "Flare"), 0, "no flares at 0")

	local fast = design(12, "hatch", "Street", levels(5, 0, 0, 0))
	Check.eq(#named(fast, "Spoiler") > 0, true, "Speed adds a spoiler")
	Check.eq(named(fast, "Spoiler")[1].slot, "tail")

	local tough = design(12, "hatch", "Street", levels(0, 0, 5, 0))
	Check.eq(#named(tough, "BullBar") > 0, true, "Toughness adds a bull bar")
	Check.eq(named(tough, "BullBar")[1].slot, "nose")

	local grippy = design(12, "hatch", "Street", levels(0, 0, 0, 5))
	Check.eq(#named(grippy, "Flare") > 0, true, "Grip adds fender flares")
	Check.eq(named(grippy, "Flare")[1].slot, "sides")
end)

Check.test("higher steps add more stat parts", function()
	local lowSpeed = #design(12, "hatch", "Street", levels(5, 0, 0, 0)).parts
	local highSpeed = #design(12, "hatch", "Street", levels(30, 0, 0, 0)).parts
	Check.eq(highSpeed > lowSpeed, true, "Speed")
	local lowTough = #design(12, "hatch", "Street", levels(0, 0, 5, 0)).parts
	local highTough = #design(12, "hatch", "Street", levels(0, 0, 30, 0)).parts
	Check.eq(highTough > lowTough, true, "Toughness")
	local lowGrip = #design(12, "hatch", "Street", levels(0, 0, 0, 5)).parts
	local highGrip = #design(12, "hatch", "Street", levels(0, 0, 0, 30)).parts
	Check.eq(highGrip > lowGrip, true, "Grip")
end)

local WHEELS = { "FL", "FR", "RL", "RR" }

Check.test("a wheel's center is where its hub rests", function()
	local fl = CarDesign.wheelCenter("FL", LOOKS)
	Check.eq(fl.x, -3.6, "front left is on the left")
	Check.eq(fl.y, -0.5)
	Check.eq(fl.z, -3.8, "front is toward -z")
	local rr = CarDesign.wheelCenter("RR", LOOKS)
	Check.eq(rr.x, 3.6)
	Check.eq(rr.z, 3.8)
end)

Check.test("Brakes adds a caliper and a disc on every wheel, and they never break off", function()
	Check.eq(#withRole(design(12, "hatch", "Street", ZERO), "brake"), 0, "no brake parts at 0")
	local d = design(12, "hatch", "Street", levels(0, 0, 0, 0, 5))
	for _, name in { "Caliper", "BrakeDisc" } do
		local found = named(d, name)
		Check.eq(#found, 4, `{name} count`)
		for i, part in found do
			Check.eq(part.wheel, WHEELS[i], `{name} {i} rides on its wheel`)
			Check.eq(part.slot, nil, `{name} {i} never breaks off`)
			Check.eq(part.role, "brake", `{name} {i} glows when braking`)
		end
	end
end)

Check.test("brake parts sit on the outside face of their wheel", function()
	local d = design(12, "hatch", "Street", levels(0, 0, 0, 0, 30))
	for _, part in withRole(d, "brake") do
		local wheel = part.wheel
		assert(wheel, `{part.name} has a wheel`)
		local center = CarDesign.wheelCenter(wheel, LOOKS)
		local outward = math.sign(center.x)
		local inner = outward * (part.position.x - center.x) - part.size.x / 2
		Check.eq(inner >= LOOKS.WheelWidth / 2 - 1e-6, true, `{part.name} {wheel} outside the tire`)
		local reach = math.max(math.abs(part.position.y - center.y), math.abs(part.position.z - center.z))
		Check.eq(reach <= LOOKS.WheelRadius, true, `{part.name} {wheel} within the tire`)
	end
end)

Check.test("wheel brakes grow and turn red as Brakes steps up", function()
	local sizes = {}
	local colors = {}
	for _, brakes in { 5, 12, 20, 30 } do
		local d = design(12, "hatch", "Street", levels(0, 0, 0, 0, brakes))
		local caliper = named(d, "Caliper")[1]
		local disc = named(d, "BrakeDisc")[1]
		table.insert(sizes, { caliper = caliper.size.y, disc = disc.size.y })
		table.insert(colors, caliper.color)
	end
	for i = 2, 4 do
		Check.eq(sizes[i].caliper > sizes[i - 1].caliper, true, `caliper grows at step {i}`)
		Check.eq(sizes[i].disc > sizes[i - 1].disc, true, `disc grows at step {i}`)
	end
	Check.eq(colors[1][1] < colors[4][1] and colors[4][1] > colors[4][2] * 2, true, "the top calipers are red")
end)

Check.test("brake lights come halfway up the Brakes steps, on the tail", function()
	Check.eq(#named(design(12, "hatch", "Street", levels(0, 0, 0, 0, 5)), "BrakeLight"), 0, "none at step 1")
	local d = design(12, "hatch", "Street", levels(0, 0, 0, 0, 12))
	local lights = named(d, "BrakeLight")
	Check.eq(#lights > 0, true, "lights at step 2")
	for _, light in lights do
		Check.eq(light.slot, "tail")
		Check.eq(light.role, "brakeLight")
		Check.eq(light.position.z > d.length / 2, true, "behind the body")
	end
end)

Check.test("taillights stay unlit, and light with the brakes from step 2", function()
	for _, taillight in named(design(12, "hatch", "Street", levels(0, 0, 0, 0, 5)), "Taillight") do
		Check.eq(taillight.material ~= "Neon", true, "unlit")
		Check.eq(taillight.role, "trim", "no brake glow at step 1")
	end
	for _, taillight in named(design(12, "hatch", "Street", levels(0, 0, 0, 0, 12)), "Taillight") do
		Check.eq(taillight.material ~= "Neon", true, "unlit")
		Check.eq(taillight.role, "brakeLight", "glows with the brakes at step 2")
	end
end)

Check.test("brake lights never overlap each other or the taillights", function()
	local function overlap(a: CarDesign.PartSpec, b: CarDesign.PartSpec): boolean
		return math.abs(a.position.x - b.position.x) < (a.size.x + b.size.x) / 2
			and math.abs(a.position.y - b.position.y) < (a.size.y + b.size.y) / 2
	end
	for _, archetype in ARCHETYPES do
		for seed = 1, 10 do
			local d = design(seed, archetype, "Street", MAX)
			local lights = named(d, "BrakeLight")
			local others = table.clone(lights)
			for _, taillight in named(d, "Taillight") do
				table.insert(others, taillight)
			end
			for i, light in lights do
				for j, other in others do
					if i ~= j then
						local label = `{archetype} seed {seed} brake light {i} and {other.name} {j}`
						Check.eq(overlap(light, other), false, label)
					end
				end
			end
		end
	end
end)

Check.test("hover cars get brake lights but no wheel brakes", function()
	local d = design(4, "hover", "Supercar", levels(0, 0, 0, 0, 30))
	Check.eq(#withRole(d, "brake"), 0, "no wheels to brake")
	Check.eq(#named(d, "BrakeLight") > 0, true, "brake lights")
end)

Check.test("only hover cars hide their wheels, and they get hover pads", function()
	for _, archetype in ARCHETYPES do
		local d = design(4, archetype, "Supercar")
		Check.eq(d.hideWheels, archetype == "hover", archetype)
		Check.eq(#named(d, "HoverPad") > 0, archetype == "hover", `{archetype} pads`)
	end
end)

Check.test("jeeps have a flat nose with a grille, an upright windshield, and a spare tire", function()
	for seed = 1, 20 do
		local d = design(seed, "jeep", "Street")
		local label = `jeep seed {seed}`
		Check.eq(#named(d, "NoseSlope"), 0, `{label} no sloped hood`)
		Check.eq(#named(d, "Grille"), 1, `{label} grille`)
		Check.eq(#named(d, "Windshield"), 0, `{label} no sloped windshield`)
		Check.eq(#named(d, "RearWindow"), 0, `{label} no sloped rear window`)
		local spare = named(d, "Spare")
		Check.eq(#spare, 1, `{label} one spare`)
		Check.eq(spare[1].shape, "cylinder", `{label} spare is round`)
		Check.eq(spare[1].slot, "tail", `{label} spare breaks off the tail`)
		Check.eq(spare[1].position.z > d.length / 2, true, `{label} spare behind the body`)
	end
end)

Check.test("some jeeps are open with a windshield frame, the rest have a hard top", function()
	local open, closed = 0, 0
	for seed = 1, 40 do
		local d = design(seed, "jeep", "Street")
		local isOpen = #named(d, "Seat") > 0
		if isOpen then
			open += 1
			Check.eq(#named(d, "Roof"), 0, `jeep seed {seed} open has no roof`)
			Check.eq(#named(d, "FrontWindow"), 1, `jeep seed {seed} open has a windshield`)
		else
			closed += 1
			Check.eq(#named(d, "Roof") > 0, true, `jeep seed {seed} hard top has a roof`)
		end
	end
	Check.eq(open > 0, true, "some open jeeps")
	Check.eq(closed > 0, true, "some hard top jeeps")
end)

Check.test("school buses are yellow on every tier", function()
	local yellow = CarKit.Archetypes.bus.Paint
	assert(yellow, "the bus has a fixed paint")
	for _, tier in TIERS do
		for seed = 1, 5 do
			local d = design(seed, "bus", tier)
			for _, part in withRole(d, "body") do
				local label = `bus {tier} seed {seed} {part.name}`
				Check.eq(table.concat(part.color, ","), table.concat(yellow, ","), label)
			end
		end
	end
end)

Check.test("school buses have painted walls with windows, stripes, and a stop sign", function()
	for seed = 1, 20 do
		local d = design(seed, "bus", "Street")
		local label = `bus seed {seed}`
		local cabins = named(d, "Cabin")
		Check.eq(#cabins >= 3, true, `{label} a long cabin`)
		for _, cabin in cabins do
			Check.eq(cabin.role, "body", `{label} walls are painted`)
		end
		local left, right = 0, 0
		for _, window in named(d, "Window") do
			Check.eq(window.role, "glass", `{label} windows are glass`)
			if window.position.x < 0 then
				left += 1
			else
				right += 1
			end
		end
		Check.eq(left, #cabins, `{label} a window per cabin slice on the left`)
		Check.eq(right, #cabins, `{label} a window per cabin slice on the right`)
		Check.eq(#named(d, "FrontWindow"), 1, `{label} front window`)
		Check.eq(#named(d, "BusStripe") > 0, true, `{label} stripes`)
		local sign = named(d, "StopSign")
		Check.eq(#sign, 1, `{label} stop sign`)
		Check.eq(sign[1].position.x < 0, true, `{label} stop sign on the left`)
	end
end)

Check.test("school buses stand taller than the other cars", function()
	local function height(d: CarDesign.Design): number
		local highest = -math.huge
		for _, part in d.parts do
			if part.role == "body" or part.role == "glass" then
				highest = math.max(highest, top(part))
			end
		end
		return highest
	end
	for seed = 1, 20 do
		local bus = height(design(seed, "bus", "Street"))
		for _, archetype in { "hatch", "pickup", "muscle", "jeep" } do
			Check.eq(bus > height(design(seed, archetype, "Street")), true, `bus vs {archetype} seed {seed}`)
		end
	end
end)

Check.test("breakable lists a slot's parts in a fixed order", function()
	local d = design(21, "pickup", "Street", levels(10, 10, 10, 10))
	for _, slot in { "nose", "tail", "roof", "sides" } :: { CarDesign.Slot } do
		local indexes = CarDesign.breakable(d, slot)
		Check.eq(#indexes > 0, true, `{slot} has parts`)
		for i, index in indexes do
			Check.eq(d.parts[index].slot, slot, `{slot} part {i}`)
			if i > 1 then
				Check.eq(index > indexes[i - 1], true, `{slot} in order`)
			end
		end
	end
end)

Check.test("junkers have mismatched panels; street cars are one color", function()
	local function tubColors(d: CarDesign.Design): { [string]: boolean }
		local colors = {}
		for _, part in named(d, "Tub") do
			colors[table.concat(part.color, ",")] = true
		end
		return colors
	end
	local mixed = 0
	for seed = 1, 10 do
		local count = 0
		for _ in tubColors(design(seed, "hatch", "Junker")) do
			count += 1
		end
		if count > 1 then
			mixed += 1
		end
	end
	Check.eq(mixed >= 5, true, `only {mixed} of 10 junkers are mismatched`)
	local street = 0
	for _ in tubColors(design(3, "hatch", "Street")) do
		street += 1
	end
	Check.eq(street, 1, "street tub colors")
end)

Check.test("sports cars get stripes and supercars get glowing trim", function()
	Check.eq(#named(design(6, "muscle", "Sports"), "Stripe") > 0, true, "stripes")
	Check.eq(#named(design(6, "muscle", "Street"), "Stripe"), 0, "no stripes on street")
	Check.eq(#withRole(design(6, "wedge", "Supercar"), "glow") > 0, true, "glow")
	Check.eq(#withRole(design(6, "wedge", "Street"), "glow"), 0, "no glow on street")
end)

Check.test("the name comes from the tier's words", function()
	for seed = 1, 10 do
		local name = design(seed, "hatch", "Junker").name
		local found = false
		for _, word in CarKit.Names.Junker do
			if string.sub(name, 1, #word) == word then
				found = true
			end
		end
		Check.eq(found, true, `{name} starts with a junker word`)
	end
end)

Check.finish("CarDesign")
