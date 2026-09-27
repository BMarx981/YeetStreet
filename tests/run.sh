#!/bin/sh
# Runs every tests/*.spec.lua under the luau CLI, outside Roblox. Only pure
# modules from src/shared are tested here; flight feel is tuned by playtesting.
#
# Usage: tests/run.sh
# Requires the luau CLI pinned in rokit.toml (`rokit install`).

here=$(dirname "$0")

luau=$(command -v luau || echo "$HOME/.rokit/tool-storage/luau-lang/luau/0.732.0/luau")
if ! "$luau" --help >/dev/null 2>&1; then
	echo "luau not found; run 'rokit install' in the repo root" >&2
	exit 1
fi

status=0
for spec in "$here"/*.spec.lua; do
	"$luau" "$spec" || status=1
done
exit $status
