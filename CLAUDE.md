# CLAUDE.md

## Project

Yeet Street (working name), a Roblox game by Hawkstreak Studio. Players grab a car, hit a launcher, and steer it through the air with jets to score points from airtime, tricks, and crashes. Points buy upgrades and better cars. Rebirth trades progress for permanent multipliers and stronger cars. There is also a car obby.

The full design plan lives in the "Car Launch Roblox Game: Plan" doc. When this file and the plan disagree, ask Brian.

## Pillars

Every change must respect these:

1. Launching is the game. Everything else supports getting to the next launch.
2. Flight feels good. Air control is the core skill.
3. Nobody oofs. The driver never dies, ragdolls, or takes damage. A wrecked car respawns instantly.
4. Crashes are a reward. Big hits score points and never punish beyond losing the current combo.
5. Show off. Big jumps are visible to the server and replayable.

## Stack

- Same toolchain as MazeCity: code in VS Code, with Rojo syncing the file tree into Roblox Studio. All code lives in this repo.
- Luau with `--!strict` at the top of every script and module.
- StyLua for formatting and Selene for linting (proposed, confirm before relying on them).
- Unit tests for pure logic modules. Runner to be decided.

## Layout

```
default.project.json   Rojo project file
src/
  server/              Server scripts: data, scoring validation, payouts, leaderboards
  client/              Client scripts: driving, air control, input, camera, UI, replays
  shared/              Modules used by both: config, types, pure logic
tests/                 Unit tests for shared logic
```

Keep game logic that can be pure (scoring, combo decay, upgrade costs, rebirth math, stat caps) in `src/shared` with no Roblox service calls, so it can be tested outside Studio.

## Architecture rules

- The client owns feel: driving, air control, jet force, camera. The driver's client gets network ownership of their car.
- The server owns truth: cash, stats, upgrades, cars owned, rebirths, scores, and leaderboards.
- Never trust a value the client sends about money, stats, or score. The server scores each run itself from the car's replicated motion, using the same shared RunTracker the client runs for its HUD. The server's score is the one that counts.
- Jet power, fuel, turn rate, and toughness are read from server data and replicated. The client never decides its own stats.
- Tuning numbers (point values, costs, stat caps, thresholds) live in config modules in `src/shared`, not scattered in scripts.
- Player data saves through one data module with session locking. No other code calls DataStoreService directly.

## Car generator rules

- Cars come from a fixed ladder. The generator is a design tool: chosen seeds are locked into the ladder config with tier, stat caps, and price. No random car rolls for players.
- Generation must be deterministic from the seed, stat levels, and equipped cosmetics. Same inputs, same car, on every client.
- Only seed, stat levels, and equipped cosmetics replicate. Each client builds the car locally.
- Visuals never touch physics. Every car uses the same invisible collision hull; generated parts are cosmetic, with collisions off and no mass. Handling comes only from stats.
- Stat levels drive visible parts through named slots (nose, tail, roof, sides, underside, wheels). Toughness breaks parts by slot, and respawn regenerates from the seed.
- Cosmetics never change stats.

## Map rules

- The map is a small city of themed stunt parks around a central hub. Each park owns its launchers, obstacles, and record signs.
- The car obby is its own zone, separate from the stunt parks.
- Keep each park's content in its own folder so parks can be added or changed independently.
- The air control upgrade is called Jets everywhere: code, UI, and data keys.

## Working with Brian

- Brian commits. Never run `git commit`, `git merge`, or `git push`. You may create branches and stage changes.
- Brian reviews through diffs. Prefer small, focused changes over large rewrites, and do not reformat code you are not otherwise changing.
- Test first for logic: write or update the failing test, then the code.
- Flight feel and physics tuning cannot be unit tested. Say what to playtest and what values to try.
- Do not write suggestion comments in code. Put suggestions in your reply instead.
- Plain language in replies. No em dashes.
- When unsure whether something is true about the Roblox API, say so and suggest how to check, rather than guessing.

## Current milestone

M1 Score: scoring, combos, toughness, wreck and respawn. Done when a run ends with a score and nobody ever oofs. Runs start only from launch pads. Sky rings and smash props wait for the first real park.
