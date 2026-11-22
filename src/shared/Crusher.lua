--!strict
-- Crusher (ModuleScript) -> ReplicatedStorage.Crusher
-- The Scrapyard's car crusher (Tuning.Scrapyard.Crusher). A countdown of
-- Fill seconds from the first car stopping on the bed lets others drive on
-- too. Then one cycle: the head slams down to ContactHeight over Close seconds, crushes on down to
-- FlatHeight over the crush time, holds flat for Hold, then rises back to
-- TopHeight over Open. The crush time grows with the car's toughness, so a
-- tougher car holds out longer and the pressure (tons) climbs higher.
-- Heights are studs above the bed's top; places on the bed are studs from
-- its middle, X across and Z along. Pure, see InputAxes.

local Crusher = {}

export type Config = {
	BedWidth: number,
	BedLength: number,
	CatchHeight: number, -- a hull at most this high over the bed is on it
	TopHeight: number,
	ContactHeight: number,
	FlatHeight: number,
	Close: number,
	Hold: number,
	Open: number,
	CrushBase: number,
	CrushPerToughness: number,
	CrushMax: number,
	TonsPerSecond: number,
	MinSquash: number,
	Fill: number, -- seconds from the first car stopping on the bed to the slam, for others to drive on
}

export type Phase = "idle" | "closing" | "crushing" | "holding" | "opening"

-- Seconds to crush a car of `toughness` flat.
function Crusher.crushTime(c: Config, toughness: number): number
	return math.clamp(c.CrushBase + toughness * c.CrushPerToughness, c.CrushBase, c.CrushMax)
end

function Crusher.cycleLength(c: Config, crushTime: number): number
	return c.Close + crushTime + c.Hold + c.Open
end

-- The phase `elapsed` seconds into a cycle, and how far through it (0 to 1).
function Crusher.phase(c: Config, elapsed: number, crushTime: number): (Phase, number)
	if elapsed < 0 then
		return "idle", 0
	end
	local t = elapsed
	if t < c.Close then
		return "closing", t / c.Close
	end
	t -= c.Close
	if t < crushTime then
		return "crushing", t / crushTime
	end
	t -= crushTime
	if t < c.Hold then
		return "holding", t / c.Hold
	end
	t -= c.Hold
	if t < c.Open then
		return "opening", t / c.Open
	end
	return "idle", 0
end

-- The head's underside above the bed, `elapsed` seconds into a cycle.
function Crusher.headHeight(c: Config, elapsed: number, crushTime: number): number
	local phase, p = Crusher.phase(c, elapsed, crushTime)
	if phase == "closing" then
		return c.TopHeight + (c.ContactHeight - c.TopHeight) * p * p
	elseif phase == "crushing" then
		return c.ContactHeight + (c.FlatHeight - c.ContactHeight) * p
	elseif phase == "holding" then
		return c.FlatHeight
	elseif phase == "opening" then
		local eased = p * p * (3 - 2 * p)
		return c.FlatHeight + (c.TopHeight - c.FlatHeight) * eased
	end
	return c.TopHeight
end

-- The pressure on the gauge: climbing through the crush, then held at its
-- peak until the cycle ends.
function Crusher.tons(c: Config, elapsed: number, crushTime: number): number
	return c.TonsPerSecond * math.clamp(elapsed - c.Close, 0, crushTime)
end

-- The sounds a cycle makes after `from` and by `to` seconds into it, in
-- order: "close" as the head starts down, "slam" as it meets the cars, and
-- "open" as it starts back up.
function Crusher.cues(c: Config, from: number, to: number, crushTime: number): { string }
	local cues: { string } = {}
	for _, cue in
		{
			{ name = "close", at = 0 },
			{ name = "slam", at = c.Close },
			{ name = "open", at = c.Close + crushTime + c.Hold },
		}
	do
		if from < cue.at and cue.at <= to then
			table.insert(cues, cue.name)
		end
	end
	return cues
end

-- Whether a hull at (x, z) on the bed, `y` above its top, is on it.
function Crusher.onBed(c: Config, x: number, z: number, y: number): boolean
	return math.abs(x) <= c.BedWidth / 2 and math.abs(z) <= c.BedLength / 2 and y >= -2 and y <= c.CatchHeight
end

-- Whole seconds left on the countdown `elapsed` seconds after the first car
-- stopped on the bed, for the gauge.
function Crusher.countdown(c: Config, elapsed: number): number
	return math.ceil(math.max(c.Fill - elapsed, 0))
end

-- How much of its height a car keeps (1 is all) so that its top, `top`
-- above the bed, fits under the head `head` above the bed.
function Crusher.squash(c: Config, top: number, head: number): number
	if top <= 0 then
		return 1
	end
	return math.clamp(head / top, c.MinSquash, 1)
end

return Crusher
