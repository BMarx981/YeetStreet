--!strict
local Check = require("./Check")
local PlaneMorph = require("../src/shared/PlaneMorph")

Check.test("a plane has nothing folded", function()
	local s = PlaneMorph.stages(0)
	Check.eq(s.fold, 0, "fold")
	Check.eq(s.tip, 0, "tip")
	Check.eq(s.guns, 0, "guns")
	Check.eq(s.wheels, 0, "wheels")
end)

Check.test("a car has everything folded", function()
	local s = PlaneMorph.stages(1)
	Check.eq(s.fold, 1, "fold")
	Check.eq(s.tip, 1, "tip")
	Check.eq(s.guns, 1, "guns")
	Check.eq(s.wheels, 1, "wheels")
end)

Check.test("the wings fold before the plane tips up, and the wheels pop out last", function()
	local early = PlaneMorph.stages(PlaneMorph.Stages.tip[1])
	Check.eq(early.tip, 0, "tip not started")
	Check.eq(early.fold > 0.5, true, "fold well under way")
	local late = PlaneMorph.stages(PlaneMorph.Stages.wheels[1])
	Check.eq(late.fold, 1, "fold done")
	Check.eq(late.wheels, 0, "wheels not started")
end)

Check.test("every stage only moves one way as the plane turns into a car", function()
	local last = PlaneMorph.stages(0)
	for i = 1, 100 do
		local s = PlaneMorph.stages(i / 100)
		for _, name in { "fold", "tip", "guns", "wheels" } do
			local now, before = (s :: any)[name], (last :: any)[name]
			Check.eq(now >= before, true, `{name} at {i / 100}`)
		end
		last = s
	end
end)

Check.test("out-of-range progress is clamped", function()
	Check.eq(PlaneMorph.stages(-0.5).fold, 0, "below")
	Check.eq(PlaneMorph.stages(1.5).wheels, 1, "above")
end)

Check.test("progress moves toward the target at one transform per Duration", function()
	local dt = PlaneMorph.Duration / 4
	Check.near(PlaneMorph.approach(0, 1, dt), 0.25, "toward car")
	Check.near(PlaneMorph.approach(1, 0, dt), 0.75, "toward plane")
end)

Check.test("progress stops at the target", function()
	Check.eq(PlaneMorph.approach(0.9, 1, PlaneMorph.Duration), 1, "car")
	Check.eq(PlaneMorph.approach(0.1, 0, PlaneMorph.Duration), 0, "plane")
	Check.eq(PlaneMorph.approach(1, 1, 0.1), 1, "already there")
end)

Check.finish("PlaneMorph")
