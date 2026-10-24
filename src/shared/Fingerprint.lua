--!strict
-- Fingerprint (ModuleScript) -> ReplicatedStorage.Fingerprint
-- A short fingerprint of a tuning table, the same for the same numbers
-- whatever order its keys were written in. A park saved with the place
-- (frozen) keeps the fingerprint of the tuning it was built from, so
-- ParkService can warn when that tuning has changed since and the saved
-- parts no longer match it. Pure, see InputAxes.

local Fingerprint = {}

-- Every value as text, tables with their keys in order, each piece marked
-- off so a key and a value can never run together. Keys whose dotted path
-- from the top is in `skip` are left out.
local function write(value: any, path: string, skip: { [string]: boolean }, out: { string })
	if type(value) == "table" then
		local keys = {}
		for key in value do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		table.insert(out, "{")
		for _, key in keys do
			local inner = if path == "" then tostring(key) else `{path}.{tostring(key)}`
			if not skip[inner] then
				table.insert(out, `{tostring(key)}=`)
				write(value[key], inner, skip, out)
				table.insert(out, ";")
			end
		end
		table.insert(out, "}")
	else
		table.insert(out, `{typeof(value)}:{tostring(value)}`)
	end
end

-- Eight hex digits from `tuning`, leaving out the keys at the dotted paths
-- in `skip` (numbers only used while the game runs, such as a creature's).
function Fingerprint.of(tuning: { [any]: any }, skip: { string }?): string
	local skipped: { [string]: boolean } = {}
	for _, path in skip or {} do
		skipped[path] = true
	end
	local out: { string } = {}
	write(tuning, "", skipped, out)
	return Fingerprint.hash(table.concat(out))
end

-- FNV-1a of `text`, 32 bits, as eight hex digits. Its prime is 2^24 + 403,
-- multiplied in two parts so no step goes past what a number holds exactly.
function Fingerprint.hash(text: string): string
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = (bit32.lshift(hash, 24) + hash * 403) % 4294967296
	end
	return string.format("%08x", hash)
end

return Fingerprint
