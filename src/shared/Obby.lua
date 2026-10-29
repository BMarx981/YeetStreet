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

-- Whether `visit` has reached the finish.
function Obby.finished(visit: Visit, tuning: Tuning): boolean
	return visit.Reached >= tuning.Stages
end

-- `seconds` into a visit as the HUD's clock shows it, like 1:05.3.
function Obby.clock(seconds: number): string
	local tenths = math.floor(seconds * 10)
	return string.format("%d:%02d.%d", tenths // 600, tenths // 10 % 60, tenths % 10)
end

export type StageState = "Cleared" | "Current" | "Ahead"

-- How the HUD shows `stage`: the one after the respawn pad is the one being
-- played, and every stage up to the furthest pad is cleared.
function Obby.stageState(stage: number, visit: Visit, tuning: Tuning): StageState
	if stage == visit.Current + 1 and stage <= tuning.Stages then
		return "Current"
	elseif stage <= visit.Reached then
		return "Cleared"
	end
	return "Ahead"
end

export type PadState = "Here" | "Open" | "Locked"

-- How the stage select shows `checkpoint`: where the car respawns now, a
-- reached pad it can go back to, or one not reached yet.
function Obby.padState(checkpoint: number, visit: Visit): PadState
	if checkpoint == visit.Current then
		return "Here"
	elseif checkpoint <= visit.Reached then
		return "Open"
	end
	return "Locked"
end

return Obby
