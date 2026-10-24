--!strict
local Check = require("./Check")
local Raptors = require("../src/shared/Raptors")

local TUNING: Raptors.Tuning = {
	WalkSpeed = 30,
	SneakSpeed = 40,
	RunSpeed = 110,
	Accel = 400,
	TurnRate = 720,
	Body = 4,
	Watch = 400,
	Ambush = 120,
	HideGap = 8,
	Spacing = 6,
	Wide = 12,
	ViaReach = 8,
	Lead = 0.3,
	LatchReach = 10,
	ChaseTime = 6,
	Lose = 250,
	StopSpeed = 4,
	BiteEvery = 1,
	Bites = 5,
	PinTime = 2.5,
	Rest = 5,
}

local TERRITORY: Raptors.Territory = {
	rect = { MinX = -1000, MaxX = 1000, MinZ = -1000, MaxZ = 1000 },
	keepOut = {},
}

-- A mound lying along z at the middle, 37 by 52 out from its middle, and a
-- bush off to the east.
local MOUND: Raptors.Cover = { x = 0, z = 0, heading = 0, halfX = 37, halfZ = 52, bush = false }
local BUSH: Raptors.Cover = { x = 500, z = 0, heading = 0, halfX = 10, halfZ = 10, bush = true }

local function car(id: any, x: number, z: number, fields: { [string]: any }?): Raptors.Car
	local c: { [string]: any } = { id = id, x = x, y = 3, z = z, vx = 0, vy = 0, vz = 0, air = false, foot = false }
	for key, value in fields or {} do
		c[key] = value
	end
	return (c :: any) :: Raptors.Car
end

local function run(packs: { Raptors.Pack }, cars: { Raptors.Car }, covers: { Raptors.Cover }, seconds: number)
	local events: { Raptors.Event } = {}
	for _ = 1, math.floor(seconds / 0.05) do
		for _, event in Raptors.step(packs, cars, covers, TERRITORY, 0.05, TUNING) do
			table.insert(events, event)
		end
	end
	return events
end

local function count(events: { Raptors.Event }, kind: string): number
	local n = 0
	for _, event in events do
		if event.kind == kind then
			n += 1
		end
	end
	return n
end

local function middle(pack: Raptors.Pack): (number, number)
	local x, z = 0, 0
	for _, r in pack.raptors do
		x += r.x / #pack.raptors
		z += r.z / #pack.raptors
	end
	return x, z
end

Check.test("the hiding spot is just past the far side of a mound from the car", function()
	local x, z = Raptors.hideSpot(MOUND, 0, -300, TUNING)
	Check.near(x, 0, "straight behind")
	Check.near(z, 52 + 8, "past its end, HideGap out")
	x, z = Raptors.hideSpot(MOUND, -300, 0, TUNING)
	Check.near(x, 37 + 8, "past its side")
	Check.near(z, 0, "level with its middle")
end)

Check.test("the hiding spot turns with the mound", function()
	local turned: Raptors.Cover = { x = 0, z = 0, heading = math.pi / 2, halfX = 37, halfZ = 52, bush = false }
	local x, z = Raptors.hideSpot(turned, 0, -300, TUNING)
	Check.near(x, 0, "straight behind", 1e-6)
	Check.near(z, 37 + 8, "its side now faces the car")
end)

Check.test("in a bush the hiding spot is the bush itself", function()
	local x, z = Raptors.hideSpot(BUSH, 0, 0, TUNING)
	Check.near(x, 500, "x")
	Check.near(z, 0, "z")
end)

Check.test("a pack hides at the nearest cover, and no two packs share one", function()
	local packs = { Raptors.newPack(20, 100, 0), Raptors.newPack(40, 100, 0) }
	run(packs, {}, { MOUND, BUSH }, 0.1)
	Check.eq(packs[1].cover, 1, "first takes the mound")
	Check.eq(packs[2].cover, 2, "second goes to the bush")
end)

Check.test("a hidden pack keeps the mound between it and the closest car", function()
	local packs = { Raptors.newPack(0, 70, 0) }
	run(packs, { car("a", 0, -300) }, { MOUND }, 4)
	local _, z = middle(packs[1])
	Check.eq(z > 52, true, `behind the far end, at z {z}`)
	run(packs, { car("a", 0, 300) }, { MOUND }, 8)
	_, z = middle(packs[1])
	Check.eq(z < -52, true, `round to the other end, at z {z}`)
end)

Check.test("a car out past Ambush is only watched", function()
	local packs = { Raptors.newPack(0, 70, 0) }
	run(packs, { car("a", 0, -200) }, { MOUND }, 3)
	Check.eq(packs[1].mode ~= "attack", true, packs[1].mode)
end)

Check.test("a car coming close is ambushed: one over the top, two round the sides", function()
	local packs = { Raptors.newPack(0, 60, 0) }
	run(packs, { car("a", 0, -300) }, { MOUND }, 3)
	run(packs, { car("a", 0, -100) }, { MOUND }, 0.05)
	local pack = packs[1]
	Check.eq(pack.mode, "attack", "attacking")
	local top, left, right = pack.raptors[1], pack.raptors[2], pack.raptors[3]
	Check.eq(top.mode, "chase", "top chases")
	Check.near(top.viaX :: number, 0, "top goes over the middle")
	Check.near(top.viaZ :: number, 0, "top goes over the middle")
	Check.eq((left.viaX :: number) * (right.viaX :: number) < 0, true, "the others go round opposite sides")
	Check.eq(math.abs(left.viaX :: number) > 37, true, "clear of the mound's side")
end)

Check.test("a raptor that reaches a moving car runs beside it, biting once a second for five", function()
	local packs = { Raptors.newPack(0, 60, 0) }
	run(packs, { car("a", 0, -300) }, { MOUND }, 3)
	-- The car drives slowly past close by, so they catch it.
	local moving = car("a", 0, -60, { vz = 20 })
	local events = {}
	for _ = 1, 160 do
		moving.z += moving.vz * 0.05
		for _, event in Raptors.step(packs, { moving }, { MOUND }, TERRITORY, 0.05, TUNING) do
			table.insert(events, event)
		end
	end
	Check.eq(count(events, "latch"), 3, "all three latch")
	Check.eq(count(events, "bite"), 15, "five bites each")
	Check.eq(count(events, "done"), 3, "then let go")
	Check.eq(count(events, "survived"), 1, "the car survived the pack once")
	Check.eq(count(events, "shakeOff"), 0, "never shaken off")
	local slots = {}
	for _, event in events do
		if event.kind == "latch" then
			slots[event.slot :: string] = true
		end
	end
	Check.eq(slots.roof and slots.left and slots.right, true, "top on the roof, the others alongside")
end)

Check.test("on a stopped car they pounce onto it", function()
	local packs = { Raptors.newPack(0, 60, 0) }
	run(packs, { car("a", 0, -300) }, { MOUND }, 3)
	local events = run(packs, { car("a", 0, -90) }, { MOUND }, 4)
	local slots = {}
	for _, event in events do
		if event.kind == "latch" then
			slots[event.slot :: string] = true
		end
	end
	Check.eq(slots.roof and slots.hood and slots.trunk, true, "roof, hood and trunk")
end)

Check.test("getting air shakes them off", function()
	local packs = { Raptors.newPack(0, 60, 0) }
	run(packs, { car("a", 0, -300) }, { MOUND }, 3)
	local events = run(packs, { car("a", 0, -90) }, { MOUND }, 3)
	Check.eq(count(events, "latch") > 0, true, "latched")
	events = run(packs, { car("a", 0, -90, { air = true, y = 20 }) }, { MOUND }, 0.1)
	Check.eq(count(events, "shaken") > 0, true, "shaken")
	Check.eq(count(events, "shakeOff"), 1, "one shake-off for the pack")
	Check.eq(count(events, "survived"), 0, "shaken off is not surviving")
	for _, r in packs[1].raptors do
		Check.eq(r.mode ~= "latch", true, "none still on")
	end
end)

Check.test("a car that is gone is let go", function()
	local packs = { Raptors.newPack(0, 60, 0) }
	run(packs, { car("a", 0, -300) }, { MOUND }, 3)
	run(packs, { car("a", 0, -90) }, { MOUND }, 3)
	local events = run(packs, {}, { MOUND }, 0.1)
	Check.eq(count(events, "lost") > 0, true, "lost")
	Check.eq(count(events, "survived"), 0, "a car that is gone did not survive")
end)

Check.test("a car in the air is never ambushed", function()
	local packs = { Raptors.newPack(0, 60, 0) }
	run(packs, { car("a", 0, -300) }, { MOUND }, 3)
	run(packs, { car("a", 0, -80, { air = true, y = 40 }) }, { MOUND }, 1)
	Check.eq(packs[1].mode ~= "attack", true, packs[1].mode)
end)

Check.test("a player on foot is pinned, never bitten, and let go", function()
	local packs = { Raptors.newPack(0, 60, 0) }
	run(packs, { car("p", 0, -300, { foot = true }) }, { MOUND }, 3)
	local events = run(packs, { car("p", 0, -90, { foot = true }) }, { MOUND }, 6)
	Check.eq(count(events, "latch") > 0, true, "pinned")
	Check.eq(count(events, "bite"), 0, "no bites")
	Check.eq(count(events, "done") > 0, true, "let go")
	Check.eq(count(events, "survived"), 0, "no bonus on foot")
end)

Check.test("after an attack the pack moves on to other cover", function()
	local packs = { Raptors.newPack(0, 60, 0) }
	local covers = { MOUND, BUSH }
	run(packs, { car("a", 0, -300) }, covers, 3)
	Check.eq(packs[1].cover, 1, "at the mound")
	run(packs, { car("a", 0, -90) }, covers, 8)
	run(packs, { car("a", 0, -900) }, covers, 0.5)
	Check.eq(packs[1].cover, 2, "off to the bush")
end)

Check.test("they keep out of keep-outs and inside the territory", function()
	local fenced: Raptors.Territory = {
		rect = { MinX = -200, MaxX = 200, MinZ = -200, MaxZ = 200 },
		keepOut = { { AX = 0, AZ = -130, BX = 0, BZ = -130, Radius = 30 } },
	}
	-- Starting inside the keep-out.
	local packs = { Raptors.newPack(0, -130, 0) }
	for _ = 1, 200 do
		Raptors.step(packs, { car("a", 0, -400) }, { MOUND }, fenced, 0.05, TUNING)
		for _, r in packs[1].raptors do
			Check.eq(r.z >= -200 + TUNING.Body - 1e-6 and r.z <= 200 - TUNING.Body + 1e-6, true, `inside at z {r.z}`)
			Check.eq(math.sqrt(r.x ^ 2 + (r.z + 130) ^ 2) >= 30 + TUNING.Body - 1e-6, true, "clear of the keep-out")
		end
	end
end)

Check.finish("Raptors")
