# Yeet Street: Plan

Sep 26, 2026 · @Brian · Updated Nov 15, 2026

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

Cars get slicker, faster, and tougher as you earn points and rebirth. Every car has five stats, each upgradeable with cash:

| Stat | What it does |
| --- | --- |
| Speed | Top speed on the ground, which sets launch distance |
| Jets | Jet power, fuel, and turn rate in the air |
| Toughness | How much impact the car takes before it wrecks |
| Grip | Handling on the ground and on landings |
| Brakes | Stopping power, shown as calipers, discs, and brake lights (added Oct 2026) |

Each car has a stat cap, so moving to a better car raises the ceiling. Rough car ladder: junker, hatchback, muscle car, sports car, supercar, then rebirth only cars (rocket car, hover car, and so on).

The ladder as built (Nov 2026):

| Car | How you get it | Top caps |
| --- | --- | --- |
| Junker | Free | 10 |
| Hatchback | 15,000 | 20 |
| Muscle Car | 75,000, plus 16 bodies at 10,000 each | 30 |
| Speed Car | 100,000 | 40 |
| Axolotl Throttle | 125,000, or free for clearing obby world 1 | 36 |
| Squad hover car | Invite reward (10 friends) | 34 |
| Five dino cars | Dino Mystery Box in the Bone Shop | 34 to 50 |
| Frog Car | Limited (son's admin car) | |
| PlaneCar, HeliCar | Admin only for now; PlaneCar planned at 1,000,000 or a game pass | |

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
2. Pick an archetype weighted by tier: hatchback, pickup, muscle, buggy, wedge supercar, hover car, jeep, school bus. The school bus is a short, tall cartoon bus that fits the shared hull, and it is school bus yellow on every tier. Jeeps are open or hard top by seed.
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

Paint jobs, decals, trail colors, and alternate part styles, unlocked by obby stages, launcher records, and rebirths. Cosmetics never change stats. Body styles (below) are the collecting hook, added without touching the ladder.

### Body collection

Decision (2026-10-17): generated seeds become collectible body styles. Brian liked nearly every seed in the gallery and wants them in the game for players to earn or buy.

- A body is a seed. It changes only the look. The ladder car still sets stats, caps, and price.
- A ladder car can wear any body from its own tier, of any type. The Muscle Car can wear any Sports body: muscle, wedge, hover, and so on. A hover body hides the wheels on screen only; the physics wheels stay.
- Each ladder car comes with its locked seed as its default body.
- Players get bodies three ways: earned by playing (launcher records, big crashes, obby stages, rebirths), bought with cash in the garage, and some sold for Robux.
- The catalog is a fixed list of chosen seeds per tier and type, which can grow over time.
- The equipped body replicates as the seed, like any other equipped cosmetic.
- Once players own bodies, changes to the generator reshape cars they own. Finish tuning the looks before release; after release, generator changes must keep existing bodies looking the same.
- Timing: after M2. M2 still ends with three ladder cars.

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

Built so far (Nov 2026), all reached from the Teleport menu:

| Park | What's in it |
| --- | --- |
| Hub | Garages, spawn |
| Long Jump | Open field launch with distance boards |
| Skate Park | Bowls, quarter pipes, grind rails |
| Corkscrew | Tubes, the Gravitron, the Globe |
| Downtown | Tubes, trains, billboard smash, wrecking ball cranes, kaiju, pedestrians, rooftops |
| Dino Valley | Bronto, Volcano with eruption launch, T-Rex, raptors, pterodactyl |
| Missile Silo | Sticky walls, spiral ramp with traps, buttons, rideable missile |
| Nuclear Plant | Two sticky cooling towers with timed eruptions |

Planned: a plane sky park with rings, tornados, and warp boosters.

The original list of theme ideas:

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

World 1 as built (Oct 2026), changed from the list above where Brian chose differently:

- A sky course high over the city, reached from the Teleport menu.
- Checkpoints last for one visit only. Leaving the obby or the game starts you over at the start pad. A stage select grid opens from the HUD strip and goes to any checkpoint reached this visit.
- Stage cash pays on every visit, in small amounts (100, rising 25 per stage). Clearing all 20 pays a 50,000 prize once ever, plus the Axolotl Throttle.
- Stages: 1 to 7 driving and small hops, 8 to 10 boosters, 11 to 14 moving platforms, 15 to 17 jets gaps, 18 to 20 rings.
- Obby boosters push without starting a run, so there's no score HUD in the obby. The world is built to clear at Jets 20 (a maxed Hatchback).
- Not built: stage count on the nameplate, wind tunnels, spinning bars, bounce pads.

## Progression and rebirth

Cash buys upgrades and cars; rebirth trades all of that for permanent power.

- Rebirth unlocks once a player owns the top car of the current tier.
- Rebirth resets cash, cars, and upgrades.
- Rebirth keeps a permanent point multiplier, obby progress, cosmetics, and best scores.
- Each rebirth tier unlocks rebirth only cars with higher stat caps, plus a trail or effect to show it off.
- Rebirth count shows on the nameplate and the leaderboard.

### Rebirth picks (Nov 15, 2026)

Brian's picks:

- **Unlock:** the first rebirth needs the Axolotl Throttle. Each later rebirth needs the newest rebirth car (see below).
- **Resets:** cash, every upgrade level, and every car bought with cash (Hatchback, Muscle Car, Speed Car, Axolotl Throttle, and the rebirth cars). You start over in the Junker.
- **Keeps:** everything off the cash ladder: the dino cars, the Squad hover car, the Frog Car, PlaneCar and HeliCar, and anything bought with Robux. Also bones, owned bodies (worn again once you rebuy their car), best scores, the obby prize flag, invite progress, and the daily streak.
- **Multiplier:** run pay times (1 + rebirths): 2x after the first, 3x after the second, with no cap. Flat rewards don't multiply: obby stage cash, the obby prize, daily rewards, invite rewards, and admin cash.
- **Show off:** a trail, the rebirth count on a nameplate, and a rebirth leaderboard (built with the M5 leaderboards).
- **Obby world 2:** later, not part of the first rebirth build.

Claude's starting numbers for the rebirth cars, to tune by playtesting:

| Car | Buyable after | Price | Caps | Free levels |
| --- | --- | --- | --- | --- |
| Phoenix | Rebirth 1 | 250,000 | 44 | 24 |
| Comet | Rebirth 2 | 500,000 | 48 | 28 |
| Eclipse | Rebirth 3 | 1,000,000 | 52 | 32 |

- Rebirth 2 needs the Phoenix, rebirth 3 the Comet, and rebirth 4 and up the Eclipse.
- Upgrade costs grow 1.16x per level, so maxing all five stats costs about 3.5 million at cap 40 and 33 million at cap 55. That's why rebirth cars get their power mostly from free levels, with caps only a little past the Speed Car's 40.
- Stats past level 60 have never been driven. Jets, speed, and turn rate may need flatter curves up there.
- Rebirth cars wear the Rebirth palette (dark metal with glowing parts), already in CarKit.
- The Axolotl Throttle is on the cash ladder, so it resets even when it was won in the obby. Players can rebuy it.

Steps, one diff each:

1. Pure Rebirth module and tests, plus Tuning.Rebirth: can this player rebirth, what resets and what stays, the multiplier, and which car the next rebirth needs.
2. Server: save Rebirths in PlayerData, add a rebirth remote the server checks, reset the save in one update, respawn the Junker, and log an analytics event.
3. Multiply run pay in ScoreService, and show the multiplier on the run card.
4. A REBIRTH button and confirm screen in the garage that lists what you lose and what you keep.
5. The rebirth cars in the ladder. The server refuses to sell a car the player hasn't unlocked (BuyCar doesn't check this today).
6. The rebirth effect and trail, built as the same trail system the daily reward needs.
7. A nameplate over the car with the player's name and rebirth count.
8. The rebirth leaderboard, as part of the M5 leaderboards (see Leaderboard picks).

## Leaderboards and replays

Big jumps should be seen by the whole server, then remembered.

- Everyone sees your car in the air live, with a callout banner for runs over a score threshold.
- After a big run, a short slow motion replay plays for you, and other players can tap to watch it.
- Leaderboards: best single run (server and global), daily longest flight per launcher, highest obby stage, most rebirths.
- Named launchers and jumps become landmarks with their own record holder shown on a sign.

Built so far (Nov 2026): a replay button that plays your last 5 flights with a free orbit camera, showing breaking parts, jet flames, brake lights, lava fire, and the creatures that grabbed you. Global leaderboards for best run, airtime, and rebirths stand beside the garage near spawn (Nov 16). Each park's biggest launcher has a record sign for its longest distance this week and all time (Nov 16). Not built: callout banners and watching other players' runs. The time-played board in the place is a toolbox model, not part of this plan, and it calls DataStoreService outside the data module.

### Leaderboard picks (Nov 15, 2026)

Brian's picks:

- **Boards:** best single run, most rebirths, and longest airtime (one flight, in seconds). Highest obby stage is dropped for now. Daily longest flight per launcher becomes the launcher record signs, a feature of its own after this.
- **Reset:** each board has an all-time list and a this-week list that starts fresh every Monday, UTC.
- **Display:** big lit boards near the spawn lanes, street garage style, top 10 of each list. No menu panel for now.
- **Time-played board:** the toolbox one stays as it is for now.

Claude's calls:

- Only the server's own run score counts, and flagged runs (RunCheck) never reach a board, the same as Best today.
- Global boards use OrderedDataStore through PlayerData, since no other code calls DataStoreService. Studio writes to its own boards, so testing never lands on the live ones.
- A score is sent only when it beats the player's own saved best for that list, so the store limits hold with full servers.

Steps, one diff each:

1. Pure Leaderboard module and tests, plus Tuning.Leaderboards: the boards, the week number, the store names, airtime as a whole number for the store, and how each value shows on a board.
2. Save the best airtime and this week's bests in PlayerData, set by ScoreService from the server's run.
3. Send new bests to the ordered stores through PlayerData, including the rebirth count after a rebirth.
4. The server reads the top 10 of every list each minute, looks up the names, and publishes them to clients.
5. The three boards at spawn: the server places them, each client draws them, with THIS WEEK and ALL TIME side by side.

### Launcher record sign picks (Nov 16, 2026)

Brian's picks:

- **Launchers:** one per park, its biggest jump.
- **Record:** the longest distance, flat studs from launch to where the run ended (the run card's Distance).
- **Reset:** a weekly record (Monday UTC, as the spawn boards) and an all-time record.
- **Scope:** one record across every server.

Claude's calls:

- The biggest jump per park, by launch speed: Hub's Main Ramp, Long Jump's Sky Ramp, Skate's Mega Ramp, Dino's Volcano Vent, Corkscrew's Middle Ramp, and City's Highway Overpass. Missile Silo and the Nuclear Plant have no launch pads, so no sign.
- A run counts for the launcher of the last pad it touched, the same pad that sets its pay scale. Flagged runs never count.
- Each record is one key in a plain DataStore through PlayerData, holding the holder's id, name, and distance. Ordered stores can't be read this often, and a sign only needs the top entry. Studio uses its own store.

Steps, one diff each:

1. Pure LaunchRecords module and tests, plus Tuning.LaunchRecords: the six launchers, the record keys, when a run beats a record, how a record shows, and reading a saved record safely.
2. Server: ScoreService works out a pad's launcher the first time the pad is touched (so parks built or loaded at any time are covered), notes which launcher a run left from, and reports its distance.
3. A records script that writes a new record through PlayerData (only if it still beats the saved one), reads every record each minute, and publishes them to clients.
4. The six signs at their launchers: the server places them beside each launcher, each client draws them with THIS WEEK and ALL TIME, holder and distance.

## Sound

The car, the jets, wrecks, and the obby have no sounds yet. Creatures, the volcano, the silo, rebirth, and the menus already do.

### Sound picks (Nov 16, 2026)

Brian's picks:

- **Engine:** every nearby car has one. Your own car's pitch follows speed and jumps when you hit the gas. Other players' cars sound slightly lower and much quieter, are silent past 150 studs, and fade in as they come closer. Only the closest few cars play at once.
- **In the air:** the engine drops toward idle, and the jets have their own whoosh while they burn.
- **Wreck:** a loud crunch that everyone nearby hears, one of two picked at random each wreck. Your own hard hits that don't wreck the car get a softer thud. It should sound punchy and fun, never sad, since crashes are a reward.
- **Obby:** a short chime at each new pad and a bigger fanfare when you clear the world. Only you hear them.
- **Sources:** Roblox's own uploads or the licensed libraries in the Creator Store, not community uploads that could vanish.

Claude's calls:

- Sounds are made on each client with the classic Sound object, like the rest of the game. No new server code: the server already shares each car's speed and JetsBurning, tells everyone where a car wrecked (CarWrecked), tells the driver about hits (CarImpact), and tells a player about each new pad (ObbyReward).
- Sound IDs, volumes, pitches, and distances live in Tuning.CarSounds and Tuning.ObbySounds.

Steps, one diff each:

1. Find the sounds: two or three Creator Store choices per slot, each checked to play in Play, for Brian to pick by ear. The picks go in Tuning. Done Nov 16.
2. Pure EngineSound module and tests: speed, gas, airborne, and own car or not in, pitch and volume out. Done Nov 16.
3. The engine loop on every nearby car, using EngineSound.
4. The jet whoosh while a car's jets burn.
5. The wreck crunch for everyone nearby and the hit thud on your own car.
6. The obby chime at each new pad and the fanfare at the finish.
7. Optional: replays play the engine, jet, and wreck sounds.
8. Optional: a sound setting to turn the engine down or off.

## Technical approach

The client drives and flies the car for smooth feel; the server owns stats, cash, and scores.

- Toolchain: same as MazeCity. Code in VS Code, with Rojo syncing files into Studio so all code lives in git and changes review as diffs. Luau with strict type checking. StyLua for formatting and Selene for linting are proposed.
- Car physics: constraint based chassis. The server gives the driver's client network ownership of the car while they drive.
- Air control: the client detects airborne state with raycasts under the wheels, then applies torque and jet force with constraint movers. Jet power and fuel values come from server data, not the client.
- Anti cheat: the server scores every run itself from the car's replicated motion, using the same shared run tracker the client uses for its live HUD. The client never reports a score.
- Toughness: impact strength measured from the drop in velocity between physics steps, since Touched events alone do not report impact force. Cosmetic parts detach by breaking their welds.
- Saves: DataStoreService for player data with session locking. OrderedDataStore for global leaderboards.
- Replays: record the car's CFrame at a fixed rate during a run, then play it back on a local clone.
- Tests: pure logic modules (scoring, combo decay, upgrade costs, rebirth math) get unit tests. Flight feel gets tuned by playtesting.

## Milestones

Nothing past M0 starts until flight feels fun with one car and one ramp.

| Milestone | Scope | Done when | Status (Nov 15, 2026) |
| --- | --- | --- | --- |
| M0 Feel | One car, one ramp, air control, jets, touch controls | Launching and flying is fun for 10 minutes with no goals | Done Oct 16 |
| M1 Score | Scoring, combos, toughness, wreck and respawn | A run ends with a score and nobody ever oofs | Done Oct 16 |
| M2 Economy | Cash, four upgrade stats, car generator v1, first three ladder cars, saves | Progress survives rejoining | Done Oct 18 |
| M3 World | Hub, 5 to 8 launchers, parked cars to grab | A new player finds a launcher within 30 seconds | Done Oct 28. Parked cars dropped; a Teleport menu instead |
| M4 Obby | Obby world 1 with checkpoints | 20 stages clearable with mid tier jets | All 20 stages built. Not signed off: Brian can't clear the ring stages (18 to 20) yet, and the world prize hasn't been tested live |
| M5 Social | Leaderboards, replays, launcher record signs | Other players can watch your best run | Replays of your own runs done. Global leaderboards done (Nov 16), not tested with a second account. Launcher record signs done (Nov 16): all six stand at their launchers and show this week and all time, and real flights have set records; not yet tested across two servers. Watching others not started |
| M6 Rebirth | Rebirth flow, rebirth cars, obby world 2 | A full rebirth cycle works end to end | Not started |
| M7 Launch | Polish, icon, thumbnails, mobile testing | Public release | Not started. Blockers listed in the Nov 1 release audit |

### Built outside the milestones

- More parks than M3 asked for (see the map section), with creatures, traps, and rides.
- Cars: body collection, Brakes, the dino cars, the Axolotl Throttle, PlaneCar and HeliCar.
- Bones and the Bone Shop with the Dino Mystery Box (son's work).
- Invite rewards, with the Squad hover car at 10 friends.
- Server analytics (AnalyticsService) for onboarding, the economy, and the obby.
- RunCheck: the server flags faked flights and rail grinds, and keeps them off Best.
- A CONTROLS panel, a restyled menu, park signs, and admin commands.
- In progress: a 7-day daily reward (only the pure logic is built).

## Decisions

- The game is called Yeet Street.
- The in game upgrade is called Jets.
- The map is a small city of themed stunt parks.
- Same toolchain as MazeCity: VS Code plus Rojo.
- The car obby is its own separate zone.
- Cars follow a fixed ladder with stat driven visuals and earned cosmetics.
- Generated seeds are collectible body styles for ladder cars of the same tier, earned, bought with cash, or bought with Robux. Bodies never change stats.
- No parked cars to grab. Players spawn a car anywhere and use the Teleport menu to reach parks and the obby (Oct 18).
- Obby checkpoints last one visit, stage cash pays every visit, and the world prize pays once (Oct 29).
- Planes earn no score with their wings out and no obby pay (Oct 29).

## Open questions

- [ ] Which stunt parks ship at launch, and in what order the rest arrive
- [ ] Monetization: game passes (2x cash, extra jet fuel), or none at launch. Some body styles will sell for Robux (decided 2026-10-17).
- [ ] Launch scope: what has to be in for the first public release, and what waits (raised in the Nov 1 audit).
- [ ] The Dino Mystery Box gives random cars, which goes against "no random car rolls." Keep it as is (it costs bones, not Robux) or change it?
- [ ] Rebirth car numbers: the Phoenix, Comet, and Eclipse prices, caps, and free levels are placeholders.
