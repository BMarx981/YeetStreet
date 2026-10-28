--!strict
-- ReplayLog (ModuleScript) -> ReplicatedStorage.ReplayLog
-- Records how values change over time, by key, so a replay can show them as
-- they were: a creature's attributes, like the kaiju's Mode or HeldCar. Pure,
-- see InputAxes.
--
-- note adds a change when a key's value differs from its last, and at reads
-- a key's value at any time. trim forgets old changes but keeps each key's
-- value from then on, and cut copies a stretch with times counted from a
-- zero, the way ReplayTape cuts a clip. passed lists the changes the time
-- went past going forward, for things that happen at a moment, like a shot,
-- and last the last change by a time and what it changed from.

local ReplayLog = {}

export type Change = {
	t: number,
	value: any,
}

-- Each key's changes, in time order.
export type Log = { [string]: { Change } }

function ReplayLog.new(): Log
	return {}
end

-- Notes that `key` is `value` from time `t` on, if that is a change.
function ReplayLog.note(log: Log, t: number, key: string, value: any)
	local changes = log[key]
	if not changes then
		changes = {}
		log[key] = changes
	end
	local last = changes[#changes]
	if last and last.value == value then
		return
	end
	table.insert(changes, { t = t, value = value })
end

-- The index of the last change at or before `t`, or 0 if none.
local function lastAt(changes: { Change }, t: number): number
	local lo, hi = 1, #changes
	local found = 0
	while lo <= hi do
		local mid = (lo + hi) // 2
		if changes[mid].t <= t then
			found = mid
			lo = mid + 1
		else
			hi = mid - 1
		end
	end
	return found
end

-- The value of `key` at time `t`, nil if it was never noted by then.
function ReplayLog.at(log: Log, key: string, t: number): any
	local changes = log[key]
	if not changes then
		return nil
	end
	local i = lastAt(changes, t)
	return if i > 0 then changes[i].value else nil
end

-- The last change to `key` at or before `t`, and the value before it, nil
-- if it is the first. Nil if there is none.
function ReplayLog.last(log: Log, key: string, t: number): (Change?, any)
	local changes = log[key]
	if not changes then
		return nil, nil
	end
	local i = lastAt(changes, t)
	if i == 0 then
		return nil, nil
	end
	return changes[i], if i > 1 then changes[i - 1].value else nil
end

-- Forgets the changes before `before`, keeping each key's value at it.
function ReplayLog.trim(log: Log, before: number)
	for _, changes in log do
		local i = lastAt(changes, before)
		if i > 1 then
			table.move(changes, i, #changes, 1)
			for k = #changes, #changes - i + 2, -1 do
				changes[k] = nil
			end
		end
	end
end

-- A copy of the stretch from `from` to `to`, with times counted from
-- `zero`: each key's value at `from`, then its changes after it.
function ReplayLog.cut(log: Log, from: number, to: number, zero: number): Log
	local cut: Log = {}
	for key, changes in log do
		local copy: { Change } = {}
		local i = lastAt(changes, from)
		if i > 0 then
			table.insert(copy, { t = from - zero, value = changes[i].value })
		end
		for k = i + 1, #changes do
			local change = changes[k]
			if change.t > to then
				break
			end
			table.insert(copy, { t = change.t - zero, value = change.value })
		end
		if #copy > 0 then
			cut[key] = copy
		end
	end
	return cut
end

-- The changes to `key` after `from` and up to `to`, in order; none when the
-- time went backward.
function ReplayLog.passed(log: Log, key: string, from: number, to: number): { Change }
	local changes = log[key]
	local list: { Change } = {}
	if not changes or to <= from then
		return list
	end
	for k = lastAt(changes, from) + 1, lastAt(changes, to) do
		table.insert(list, changes[k])
	end
	return list
end

return ReplayLog
