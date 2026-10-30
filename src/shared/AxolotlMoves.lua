--!strict
-- AxolotlMoves (ModuleScript) -> ReplicatedStorage.AxolotlMoves
-- How the Axolotl Throttle's tail, gills, and smile move. Pure, see InputAxes.
--
-- Angles are radians. Speeds are studs per second. In car space x is to the
-- right, y up, and the nose toward -z, like CarDesign.

local AxolotlMoves = {}

AxolotlMoves.TopSpeed = 120 -- the speed the moves stop growing at
AxolotlMoves.AirCheck = 5 -- no ground this far under the hull's center means airborne

AxolotlMoves.Tail = {
	MaxAngle = math.rad(35),
	SteerGain = 1.2, -- tail angle per radian of front wheel steer
	IdleSway = math.rad(8), -- swim size parked
	SwimSway = math.rad(22), -- swim size at top speed
	IdleRate = 1.5, -- swim radians per second parked
	SwimRate = 9, -- at top speed
	Follow = 8, -- how fast it catches up to the steering, per second
}

AxolotlMoves.Gills = {
	IdleSize = math.rad(6),
	IdleRate = 2.5,
	DriveSize = math.rad(12),
	DriveRate = 9,
	AirSize = math.rad(28),
	AirRate = 22,
	MaxSweep = math.rad(25), -- how far back they lie at top speed
	Follow = 6, -- how fast size and sweep change, per second
}

AxolotlMoves.Smile = {
	Count = 31, -- close enough to overlap into one line
	CenterY = 0.85, -- the middle of the smile, in car space
	HalfWidth = 1.7,
	Rise = 0.35, -- how far the ends sit above the middle
	DotSize = 0.26,
	-- The stretched head's shape, close enough to lay the smile on.
	Head = { Y = 1.46, Z = -3.14, RadiusX = 2.7, RadiusY = 2.6, RadiusZ = 3.59 },
	-- Seconds for the laugh after a hit.
	OpenTime = 0.08,
	Hold = 0.7,
	CloseTime = 0.4,
	-- The dark inside of the mouth: unseen in the head, slides out to show.
	MouthSize = { X = 2.4, Y = 1, Z = 0.9 },
	MouthDrop = 0.38, -- its middle below the smile's middle
	MouthShown = 0.25, -- how far its front pokes out of the head when open
	MouthHidden = 0.6, -- how far its front is inside the head when shut
}

-- The share of the car's breakable parts gone when each piece flies off, in
-- the order of AxolotlThrottle.BreakOrder.
AxolotlMoves.Breaks = { 0.15, 0.4, 0.7 }

local function share(speed: number): number
	return math.clamp(speed / AxolotlMoves.TopSpeed, 0, 1)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function AxolotlMoves.swimRate(speed: number): number
	local T = AxolotlMoves.Tail
	return lerp(T.IdleRate, T.SwimRate, share(speed))
end

-- The tail's yaw about the car's up axis: positive swings it to the right,
-- which is the outside of a left turn. steer is positive for left.
function AxolotlMoves.tailAngle(steer: number, speed: number, phase: number): number
	local T = AxolotlMoves.Tail
	local sway = lerp(T.IdleSway, T.SwimSway, share(speed))
	return math.clamp(steer * T.SteerGain + math.sin(phase) * sway, -T.MaxAngle, T.MaxAngle)
end

-- Beat rate and size for the gills' flap.
function AxolotlMoves.gillBeat(speed: number, airborne: boolean): (number, number)
	local G = AxolotlMoves.Gills
	if airborne then
		return G.AirRate, G.AirSize
	end
	local s = share(speed)
	return lerp(G.IdleRate, G.DriveRate, s), lerp(G.IdleSize, G.DriveSize, s)
end

function AxolotlMoves.gillSweep(speed: number): number
	return AxolotlMoves.Gills.MaxSweep * share(speed)
end

function AxolotlMoves.approach(current: number, target: number, rate: number, dt: number): number
	return target + (current - target) * math.exp(-rate * dt)
end

-- Keeps a beat's phase small over a long drive.
function AxolotlMoves.wrap(phase: number): number
	return phase % (2 * math.pi)
end

export type Moves = {
	swim: number, -- the tail's swim phase
	beat: number, -- the gills' beat phase
	tailYaw: number,
	gillSize: number,
	sweep: number,
	flap: number, -- the gills' angle this moment
}

function AxolotlMoves.newMoves(): Moves
	return { swim = 0, beat = 0, tailYaw = 0, gillSize = 0, sweep = 0, flap = 0 }
end

-- Moves the tail and gills on by `dt` seconds. steer is positive for left.
function AxolotlMoves.step(moves: Moves, steer: number, speed: number, airborne: boolean, dt: number)
	moves.swim = AxolotlMoves.wrap(moves.swim + AxolotlMoves.swimRate(speed) * dt)
	local tail = AxolotlMoves.tailAngle(steer, speed, moves.swim)
	moves.tailYaw = AxolotlMoves.approach(moves.tailYaw, tail, AxolotlMoves.Tail.Follow, dt)

	local G = AxolotlMoves.Gills
	local rate, size = AxolotlMoves.gillBeat(speed, airborne)
	moves.beat = AxolotlMoves.wrap(moves.beat + rate * dt)
	moves.gillSize = AxolotlMoves.approach(moves.gillSize, size, G.Follow, dt)
	moves.sweep = AxolotlMoves.approach(moves.sweep, AxolotlMoves.gillSweep(speed), G.Follow, dt)
	moves.flap = math.sin(moves.beat) * moves.gillSize
end

-- The steer angle that would turn a car of this wheelbase at this yaw rate, for
-- a replay, which has no wheels to read. Positive is left.
function AxolotlMoves.steerFromTurn(yawRate: number, speed: number, wheelbase: number): number
	if speed < 1 then
		return 0
	end
	return math.atan(yawRate * wheelbase / speed)
end

-- How many pieces were off before a clip, and the clip time each later piece
-- flies off (by its place in AxolotlThrottle.BreakOrder). `times` are the
-- clip's part breaks in order, and `before` the parts broken before it.
function AxolotlMoves.pieceBreaks(before: number, times: { number }, total: number): (number, { [number]: number })
	local gone = AxolotlMoves.piecesOff(before, total)
	local at: { [number]: number } = {}
	local shown = gone
	for i, t in times do
		local off = AxolotlMoves.piecesOff(before + i, total)
		for k = shown + 1, off do
			at[k] = t
		end
		shown = math.max(shown, off)
	end
	return gone, at
end

-- Seconds since the latest of `times` at or before `t`, nil if none has come.
function AxolotlMoves.sinceHit(times: { number }, t: number): number?
	local since: number? = nil
	for _, at in times do
		if at <= t then
			since = t - at
		end
	end
	return since
end

-- How open the mouth is, 0 to 1, this many seconds after a hit. nil means no
-- hit yet.
function AxolotlMoves.smileOpen(sinceHit: number?): number
	if sinceHit == nil then
		return 0
	end
	local S = AxolotlMoves.Smile
	if sinceHit < S.OpenTime then
		return sinceHit / S.OpenTime
	end
	local closing = sinceHit - S.OpenTime - S.Hold
	if closing <= 0 then
		return 1
	end
	if closing >= S.CloseTime then
		return 0
	end
	return 1 - closing / S.CloseTime
end

local function headFront(x: number, y: number): number
	local H = AxolotlMoves.Smile.Head
	local a = x / H.RadiusX
	local b = (y - H.Y) / H.RadiusY
	return H.Z - H.RadiusZ * math.sqrt(math.max(1 - a * a - b * b, 0))
end

-- The dots of the smile, nose side of the head, curving up at both ends.
function AxolotlMoves.smileDots(): { { x: number, y: number, z: number } }
	local S = AxolotlMoves.Smile
	local dots = {}
	for i = 1, S.Count do
		local t = (i - 1) / (S.Count - 1) * 2 - 1
		local x = t * S.HalfWidth
		local y = S.CenterY + t * t * S.Rise
		table.insert(dots, { x = x, y = y, z = headFront(x, y) })
	end
	return dots
end

-- The mouth's middle, in car space, for how open it is.
function AxolotlMoves.mouthAt(open: number): { x: number, y: number, z: number }
	local S = AxolotlMoves.Smile
	local y = S.CenterY - S.MouthDrop
	local halfDepth = S.MouthSize.Z / 2
	local front = headFront(0, y)
	return { x = 0, y = y, z = front + halfDepth + lerp(S.MouthHidden, -S.MouthShown, open) }
end

-- How many pieces are off, with this many of the car's breakable parts broken.
function AxolotlMoves.piecesOff(broken: number, total: number): number
	if total <= 0 then
		return 0
	end
	local off = 0
	for _, at in AxolotlMoves.Breaks do
		if broken / total >= at then
			off += 1
		end
	end
	return off
end

return AxolotlMoves
