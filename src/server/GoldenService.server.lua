--!strict
-- GoldenService (Script) -> ServerScriptService.GoldenService
-- Runs the golden booster (Golden). FirstAfter seconds after the server
-- starts, and every Every seconds from then, one of Tuning.Golden.Launchers
-- turns gold for up to Duration seconds, never the same one twice in a row.
-- None turns gold during Mega Boosters, and one that is gold when Mega
-- Boosters starts goes back to normal.
--
-- Everything is on workspace attributes, for ScoreService and every client
-- (GoldenLook): GoldenBooster is the launcher id while it is gold, and
-- GoldenEnds when it stops being gold (workspace:GetServerTimeNow()).
-- ScoreService claims it on the first launch off it: it sets GoldenTakenBy
-- to the player's display name and clears GoldenBooster, which ends it here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Golden = require(ReplicatedStorage.Golden)
local Tuning = require(ReplicatedStorage.Tuning)

local G = Tuning.Golden
local CHECK_EVERY = 0.25

local random = Random.new()

local function isMega(): boolean
	return workspace:GetAttribute("Event") == "Mega"
end

-- The launchers that are in this place.
local function present(): { string }
	local ids: { string } = {}
	for _, id in G.Launchers do
		local launcher = nil
		for _, l in Tuning.LaunchRecords.Launchers do
			if l.Id == id then
				launcher = l
			end
		end
		local at: Instance? = if launcher then workspace else nil
		if launcher then
			for name in string.gmatch(launcher.Path, "[^%.]+") do
				at = if at then at:FindFirstChild(name) else nil
			end
		end
		if at then
			table.insert(ids, id)
		else
			warn(`GoldenService: no launcher {id} in this place`)
		end
	end
	return ids
end

local function run(id: string)
	workspace:SetAttribute("GoldenTakenBy", nil)
	workspace:SetAttribute("GoldenEnds", workspace:GetServerTimeNow() + G.Duration)
	workspace:SetAttribute("GoldenBooster", id)
	local endsAt = os.clock() + G.Duration
	while os.clock() < endsAt and workspace:GetAttribute("GoldenBooster") == id and not isMega() do
		task.wait(CHECK_EVERY)
	end
	if workspace:GetAttribute("GoldenBooster") == id then
		workspace:SetAttribute("GoldenBooster", nil)
	end
end

task.wait(G.FirstAfter)
local ids = present()
local last: string? = nil
local nextAt = os.clock()
while true do
	task.wait(math.max(nextAt - os.clock(), 0))
	nextAt += G.Every
	if not isMega() then
		local id = Golden.pick(ids, last, random:NextNumber())
		if id then
			last = id
			run(id)
		end
	end
end
