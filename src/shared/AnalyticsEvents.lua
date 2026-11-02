--!strict
-- AnalyticsEvents (ModuleScript) -> ReplicatedStorage.AnalyticsEvents
-- What the server's Analytics module logs, built here. Pure, see InputAxes.
--
-- Analytics runs only in the live game (isLive). Economy events (source,
-- sink) name every cash or bones change by its reason; a reason in Unlogged
-- is left out on purpose, and one Tuning does not know is a problem for the
-- caller to report. The onboarding funnel (reach) logs its steps strictly in
-- order: a step reached early waits until every step before it is reached,
-- since Roblox counts skipped steps as done. Numbers that vary a lot, like
-- run scores and minutes, go out as ranges (bucket), so custom field values
-- stay few. The budget (spend) keeps each server under Roblox's rate limit.

local AnalyticsEvents = {}

-- Same fields as Tuning.Analytics that this module reads, declared here so
-- this module needs no require.
export type Tuning = {
	DevGameIds: { number }, -- GameIds of dev copies, never logged
	BaseRate: number, -- events each server may send per minute
	PerPlayerRate: number, -- plus this many per player in the server
	Currencies: { [string]: string },
	Sources: { [string]: string }, -- reason -> transaction type
	Sinks: { [string]: string }, -- what was bought -> transaction type
	Unlogged: { string }, -- reasons left out of the economy events
	Onboarding: { string }, -- funnel step names, in order
	ScoreBuckets: { number }, -- rising range edges
	MinuteBuckets: { number },
}

export type Economy = {
	Flow: "Source" | "Sink",
	Currency: string,
	Amount: number, -- always positive
	Balance: number, -- after the change
	Transaction: string,
	Sku: string,
}

export type Step = {
	Step: number,
	Name: string,
}

export type Onboarding = {
	reached: { [string]: boolean },
	logged: number, -- steps logged so far, from the first
}

export type Budget = {
	from: number, -- when this minute started
	used: number,
}

local FIELD_KEYS = { "CustomField01", "CustomField02", "CustomField03" }
local MINUTE = 60

-- Whether this server logs analytics: never in Studio or a dev game.
function AnalyticsEvents.isLive(isStudio: boolean, gameId: number, tuning: Tuning): boolean
	return not isStudio and table.find(tuning.DevGameIds, gameId) == nil
end

-- The range `value` falls in, given rising `edges`: "<a", "a-b", or "z+".
-- A value equal to an edge is in the range that starts there.
function AnalyticsEvents.bucket(value: number, edges: { number }): string
	if #edges == 0 or value < edges[1] then
		return `<{edges[1] or 0}`
	end
	for i = 2, #edges do
		if value < edges[i] then
			return `{edges[i - 1]}-{edges[i]}`
		end
	end
	return `{edges[#edges]}+`
end

-- Cash or bones gained for `reason`. Nil when nothing was gained or the
-- reason is left out, with "UnknownSource" for a reason Tuning lacks.
function AnalyticsEvents.source(
	reason: string,
	currency: string,
	amount: number,
	balance: number,
	tuning: Tuning
): (Economy?, string?)
	if amount <= 0 or table.find(tuning.Unlogged, reason) then
		return nil, nil
	end
	local transaction = tuning.Sources[reason]
	if not transaction then
		return nil, "UnknownSource"
	end
	return {
		Flow = "Source",
		Currency = currency,
		Amount = amount,
		Balance = balance,
		Transaction = transaction,
		Sku = reason,
	},
		nil
end

-- Cash or bones spent on `id` of kind `sink` (Upgrade "Jets", Car
-- "Hatchback"). Nil when it was free, with "UnknownSink" for a kind Tuning
-- lacks.
function AnalyticsEvents.sink(
	sink: string,
	id: string,
	currency: string,
	amount: number,
	balance: number,
	tuning: Tuning
): (Economy?, string?)
	if amount <= 0 then
		return nil, nil
	end
	local transaction = tuning.Sinks[sink]
	if not transaction then
		return nil, "UnknownSink"
	end
	return {
		Flow = "Sink",
		Currency = currency,
		Amount = amount,
		Balance = balance,
		Transaction = transaction,
		Sku = `{sink}_{id}`,
	},
		nil
end

function AnalyticsEvents.newOnboarding(): Onboarding
	return { reached = {}, logged = 0 }
end

-- Marks step `name` reached, and returns the steps now ready to log, in
-- order: every step from the next unlogged one up to the first not reached.
function AnalyticsEvents.reach(state: Onboarding, name: string, tuning: Tuning): { Step }
	local ready: { Step } = {}
	if not table.find(tuning.Onboarding, name) then
		return ready
	end
	state.reached[name] = true
	while state.logged < #tuning.Onboarding do
		local nextName = tuning.Onboarding[state.logged + 1]
		if not state.reached[nextName] then
			break
		end
		state.logged += 1
		table.insert(ready, { Step = state.logged, Name = nextName })
	end
	return ready
end

function AnalyticsEvents.newBudget(now: number): Budget
	return { from = now, used = 0 }
end

-- Takes one event from this minute's budget for a server of `players`.
-- False when it is spent, so the event is dropped.
function AnalyticsEvents.spend(budget: Budget, now: number, players: number, tuning: Tuning): boolean
	if now - budget.from >= MINUTE then
		budget.from = now
		budget.used = 0
	end
	if budget.used >= tuning.BaseRate + tuning.PerPlayerRate * players then
		return false
	end
	budget.used += 1
	return true
end

export type Gain = {
	Currency: string,
	Reason: string,
	Amount: number,
	Balance: number, -- the latest balance seen
}

-- Gains waiting to be logged as one event each, by currency and reason.
export type Batch = { [string]: Gain }

function AnalyticsEvents.newBatch(): Batch
	return {}
end

function AnalyticsEvents.add(batch: Batch, currency: string, reason: string, amount: number, balance: number)
	local key = `{currency} {reason}`
	local gain = batch[key]
	if gain then
		gain.Amount += amount
		gain.Balance = balance
	else
		batch[key] = { Currency = currency, Reason = reason, Amount = amount, Balance = balance }
	end
end

-- Every gain added since the last flush, and empties the batch.
function AnalyticsEvents.flush(batch: Batch): { Gain }
	local gains: { Gain } = {}
	for key, gain in batch do
		table.insert(gains, gain)
		batch[key] = nil
	end
	return gains
end

-- The obby funnel step for reaching `checkpoint`: step 1 is the start pad,
-- and checkpoint n, the end of stage n, is step n + 1 named for that stage.
function AnalyticsEvents.obbyStep(checkpoint: number, stageNames: { string }): (number, string)
	if checkpoint <= 0 then
		return 1, "Start"
	end
	local number = string.format("%02d", checkpoint)
	local name = stageNames[checkpoint]
	return checkpoint + 1, if name then `{number} {name}` else number
end

-- Custom fields from up to three string values, in order.
function AnalyticsEvents.fields(values: { string }): { [string]: string }
	local fields = {}
	for i, key in FIELD_KEYS do
		fields[key] = values[i]
	end
	return fields
end

return AnalyticsEvents
