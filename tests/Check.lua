--!strict
-- Minimal test harness for the luau CLI. A spec calls Check.test for each case
-- and Check.finish at the end, which errors (exit code 1) if anything failed.

local Check = {}

local passed = 0
local failed = 0

function Check.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print(`  FAIL {name}\n       {err}`)
	end
end

function Check.eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function Check.near(actual: number, expected: number, label: string?, tolerance: number?)
	local tol = tolerance or 1e-6
	if math.abs(actual - expected) > tol then
		error(`{label or "value"}: expected {expected} (within {tol}), got {actual}`, 2)
	end
end

function Check.finish(suite: string)
	print(`{suite}: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{suite} had {failed} failing test(s)`, 0)
	end
end

return Check
