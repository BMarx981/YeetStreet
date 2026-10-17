--!strict
-- SaveRecord (ModuleScript) -> ReplicatedStorage.SaveRecord
-- The session lock around a player's saved data. Pure, see InputAxes. Used
-- only by PlayerData, inside DataStore UpdateAsync calls.
--
-- A server claims a player's record when they join and holds the lock while
-- they play. Another server can't claim it until the lock is released, goes
-- stale (no write for LockTimeout seconds, so its server is gone), or the
-- claim is forced. A server can only write while it still holds the lock, so
-- one that lost it never overwrites newer data.

local SaveRecord = {}

export type Lock = {
	Session: string, -- the id of the server holding the lock
	Time: number, -- os.time() of its last claim or write
}

export type Record = {
	Data: any,
	Lock: Lock?,
}

local function lockOf(stored: any): Lock?
	if typeof(stored) ~= "table" then
		return nil
	end
	local lock = stored.Lock
	if typeof(lock) == "table" and typeof(lock.Session) == "string" and typeof(lock.Time) == "number" then
		return lock
	end
	return nil
end

-- The record to store for `session` claiming `stored`. Fails with "Locked".
function SaveRecord.claim(
	stored: any,
	session: string,
	now: number,
	lockTimeout: number,
	force: boolean
): (Record?, string?)
	local lock = lockOf(stored)
	if lock and lock.Session ~= session and now - lock.Time <= lockTimeout and not force then
		return nil, "Locked"
	end
	local data = if typeof(stored) == "table" then stored.Data else nil
	return { Data = data, Lock = { Session = session, Time = now } }, nil
end

-- The record to store for `session` writing `data` over `stored`, dropping the
-- lock if `release`. Fails with "NotOurs" if this session no longer holds it.
function SaveRecord.write(stored: any, session: string, now: number, data: any, release: boolean): (Record?, string?)
	local lock = lockOf(stored)
	if not lock or lock.Session ~= session then
		return nil, "NotOurs"
	end
	return { Data = data, Lock = if release then nil else { Session = session, Time = now } }, nil
end

return SaveRecord
