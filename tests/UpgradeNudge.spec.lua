--!strict
local Check = require("./Check")
local UpgradeNudge = require("../src/shared/UpgradeNudge")

local TUNING = { MaxShows = 3, Text = "You have {cash}! Buy an upgrade at the GARAGE." }

local function input(): UpgradeNudge.Input
	return { paid = 440, cash = 440, cheapest = 300, levels = { 0, 0, 0, 0, 0 }, rebirths = 0, shown = 0 }
end

Check.test("due after a paid run that leaves a new player able to afford an upgrade", function()
	Check.eq(UpgradeNudge.due(input(), TUNING), true)
end)

Check.test("not after a run that paid nothing", function()
	local i = input()
	i.paid = 0
	Check.eq(UpgradeNudge.due(i, TUNING), false)
end)

Check.test("not while the cheapest upgrade costs more than the player has", function()
	local i = input()
	i.cash = 299
	Check.eq(UpgradeNudge.due(i, TUNING), false)
	i.cash = 300
	Check.eq(UpgradeNudge.due(i, TUNING), true, "exactly enough")
end)

Check.test("not once the player has bought any upgrade", function()
	local i = input()
	i.levels = { 0, 0, 1, 0, 0 }
	Check.eq(UpgradeNudge.due(i, TUNING), false)
end)

Check.test("not after a rebirth, which resets levels but not know-how", function()
	local i = input()
	i.rebirths = 1
	Check.eq(UpgradeNudge.due(i, TUNING), false)
end)

Check.test("stops after MaxShows in a session", function()
	local i = input()
	i.shown = 2
	Check.eq(UpgradeNudge.due(i, TUNING), true, "third")
	i.shown = 3
	Check.eq(UpgradeNudge.due(i, TUNING), false, "fourth")
end)

Check.test("the line names the player's cash with commas", function()
	Check.eq(UpgradeNudge.text(1240, TUNING), "You have $1,240! Buy an upgrade at the GARAGE.")
	Check.eq(UpgradeNudge.text(440, TUNING), "You have $440! Buy an upgrade at the GARAGE.")
	Check.eq(UpgradeNudge.text(1234567, TUNING), "You have $1,234,567! Buy an upgrade at the GARAGE.")
end)

Check.finish("UpgradeNudge")
