--!strict
local Check = require("./Check")
local LaunchRecords = require("../src/shared/LaunchRecords")

local T: LaunchRecords.Tuning = {
	Launchers = {
		{ Id = "MainRamp", Name = "MAIN RAMP", Path = "TestPark.Ramp" },
		{ Id = "SkyRamp", Name = "SKY RAMP", Path = "Parks.LongJump.SkyRamp" },
	},
	Store = "LaunchRecords1",
	StudioStore = "StudioLaunchRecords1",
}

Check.test("each launcher has an all-time key and one per week", function()
	Check.eq(LaunchRecords.key("SkyRamp", nil), "SkyRamp_All", "all time")
	Check.eq(LaunchRecords.key("SkyRamp", 2968), "SkyRamp_W2968", "week")
end)

Check.test("Studio keeps its records in a store of its own", function()
	Check.eq(LaunchRecords.storeName(false, T), "LaunchRecords1", "live")
	Check.eq(LaunchRecords.storeName(true, T), "StudioLaunchRecords1", "Studio")
end)

Check.test("a launcher is found by id", function()
	local sky = LaunchRecords.find("SkyRamp", T)
	assert(sky, "SkyRamp")
	Check.eq(sky.Path, "Parks.LongJump.SkyRamp")
	Check.eq(LaunchRecords.find("Bowl", T), nil, "unknown")
end)

Check.test("distances are whole studs, rounded down", function()
	Check.eq(LaunchRecords.encode(1234.9), 1234)
	Check.eq(LaunchRecords.encode(0.4), 0)
end)

Check.test("a distance beats a record only when farther, and above 0", function()
	local held = { UserId = 1, Name = "Ann", Value = 500 }
	Check.eq(LaunchRecords.beats(nil, 10), true, "no record yet")
	Check.eq(LaunchRecords.beats(nil, 0), false, "zero")
	Check.eq(LaunchRecords.beats(held, 500), false, "tie keeps the holder")
	Check.eq(LaunchRecords.beats(held, 501), true, "farther")
	Check.eq(LaunchRecords.beats(held, 499), false, "shorter")
end)

Check.test("a saved record is read back only when whole", function()
	local good = LaunchRecords.reconcile({ UserId = 7, Name = "Bo", Value = 900 })
	assert(good, "good record")
	Check.eq(good.UserId, 7, "UserId")
	Check.eq(good.Name, "Bo", "Name")
	Check.eq(good.Value, 900, "Value")
	Check.eq(LaunchRecords.reconcile(nil), nil, "nothing saved")
	Check.eq(LaunchRecords.reconcile({ UserId = 7, Value = 900 }), nil, "no name")
	Check.eq(LaunchRecords.reconcile({ UserId = "7", Name = "Bo", Value = 900 }), nil, "string id")
	Check.eq(LaunchRecords.reconcile({ UserId = 7, Name = "Bo", Value = -1 }), nil, "negative")
	Check.eq(LaunchRecords.reconcile({ UserId = 7, Name = "Bo", Value = 0 / 0 }), nil, "NaN")
end)

Check.test("a record shows as studs with commas", function()
	Check.eq(LaunchRecords.show(1234567), "1,234,567 studs")
	Check.eq(LaunchRecords.show(850), "850 studs")
end)

Check.finish("LaunchRecords")
