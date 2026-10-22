--!strict
local Check = require("./Check")
local Toughness = require("../src/shared/Toughness")

local TUNING: Toughness.Tuning = {
	HitThreshold = 30,
	DamagePerSpeed = 1,
	BreakDamage = 20,
}

Check.test("hits under the threshold do no damage", function()
	Check.eq(Toughness.damage(29, "roof", TUNING), 0)
	Check.eq(Toughness.damage(30, "roof", TUNING), 0)
end)

Check.test("damage is the speed over the threshold", function()
	Check.eq(Toughness.damage(64, "roof", TUNING), 34)
	Check.eq(Toughness.damage(74, "nose", TUNING), 44)
	Check.eq(Toughness.damage(93, "sides", TUNING), 63)
	Check.eq(Toughness.damage(50, "tail", TUNING), 20)
end)

Check.test("landing on the wheels or belly never does damage", function()
	Check.eq(Toughness.damage(200, "underside", TUNING), 0)
end)

Check.test("damage scales with DamagePerSpeed", function()
	local tuning = table.clone(TUNING)
	tuning.DamagePerSpeed = 0.5
	Check.eq(Toughness.damage(70, "nose", tuning), 20)
end)

Check.test("a part breaks for every BreakDamage a slot takes", function()
	Check.eq(Toughness.breaks(0, 19, TUNING), 0, "not enough yet")
	Check.eq(Toughness.breaks(0, 20, TUNING), 1)
	Check.eq(Toughness.breaks(0, 63, TUNING), 3)
end)

Check.test("damage to a slot adds up across hits", function()
	Check.eq(Toughness.breaks(15, 25, TUNING), 1, "two small hits break one part")
	Check.eq(Toughness.breaks(25, 35, TUNING), 0, "the next break needs 40 in total")
	Check.eq(Toughness.breaks(35, 45, TUNING), 1)
end)

Check.test("lava burns all of any car's toughness in the same time", function()
	Check.near(Toughness.burn(60, 1, 3), 20, "a third of it each second")
	Check.near(Toughness.burn(200, 1, 3), 200 / 3, "a tougher car loses more")
	local left = 60
	for _ = 1, 180 do
		left -= Toughness.burn(60, 1 / 60, 3)
	end
	Check.near(left, 0, "gone after 3 seconds of steps", 1e-9)
end)

Check.finish("Toughness")
