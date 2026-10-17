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
	StatSteps = { 5, 12, 20, 30 },
}

local ARCHETYPES = { "hatch", "pickup", "muscle", "buggy", "wedge", "hover" }
local TIERS = { "Junker", "Street", "Sports", "Supercar", "Rebirth" }

local function levels(speed: number, jets: number, toughness: number, grip: number): CarDesign.Levels
	return { Speed = speed, Jets = jets, Toughness = toughness, Grip = grip }
end

local ZERO = levels(0, 0, 0, 0)
local MAX = levels(40, 40, 40, 40)

local function design(seed: number, archetype: string, tier: string, lv: CarDesign.Levels?): CarDesign.Design
	return CarDesign.design(Rng.new(seed), { archetype = archetype, tier = tier, levels = lv or ZERO }, CarKit, LOOKS)
end

local function describe(part: CarDesign.PartSpec): string
	local function v(x: CarDesign.Vec): string
		return string.format("%.4f,%.4f,%.4f", x.x, x.y, x.z)
	end
	return `{part.name}|{part.slot or "-"}|{part.shape}|{v(part.size)}|{v(part.position)}|{part.turn}|`
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

Check.test("only hover cars hide their wheels, and they get hover pads", function()
	for _, archetype in ARCHETYPES do
		local d = design(4, archetype, "Supercar")
		Check.eq(d.hideWheels, archetype == "hover", archetype)
		Check.eq(#named(d, "HoverPad") > 0, archetype == "hover", `{archetype} pads`)
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
