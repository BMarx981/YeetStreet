--!strict
local Check = require("./Check")
local Golden = require("../src/shared/Golden")

local IDS = { "A", "B", "C", "D" }

Check.test("the roll picks evenly across the launchers", function()
	Check.eq(Golden.pick(IDS, nil, 0), "A")
	Check.eq(Golden.pick(IDS, nil, 0.26), "B")
	Check.eq(Golden.pick(IDS, nil, 0.51), "C")
	Check.eq(Golden.pick(IDS, nil, 0.99), "D")
end)

Check.test("the last golden launcher is never picked twice in a row", function()
	for _, roll in { 0, 0.2, 0.4, 0.6, 0.8, 0.99 } do
		local id = Golden.pick(IDS, "B", roll)
		Check.eq(id ~= "B", true, `roll {roll} gave {id}`)
	end
	Check.eq(Golden.pick(IDS, "B", 0), "A")
	Check.eq(Golden.pick(IDS, "B", 0.34), "C")
	Check.eq(Golden.pick(IDS, "B", 0.99), "D")
end)

Check.test("with one launcher it is picked even if it was last", function()
	Check.eq(Golden.pick({ "A" }, "A", 0.5), "A")
end)

Check.test("with no launchers nothing is picked", function()
	Check.eq(Golden.pick({}, nil, 0.5), nil)
end)

Check.test("a launch claims the golden booster only from its launcher, outside Mega Boosters", function()
	Check.eq(Golden.claims("A", "A", false), true)
	Check.eq(Golden.claims("A", "B", false), false)
	Check.eq(Golden.claims("A", nil, false), false)
	Check.eq(Golden.claims(nil, "A", false), false)
	Check.eq(Golden.claims("A", "A", true), false)
end)

Check.finish("Golden")
