--!strict
-- ObbyMover (ModuleScript) -> ReplicatedStorage.ObbyMover
-- Where a moving obby platform (ObbyCourse's Mover) is at a time on the
-- server's clock, the same on every machine. Pure, see InputAxes.
--
-- A cycle holds in line for Hold seconds, eases out to Travel over Move
-- seconds, holds there for Hold, and eases back over Move. Phase starts it
-- that far through its cycle (0 to 1), so platforms side by side can take
-- turns.

local ObbyMover = {}

export type Mover = {
	Axis: string, -- "Side" moves it right (Travel > 0) or left, "Up" up or down
	Travel: number,
	Move: number,
	Hold: number,
	Phase: number,
}

function ObbyMover.cycle(m: Mover): number
	return 2 * (m.Hold + m.Move)
end

-- An eased move, 0 to 1 over u = 0 to 1, and how fast it changes with u.
local function ease(u: number): (number, number)
	return u * u * (3 - 2 * u), 6 * u * (1 - u)
end

-- How far it is out of line at `time`, and how fast it is moving out.
function ObbyMover.offset(m: Mover, time: number): (number, number)
	local cycle = ObbyMover.cycle(m)
	local t = (time / cycle + m.Phase) % 1 * cycle
	if t < m.Hold then
		return 0, 0
	end
	t -= m.Hold
	if t < m.Move then
		local s, ds = ease(t / m.Move)
		return m.Travel * s, m.Travel * ds / m.Move
	end
	t -= m.Move
	if t < m.Hold then
		return m.Travel, 0
	end
	local s, ds = ease((t - m.Hold) / m.Move)
	return m.Travel * (1 - s), -m.Travel * ds / m.Move
end

return ObbyMover
