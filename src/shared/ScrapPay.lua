--!strict
-- ScrapPay (ModuleScript) -> ReplicatedStorage.ScrapPay
-- What the Scrapyard's machines pay (ScoreService). Each pays at most once
-- every so often per player, so crushing never beats launching for cash. A
-- crush pays by the tons the crusher reached (Crusher.tons), more for a
-- tougher car. A run off Hammer Alley's kicker pays its target only if the
-- car ran the lane from the start. Pure, see InputAxes.

local ScrapPay = {}

export type Crusher = {
	TonsPerSecond: number,
	PayPerTon: number,
}

export type Lane = {
	Width: number,
	Length: number,
	StartZone: number, -- a car this far into the lane counts as starting it
}

-- Cash for a crush that took `crushTime` seconds.
function ScrapPay.crush(c: Crusher, crushTime: number): number
	return math.floor(c.TonsPerSecond * crushTime * c.PayPerTon + 0.5)
end

-- Whether pay last given at `last` (nil if never) is due again at `now`.
function ScrapPay.due(last: number?, now: number, gap: number): boolean
	return last == nil or now - last >= gap
end

-- Whether a car at (x, a) in the lane's studs (Hammers.toLane) is running
-- the alley, given whether it `was`: it starts within StartZone of the
-- lane's start, and stops once it leaves the lane any way but over the end,
-- onto the kicker.
function ScrapPay.alleyRun(c: Lane, was: boolean, x: number, a: number): boolean
	local between = math.abs(x) <= c.Width / 2
	if between and a >= 0 and a <= c.Length then
		return was or a <= c.StartZone
	end
	return was and between and a > c.Length
end

return ScrapPay
