--!strict
local Check = require("./Check")
local Fingerprint = require("../src/shared/Fingerprint")

Check.test("the same numbers give the same fingerprint, whatever order the keys were written in", function()
	local a = { Width = 10, Lot = { Size = 160, Gap = 50 }, Seed = 7 }
	local b = { Seed = 7, Lot = { Gap = 50, Size = 160 }, Width = 10 }
	Check.eq(Fingerprint.of(a), Fingerprint.of(b))
end)

Check.test("changing any number changes it", function()
	local a = { Width = 10, Lot = { Size = 160, Gap = 50 }, List = { 1, 2, 3 } }
	local b = { Width = 10, Lot = { Size = 160, Gap = 51 }, List = { 1, 2, 3 } }
	local c = { Width = 10, Lot = { Size = 160, Gap = 50 }, List = { 1, 3, 2 } }
	Check.eq(Fingerprint.of(a) ~= Fingerprint.of(b), true, "nested number")
	Check.eq(Fingerprint.of(a) ~= Fingerprint.of(c), true, "list order")
end)

Check.test("skipped top-level keys never change it", function()
	local a = { Width = 10, Kaiju = { Speed = 60 } }
	local b = { Width = 10, Kaiju = { Speed = 80 } }
	Check.eq(Fingerprint.of(a, { "Kaiju" }), Fingerprint.of(b, { "Kaiju" }))
	Check.eq(Fingerprint.of(a) ~= Fingerprint.of(b), true, "but counted when not skipped")
end)

Check.test("a skipped dotted path leaves out just that nested table", function()
	local a = { Cranes = { Mast = 60, Ball = { Period = 3 } } }
	local b = { Cranes = { Mast = 60, Ball = { Period = 4 } } }
	local c = { Cranes = { Mast = 70, Ball = { Period = 3 } } }
	Check.eq(Fingerprint.of(a, { "Cranes.Ball" }), Fingerprint.of(b, { "Cranes.Ball" }))
	Check.eq(Fingerprint.of(a, { "Cranes.Ball" }) ~= Fingerprint.of(c, { "Cranes.Ball" }), true, "the rest counts")
end)

Check.test("a key and a value never run together", function()
	Check.eq(Fingerprint.of({ ab = "c" }) ~= Fingerprint.of({ a = "bc" }), true)
end)

Check.test("it is eight hex digits", function()
	local print = Fingerprint.of({ x = 1 })
	Check.eq(#print, 8)
	Check.eq(string.match(print, "^%x+$") ~= nil, true)
end)

Check.test("it matches FNV-1a on a known text", function()
	Check.eq(Fingerprint.hash("a"), "e40c292c")
	Check.eq(Fingerprint.hash("foobar"), "bf9cf968")
end)

Check.test("a big table hashes without trouble", function()
	local big = {}
	for i = 1, 20000 do
		big[i] = i * 0.5
	end
	Check.eq(#Fingerprint.of({ Big = big }), 8)
end)

Check.finish("Fingerprint")
