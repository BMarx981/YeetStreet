--!strict
local Check = require("./Check")
local Purchases = require("../src/shared/Purchases")

Check.test("a new state has seen no receipts", function()
	local s = Purchases.new()
	Check.eq(#s.Receipts, 0)
	Check.eq(Purchases.seen(s, "abc"), false)
end)

Check.test("record remembers a receipt and leaves the old state alone", function()
	local before = Purchases.new()
	local after = Purchases.record(before, "abc", 3)
	Check.eq(Purchases.seen(after, "abc"), true)
	Check.eq(Purchases.seen(before, "abc"), false, "old state")
end)

Check.test("record keeps only the newest receipts", function()
	local s = Purchases.new()
	for _, id in { "a", "b", "c", "d" } do
		s = Purchases.record(s, id, 3)
	end
	Check.eq(#s.Receipts, 3)
	Check.eq(Purchases.seen(s, "a"), false, "oldest dropped")
	Check.eq(Purchases.seen(s, "d"), true, "newest kept")
end)

Check.test("recording a receipt twice keeps one copy", function()
	local s = Purchases.record(Purchases.record(Purchases.new(), "a", 3), "a", 3)
	Check.eq(#s.Receipts, 1)
end)

Check.test("reconcile keeps saved receipt ids and drops junk", function()
	local s = Purchases.reconcile({ Receipts = { "a", 7, "b", "a", "" } })
	Check.eq(table.concat(s.Receipts, ","), "a,b")
	Check.eq(#Purchases.reconcile(nil).Receipts, 0, "old save")
	Check.eq(#Purchases.reconcile({ Receipts = "a" }).Receipts, 0, "not a list")
end)

Check.finish("Purchases")
