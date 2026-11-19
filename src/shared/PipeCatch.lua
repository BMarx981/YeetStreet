--!strict
-- PipeCatch (ModuleScript) -> ReplicatedStorage.PipeCatch
-- Brings a car that flies off the top of a half pipe wall back down on the
-- top of the same wall, as a skater comes back in: the speed across the pipe
-- that lands it Catch.Inset studs inside the lip at the lip's height. Speed
-- along the pipe and up is left as it is. Pure, see InputAxes.
--
-- Pipe coordinates: `across` is studs from the pipe's middle line toward
-- either wall (signed), `along` is studs along the pipe from its middle, and
-- `height` is studs above the pipe's floor.

local PipeCatch = {}

export type Pipe = {
	FlatWidth: number,
	Radius: number,
	Angle: number, -- degrees the walls curve up
	Length: number,
	Catch: {
		Inset: number, -- studs inside the lip to bring the car down
		Reach: number, -- studs either side of the lip that a car is caught
		MinRise: number, -- studs per second up, at least
	},
}

-- How far across from the middle line the top of either wall is, and how
-- high.
function PipeCatch.lip(pipe: Pipe): (number, number)
	local angle = math.rad(pipe.Angle)
	return pipe.FlatWidth / 2 + pipe.Radius * math.sin(angle), pipe.Radius * (1 - math.cos(angle))
end

-- The speed across that takes a car at `across`, `height`, going `up`, to
-- `toAcross` when it falls back to `toHeight`, or nil if it can't get there.
function PipeCatch.aim(
	across: number,
	height: number,
	up: number,
	toAcross: number,
	toHeight: number,
	gravity: number
): number?
	local square = up * up + 2 * gravity * (height - toHeight)
	if square < 0 then
		return nil
	end
	local time = (up + math.sqrt(square)) / gravity
	if time <= 0 then
		return nil
	end
	return (toAcross - across) / time
end

-- The speed across to give a car rising off the top of either wall, or nil
-- to leave it alone.
function PipeCatch.catch(
	pipe: Pipe,
	across: number,
	along: number,
	height: number,
	up: number,
	gravity: number
): number?
	local C = pipe.Catch
	if up < C.MinRise or math.abs(along) > pipe.Length / 2 then
		return nil
	end
	local lipAcross, lipHeight = PipeCatch.lip(pipe)
	if height < lipHeight or math.abs(math.abs(across) - lipAcross) > C.Reach then
		return nil
	end
	local side = if across < 0 then -1 else 1
	return PipeCatch.aim(across, height, up, side * (lipAcross - C.Inset), lipHeight, gravity)
end

return PipeCatch
