--!strict
local Check = require("./Check")
local Rng = require("../src/shared/Rng")

local function sequence(seed: number, count: number): { number }
	local rng = Rng.new(seed)
	local out = {}
	for _ = 1, count do
		table.insert(out, rng.next())
	end
	return out
end

Check.test("the same seed gives the same numbers", function()
	local a = sequence(42, 20)
	local b = sequence(42, 20)
	for i = 1, 20 do
		Check.eq(a[i], b[i], `number {i}`)
	end
end)

Check.test("different seeds give different numbers", function()
	local a = sequence(1, 5)
	local b = sequence(2, 5)
	local same = 0
	for i = 1, 5 do
		if a[i] == b[i] then
			same += 1
		end
	end
	Check.eq(same < 5, true)
end)

Check.test("numbers are in 0 to 1, never 1", function()
	for seed = 0, 30 do
		for _, value in sequence(seed, 50) do
			Check.eq(value >= 0 and value < 1, true, `seed {seed} gave {value}`)
		end
	end
end)

Check.test("seed 0, negative, and huge seeds still work", function()
	for _, seed in { 0, -7, 2 ^ 40, 1.5 } do
		local value = Rng.new(seed).next()
		Check.eq(value >= 0 and value < 1, true, `seed {seed}`)
	end
end)

Check.test("range stays between its ends", function()
	local rng = Rng.new(9)
	for _ = 1, 200 do
		local value = rng.range(2, 5)
		Check.eq(value >= 2 and value <= 5, true)
	end
end)

Check.test("int covers both ends and nothing outside them", function()
	local rng = Rng.new(3)
	local seen: { [number]: boolean } = {}
	for _ = 1, 500 do
		local value = rng.int(5, 8)
		Check.eq(value == math.floor(value) and value >= 5 and value <= 8, true, `got {value}`)
		seen[value] = true
	end
	Check.eq(seen[5] and seen[8], true, "both ends come up")
end)

Check.finish("Rng")
