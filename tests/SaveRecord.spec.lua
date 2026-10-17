--!strict
local Check = require("./Check")
local SaveRecord = require("../src/shared/SaveRecord")

local TIMEOUT = 300

local function lockedBy(session: string, time: number): SaveRecord.Record
	return { Data = { Best = 7 }, Lock = { Session = session, Time = time } }
end

Check.test("a player with no record gets an empty one locked to this server", function()
	local record = SaveRecord.claim(nil, "A", 1000, TIMEOUT, false)
	assert(record)
	Check.eq(record.Data, nil, "no data yet")
	assert(record.Lock)
	Check.eq(record.Lock.Session, "A")
	Check.eq(record.Lock.Time, 1000)
end)

Check.test("an unlocked record is claimed with its data", function()
	local record = SaveRecord.claim({ Data = { Best = 7 } }, "A", 1000, TIMEOUT, false)
	assert(record and record.Lock)
	Check.eq(record.Data.Best, 7)
	Check.eq(record.Lock.Session, "A")
end)

Check.test("a record locked by another server is refused until the lock goes stale", function()
	local record, reason = SaveRecord.claim(lockedBy("B", 1000), "A", 1000 + TIMEOUT, TIMEOUT, false)
	Check.eq(record, nil)
	Check.eq(reason, "Locked")
	local stale = SaveRecord.claim(lockedBy("B", 1000), "A", 1001 + TIMEOUT, TIMEOUT, false)
	assert(stale and stale.Lock)
	Check.eq(stale.Lock.Session, "A")
	Check.eq(stale.Data.Best, 7, "keeps the data")
end)

Check.test("a forced claim takes a fresh lock", function()
	local record = SaveRecord.claim(lockedBy("B", 1000), "A", 1001, TIMEOUT, true)
	assert(record and record.Lock)
	Check.eq(record.Lock.Session, "A")
end)

Check.test("this server's own lock can be claimed again", function()
	local record = SaveRecord.claim(lockedBy("A", 1000), "A", 1001, TIMEOUT, false)
	assert(record and record.Lock)
	Check.eq(record.Lock.Time, 1001)
end)

Check.test("a record that isn't a table is treated as empty", function()
	local record = SaveRecord.claim("junk", "A", 1000, TIMEOUT, false)
	assert(record)
	Check.eq(record.Data, nil)
end)

Check.test("a write stores the data and refreshes the lock", function()
	local record, reason = SaveRecord.write(lockedBy("A", 1000), "A", 1060, { Best = 9 }, false)
	assert(record and record.Lock, reason)
	Check.eq(record.Data.Best, 9)
	Check.eq(record.Lock.Time, 1060)
end)

Check.test("a release writes the data and drops the lock", function()
	local record = SaveRecord.write(lockedBy("A", 1000), "A", 1060, { Best = 9 }, true)
	assert(record)
	Check.eq(record.Data.Best, 9)
	Check.eq(record.Lock, nil)
end)

Check.test("a server that lost its lock can't write", function()
	local stolen, reason = SaveRecord.write(lockedBy("B", 1000), "A", 1060, { Best = 1 }, false)
	Check.eq(stolen, nil)
	Check.eq(reason, "NotOurs")
	local released = SaveRecord.write({ Data = { Best = 7 } }, "A", 1060, { Best = 1 }, false)
	Check.eq(released, nil, "unlocked")
	local missing = SaveRecord.write(nil, "A", 1060, { Best = 1 }, false)
	Check.eq(missing, nil, "no record")
end)

Check.finish("SaveRecord")
