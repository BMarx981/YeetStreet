--!strict
-- Scrapyard (ModuleScript) -> ReplicatedStorage.Scrapyard
-- Shapes for the Scrapyard (Tuning.Scrapyard), the junkyard park past the
-- east edge wall. Pure, see InputAxes.

local Scrapyard = {}

export type Span = { from: number, to: number }

-- What is left of the span from `from` to `to` once the gap from `gapFrom`
-- to `gapTo` is cut out of it, low end first. Either pair can be given
-- either way round.
function Scrapyard.cutSpan(from: number, to: number, gapFrom: number, gapTo: number): { Span }
	local lo, hi = math.min(from, to), math.max(from, to)
	local gapLo, gapHi = math.min(gapFrom, gapTo), math.max(gapFrom, gapTo)
	if gapHi <= lo or gapLo >= hi then
		return { { from = lo, to = hi } }
	end
	local pieces: { Span } = {}
	if gapLo > lo then
		table.insert(pieces, { from = lo, to = gapLo })
	end
	if gapHi < hi then
		table.insert(pieces, { from = gapHi, to = hi })
	end
	return pieces
end

return Scrapyard
