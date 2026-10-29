--!strict
-- Obby (ModuleScript) -> ReplicatedStorage.Obby
-- The car obby's checkpoints and stage cash. Pure, see InputAxes.
--
-- Checkpoint 0 is the start pad and checkpoint n ends stage n, so the last
-- checkpoint (Stages) is the finish. A visit lasts from arriving in the obby
-- until the player leaves it or the game; nothing in it is saved.
--
-- Touching the next new checkpoint clears its stage and pays it, every visit.
-- Checkpoints can't be skipped. The respawn point moves forward as cleared
-- checkpoints are touched, and can be set back to any reached one (select).

local Obby = {}

-- Same fields as Tuning.Obby, declared here so this module needs no require.
export type Tuning = {
	Stages: number, -- stages in the world, and the finish checkpoint's number
	StageCash: number, -- cash for clearing stage 1
	StageCashStep: number, -- cash added for each later stage
	WorldPrize: number, -- cash for the first ever finish, paid once
	DesignJets: number, -- Jets level every stage must be clearable with
	HangSpeed: number, -- only a car slower than this can be hung
	HangRoll: number, -- degrees tipped sideways that hang a car with two wheels down
	HangTime: number, -- seconds hung before it respawns
}

export type Visit = {
	Reached: number, -- furthest checkpoint touched this visit
	Current: number, -- checkpoint the car respawns at
}

local function isCheckpoint(n: number, last: number): boolean
	return n % 1 == 0 and n >= 0 and n <= last
end

function Obby.newVisit(): Visit
	return { Reached = 0, Current = 0 }
end

-- Cash for clearing `stage`.
function Obby.stageCash(stage: number, tuning: Tuning): number
	return tuning.StageCash + (stage - 1) * tuning.StageCashStep
end

-- `visit` after touching `checkpoint`, and the cash that pays.
function Obby.touch(visit: Visit, checkpoint: number, tuning: Tuning): (Visit, number)
	if not isCheckpoint(checkpoint, tuning.Stages) or checkpoint == 0 then
		return visit, 0
	end
	if checkpoint == visit.Reached + 1 then
		return { Reached = checkpoint, Current = checkpoint }, Obby.stageCash(checkpoint, tuning)
	end
	if checkpoint <= visit.Reached and checkpoint > visit.Current then
		return { Reached = visit.Reached, Current = checkpoint }, 0
	end
	return visit, 0
end

-- `visit` respawning at `checkpoint`, or nil if it hasn't been reached.
function Obby.select(visit: Visit, checkpoint: number): Visit?
	if not isCheckpoint(checkpoint, visit.Reached) then
		return nil
	end
	return { Reached = visit.Reached, Current = checkpoint }
end

-- A car can catch its hull on an edge with its outside wheels hanging off,
-- tipped sideways with its inside wheels too light to grip, unable to drive.
-- It is hung when slow with at most one wheel down, or two down and tipped
-- `roll` degrees sideways past HangRoll (the course is level across, so a
-- car on it never is). Given when it started hanging (`since`, nil if it
-- wasn't) and how it is now, returns when it started hanging, and whether it
-- has hung long enough to respawn (which ends the hang).
function Obby.hang(
	since: number?,
	now: number,
	speed: number,
	wheelsDown: number,
	roll: number,
	tuning: Tuning
): (number?, boolean)
	local stuck = wheelsDown <= 1 or (wheelsDown == 2 and roll > tuning.HangRoll)
	if speed >= tuning.HangSpeed or not stuck then
		return nil, false
	end
	local start = since or now
	if now - start >= tuning.HangTime then
		return nil, true
	end
	return start, false
end

-- Whether `visit` has reached the finish.
function Obby.finished(visit: Visit, tuning: Tuning): boolean
	return visit.Reached >= tuning.Stages
end

return Obby
