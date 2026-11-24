--!strict
-- UpgradeNudge (ModuleScript) -> ReplicatedStorage.UpgradeNudge
-- Whether to tell a new player, after a run that paid, that they can afford
-- an upgrade and where to buy it, and the line to show. Only for players who
-- have never bought an upgrade and never reborn, at most MaxShows times a
-- session. Pure.

local UpgradeNudge = {}

export type Tuning = {
	MaxShows: number,
	Text: string, -- "{cash}" is replaced with the player's cash
}

export type Input = {
	paid: number, -- cash the run paid
	cash: number, -- the player's cash after it
	cheapest: number, -- price of the cheapest upgrade level
	levels: { number }, -- every upgrade level the player has bought
	rebirths: number,
	shown: number, -- times shown this session
}

function UpgradeNudge.due(input: Input, tuning: Tuning): boolean
	if input.paid <= 0 or input.cash < input.cheapest then
		return false
	end
	if input.rebirths > 0 or input.shown >= tuning.MaxShows then
		return false
	end
	for _, level in input.levels do
		if level > 0 then
			return false
		end
	end
	return true
end

local function withCommas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function UpgradeNudge.text(cash: number, tuning: Tuning): string
	local line = tuning.Text:gsub("{cash}", "$" .. withCommas(cash))
	return line
end

return UpgradeNudge
