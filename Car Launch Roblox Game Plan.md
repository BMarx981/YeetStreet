# Yeet Street: Plan

Sep 26, 2026 · @Brian

## Pitch and name

Grab a car, hit a launcher, and steer it through the sky with jets while you flip, spin, and smash your way to a high score. No missions, no dying, just the part of open world games everyone actually played.

Name: Yeet Street (final). Other names considered:

| Name | Why it works |
| --- | --- |
| Yeet Street | Short, rhymes, says the whole game |
| Launch Lot | Clear, easy to brand around a parking lot hub |
| Car Yeet Tycoon | Leans into the Roblox tycoon search habit |
| Sky Wreck | Hints at flying and crashing |
| Jet Jalopy | Fits the upgrade path from junker to rocket car |

Before launch, search Roblox for existing games with the same or similar names.

## Pillars

Every feature has to serve at least one of these, and none can break them.

- Launching is the game. Everything else exists to get you to a launcher faster or to make the next launch bigger.
- Flight feels good. Air control is the core skill and gets the most tuning time.
- Nobody oofs. The driver never dies and a wrecked car comes back instantly.
- Crashes are a reward. Big hits look great and pay points instead of punishing you.
- Show off. Every big jump is visible to the server and easy to replay.

## Core loop

Target: one run takes under a minute, so a player can do dozens in a session.

1. Grab a car from the hub or one parked around the map (quick yank animation, no NPC harm shown).
2. Drive to a launcher and build speed.
3. Launch and take over with air control and jets.
4. Rack up points from airtime, tricks, and hits until the car lands, stops, or wrecks.
5. Points convert to cash. Spend it on upgrades or better cars.
6. Respawn at the last launcher or the hub and go again.

## Air control and jets

When all wheels leave the ground, driving controls switch to flight controls. Jets are the upgradeable part.

| Input | On the ground | In the air |
| --- | --- | --- |
| Steer left/right | Turn | Spin (yaw) |
| Gas/brake | Accelerate, brake | Tip nose up or down (pitch) |
| Jet button | Short speed boost | Push in the direction the nose points |
| Roll button (unlock) | None | Barrel roll left or right |

Jet stats that upgrade: jet power, jet fuel, fuel recharge speed, and turn rate. Fuel refills on the ground and from fuel rings in the air.

All controls need touch buttons from day one, placed for thumbs, plus gamepad and keyboard.

## Cars, upgrades, and durability

Cars get slicker, faster, and tougher as you earn points and rebirth. Every car has four stats, each upgradeable with cash:

| Stat | What it does |
| --- | --- |
| Speed | Top speed on the ground, which sets launch distance |
| Jets | Jet power, fuel, and turn rate in the air |
| Toughness | How much impact the car takes before it wrecks |
| Grip | Handling on the ground and on landings |

Each car has a stat cap, so moving to a better car raises the ceiling. Rough car ladder: junker, hatchback, muscle car, sports car, supercar, then rebirth only cars (rocket car, hover car, and so on).

No oof rules:

- The driver is locked in and never takes damage, ragdolls, or dies.
- Impacts drain toughness based on impact speed. Cosmetic parts (bumpers, doors, spoiler) break off for show and score points.
- At zero toughness the car bursts into sparks and respawns fresh at the last launcher. You lose your current combo, nothing else.
- Toughness refills between runs.

## Car generator

Decision: a fixed ladder of hand picked generated cars, with upgrades shown on the car itself and earned cosmetics layered on top. No random car rolls.

Why: it is cheaper to build and balance, keeps leaderboards fair, keeps the focus on launching, and avoids loot box rules. Stat driven parts and cosmetics still make each player's car look like theirs.

### How the ladder is made

The generator is a design tool used in Studio. Brian rolls seeds, keeps the ones he likes, and locks each chosen seed into the ladder config with its tier, stat caps, and price. Players only ever see locked cars.

1. Inputs: seed, tier, the four stat levels, rebirth count.
2. Pick an archetype weighted by tier: hatchback, pickup, muscle, buggy, wedge supercar, hover car.
3. Build the body from 5 to 8 slices nose to tail, each with a height and width sampled from the archetype's ranges, filled with blocks and wedges.
4. The body exposes named slots: nose, tail, roof, sides, underside, and four wheel spots.
5. Fill slots from a hand made part kit based on stat levels.
6. Paint from the tier palette and add cosmetics the player has equipped.
7. Name it from word lists, for example "Rustbucket Mk II".

### Stats show on the car

| Stat | Visible changes as it levels |
| --- | --- |
| Speed | Bigger spoiler, more exhaust pipes, lower stance, hood scoop |
| Jets | More and bigger thrusters, flame color steps up |
| Toughness | Bull bar, armor plates, roll cage |
| Grip | Wider tires, bigger rims, fender flares |

### Tier palettes

| Tier | Look |
| --- | --- |
| Junker | Mismatched panels, corroded metal, dull colors |
| Street | Clean single color, basic trim |
| Sports | Glossy two tone, racing stripes |
| Supercar | Neon trim, bold colors |
| Rebirth | Glowing parts and signature effects per rebirth tier |

### Earned cosmetics

Paint jobs, decals, trail colors, and alternate part styles, unlocked by obby stages, launcher records, and rebirths. Cosmetics never change stats. Cosmetic only variants could be added later if a collecting hook is ever wanted, without touching the ladder.

### Rules

- Visuals never touch physics. Every car drives on the same invisible collision hull, and generated parts have collisions off and no mass. Handling comes only from stats.
- Only the seed, stat levels, and equipped cosmetics replicate. Each client builds the car locally from those.
- Breakable parts come from named slots, so toughness knows what to knock off. Respawn regenerates the car from its seed.

## Scoring and combos

A run's score is the sum of its actions times a combo multiplier that grows as you chain different tricks without touching the ground.

| Action | Scored by |
| --- | --- |
| Airtime | Seconds in the air |
| Distance | Studs from launch point to landing |
| Height | Peak height above launch point |
| Flips and spins | Each full rotation on any axis |
| Ring pass | Flying through a sky ring |
| Smash | Hitting a breakable object or losing a car part |
| Clean landing | Landing on all wheels, bonus multiplier |

Repeating the same trick in a combo pays less each time, so variety wins. Exact point values get tuned during playtesting.

## Map: a small city of stunt parks

The map is a small city built from themed stunt parks around a central hub, each with its own launchers, obstacles, and record signs. The car obby is its own separate zone.

| Park | Signature launchers and obstacles |
| --- | --- |
| Space | Low gravity zone, moon craters, rocket pad launch, satellite rings |
| Beach | Pier ramps, lifeguard towers, sand dunes, surf wave half pipe |
| Dense city | Rooftop gaps, parking garage spiral, billboard smash, highway overpass |
| Skate park | Giant bowls, rails, quarter pipes, vert ramp |
| Woods | Log ramps, tree canopy rings, river jump, cabin smash |
| Mountains | Cliff launches, switchback roads, avalanche nets, long fall to a lake |
| Ski | Ski jump launcher, slalom gates in the air, snow banked turns |
| Suburbs | Cul de sac loops, backyard pools, trampolines, garden gnome smash |

More theme ideas to pick from:

- Desert canyon: mesa gaps, cactus smash, dry riverbed rails
- Volcano: lava lake jump (respawn, no oof), eruption launch pad
- Airport: runway speed strip, jet blast launcher, hangar fly through
- Harbor: shipping container stacks, crane swing, cargo ship deck landing
- Construction site: cranes, girder ramps, wrecking ball
- Junkyard: car crusher, tire stacks, magnet crane grab
- Carnival: loop the loop coaster track, giant slide, ferris wheel rings
- Farm: hay bale ramps, barn fly through, silo rings
- Stadium: race track with banked turns, jumbotron smash
- Ice: frozen lake spins, ice caves, glacier ramps
- Jungle: vine swings, temple ruins, waterfall jump
- Candy land: gumdrop bounce pads, frosting slides
- Seasonal: haunted town in October, snow globe town in December

## Car obby

A sky course of stages you clear by launching and flying, which gives jets a purpose beyond score chasing.

- Obstacles: floating platforms, rings, moving ramps, bounce pads, wind tunnels, spinning bars, narrow landing strips.
- Checkpoint pads save progress. Falling or wrecking respawns you and your car at the last checkpoint.
- Later stages need jet upgrades to clear gaps, which pulls players back to earn and upgrade.
- Each stage cleared pays a one time cash reward. Stage count shows on the player's nameplate.
- The obby is its own zone of the map, separate from the stunt parks. Each rebirth tier can unlock a new obby world with a new theme.

## Progression and rebirth

Cash buys upgrades and cars; rebirth trades all of that for permanent power.

- Rebirth unlocks once a player owns the top car of the current tier.
- Rebirth resets cash, cars, and upgrades.
- Rebirth keeps a permanent point multiplier, obby progress, cosmetics, and best scores.
- Each rebirth tier unlocks rebirth only cars with higher stat caps, plus a trail or effect to show it off.
- Rebirth count shows on the nameplate and the leaderboard.

## Leaderboards and replays

Big jumps should be seen by the whole server, then remembered.

- Everyone sees your car in the air live, with a callout banner for runs over a score threshold.
- After a big run, a short slow motion replay plays for you, and other players can tap to watch it.
- Leaderboards: best single run (server and global), daily longest flight per launcher, highest obby stage, most rebirths.
- Named launchers and jumps become landmarks with their own record holder shown on a sign.

## Technical approach

The client drives and flies the car for smooth feel; the server owns stats, cash, and scores.

- Toolchain: same as MazeCity. Code in VS Code, with Rojo syncing files into Studio so all code lives in git and changes review as diffs. Luau with strict type checking. StyLua for formatting and Selene for linting are proposed.
- Car physics: constraint based chassis. The server gives the driver's client network ownership of the car while they drive.
- Air control: the client detects airborne state with raycasts under the wheels, then applies torque and jet force with constraint movers. Jet power and fuel values come from server data, not the client.
- Anti cheat: the client reports tricks, the server sanity checks them against the car's replicated position and velocity (max speed, max height, plausible airtime) before paying out.
- Toughness: impact strength measured from the drop in velocity between physics steps, since Touched events alone do not report impact force. Cosmetic parts detach by breaking their welds.
- Saves: DataStoreService for player data with session locking. OrderedDataStore for global leaderboards.
- Replays: record the car's CFrame at a fixed rate during a run, then play it back on a local clone.
- Tests: pure logic modules (scoring, combo decay, upgrade costs, rebirth math) get unit tests. Flight feel gets tuned by playtesting.

## Milestones

Nothing past M0 starts until flight feels fun with one car and one ramp.

| Milestone | Scope | Done when |
| --- | --- | --- |
| M0 Feel | One car, one ramp, air control, jets, touch controls | Launching and flying is fun for 10 minutes with no goals |
| M1 Score | Scoring, combos, toughness, wreck and respawn | A run ends with a score and nobody ever oofs |
| M2 Economy | Cash, four upgrade stats, car generator v1, first three ladder cars, saves | Progress survives rejoining |
| M3 World | Hub, 5 to 8 launchers, parked cars to grab | A new player finds a launcher within 30 seconds |
| M4 Obby | Obby world 1 with checkpoints | 20 stages clearable with mid tier jets |
| M5 Social | Leaderboards, replays, launcher record signs | Other players can watch your best run |
| M6 Rebirth | Rebirth flow, rebirth cars, obby world 2 | A full rebirth cycle works end to end |
| M7 Launch | Polish, icon, thumbnails, mobile testing | Public release |

## Decisions

- The game is called Yeet Street.
- The in game upgrade is called Jets.
- The map is a small city of themed stunt parks.
- Same toolchain as MazeCity: VS Code plus Rojo.
- The car obby is its own separate zone.
- Cars follow a fixed ladder with stat driven visuals and earned cosmetics.

## Open questions

- [ ] Which stunt parks ship at launch, and in what order the rest arrive
- [ ] Monetization: game passes (2x cash, extra jet fuel), cosmetic car skins, or none at launch
