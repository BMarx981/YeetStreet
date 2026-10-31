--!strict
-- Missile (ModuleScript) -> ReplicatedStorage.Missile
-- How a silo missile flies (Tuning.Silo.Missile). After its ignition it goes
-- straight up out of the hole. Past ExitHeight it pitches over toward its
-- heading on its own and comes down whatever the rider does: steering only
-- nudges it, slower than its own turn. Heights are above the ground, and
-- angles are in degrees. Azimuth is round from +X toward +Z; pitch is up from
-- level. Pure, see InputAxes.

local Missile = {}

export type Config = {
	Ignition: number, -- seconds on the pad
	Speed: number,
	ExitHeight: number,
	PitchRate: number, -- degrees a second it noses over by itself
	MinPitch: number,
	SteerYaw: number, -- degrees a second at full steer
	SteerPitch: number, -- at full pitch; less than PitchRate, so it always comes down
	Wander: number, -- degrees a second it drifts by itself, at most
	WanderRate: number, -- radians a second through that drift
}

export type State = {
	x: number,
	y: number,
	z: number,
	azimuth: number,
	pitch: number,
	wait: number,
	wander: number, -- radians through the drift
}

export type Bounds = {
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
}

function Missile.new(x: number, y: number, z: number, azimuth: number, wander: number, ignition: number?): State
	return { x = x, y = y, z = z, azimuth = azimuth, pitch = 90, wait = ignition or 1, wander = wander }
end

-- Whether it is still going up out of the hole, on rails.
function Missile.climbing(s: State, config: Config): boolean
	return s.pitch >= 90 and s.y < config.ExitHeight
end

function Missile.direction(s: State): (number, number, number)
	local a, p = math.rad(s.azimuth), math.rad(s.pitch)
	return math.cos(p) * math.cos(a), math.sin(p), math.cos(p) * math.sin(a)
end

-- Which way its top faces, where a rider sits: square to its direction, and
-- leaning back from the heading while it climbs, so it never flips.
function Missile.up(s: State): (number, number, number)
	local a, p = math.rad(s.azimuth), math.rad(s.pitch)
	return -math.sin(p) * math.cos(a), math.cos(p), -math.sin(p) * math.sin(a)
end

-- Moves it on by `dt`, with the rider's steer and pitch from -1 to 1.
function Missile.step(s: State, config: Config, steer: number, pitch: number, dt: number)
	if s.wait > 0 then
		s.wait -= dt
		return
	end
	if not Missile.climbing(s, config) then
		s.wander += config.WanderRate * dt
		local yaw = math.clamp(steer, -1, 1) * config.SteerYaw + math.sin(s.wander) * config.Wander
		local nose = math.clamp(pitch, -1, 1) * config.SteerPitch - config.PitchRate
		s.azimuth += yaw * dt
		s.pitch = math.clamp(s.pitch + nose * dt, config.MinPitch, 90)
	end
	local x, y, z = Missile.direction(s)
	s.x += x * config.Speed * dt
	s.y += y * config.Speed * dt
	s.z += z * config.Speed * dt
end

-- Where it comes down with no steering and no drift, on the ground.
function Missile.landing(config: Config, x: number, y: number, z: number, azimuth: number): (number, number)
	local still = table.clone(config)
	still.Wander = 0
	local s = Missile.new(x, y, z, azimuth, 0, 0)
	for _ = 1, 3000 do
		Missile.step(s, still, 0, 0, 0.05)
		if s.y <= 0 and s.pitch < 90 then
			break
		end
	end
	return s.x, s.z
end

-- A random heading whose unsteered landing is inside `bounds`. The last one
-- tried if none in 64 is.
function Missile.pickHeading(
	config: Config,
	rng: { next: () -> number },
	x: number,
	y: number,
	z: number,
	bounds: Bounds
): number
	local azimuth = 0
	for _ = 1, 64 do
		azimuth = rng.next() * 360
		local landX, landZ = Missile.landing(config, x, y, z, azimuth)
		if landX >= bounds.MinX and landX <= bounds.MaxX and landZ >= bounds.MinZ and landZ <= bounds.MaxZ then
			return azimuth
		end
	end
	return azimuth
end

return Missile
