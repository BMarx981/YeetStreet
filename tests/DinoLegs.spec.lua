--!strict
local Check = require("./Check")
local DinoLegs = require("../src/shared/DinoLegs")

local L = DinoLegs

local function run(speed: number, airborne: boolean, seconds: number): DinoLegs.Moves
	local moves = L.newMoves()
	for _ = 1, math.floor(seconds * 60) do
		L.step(moves, speed, airborne, 1 / 60)
	end
	return moves
end

Check.test("only leg pieces are legs", function()
	for _, name in { "leftleg", "rightleg", "frontleftleg", "backrightleg" } do
		Check.eq(L.isLeg(name), true, name)
	end
	for _, name in { "head", "body", "tail", "leftarm", "Claw", "Horn" } do
		Check.eq(L.isLeg(name), false, name)
	end
end)

Check.test("two legs step in turn", function()
	local moves = run(30, false, 1)
	Check.near(L.angle(moves, "leftleg"), -L.angle(moves, "rightleg"))
end)

Check.test("four legs step in diagonal pairs", function()
	local moves = run(30, false, 1)
	Check.near(L.angle(moves, "frontleftleg"), L.angle(moves, "backrightleg"), "one pair")
	Check.near(L.angle(moves, "frontrightleg"), L.angle(moves, "backleftleg"), "other pair")
	Check.near(L.angle(moves, "frontleftleg"), -L.angle(moves, "frontrightleg"), "pairs opposite")
end)

Check.test("legs stay still while the dino is stopped", function()
	local moves = run(0, false, 2)
	Check.near(L.angle(moves, "leftleg"), 0)
end)

Check.test("legs swing further with speed, up to their limit", function()
	Check.eq(L.reach(L.Gait.FullAt / 2) < L.reach(L.Gait.FullAt), true, "bigger with speed")
	Check.near(L.reach(L.Gait.FullAt), math.rad(L.Gait.Degrees), "full swing")
	Check.near(L.reach(L.Gait.FullAt * 10), math.rad(L.Gait.Degrees), "stops growing")
	local most = math.rad(L.Gait.Degrees) + 1e-6
	local moves = L.newMoves()
	for _ = 1, 600 do
		L.step(moves, 160, false, 1 / 60)
		Check.eq(math.abs(L.angle(moves, "leftleg")) <= most, true, "within the limit")
	end
end)

Check.test("steps get quicker with speed, up to a limit", function()
	Check.eq(L.rate(10) < L.rate(30), true, "quicker")
	Check.near(L.rate(1000), L.Gait.MostRate, "capped")
	Check.near(L.rate(-30), -L.rate(30), "backward when reversing")
end)

Check.test("legs settle back in the air", function()
	local moves = run(30, false, 1)
	for _ = 1, 180 do
		L.step(moves, 30, true, 1 / 60)
	end
	Check.eq(math.abs(L.angle(moves, "leftleg")) < 0.01, true)
end)

Check.test("legs pick up smoothly instead of jumping", function()
	local moves = L.newMoves()
	L.step(moves, 160, false, 1 / 60)
	Check.eq(moves.size < L.reach(160) / 2, true)
end)

Check.finish("DinoLegs")
