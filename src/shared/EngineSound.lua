--!strict
-- EngineSound (ModuleScript) -> ReplicatedStorage.EngineSound
-- How a car's engine loop should sound right now. On the ground the pitch and
-- volume rise with speed, and the driver's gas revs it on top. In the air the
-- engine falls back to idle, since the jets take over. Other players' cars
-- play a little lower and much quieter than your own. Pitch is a multiplier
-- on the sound's PlaybackSpeed, volume a fraction of its Volume. Only the
-- closest few other cars play at once (nearest). The player's engine sound
-- setting turns them all down or off (setting, settingVolume). Pure.

local EngineSound = {}

export type Tuning = {
	IdlePitch: number,
	TopPitch: number,
	GasPitch: number, -- added at full gas, forward or reverse
	IdleVolume: number,
	TopVolume: number,
	OthersPitch: number,
	OthersVolume: number,
}

-- The pitch and volume to aim for. `speed` is along the car (negative in
-- reverse), `gas` the throttle from -1 to 1 (0 for other players' cars, whose
-- throttle isn't known), `own` true for the local player's car.
function EngineSound.target(
	speed: number,
	topSpeed: number,
	gas: number,
	airborne: boolean,
	own: boolean,
	tuning: Tuning
): (number, number)
	local pitch = tuning.IdlePitch
	local volume = tuning.IdleVolume
	if not airborne then
		local fraction = if topSpeed > 0 then math.clamp(math.abs(speed) / topSpeed, 0, 1) else 0
		local push = math.clamp(math.abs(gas), 0, 1)
		pitch += (tuning.TopPitch - tuning.IdlePitch) * fraction + tuning.GasPitch * push
		volume += (tuning.TopVolume - tuning.IdleVolume) * math.max(fraction, push)
	end
	if not own then
		pitch *= tuning.OthersPitch
		volume *= tuning.OthersVolume
	end
	return pitch, volume
end

-- The jet loop's pitch and volume: on while the jets burn, lower and quieter
-- on other players' cars like their engines.
function EngineSound.jet(burning: boolean, own: boolean, tuning: Tuning): (number, number)
	local pitch = if own then 1 else tuning.OthersPitch
	local volume = if not burning then 0 elseif own then 1 else tuning.OthersVolume
	return pitch, volume
end

-- Moves `current` toward `target` by at most `rate` per second, so the engine
-- glides between pitches instead of jumping.
function EngineSound.approach(current: number, target: number, rate: number, dt: number): number
	local step = rate * dt
	if math.abs(target - current) <= step then
		return target
	end
	return current + math.sign(target - current) * step
end

-- Which other cars play their engine: the `count` closest that are nearer
-- than `reach`, by their index in `distances`. Ties go to the earlier index.
function EngineSound.nearest(distances: { number }, count: number, reach: number): { [number]: boolean }
	local order: { number } = {}
	for i, distance in distances do
		if distance < reach then
			table.insert(order, i)
		end
	end
	table.sort(order, function(a: number, b: number): boolean
		if distances[a] ~= distances[b] then
			return distances[a] < distances[b]
		end
		return a < b
	end)
	local picked: { [number]: boolean } = {}
	for n = 1, math.min(count, #order) do
		picked[order[n]] = true
	end
	return picked
end

-- One choice of the engine sound setting: Volume scales every engine and jet
-- loop, 0 for silent.
export type Setting = { Name: string, Volume: number }

-- The saved setting's name, or the first choice's when `raw` isn't one of them.
function EngineSound.setting(raw: any, settings: { Setting }): string
	for _, s in settings do
		if s.Name == raw then
			return s.Name
		end
	end
	return settings[1].Name
end

-- How much the setting named `name` scales the loops' volume.
function EngineSound.settingVolume(name: any, settings: { Setting }): number
	local wanted = EngineSound.setting(name, settings)
	for _, s in settings do
		if s.Name == wanted then
			return s.Volume
		end
	end
	return 1
end

-- A loop whose seam clicks plays as two twins half a loop apart, each faded
-- to silence at its own seam while the other is at full volume. This is a
-- twin's volume at `position` seconds into its file, looping from
-- `loopStart` to `loopEnd`: 0 for `quiet` seconds either side of the seam,
-- 1 for as long either side of halfway round, and the two twins' powers
-- always add up to 1. `quiet` must be under a quarter of the loop.
function EngineSound.seamGain(position: number, loopStart: number, loopEnd: number, quiet: number): number
	local length = loopEnd - loopStart
	local phase = (position - loopStart) / length
	if phase < 0 or phase > 1 then
		return 0
	end
	local margin = quiet / length
	local function rise(x: number): number
		return math.clamp((x - margin) / (0.5 - 2 * margin), 0, 1)
	end
	if phase < 0.5 then
		return math.sin(math.pi / 2 * rise(phase))
	end
	return math.cos(math.pi / 2 * rise(phase - 0.5))
end

-- Where the second twin starts when the first is at `position`: half a loop
-- on, wrapped round the region.
function EngineSound.twinStart(position: number, loopStart: number, loopEnd: number): number
	local length = loopEnd - loopStart
	local phase = math.clamp((position - loopStart) / length, 0, 1)
	return loopStart + ((phase + 0.5) % 1) * length
end

return EngineSound
