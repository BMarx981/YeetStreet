--!strict
local Check = require("./Check")
local AnalyticsEvents = require("../src/shared/AnalyticsEvents")

local T: AnalyticsEvents.Tuning = {
	DevGameIds = { 111 },
	BaseRate = 10,
	PerPlayerRate = 2,
	Currencies = { Cash = "Cash", Bones = "Bones" },
	Sources = { Run = "Gameplay", InviteWelcome = "Onboarding" },
	Sinks = { Upgrade = "Shop", BoneShop = "Shop" },
	Unlogged = { "Admin" },
	Onboarding = { "Joined", "CarSpawned", "FirstLaunch", "FirstUpgrade" },
	ScoreBuckets = { 100, 1000 },
	MinuteBuckets = { 2, 5 },
}

Check.test("Studio is never live", function()
	Check.eq(AnalyticsEvents.isLive(true, 999, T), false)
end)

Check.test("a dev game is never live", function()
	Check.eq(AnalyticsEvents.isLive(false, 111, T), false)
end)

Check.test("any other game is live", function()
	Check.eq(AnalyticsEvents.isLive(false, 999, T), true)
end)

Check.test("buckets name the range a value falls in", function()
	Check.eq(AnalyticsEvents.bucket(0, T.ScoreBuckets), "<100")
	Check.eq(AnalyticsEvents.bucket(99.5, T.ScoreBuckets), "<100")
	Check.eq(AnalyticsEvents.bucket(100, T.ScoreBuckets), "100-1000")
	Check.eq(AnalyticsEvents.bucket(999, T.ScoreBuckets), "100-1000")
	Check.eq(AnalyticsEvents.bucket(1000, T.ScoreBuckets), "1000+")
	Check.eq(AnalyticsEvents.bucket(5e9, T.ScoreBuckets), "1000+")
end)

Check.test("a source names its reason as the sku", function()
	local event = AnalyticsEvents.source("Run", "Cash", 250, 1250, T)
	assert(event, "expected an event")
	Check.eq(event.Flow, "Source")
	Check.eq(event.Currency, "Cash")
	Check.eq(event.Amount, 250)
	Check.eq(event.Balance, 1250)
	Check.eq(event.Transaction, "Gameplay")
	Check.eq(event.Sku, "Run")
end)

Check.test("an unlogged source is left out", function()
	local event, problem = AnalyticsEvents.source("Admin", "Cash", 1000, 2000, T)
	Check.eq(event, nil)
	Check.eq(problem, nil)
end)

Check.test("an unknown source is a problem, not an event", function()
	local event, problem = AnalyticsEvents.source("Typo", "Cash", 10, 20, T)
	Check.eq(event, nil)
	Check.eq(problem, "UnknownSource")
end)

Check.test("nothing gained is no event", function()
	Check.eq(AnalyticsEvents.source("Run", "Cash", 0, 20, T), nil)
	Check.eq(AnalyticsEvents.source("Run", "Cash", -5, 20, T), nil)
end)

Check.test("a sink names what was bought as the sku", function()
	local event = AnalyticsEvents.sink("Upgrade", "Jets", "Cash", 400, 100, T)
	assert(event, "expected an event")
	Check.eq(event.Flow, "Sink")
	Check.eq(event.Amount, 400)
	Check.eq(event.Balance, 100)
	Check.eq(event.Transaction, "Shop")
	Check.eq(event.Sku, "Upgrade_Jets")
end)

Check.test("a free sink, like equipping, is no event", function()
	Check.eq(AnalyticsEvents.sink("Upgrade", "Jets", "Cash", 0, 100, T), nil)
end)

Check.test("an unknown sink is a problem", function()
	local event, problem = AnalyticsEvents.sink("Nope", "X", "Cash", 5, 0, T)
	Check.eq(event, nil)
	Check.eq(problem, "UnknownSink")
end)

Check.test("onboarding logs steps in order as they are reached", function()
	local state = AnalyticsEvents.newOnboarding()
	local steps = AnalyticsEvents.reach(state, "Joined", T)
	Check.eq(#steps, 1)
	Check.eq(steps[1].Step, 1)
	Check.eq(steps[1].Name, "Joined")
	steps = AnalyticsEvents.reach(state, "CarSpawned", T)
	Check.eq(#steps, 1)
	Check.eq(steps[1].Step, 2)
end)

Check.test("a step reached again logs nothing", function()
	local state = AnalyticsEvents.newOnboarding()
	AnalyticsEvents.reach(state, "Joined", T)
	Check.eq(#AnalyticsEvents.reach(state, "Joined", T), 0)
end)

Check.test("a step reached early waits for the steps before it", function()
	local state = AnalyticsEvents.newOnboarding()
	AnalyticsEvents.reach(state, "Joined", T)
	Check.eq(#AnalyticsEvents.reach(state, "FirstUpgrade", T), 0)
	Check.eq(#AnalyticsEvents.reach(state, "FirstLaunch", T), 0)
	local steps = AnalyticsEvents.reach(state, "CarSpawned", T)
	Check.eq(#steps, 3)
	Check.eq(steps[1].Name, "CarSpawned")
	Check.eq(steps[2].Name, "FirstLaunch")
	Check.eq(steps[3].Step, 4)
	Check.eq(steps[3].Name, "FirstUpgrade")
end)

Check.test("an unknown step logs nothing", function()
	local state = AnalyticsEvents.newOnboarding()
	Check.eq(#AnalyticsEvents.reach(state, "Nope", T), 0)
	Check.eq(#AnalyticsEvents.reach(state, "Joined", T), 1)
end)

Check.test("the budget allows the base rate plus some per player each minute", function()
	local budget = AnalyticsEvents.newBudget(0)
	local allowed = 0
	for _ = 1, 20 do
		if AnalyticsEvents.spend(budget, 30, 2, T) then
			allowed += 1
		end
	end
	Check.eq(allowed, 14)
end)

Check.test("the budget refills after a minute", function()
	local budget = AnalyticsEvents.newBudget(0)
	for _ = 1, 10 do
		AnalyticsEvents.spend(budget, 1, 0, T)
	end
	Check.eq(AnalyticsEvents.spend(budget, 59, 0, T), false)
	Check.eq(AnalyticsEvents.spend(budget, 60, 0, T), true)
end)

Check.test("obby steps start at the start pad and name each cleared stage", function()
	local names = { "Warm Up", "Zigzag" }
	local step, name = AnalyticsEvents.obbyStep(0, names)
	Check.eq(step, 1)
	Check.eq(name, "Start")
	step, name = AnalyticsEvents.obbyStep(2, names)
	Check.eq(step, 3)
	Check.eq(name, "02 Zigzag")
end)

Check.test("obby step for a stage with no name still has its number", function()
	local step, name = AnalyticsEvents.obbyStep(5, {})
	Check.eq(step, 6)
	Check.eq(name, "05")
end)

Check.test("fields fill the custom field keys in order", function()
	local fields = AnalyticsEvents.fields({ "Dino", "<100" })
	Check.eq(fields.CustomField01, "Dino")
	Check.eq(fields.CustomField02, "<100")
	Check.eq(fields.CustomField03, nil)
end)

Check.test("a batch adds up gains by currency and reason, keeping the last balance", function()
	local batch = AnalyticsEvents.newBatch()
	AnalyticsEvents.add(batch, "Bones", "BoneRain", 5, 5)
	AnalyticsEvents.add(batch, "Bones", "BoneRain", 5, 10)
	AnalyticsEvents.add(batch, "Cash", "NearMiss", 50, 1050)
	local gains = AnalyticsEvents.flush(batch)
	Check.eq(#gains, 2)
	table.sort(gains, function(a, b)
		return a.Reason < b.Reason
	end)
	Check.eq(gains[1].Reason, "BoneRain")
	Check.eq(gains[1].Currency, "Bones")
	Check.eq(gains[1].Amount, 10)
	Check.eq(gains[1].Balance, 10)
	Check.eq(gains[2].Reason, "NearMiss")
	Check.eq(gains[2].Amount, 50)
end)

Check.test("a flushed batch starts empty", function()
	local batch = AnalyticsEvents.newBatch()
	AnalyticsEvents.add(batch, "Bones", "BoneRain", 5, 5)
	AnalyticsEvents.flush(batch)
	Check.eq(#AnalyticsEvents.flush(batch), 0)
end)

Check.finish("AnalyticsEvents")
