--!strict
-- Juice (ModuleScript) -> ReplicatedStorage.Juice
-- The numbers behind the show around moments that already happen: how a
-- trick popup is colored, a landing's grade stamp, the combo ding's pitch,
-- how big the live score grows, speed lines and the top speed shake, and the
-- coins that fly into the cash counter. Feel only: nothing here changes pay
-- or score. Pure, see InputAxes.

local Juice = {}

-- Same fields as Tuning.Juice, declared here so this module needs no require.
export type Tuning = {
	GoldFrom: number, -- trick points
	RainbowFrom: number,
	PerfectUpY: number, -- up vector Y at touchdown, on a clean landing
	DingSemitones: number, -- per combo step
	ScoreTiers: { number }, -- combos where the live score steps up, lowest first
	LinesFrom: number, -- out of 1 of the camera's full speed
	ShakeFrom: number,
	CashPerCoin: number,
	MaxCoins: number,
	RainFrom: number, -- cash paid by one run
	RollRate: number, -- per second
	RollSnap: number, -- points
	StopHold: number, -- seconds
	StopCatch: number, -- seconds
	PunchFov: number, -- degrees
	PunchTime: number, -- seconds
}

export type HitStop = {
	blend: number, -- 0 is the held view, 1 the camera's own
	fov: number, -- degrees to add to the field of view
	done: boolean,
}

export type PopupTier = "White" | "Gold" | "Rainbow"
export type Grade = "Sloppy" | "Clean" | "Perfect"

function Juice.popupTier(points: number, tuning: Tuning): PopupTier
	if points >= tuning.RainbowFrom then
		return "Rainbow"
	elseif points >= tuning.GoldFrom then
		return "Gold"
	end
	return "White"
end

-- A landing's stamp. `clean` is RunTracker's verdict, so a landing it calls
-- clean is never Sloppy here and one it doesn't is never better.
function Juice.grade(clean: boolean, upY: number, tuning: Tuning): Grade
	if not clean then
		return "Sloppy"
	elseif upY >= tuning.PerfectUpY then
		return "Perfect"
	end
	return "Clean"
end

-- PlaybackSpeed for the ding as the combo reaches `combo`, rising
-- DingSemitones for each ComboStep (Tuning.Score) above x1.
function Juice.dingPitch(combo: number, comboStep: number, tuning: Tuning): number
	local steps = math.max(math.floor((combo - 1) / comboStep + 0.5), 0)
	return 2 ^ (steps * tuning.DingSemitones / 12)
end

-- How many of ScoreTiers the combo has reached: 0 for none, and the last one
-- means the max combo.
function Juice.scoreTier(combo: number, tuning: Tuning): number
	local tier = 0
	for i, from in tuning.ScoreTiers do
		if combo >= from then
			tier = i
		end
	end
	return tier
end

-- The live score shown after `dt` seconds more of rolling from `shown`
-- toward `target`: it closes the same share of the gap each second
-- (RollRate), so a big jump rolls fast and slows as it lands, and it snaps
-- the last RollSnap points.
function Juice.roll(shown: number, target: number, dt: number, tuning: Tuning): number
	if math.abs(target - shown) <= tuning.RollSnap then
		return target
	end
	local rolled = shown + (target - shown) * (1 - math.exp(-tuning.RollRate * dt))
	if math.abs(target - rolled) <= tuning.RollSnap then
		return target
	end
	return rolled
end

-- The camera's hit-stop `elapsed` seconds after it started: it holds its view
-- for StopHold while the car moves on, then catches up over StopCatch, and
-- the zoom punches in by PunchFov and back out over PunchTime after the hold.
-- Camera only: physics never slows.
function Juice.hitStop(elapsed: number, tuning: Tuning): HitStop
	local after = elapsed - tuning.StopHold
	local blend = math.clamp(after / tuning.StopCatch, 0, 1)
	local punch = after / tuning.PunchTime
	local fov = if punch > 0 and punch < 1 then -tuning.PunchFov * math.sin(math.pi * punch) else 0
	return {
		blend = blend,
		fov = fov,
		done = after >= math.max(tuning.StopCatch, tuning.PunchTime),
	}
end

local function ramp(t: number, from: number): number
	return math.clamp((t - from) / (1 - from), 0, 1)
end

-- How strong the speed lines are, 0 to 1, for `speedT` out of the camera's
-- full speed (ChaseCamera).
function Juice.speedLines(speedT: number, tuning: Tuning): number
	return ramp(speedT, tuning.LinesFrom)
end

-- How strong the camera shake near top speed is, 0 to 1.
function Juice.topShake(speedT: number, tuning: Tuning): number
	return ramp(speedT, tuning.ShakeFrom)
end

-- Coins that fly from the run card into the cash counter for `paid`.
function Juice.flyCoins(paid: number, tuning: Tuning): number
	if paid <= 0 then
		return 0
	end
	return math.min(math.ceil(paid / tuning.CashPerCoin), tuning.MaxCoins)
end

function Juice.rains(paid: number, tuning: Tuning): boolean
	return paid >= tuning.RainFrom
end

return Juice
