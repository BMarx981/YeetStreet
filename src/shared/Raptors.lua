--!strict
-- Raptors (ModuleScript) -> ReplicatedStorage.Raptors
-- Dino Valley's velociraptors, seen from above: packs of three that hide,
-- ambush cars and bite them. Pure, see InputAxes. The server steps every
-- pack together and decides every bite (Parks.DinoRaptors); clients only
-- draw them.
--
-- A pack takes cover at the nearest mound or bush no other pack has.
-- Behind a mound it keeps to the far side from the closest car on the
-- ground within Watch, slipping round the mound as that car moves; in a bush
-- it crouches inside. When a car on the ground comes within Ambush of its
-- cover, the pack attacks: behind a mound, its top raptor goes over the
-- middle and the other two round either side, Wide clear of it; from a bush
-- all three burst straight out.
--
-- Each raptor chases at RunSpeed toward where its car will be in Lead
-- seconds. Reaching one on the ground within LatchReach, it latches on: a
-- moving car's top raptor rides its roof and the others run beside it, a
-- stopped one's ride its roof, hood and trunk, keeping up at any speed. A
-- latched raptor bites once every BiteEvery seconds, Bites times, then lets
-- go. A car that gets into the air shakes off every raptor on it. A player
-- on foot is pinned for PinTime seconds and never bitten. A raptor gives up
-- a car past Lose, in the air, out of the territory, or after ChaseTime
-- without latching.
--
-- Each attack, a pack's raptors shaken off a car tell once that the car
-- shook them off (shakeOff). A car whose last raptor of the pack lets go
-- after its full bites, with none shaken off and the car never lost,
-- survived them (survived). Neither for a player on foot.
--
-- Once none of a pack is chasing or latched, it rests for Rest seconds and
-- moves on to other cover. It leaves every car it went for alone for
-- Cooldown seconds after, though other packs may not. With no car within
-- Watch of its cover it also moves on after StayMin to StayMax seconds
-- there. Moving on, it picks a bush or a mound by a coin toss, and the
-- nearest free one of that kind. Between covers it still ambushes a car
-- within Ambush of it or of the cover it is making for, coming straight at
-- it from wherever it is.
--
-- Heading is in radians, 0 facing -Z and positive turning left, like the
-- parks' Heading. Positions are world studs.

local Raptors = {}

-- Same as Rng.Rng, declared here so this module needs no require.
type Rng = {
	next: () -> number,
	range: (low: number, high: number) -> number,
	int: (low: number, high: number) -> number,
}

export type Rect = {
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
}

-- Scatter's line: one with no length is a circle.
export type Line = {
	AX: number,
	AZ: number,
	BX: number,
	BZ: number,
	Radius: number,
}

export type Territory = {
	rect: Rect,
	keepOut: { Line },
}

-- A mound, halfX across and halfZ along from its middle (turned `heading`
-- like CFrame.Angles(0, heading, 0)), or a bush, halfX and halfZ its radius.
export type Cover = {
	x: number,
	z: number,
	heading: number,
	halfX: number,
	halfZ: number,
	bush: boolean,
}

-- A car's hull, or a player on foot, as the server sees it.
export type Car = {
	id: any,
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	air: boolean,
	foot: boolean,
}

export type Role = "top" | "left" | "right"
export type Slot = "roof" | "hood" | "trunk" | "left" | "right" | "pin"

export type Raptor = {
	role: Role,
	mode: "hide" | "chase" | "latch" | "back",
	x: number,
	z: number,
	heading: number,
	speed: number,
	timer: number, -- seconds chasing, or latched
	target: any?,
	viaX: number?, -- where it goes before making for its car
	viaZ: number?,
	slot: Slot?,
	bites: number,
}

export type Pack = {
	mode: "move" | "attack",
	cover: number?, -- its cover's place in the list of covers
	awayX: number, -- which way the closest car lies from its cover
	awayZ: number,
	rest: number,
	raptors: { Raptor },
	-- How each car its last attack latched onto has fared.
	attack: { [any]: Fate },
	target: any?, -- the car its last attack went for
	-- Seconds left before it may go for each car it attacked again.
	cooling: { [any]: number },
	stay: number, -- seconds left before it moves on, with no car near
}

export type Fate = {
	done: boolean, -- a raptor got all its bites in
	shaken: boolean,
	lost: boolean,
}

export type Kind = "latch" | "bite" | "shaken" | "done" | "lost" | "shakeOff" | "survived"

export type Event = {
	kind: Kind,
	car: any,
	pack: number,
	raptor: number,
	slot: Slot?,
}

export type Tuning = {
	WalkSpeed: number,
	SneakSpeed: number,
	RunSpeed: number,
	Accel: number,
	TurnRate: number, -- degrees per second
	Body: number,
	Watch: number,
	Ambush: number,
	HideGap: number,
	Spacing: number,
	Wide: number,
	ViaReach: number,
	Lead: number,
	LatchReach: number,
	ChaseTime: number,
	Lose: number,
	StopSpeed: number,
	BiteEvery: number,
	Bites: number,
	PinTime: number,
	Rest: number,
	Cooldown: number,
	StayMin: number,
	StayMax: number,
}

local TAU = 2 * math.pi
local ROLES: { Role } = { "top", "left", "right" }
-- Going round a mound, how far round it aims at a time.
local ORBIT_STEP = math.rad(30)
-- How much further than its hiding spot a pack may be from its cover and
-- still be at it.
local AT_COVER = 15
-- How near its hiding place a raptor is when it settles there.
local SETTLED = 2
-- Within this of where it runs to, it steps straight there.
local STEP_IN = 6

local function wrap(angle: number): number
	return (angle + math.pi) % TAU - math.pi
end

local function forward(heading: number): (number, number)
	return -math.sin(heading), -math.cos(heading)
end

function Raptors.newPack(x: number, z: number, heading: number): Pack
	local raptors = {}
	for i, role in ROLES do
		local fx, fz = forward(heading + math.pi / 2)
		local raptor: Raptor = {
			role = role,
			mode = "hide",
			x = x + fx * (i - 2) * 4,
			z = z + fz * (i - 2) * 4,
			heading = heading,
			speed = 0,
			timer = 0,
			target = nil,
			viaX = nil,
			viaZ = nil,
			slot = nil,
			bites = 0,
		}
		table.insert(raptors, raptor)
	end
	return {
		mode = "move",
		cover = nil,
		awayX = 0,
		awayZ = 1,
		rest = 0,
		raptors = raptors,
		attack = {},
		target = nil,
		cooling = {},
		stay = 0,
	}
end

-- A cover's own x, z axes in the world.
local function axes(cover: Cover): (number, number, number, number)
	local c, s = math.cos(cover.heading), math.sin(cover.heading)
	return c, -s, s, c
end

-- How far out from its middle a cover reaches in world direction dx, dz
-- (a unit vector): to the edge of its rectangle, or a bush's radius.
local function extent(cover: Cover, dx: number, dz: number): number
	if cover.bush then
		return cover.halfX
	end
	local xx, xz, zx, zz = axes(cover)
	local along, across = math.abs(dx * zx + dz * zz), math.abs(dx * xx + dz * xz)
	return math.min(
		if across > 1e-9 then cover.halfX / across else math.huge,
		if along > 1e-9 then cover.halfZ / along else math.huge
	)
end

-- Where to hide at `cover` from something at fromX, fromZ: just past the far
-- side of a mound, HideGap out, or in the middle of a bush.
function Raptors.hideSpot(cover: Cover, fromX: number, fromZ: number, tuning: Tuning): (number, number)
	if cover.bush then
		return cover.x, cover.z
	end
	local dx, dz = cover.x - fromX, cover.z - fromZ
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1e-9 then
		dx, dz, d = 0, 1, 1
	end
	dx, dz = dx / d, dz / d
	local out = extent(cover, dx, dz) + tuning.HideGap
	return cover.x + dx * out, cover.z + dz * out
end

local function nearest(line: Line, x: number, z: number): (number, number)
	local dx, dz = line.BX - line.AX, line.BZ - line.AZ
	local lengthSquared = dx * dx + dz * dz
	local t = if lengthSquared > 0
		then math.clamp(((x - line.AX) * dx + (z - line.AZ) * dz) / lengthSquared, 0, 1)
		else 0
	return line.AX + dx * t, line.AZ + dz * t
end

local function inRect(territory: Territory, x: number, z: number): boolean
	local r = territory.rect
	return x >= r.MinX and x <= r.MaxX and z >= r.MinZ and z <= r.MaxZ
end

-- Pushes it back inside its territory and out of every keep-out.
local function keepIn(r: Raptor, territory: Territory, tuning: Tuning)
	local rect = territory.rect
	local body = tuning.Body
	r.x = math.clamp(r.x, rect.MinX + body, math.max(rect.MaxX - body, rect.MinX + body))
	r.z = math.clamp(r.z, rect.MinZ + body, math.max(rect.MaxZ - body, rect.MinZ + body))
	for _, line in territory.keepOut do
		local nx, nz = nearest(line, r.x, r.z)
		local ox, oz = r.x - nx, r.z - nz
		local d = math.sqrt(ox * ox + oz * oz)
		local edge = line.Radius + body
		if d < edge then
			if d < 1e-6 then
				local fx, fz = forward(r.heading)
				ox, oz, d = -fx, -fz, 1
			end
			r.x, r.z = nx + ox / d * edge, nz + oz / d * edge
		end
	end
end

local function approach(value: number, goal: number, most: number): number
	if value < goal then
		return math.min(value + most, goal)
	end
	return math.max(value - most, goal)
end

-- Turns toward x, z and runs on at up to `speed`, slowing to stop on it.
local function runTo(r: Raptor, x: number, z: number, speed: number, territory: Territory, dt: number, tuning: Tuning)
	local dx, dz = x - r.x, z - r.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance > 0.5 then
		local turn = wrap(math.atan2(-dx, -dz) - r.heading)
		local most = math.rad(tuning.TurnRate) * dt
		r.heading = wrap(r.heading + math.clamp(turn, -most, most))
	end
	r.speed = approach(r.speed, math.min(speed, distance / dt), tuning.Accel * dt)
	if distance < STEP_IN then
		-- Close by, it steps straight there rather than circling it.
		local step = math.min(r.speed * dt, distance)
		if distance > 1e-9 then
			r.x += dx / distance * step
			r.z += dz / distance * step
		end
	else
		local fx, fz = forward(r.heading)
		r.x += fx * r.speed * dt
		r.z += fz * r.speed * dt
	end
	keepIn(r, territory, tuning)
end

local function find(cars: { Car }, id: any): Car?
	for _, car in cars do
		if car.id == id then
			return car
		end
	end
	return nil
end

local function middle(pack: Pack): (number, number)
	local x, z = 0, 0
	for _, r in pack.raptors do
		x += r.x / #pack.raptors
		z += r.z / #pack.raptors
	end
	return x, z
end

-- The nearest cover to the pack that no other pack has, other than
-- `except`, of the kind `bush` asks for if one is free (any kind when nil);
-- or the one it has if there is none.
local function chooseCover(packs: { Pack }, me: number, covers: { Cover }, except: number?, bush: boolean?): number?
	local x, z = middle(packs[me])
	local best, bestDistance, bestKind = nil, math.huge, false
	for i, cover in covers do
		local taken = i == except
		for j, other in packs do
			if j ~= me and other.cover == i then
				taken = true
			end
		end
		local distance = (cover.x - x) ^ 2 + (cover.z - z) ^ 2
		local kind = bush == nil or cover.bush == bush
		if not taken and (kind and not bestKind or kind == bestKind and distance < bestDistance) then
			best, bestDistance, bestKind = i, distance, kind
		end
	end
	return best or packs[me].cover
end

-- Moves on to other cover, and stays there a while.
local function moveOn(packs: { Pack }, me: number, covers: { Cover }, rng: Rng, tuning: Tuning)
	local pack = packs[me]
	pack.cover = chooseCover(packs, me, covers, pack.cover, rng.next() < 0.5)
	pack.stay = rng.range(tuning.StayMin, tuning.StayMax)
end

-- The closest car on the ground in the territory to x, z, within `within`,
-- other than those in `skip`.
local function closest(
	cars: { Car },
	x: number,
	z: number,
	within: number,
	territory: Territory,
	skip: { [any]: number }
): Car?
	local best, bestDistance = nil, within * within
	for _, car in cars do
		local distance = (car.x - x) ^ 2 + (car.z - z) ^ 2
		if not car.air and not skip[car.id] and inRect(territory, car.x, car.z) and distance <= bestDistance then
			best, bestDistance = car, distance
		end
	end
	return best
end

-- Where raptor `i` of a hiding pack goes: its place in the line beside the
-- hiding spot, or round the mound toward it while far round.
local function hideGoal(pack: Pack, i: number, r: Raptor, cover: Cover, tuning: Tuning): (number, number)
	local fromX, fromZ = cover.x - pack.awayX, cover.z - pack.awayZ
	local x, z = Raptors.hideSpot(cover, fromX, fromZ, tuning)
	if cover.bush then
		local spread = tuning.Spacing * 0.3 * (i - 2)
		return x + pack.awayZ * spread, z - pack.awayX * spread
	end
	local now = math.atan2(r.z - cover.z, r.x - cover.x)
	local goal = math.atan2(pack.awayZ, pack.awayX)
	local turn = wrap(goal - now)
	if math.abs(turn) > ORBIT_STEP then
		local angle = now + math.sign(turn) * ORBIT_STEP
		return Raptors.hideSpot(cover, cover.x - math.cos(angle), cover.z - math.sin(angle), tuning)
	end
	local spread = tuning.Spacing * (i - 2)
	return x + pack.awayZ * spread, z - pack.awayX * spread
end

-- `round`: it is at a mound, so goes over and round it.
local function ambush(pack: Pack, car: Car, cover: Cover, round: boolean, tuning: Tuning)
	pack.mode = "attack"
	pack.attack = {}
	pack.target = car.id
	-- Square to the line from the car to the cover.
	local sideX, sideZ = pack.awayZ, -pack.awayX
	local out = extent(cover, sideX, sideZ) + tuning.Wide
	for _, r in pack.raptors do
		r.mode = "chase"
		r.timer = 0
		r.target = car.id
		r.viaX, r.viaZ = nil, nil
		if round and not cover.bush then
			if r.role == "top" then
				r.viaX, r.viaZ = cover.x, cover.z
			else
				local s = if r.role == "left" then -1 else 1
				r.viaX, r.viaZ = cover.x + sideX * out * s, cover.z + sideZ * out * s
			end
		end
	end
end

local function slotFor(role: Role, car: Car, tuning: Tuning): Slot
	if car.foot then
		return "pin"
	end
	if role == "top" then
		return "roof"
	end
	local moving = car.vx * car.vx + car.vz * car.vz >= tuning.StopSpeed * tuning.StopSpeed
	if role == "left" then
		return if moving then "left" else "hood"
	end
	return if moving then "right" else "trunk"
end

local function stepRaptor(
	r: Raptor,
	index: number,
	packIndex: number,
	pack: Pack,
	cars: { Car },
	covers: { Cover },
	territory: Territory,
	dt: number,
	tuning: Tuning,
	events: { Event }
)
	local function tell(kind: Kind, car: any)
		table.insert(events, { kind = kind, car = car, pack = packIndex, raptor = index, slot = r.slot })
	end

	-- Lets go of `car`, and tells how the car fared once the pack's last
	-- raptor on it has.
	local function release(kind: "shaken" | "done" | "lost", car: any, foot: boolean)
		tell(kind, car)
		r.mode = "back"
		local fate = pack.attack[car] or { done = false, shaken = false, lost = false }
		pack.attack[car] = fate
		if kind == "shaken" and not fate.shaken and not foot then
			tell("shakeOff", car)
		end
		fate.done = fate.done or kind == "done"
		fate.shaken = fate.shaken or kind == "shaken"
		fate.lost = fate.lost or kind == "lost"
		for _, other in pack.raptors do
			if other.mode == "latch" and other.target == car then
				return
			end
		end
		if fate.done and not fate.shaken and not fate.lost and not foot then
			tell("survived", car)
		end
	end

	if r.mode == "latch" then
		r.timer += dt
		local car = find(cars, r.target)
		if not car then
			release("lost", r.target, false)
			return
		end
		r.x, r.z = car.x, car.z
		if car.vx * car.vx + car.vz * car.vz >= tuning.StopSpeed * tuning.StopSpeed then
			r.heading = math.atan2(-car.vx, -car.vz)
		end
		if car.air then
			release("shaken", car.id, car.foot)
			return
		end
		if car.foot then
			if r.timer >= tuning.PinTime then
				release("done", car.id, true)
			end
			return
		end
		if r.timer >= (r.bites + 1) * tuning.BiteEvery then
			r.bites += 1
			tell("bite", car.id)
			if r.bites >= tuning.Bites then
				release("done", car.id, false)
			end
		end
		return
	end

	if r.mode == "chase" then
		r.timer += dt
		local car = find(cars, r.target)
		local gone = not car
			or car.air
			or not inRect(territory, car.x, car.z)
			or r.timer > tuning.ChaseTime
			or (car.x - r.x) ^ 2 + (car.z - r.z) ^ 2 > tuning.Lose * tuning.Lose
		if gone or not car then
			r.mode = "back"
		else
			local cx, cz = car.x + car.vx * tuning.Lead, car.z + car.vz * tuning.Lead
			local viaX, viaZ = r.viaX, r.viaZ
			if viaX and viaZ then
				local toVia = (viaX - r.x) ^ 2 + (viaZ - r.z) ^ 2
				local toCar = (cx - r.x) ^ 2 + (cz - r.z) ^ 2
				if toVia <= tuning.ViaReach * tuning.ViaReach or toCar < toVia then
					r.viaX, r.viaZ = nil, nil
				else
					cx, cz = viaX, viaZ
				end
			end
			runTo(r, cx, cz, tuning.RunSpeed, territory, dt, tuning)
			if (car.x - r.x) ^ 2 + (car.z - r.z) ^ 2 <= tuning.LatchReach * tuning.LatchReach then
				r.mode = "latch"
				r.timer = 0
				r.bites = 0
				r.viaX, r.viaZ = nil, nil
				r.slot = slotFor(r.role, car, tuning)
				r.x, r.z = car.x, car.z
				tell("latch", car.id)
			end
			return
		end
	end

	-- Hiding, or heading back to cover.
	local cover = pack.cover and covers[pack.cover]
	if cover then
		local x, z = hideGoal(pack, index, r, cover, tuning)
		local speed = if pack.mode == "attack" or r.mode == "back" then tuning.SneakSpeed else tuning.WalkSpeed
		if (x - r.x) ^ 2 + (z - r.z) ^ 2 < 400 then
			speed = tuning.SneakSpeed
		end
		runTo(r, x, z, speed, territory, dt, tuning)
		-- In its place, it turns to face the way the car is, over the mound.
		if (x - r.x) ^ 2 + (z - r.z) ^ 2 < SETTLED * SETTLED then
			local turn = wrap(math.atan2(pack.awayX, pack.awayZ) - r.heading)
			local most = math.rad(tuning.TurnRate) * dt
			r.heading = wrap(r.heading + math.clamp(turn, -most, most))
		end
	end
end

-- One step of `dt` seconds for every pack. Returns what happened.
function Raptors.step(
	packs: { Pack },
	cars: { Car },
	covers: { Cover },
	territory: Territory,
	rng: Rng,
	dt: number,
	tuning: Tuning
): { Event }
	local events: { Event } = {}
	for p, pack in packs do
		pack.rest = math.max(pack.rest - dt, 0)
		for id, left in pack.cooling do
			pack.cooling[id] = if left > dt then left - dt else nil
		end
		if pack.cover == nil then
			pack.cover = chooseCover(packs, p, covers, nil, nil)
			pack.stay = rng.range(tuning.StayMin, tuning.StayMax)
		end
		local cover = pack.cover and covers[pack.cover]

		if pack.mode ~= "attack" and cover then
			-- It hides from the closest car, cooling or not.
			local car = closest(cars, cover.x, cover.z, tuning.Watch, territory, {})
			if car then
				local dx, dz = cover.x - car.x, cover.z - car.z
				local d = math.sqrt(dx * dx + dz * dz)
				if d > 1e-6 then
					pack.awayX, pack.awayZ = dx / d, dz / d
				end
			else
				pack.stay -= dt
			end
			local x, z = middle(pack)
			local at = (x - cover.x) ^ 2 + (z - cover.z) ^ 2
				<= (math.max(cover.halfX, cover.halfZ) + tuning.HideGap + AT_COVER) ^ 2
			local prey = closest(cars, cover.x, cover.z, tuning.Ambush, territory, pack.cooling)
				or closest(cars, x, z, tuning.Ambush, territory, pack.cooling)
			if prey and pack.rest <= 0 then
				ambush(pack, prey, cover, at, tuning)
			elseif pack.stay <= 0 then
				moveOn(packs, p, covers, rng, tuning)
			end
		end

		for i, r in pack.raptors do
			if pack.mode ~= "attack" and r.mode ~= "hide" then
				r.mode = "hide"
			end
			stepRaptor(r, i, p, pack, cars, covers, territory, dt, tuning, events)
		end

		if pack.mode == "attack" then
			local busy = false
			for _, r in pack.raptors do
				busy = busy or r.mode == "chase" or r.mode == "latch"
			end
			if not busy then
				pack.mode = "move"
				pack.rest = tuning.Rest
				if pack.target ~= nil then
					pack.cooling[pack.target] = tuning.Cooldown
				end
				for id in pack.attack do
					pack.cooling[id] = tuning.Cooldown
				end
				moveOn(packs, p, covers, rng, tuning)
			end
		end
	end
	return events
end

return Raptors
