--!strict
local Check = require("./Check")
local RotorMorph = require("../src/shared/RotorMorph")

Check.test("folded, nothing is out", function()
	local s = RotorMorph.stages(0)
	Check.eq(s.rise, 0, "rise")
	Check.eq(s.unfold, 0, "unfold")
	Check.eq(s.spin, 0, "spin")
end)

Check.test("open, everything is out", function()
	local s = RotorMorph.stages(1)
	Check.eq(s.rise, 1, "rise")
	Check.eq(s.unfold, 1, "unfold")
	Check.eq(s.spin, 1, "spin")
end)

Check.test("it only spins once the blades are fully out", function()
	local s = RotorMorph.stages(RotorMorph.Stages.spin[1])
	Check.eq(s.unfold, 1, "unfolded")
	Check.eq(s.spin, 0, "not spinning yet")
end)

Check.test("progress moves toward the target and stops there", function()
	local dt = RotorMorph.Duration / 4
	Check.near(RotorMorph.approach(0, 1, dt), 0.25, "opening")
	Check.near(RotorMorph.approach(1, 0, dt), 0.75, "closing")
	Check.eq(RotorMorph.approach(0.9, 1, RotorMorph.Duration), 1, "open")
	Check.eq(RotorMorph.approach(0.1, 0, RotorMorph.Duration), 0, "closed")
end)

Check.test("folded, the blades lie in pairs either side of the tail fin", function()
	for i = 1, RotorMorph.Blades do
		local side = if i <= 2 then 1 else -1
		Check.near(RotorMorph.bladeAngle(i, 0, 2), side * RotorMorph.FoldAngle, `blade {i}`)
	end
end)

Check.test("open, the blades are evenly spaced and turn with the spin", function()
	local quarter = math.pi / 2
	Check.near(RotorMorph.bladeAngle(1, 1, 0), 0, "1")
	Check.near(RotorMorph.bladeAngle(2, 1, 0), quarter, "2")
	Check.near(RotorMorph.bladeAngle(3, 1, 0), -2 * quarter, "3")
	Check.near(RotorMorph.bladeAngle(4, 1, 0), -quarter, "4")
	Check.near(RotorMorph.bladeAngle(1, 1, 0.5), 0.5, "spun")
end)

Check.test("spin wraps so the blades fold back the short way", function()
	Check.near(RotorMorph.wrap(0.5), 0.5, "small")
	Check.near(RotorMorph.wrap(2 * math.pi + 0.5), 0.5, "past a turn")
	Check.near(RotorMorph.wrap(2 * math.pi - 0.5), -0.5, "just short of a turn")
end)

Check.finish("RotorMorph")
