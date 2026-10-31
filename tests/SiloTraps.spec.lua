--!strict
local Check = require("./Check")
local SiloTraps = require("../src/shared/SiloTraps")

local RAMP: SiloTraps.Ramp = { Pitch = 80, InnerRadius = 49, OuterRadius = 130, LipWidth = 12 }

local CONFIG: SiloTraps.Config = {
	Margin = 3,
	HullHeight = 4,
	Reach = 12, -- up and down from the hull
	Poppers = {
		First = 0.5,
		Every = 1,
		Last = 2.6,
		Width = 26,
		Height = 10,
		Reach = 60,
		Period = 4,
		Chance = 0.5,
		Warn = 0.7,
		Out = 0.2,
		Hold = 0.5,
		Back = 0.4,
		PushOut = 120,
		PushUp = 70,
	},
	Sweepers = {
		First = 1,
		Every = 1,
		Last = 2.1,
		Across = 18,
		Height = 9,
		Length = 12,
		Travel = 70,
		Move = 0.4,
		Hold = 1,
		PushAlong = 100,
		PushOut = 80,
		PushUp = 60,
	},
}

local function layout(): { SiloTraps.Trap }
	return SiloTraps.layout(CONFIG)
end

-- A time when this popper is fully out, and one when it is not out at all.
local function popperTimes(trap: SiloTraps.Trap): (number, number)
	local out, still
	for t = 0, 2000, 0.05 do
		local extent = SiloTraps.popperExtent(CONFIG.Poppers, trap.id, t)
		if extent >= 1 and not out then
			out = t
		elseif extent == 0 and not still then
			still = t
		end
	end
	return out :: number, still :: number
end

local function count(kind: string): number
	local n = 0
	for _, trap in layout() do
		if trap.kind == kind then
			n += 1
		end
	end
	return n
end

Check.test("traps are spread down the ramp", function()
	Check.eq(count("popper"), 3, "poppers at 0.5, 1.5, 2.5")
	Check.eq(count("sweeper"), 2, "sweepers at 1, 2")
	local ids: { [number]: boolean } = {}
	for _, trap in layout() do
		Check.eq(ids[trap.id], nil, "ids differ")
		ids[trap.id] = true
	end
end)

Check.test("the same time gives the same popper on every machine", function()
	for t = 0, 100, 0.37 do
		Check.eq(SiloTraps.popperExtent(CONFIG.Poppers, 1, t), SiloTraps.popperExtent(CONFIG.Poppers, 1, t))
	end
end)

Check.test("a popper fires in about Chance of its periods, at varied moments", function()
	local fired = 0
	local starts: { [number]: boolean } = {}
	local distinct = 0
	for slot = 0, 999 do
		local at = SiloTraps.popperStart(CONFIG.Poppers, 2, slot)
		if at then
			fired += 1
			local key = math.floor(at * 10)
			if not starts[key] then
				starts[key] = true
				distinct += 1
			end
		end
	end
	Check.eq(fired > 400 and fired < 600, true, `fired {fired} of 1000`)
	Check.eq(distinct > 5, true, "not always the same moment")
end)

Check.test("each popper keeps its own times", function()
	local same = 0
	for slot = 0, 99 do
		if SiloTraps.popperStart(CONFIG.Poppers, 1, slot) == SiloTraps.popperStart(CONFIG.Poppers, 2, slot) then
			same += 1
		end
	end
	Check.eq(same < 60, true, `{same} of 100 the same`)
end)

Check.test("a popper warns, shoots out, holds, and goes back, within its period", function()
	local P = CONFIG.Poppers
	local slot, start
	for s = 0, 200 do
		start = SiloTraps.popperStart(P, 1, s)
		if start then
			slot = s
			break
		end
	end
	local begin = slot * P.Period + start
	Check.eq(begin + P.Warn + P.Out + P.Hold + P.Back <= (slot + 1) * P.Period + 1e-9, true, "fits its period")
	Check.near(SiloTraps.popperExtent(P, 1, begin + 0.1), 0, "still in while warning")
	Check.eq(SiloTraps.popperWarning(P, 1, begin + 0.1), true, "warning")
	Check.near(SiloTraps.popperExtent(P, 1, begin + P.Warn + P.Out / 2), 0.5, "halfway out")
	Check.near(SiloTraps.popperExtent(P, 1, begin + P.Warn + P.Out + 0.1), 1, "holding")
	Check.eq(SiloTraps.popperWarning(P, 1, begin + P.Warn + P.Out + 0.1), false, "no warning once out")
	Check.near(SiloTraps.popperExtent(P, 1, begin + P.Warn + P.Out + P.Hold + P.Back / 2), 0.5, "halfway back")
end)

Check.test("a sweeper rests at one end, darts to the other, and comes back", function()
	local S = CONFIG.Sweepers
	Check.near(SiloTraps.sweeperOffset(S, 0, 0.5), -35, "resting at the start")
	Check.near(SiloTraps.sweeperOffset(S, 0, S.Hold + S.Move / 2), 0, "halfway across")
	Check.near(SiloTraps.sweeperOffset(S, 0, S.Hold + S.Move + 0.5), 35, "resting at the end")
	Check.near(SiloTraps.sweeperOffset(S, 0, 2 * S.Hold + 1.5 * S.Move), 0, "halfway back")
end)

-- A car on the flat of the ramp at this trap's spot.
local function carAt(trap: SiloTraps.Trap, radius: number, along: number?): (number, number, number)
	local a = trap.along + (along or 0)
	return radius * math.cos(a), -RAMP.Pitch * a / (2 * math.pi) + CONFIG.HullHeight, -radius * math.sin(a)
end

local function firstOf(kind: string): SiloTraps.Trap
	for _, trap in layout() do
		if trap.kind == kind then
			return trap
		end
	end
	error("no trap")
end

Check.test("a popped popper shoves a car in front of it out and up", function()
	local trap = firstOf("popper")
	local out = popperTimes(trap)
	local x, y, z = carAt(trap, 80)
	local vx, vy, vz = SiloTraps.push(RAMP, CONFIG, { trap }, out, x, y, z, 0, 0, 0)
	Check.eq(vx ~= nil, true, "hit")
	local rx, rz = x / 80, z / 80
	Check.near((vx :: number) * rx + (vz :: number) * rz, 120, "out")
	Check.near(vy :: number, 70, "up")
end)

Check.test("a popper that hasn't popped lets a car by", function()
	local trap = firstOf("popper")
	local _, still = popperTimes(trap)
	local x, y, z = carAt(trap, 80)
	Check.eq(SiloTraps.push(RAMP, CONFIG, { trap }, still, x, y, z, 0, 0, 0), nil)
end)

Check.test("a car past a popper's reach, beside it, or a level away is safe", function()
	local trap = firstOf("popper")
	local out = popperTimes(trap)
	local x, y, z = carAt(trap, 116)
	Check.eq(SiloTraps.push(RAMP, CONFIG, { trap }, out, x, y, z, 0, 0, 0), nil, "past its reach")
	x, y, z = carAt(trap, 80, 0.4)
	Check.eq(SiloTraps.push(RAMP, CONFIG, { trap }, out, x, y, z, 0, 0, 0), nil, "beside it")
	x, y, z = carAt(trap, 80, 2 * math.pi)
	Check.eq(SiloTraps.push(RAMP, CONFIG, { trap }, out, x, y, z, 0, 0, 0), nil, "the level below")
end)

Check.test("a sweeper knocks a car it reaches along its way, out and up", function()
	local trap = firstOf("sweeper")
	local S = CONFIG.Sweepers
	local lane = SiloTraps.lane(RAMP)
	-- Find a time in the sweep's first move for this trap's phase.
	local t = 0
	while math.abs(SiloTraps.sweeperOffset(S, trap.id, t)) > 1 or SiloTraps.sweeperMoving(S, trap.id, t) == 0 do
		t += 0.01
	end
	local x, y, z = carAt(trap, lane)
	local vx, vy, vz = SiloTraps.push(RAMP, CONFIG, { trap }, t, x, y, z, 0, 0, 0)
	Check.eq(vx ~= nil, true, "hit")
	Check.near(vy :: number, 60, "up")
	local rx, rz = x / lane, z / lane
	Check.near((vx :: number) * rx + (vz :: number) * rz, 80, "out")
	local speed = math.sqrt((vx :: number) ^ 2 + (vz :: number) ^ 2)
	Check.near(speed, math.sqrt(100 ^ 2 + 80 ^ 2), "along too")
end)

Check.test("driving into a resting sweeper still knocks a car, out and up only", function()
	local trap = firstOf("sweeper")
	local S = CONFIG.Sweepers
	local lane = SiloTraps.lane(RAMP)
	local t = 0
	while SiloTraps.sweeperMoving(S, trap.id, t) ~= 0 do
		t += 0.01
	end
	local offset = SiloTraps.sweeperOffset(S, trap.id, t)
	local x, y, z = carAt(trap, lane, offset / lane)
	local vx, vy, vz = SiloTraps.push(RAMP, CONFIG, { trap }, t, x, y, z, 0, 0, 0)
	Check.near(vy :: number, 60, "up")
	Check.near(math.sqrt((vx :: number) ^ 2 + (vz :: number) ^ 2), 80, "out only")
end)

Check.test("a sweeper at the far end leaves a car in the middle alone", function()
	local trap = firstOf("sweeper")
	local S = CONFIG.Sweepers
	local t = 0
	while math.abs(SiloTraps.sweeperOffset(S, trap.id, t)) < 34 do
		t += 0.01
	end
	local x, y, z = carAt(trap, SiloTraps.lane(RAMP))
	Check.eq(SiloTraps.push(RAMP, CONFIG, { trap }, t, x, y, z, 0, 0, 0), nil)
end)

Check.finish()
