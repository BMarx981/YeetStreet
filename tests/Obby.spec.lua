--!strict
local Check = require("./Check")
local Obby = require("../src/shared/Obby")

local T: Obby.Tuning = {
	Stages = 4,
	StageCash = 100,
	StageCashStep = 10,
	WorldPrize = 1000,
	DesignJets = 20,
}

local function visit(reached: number, current: number): Obby.Visit
	return { Reached = reached, Current = current }
end

Check.test("a new visit starts at the start pad", function()
	local v = Obby.newVisit()
	Check.eq(v.Reached, 0)
	Check.eq(v.Current, 0)
end)

Check.test("stage cash rises with the stage", function()
	Check.eq(Obby.stageCash(1, T), 100)
	Check.eq(Obby.stageCash(2, T), 110)
	Check.eq(Obby.stageCash(4, T), 130)
end)

Check.test("touching the next checkpoint clears that stage and pays it", function()
	local v, cash = Obby.touch(Obby.newVisit(), 1, T)
	Check.eq(v.Reached, 1)
	Check.eq(v.Current, 1)
	Check.eq(cash, 100)
end)

Check.test("touching doesn't change the visit it was given", function()
	local before = Obby.newVisit()
	Obby.touch(before, 1, T)
	Check.eq(before.Reached, 0)
	Check.eq(before.Current, 0)
end)

Check.test("a checkpoint past the next one is ignored, so stages can't be skipped", function()
	local v, cash = Obby.touch(visit(1, 1), 3, T)
	Check.eq(v.Reached, 1)
	Check.eq(v.Current, 1)
	Check.eq(cash, 0)
end)

Check.test("touching a cleared checkpoint again pays nothing", function()
	local v, cash = Obby.touch(visit(2, 2), 2, T)
	Check.eq(v.Reached, 2)
	Check.eq(cash, 0)
end)

Check.test("touching an earlier checkpoint doesn't move the respawn back", function()
	local v = Obby.touch(visit(3, 3), 1, T)
	Check.eq(v.Current, 3)
end)

Check.test("after picking an earlier stage, cleared checkpoints move the respawn forward for free", function()
	local v, cash = Obby.touch(visit(3, 1), 2, T)
	Check.eq(v.Reached, 3)
	Check.eq(v.Current, 2)
	Check.eq(cash, 0)
end)

Check.test("after picking an earlier stage, the next new checkpoint still pays", function()
	local v, cash = Obby.touch(visit(2, 2), 3, T)
	Check.eq(v.Reached, 3)
	Check.eq(cash, 120)
end)

Check.test("checkpoints outside the world are ignored", function()
	for _, n in { 0, -1, 5, 1.5 } do
		local v, cash = Obby.touch(visit(4, 4), n, T)
		Check.eq(v.Reached, 4)
		Check.eq(v.Current, 4)
		Check.eq(cash, 0)
	end
	local v, cash = Obby.touch(Obby.newVisit(), 0.5, T)
	Check.eq(v.Reached, 0)
	Check.eq(cash, 0)
end)

Check.test("any reached checkpoint can be picked as the respawn", function()
	local v = Obby.select(visit(3, 3), 1)
	Check.eq(v and v.Current, 1)
	Check.eq(v and v.Reached, 3)
	local start = Obby.select(visit(3, 3), 0)
	Check.eq(start and start.Current, 0)
end)

Check.test("a checkpoint not reached yet can't be picked", function()
	Check.eq(Obby.select(visit(2, 2), 3), nil)
	Check.eq(Obby.select(visit(2, 2), -1), nil)
	Check.eq(Obby.select(visit(2, 2), 1.5), nil)
end)

Check.test("the world is finished once the last checkpoint is reached", function()
	Check.eq(Obby.finished(visit(3, 3), T), false)
	Check.eq(Obby.finished(visit(4, 1), T), true)
end)

Check.test("a full clear pays every stage once", function()
	local v = Obby.newVisit()
	local total = 0
	for n = 1, T.Stages do
		local cash
		v, cash = Obby.touch(v, n, T)
		total += cash
	end
	Check.eq(total, 100 + 110 + 120 + 130)
	Check.eq(Obby.finished(v, T), true)
end)

Check.finish("Obby")
