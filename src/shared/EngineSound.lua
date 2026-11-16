--!strict
-- EngineSound (ModuleScript) -> ReplicatedStorage.EngineSound
-- How a car's engine loop should sound right now. On the ground the pitch and
-- volume rise with speed, and the driver's gas revs it on top. In the air the
-- engine falls back to idle, since the jets take over. Other players' cars
-- play a little lower and much quieter than your own. Pitch is a multiplier
-- on the sound's PlaybackSpeed, volume a fraction of its Volume. Only the
-- closest few other cars play at once (nearest). Pure.

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

return EngineSound
