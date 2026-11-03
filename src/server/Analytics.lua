--!strict
-- Analytics (ModuleScript) -> ServerScriptService.Analytics
-- The only code that calls AnalyticsService. The events are AnalyticsEvents';
-- this sends them, and only in the live game (Tuning.Analytics). In Studio
-- it sends nothing, and prints what it would send if PrintInStudio is on.
--
-- Every call is wrapped in pcall, so a failure never breaks gameplay or a
-- save, and each kind of failure warns once per server. Past the server's
-- budget for the minute (AnalyticsEvents.spend), events are dropped, with
-- one warning a minute.
--
-- Callers log facts the server saw itself, never what a client reports:
--   gained / spent    every cash or bones change, at the line that makes it
--   reach             an onboarding funnel step (AnalyticsEvents.reach)
--   funnel            a step of a recurring funnel, such as an obby visit
--   custom            a custom event, with up to three string fields
--   ranRun, upgraded, gotCar   onboarding steps plus their custom events
--   flaggedRun        a run that failed RunCheck
-- Onboarding steps, run counts, and the session clock live in memory for
-- this session only. Nothing here is saved. AnalyticsWatch reaches the
-- steps no other script sees: joining, the car spawning, the first drive,
-- and reaching a garage.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsEvents = require(ReplicatedStorage.AnalyticsEvents)
local Tuning = require(ReplicatedStorage.Tuning)
local PlayerData = require(ServerScriptService.PlayerData)

local T = Tuning.Analytics

local Analytics = {}

-- Whether this server sends events. One place decides it, so a dev and live
-- switch can take it over.
Analytics.live = AnalyticsEvents.isLive(RunService:IsStudio(), game.GameId, T)
local printing = not Analytics.live and RunService:IsStudio() and T.PrintInStudio

local budget = AnalyticsEvents.newBudget(os.clock())
local warned: { [string]: boolean } = {}
local droppedWarnAt = -math.huge
local onboarding: { [Player]: AnalyticsEvents.Onboarding } = {}
local joinedAt: { [Player]: number } = {}
local batches: { [Player]: AnalyticsEvents.Batch } = {}
local runs: { [Player]: number } = {}

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`Analytics: {message}`)
	end
end

-- Sends one event through `call`, if this server sends events and the
-- budget allows. `describe` is what Studio prints.
local function send(kind: string, describe: string, call: () -> ())
	if printing then
		print(`Analytics: {kind} {describe}`)
		return
	end
	if not Analytics.live then
		return
	end
	local now = os.clock()
	if not AnalyticsEvents.spend(budget, now, #Players:GetPlayers(), T) then
		if now - droppedWarnAt >= 60 then
			droppedWarnAt = now
			warn("Analytics: over the rate budget, dropping events this minute")
		end
		return
	end
	local ok, err = pcall(call)
	if not ok then
		warnOnce(kind, `{kind} failed ({err})`)
	end
end

local function economy(player: Player, event: AnalyticsEvents.Economy?, problem: string?, name: string)
	if problem then
		warnOnce(`{problem} {name}`, `{problem} {name}, add it to Tuning.Analytics`)
	end
	if not event then
		return
	end
	local flow = if event.Flow == "Source"
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	send(
		"Economy",
		`{event.Flow} {event.Amount} {event.Currency} {event.Transaction} {event.Sku}, balance {event.Balance}`,
		function()
			AnalyticsService:LogEconomyEvent(
				player,
				flow,
				event.Currency,
				event.Amount,
				event.Balance,
				event.Transaction,
				event.Sku
			)
		end
	)
end

local function logGain(player: Player, currency: string, reason: string, amount: number, balance: number)
	local event, problem = AnalyticsEvents.source(reason, T.Currencies[currency], amount, balance, T)
	economy(player, event, problem, reason)
end

local function flush(player: Player)
	local batch = batches[player]
	if batch then
		for _, gain in AnalyticsEvents.flush(batch) do
			logGain(player, gain.Currency, gain.Reason, gain.Amount, gain.Balance)
		end
	end
end

-- `amount` of `currency` (a key of Tuning.Analytics.Currencies) gained for
-- `reason`, leaving `balance`. A Batched reason is logged later, added up.
function Analytics.gained(player: Player, currency: string, reason: string, amount: number, balance: number)
	if amount > 0 and table.find(T.Batched, reason) then
		local batch = batches[player]
		if not batch then
			batch = AnalyticsEvents.newBatch()
			batches[player] = batch
		end
		AnalyticsEvents.add(batch, currency, reason, amount, balance)
		return
	end
	logGain(player, currency, reason, amount, balance)
end

-- `amount` of `currency` spent on `id` of kind `sink`, leaving `balance`.
function Analytics.spent(player: Player, currency: string, sink: string, id: string, amount: number, balance: number)
	local event, problem = AnalyticsEvents.sink(sink, id, T.Currencies[currency], amount, balance, T)
	economy(player, event, problem, sink)
end

-- The player reached onboarding step `name`, logging it and any later steps
-- that were waiting on it.
function Analytics.reach(player: Player, name: string)
	if player.Parent ~= Players then
		return
	end
	local state = onboarding[player]
	if not state then
		state = AnalyticsEvents.newOnboarding()
		onboarding[player] = state
	end
	for _, step in AnalyticsEvents.reach(state, name, T) do
		send("Onboarding", `{step.Step} {step.Name}`, function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step.Step, step.Name)
		end)
	end
end

function Analytics.funnel(player: Player, funnel: string, sessionId: string, step: number, stepName: string)
	send("Funnel", `{funnel} {step} {stepName}`, function()
		AnalyticsService:LogFunnelStepEvent(player, funnel, sessionId, step, stepName)
	end)
end

function Analytics.custom(player: Player, name: string, values: { string })
	local fields = AnalyticsEvents.fields(values)
	send("Custom", `{name} {table.concat(values, ", ")}`, function()
		AnalyticsService:LogCustomEvent(player, name, 1, fields)
	end)
end

-- Minutes since the player joined this server.
function Analytics.minutesIn(player: Player): number
	return (os.clock() - (joinedAt[player] or os.clock())) / 60
end

-- A run of the player's ended in `park` (an area Id) with `score`, paying
-- `paid` cash.
function Analytics.ranRun(player: Player, park: string, score: number, ending: string, paid: number)
	runs[player] = (runs[player] or 0) + 1
	if paid > 0 then
		Analytics.reach(player, "FirstPaidRun")
	end
	if runs[player] == T.FifthRun then
		Analytics.reach(player, "FifthRun")
	end
	Analytics.custom(player, T.Events.Run, { park, AnalyticsEvents.bucket(score, T.ScoreBuckets), ending })
end

-- A run of the player's in `park` failed RunCheck for `reason` ("Fuel",
-- "Boost" or "Drift") in the car `car` (its CarId). It still paid.
function Analytics.flaggedRun(player: Player, reason: string, park: string, car: string)
	Analytics.custom(player, T.Events.FlaggedRun, { reason, park, car })
end

-- How far into this session, and whether it is the player's first.
local function when(player: Player): { string }
	local session = if PlayerData.isNew(player) then "FirstSession" else "Returning"
	return { AnalyticsEvents.bucket(Analytics.minutesIn(player), T.MinuteBuckets), session }
end

-- The player bought an upgrade; `firstEver` if they had none before.
function Analytics.upgraded(player: Player, firstEver: boolean)
	Analytics.reach(player, "FirstUpgrade")
	if firstEver then
		Analytics.custom(player, T.Events.FirstUpgrade, when(player))
	end
end

-- The player got a car, bought or won; `firstEver` if it is their first
-- after the starter car.
function Analytics.gotCar(player: Player, firstEver: boolean)
	Analytics.reach(player, "FirstNewCar")
	if firstEver then
		Analytics.custom(player, T.Events.FirstNewCar, when(player))
	end
end

local function onPlayerAdded(player: Player)
	joinedAt[player] = joinedAt[player] or os.clock()
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerRemoving:Connect(function(player: Player)
	flush(player)
	batches[player] = nil
	runs[player] = nil
	onboarding[player] = nil
	joinedAt[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(T.BatchGap)
		for player in batches do
			flush(player)
		end
	end
end)

return Analytics
