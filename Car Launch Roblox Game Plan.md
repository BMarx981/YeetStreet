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
| Frog Car | Limited (son's car): admin or Robux during its sale window | |
| PlaneCar, HeliCar | Admin only for now; PlaneCar planned at 1,000,000 or a game pass | |

No oof rules:

- The driver is locked in and never takes damage, ragdolls, or dies.
- Impacts drain toughness based on impact speed. Cosmetic parts (bumpers, doors, spoiler) break off for show and score points.
- At zero toughness the car bursts into sparks and respawns fresh at the last launcher. You lose your current combo, nothing else.
- Toughness refills between runs.

### Limiteds picks (Nov 18, 2026)

Limiteds started as the son's shop tab (Oct 19). Today all five are admin only, only the Frog Car works, and stock is counted per server and resets on restart.

Brian's picks:

- **What:** a mix of cars and cosmetics. First batch: the Frog Car, Neon Underglow, Gold Rims, Galaxy Trail, and Royal Crown.
- **How you get them:** an admin gives them, or you buy them with Robux. No cash.
- **Limited means:** on sale for a time window, then gone. No stock count.
- **Look:** the name sets the look. Neon Underglow glows under the car and fades through every color, Gold Rims are gold spoked rims, Galaxy Trail is a deep space trail with twinkling stars, and Royal Crown is a gold crown floating above the car. Each look is worn or taken off in the garage; the Galaxy Trail is picked in the TRAIL row.
- **Rebirth:** keeps every limited, so nothing paid for is lost (already true in the rebirth code).

Steps:

1. Data: each limited gets a sale window (start and end, UTC) and a Robux product id in place of Price and Stock. A pure on-sale check with tests. Drop the per-server stock count and the cash buy.
2. Robux: one server module owns MarketplaceService.ProcessReceipt for developer products. It grants through the data module and remembers receipt ids so one purchase never grants twice. The window is checked when the prompt opens; a receipt that lands after the window closes still grants.
3. Admin: a general give-limited admin command in place of `:frog` only.
4. Shop tab: items on sale now with a "leaves in" countdown and a Robux button. Owned items stay listed with Equip after their window ends.
5. Looks: build the four cosmetics, worn on any car, equipped in the garage. Only the equipped flags replicate and each client builds the look, like other cosmetics. Gold Rims skip cars with no wheels (HeliCar, Squad, PlaneCar).
6. Replay ghost shows equipped limiteds.
7. Test a real Robux purchase with a second account.

Open:

- Robux prices for each item.
- Window length and dates for the first batch.

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

Planned: a plane sky park with rings and warp boosters. Tornados roam the whole map instead (see Tornados).

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

- Sounds are made on each client with the classic Sound object, like the rest of the game. The engine, wreck, hit, and obby sounds need no new server code: every client already sees each car's speed and TopSpeed, and the server tells everyone where a car wrecked (CarWrecked), tells the driver about hits (CarImpact), and tells a player about each new pad (ObbyReward). JetsBurning (and Braking) are set only on the driver's own client and never reach other players, so other players' jet whoosh needs that shared first. Both are shared now (step 4 for the jets; Braking on Nov 16 through BrakingEvent, so other players see brake lights).
- Sound IDs, volumes, pitches, and distances live in Tuning.CarSounds and Tuning.ObbySounds.

Steps, one diff each:

1. Find the sounds: two or three Creator Store choices per slot, each checked to play in Play, for Brian to pick by ear. The picks go in Tuning. Done Nov 16.
2. Pure EngineSound module and tests: speed, gas, airborne, and own car or not in, pitch and volume out. Done Nov 16.
3. The engine loop on every nearby car, using EngineSound. Written Nov 16 (CarSounds): plays on your car in Play. Two players checked Nov 17 on a Local Server: each hears the other quieter and lower, silent past 150 studs.
4. The jet whoosh while a car's jets burn. Written Nov 16: the driver's client tells the server when its jets start and stop (JetsBurningEvent), and the server sets JetsBurning on the car, so other players now see the flames too and hear the jet loop (CarSounds). Two players checked Nov 17: holding jets in one window shows the flames and plays the jet loop in the other, and both go out on release.
5. The wreck crunch for everyone nearby and the hit thud on your own car. Written Nov 16 (CrashSound, CarSounds): both played in Play from server signals fired by hand; not yet heard on a real wreck.
6. The obby chime at each new pad and the fanfare at the finish. Written Nov 16 (ObbySounds, Obby.isFinish): both played in Play from reward messages sent by hand; not yet heard on a real run. A visit that has seen a HeliCar is unpaid, so its pads stay silent too.
7. Optional: replays play the engine, jet, and wreck sounds. Written Nov 16 (ReplaySounds): the ghost's engine follows its speed, jets follow the clip, and the crunch plays as the replay passes the wreck, which the tape now records (CarWrecked names the car). Slow motion lowers them, pause silences them, and the real car goes quiet. Loads without errors in Play; not yet heard in a replay.
8. Optional: a sound setting to turn the engine down or off. Written Nov 16: a SOUND row at the top of the CONTROLS panel picks On, Low, or Off (Tuning.EngineSound.Settings). It scales every car's engine and jet loops, replays too, but not wrecks, hits, or the obby. It is saved with the player's data (SoundSettings). Checked in Play: each choice saves, lights, and turns the engine down; not yet clicked by hand or tried across a rejoin. On a two-player Local Server (Nov 17), Off silences cars only for the player who picked it.

## Tutorial

New players spawn seated in a car at the hub with the hub ramp straight ahead, and nothing tells them what to do. Most players decide in the first minute whether to stay.

### Tutorial picks (Nov 19, 2026)

Brian's picks:

- **Style:** one short prompt at a time on screen, moving on as soon as the player does the thing. They play the real game at the real hub ramp the whole time.
- **Steps:** drive to the ramp, jets and air control, then score and crash. The garage and upgrades are not part of it.
- **Who:** new players, once ever, saved in their data. A Skip button ends it, and the CONTROLS panel can replay it.
- **Reward:** none. The first runs already pay cash.

Claude's calls:

- The steps, in order: Drive (hold gas), Ramp (an arrow over the hub ramp until a run starts), Jets (hold jets in the air), Tilt (spin or tip the nose in the air), Land (land it or crash it, both pay), then a short Finish message after the run ends. If a run ends before Jets or Tilt is done, the prompt asks for another launch and the arrow comes back.
- Prompts name the player's own controls: keyboard keys, gamepad buttons, or the touch buttons, from the last input they used.
- Saved players from before the tutorial count as done if they have ever scored a run (Best above 0), so testers don't get it.
- Only finishing or skipping saves. A player who leaves partway sees it again next time.
- Replaying from CONTROLS teleports the car to the hub first, so the ramp is ahead.
- Text, holds, and speeds live in Tuning.Tutorial.

Steps, one diff each:

1. Pure Tutorial module and tests: the step machine, the prompt for each step, the text for each device, and the saved flag for old records. Done Nov 19 (25 tests).
2. The saved flag: TutorialDone in PlayerData, put on the player as an attribute, and set by a TutorialEvent from the client on finish or skip. Written Nov 19 (TutorialService): Brian's record loads as done in Play; finish and skip not yet saved by a real new account.
3. The prompt panel, the Skip button, and the ramp arrow on the client, fed each frame from CarController. Written Nov 19 (TutorialHints): the first prompt and SKIP show in Play; the arrow and the later steps not yet seen or driven.
4. A TUTORIAL button in the CONTROLS panel that teleports to the hub and starts it again. Written Nov 19 (PLAY THE TUTORIAL, under SOUND), not yet clicked.
5. Analytics (added Nov 19 at Brian's ask): a Tutorial funnel, one session per new player's tutorial, with the steps Drive, Ramp, Jets, Tilt, Land, Finish, and Done. A step reached early also logs the ones it passed (AnalyticsEvents.tutorialSteps). A skip logs a TutorialSkip event with the step. Only players whose saved flag is still false are logged, so replays and old accounts are not. Written Nov 19: in Play the client sends each step to the server; nothing logs in Studio, and the live dashboard is not yet seen.

## Timed events

Server-wide events on a timer give players a reason to stay a few more minutes and to come back. Before this, Bone Rain only ran when an admin started it, and Bones were not saved, so the dino cars could not be earned.

### Timed event picks (Nov 19, 2026)

Brian's picks:

- **Events:** Bone Rain, with Bones saved from now on, and Mega Boosters, where every booster launches much harder.
- **Schedule:** the same clock in every server: an event starts every 20 minutes and lasts 3.
- **Mega Boosters runs:** pay normally, but don't count for Best, the three spawn boards, or the launcher record signs. They get their own Mega board (best run score during Mega Boosters, this week and all time) beside the others at spawn.
- **Bones and rebirth:** rebirth resets Bones, like cash.
- **Announcing:** a small countdown on the HUD all the time ("MEGA BOOSTERS in 4:12"), a big banner and sound when one starts, and a timer while it runs.

Claude's calls:

- The two events take turns, so each comes round every 40 minutes. Which one is on comes from the clock alone (UTC), so every server agrees without messaging.
- Obby boosters (NoRun) stay normal during Mega Boosters, so obby stages play the same.
- The server decides whether a run is a Mega run from when it started, by its own clock; the client's word is not used.
- Both bone counts save: BoneCoins (spent at the Bone Trader) and Bones (the count on the HUD).
- An admin command, `:event`, starts either event now or stops it, for testing.
- Times, the rotation, and the Mega launch multiplier live in Tuning.TimedEvents.

Steps, one diff each:

1. Pure TimedEvents module and tests: which event is on at a given time, how long it has left, and which comes next and when. Done Nov 19 (13 tests).
2. Save Bones: BoneCoins and Bones in PlayerData, loaded into leaderstats, saved on every change (rain pickups, giveBones, the Bone Trader), and reset on rebirth. Written Nov 19: the counts live in the economy state (Economy.addBones, spendBones), so Garage saves and shows them and Rebirth.reset clears them; the rebirth panel now lists bones under YOU LOSE. Checked in Play: rain pickups count and survive a Play restart. Not tried: buying at the Bone Trader, a real rebirth.
3. EventService on the server: follows the clock, publishes the current and next event as workspace attributes, starts and stops Bone Rain, and the `:event` admin command. Written Nov 19. Checked in Play: the schedule was live (Mega Boosters on, Bone Rain next), and the override started and stopped Bone Rain and the Bone Trader. Server time matched Unix time. `:event` itself not typed yet; it acts in one server only. Fixed Nov 19: a server starting mid Bone Rain now rains (DinoWeather checks the Event attribute at start, since EventService could fire the toggle before DinoWeather listened). Bones are now drawn as cartoon bones (shaft plus four knobs) on the same invisible pickup box.
4. Mega Boosters on the client: boosters launch at Tuning.TimedEvents.Mega.LaunchScale times their speed, except obby boosters. Written Nov 19 (CarController.launch): eruptions (LaunchZone) are left alone too. Not driven yet.
5. Mega runs on the server: a run that started during Mega Boosters pays but skips Best, the boards, and record signs, and goes to a new Mega board at spawn. Written Nov 19 (ScoreService, Leaderboard.recordMega, MegaBest in PlayerData). The fourth board shows at spawn. Not flown yet.
6. The HUD countdown, the start banner and sound, and the running timer. Written Nov 19 (EventHud, Tuning.TimedEvents.Blurbs and StartSound, the obby fanfare for now). Seen Nov 19 in Play: the countdown, then the banner and "3:00 left" when the scheduled Bone Rain started on its own.

Open: Bone Rain drops about one bone every 0.4 seconds per player, so a 3 minute rain can give a few hundred bones, enough to buy everything at the Bone Trader. Bone value and prices need a look once it runs on the timer.

## Tornados

Tornados touch down at random spots, wander, suck cars up their funnel, spin them to the top, and throw them out for a scoring run, like the pterodactyl's drop.

### Tornado picks (Nov 25, 2026)

Brian's picks:

- **Where:** everywhere but the obby: the hub, every park, and the long jump field.
- **How often:** always some, about 3 at a time across the map. Each touches down at a random spot, wanders about a minute, then lifts away, and a new one drops somewhere else.
- **Heights:** each tornado rolls its own height, 200 to 600 studs. 200 is the minimum.
- **Escape:** holding jets breaks free any time on the way up, as with the pterodactyl. Otherwise the car rides to the top and gets thrown out.
- **Other players:** several cars can ride one tornado together.

Claude's calls:

- Cars only. Players on foot are never picked up (pillar 3). Changed Nov 25: Brian wants players on foot picked up too (see below).
- It catches cars on the ground or in the air, anywhere inside the funnel. The funnel widens with height, so the base is small and you have to drive into it. A car caught mid-flight has its run paid first, as the pterodactyl and crane already do: base points count, the landing combo and clean bonus don't (pillar 4).
- It moves slower than any car, so you can chase one down or get away.
- The ride is server driven, like the pterodactyl's carry: the car is anchored and spun round the middle while it climbs and tumbles, driver seated in view. Riders are spread round the funnel so they never stack.
- The throw goes out along the spin and up, level, with no spin of its own, so trick points come from the player's own flips. The run counts height from the ground under the tornado, with cash scaled like the pterodactyl drop.
- Tornados pass through buildings and props without moving them. Cars something else holds (T-Rex, pterodactyl, crane, missile) are skipped.
- Numbers live in Tuning.Tornado.

Steps, one diff each:

1. Pure Tornado module and tests: touchdown spot, height roll, phases, wander, catch, ride, spreading riders, jets escape, throw. Done Nov 25 (25 tests).
2. TornadoService on the server: keeps 3 going, moves an invisible marker per tornado with its height and phase, catches and spins cars, hands them back on the throw (ServerStorage.CarCarried), jets escape through HeldJets, a grey stand-in column to see it by, and an admin command that drops one at your car. Written Nov 25 (TornadoService, `:tornado`). Found in Play: a car thrown at the top was still inside the funnel and was caught again in the same frame, so it sat at the top; a thrown car now can't be caught by that tornado for Recatch (4) seconds (Tornado.drop and the Recatch test added, 27 tests). Checked in Play by script: three touched down at the start, an admin tornado caught a parked car 3.1 s after touching down, carried it to 502 in 8.4 s, threw it at 110 flat and 70 up, the car landed about 380 away with a run and no damage; jets reported 1.5 s into a ride broke it free 0.63 s later. Not seen by a human yet, and no two-car ride tried.
3. Scoring: the throw starts a drop run from the tornado's ground with Tuning.Tornado.PayScale. Written Nov 25: PayScale 0.5 (under the pterodactyl's 0.6, since tornados are always about). A run cut short by a catch now ends as "carried": it pays base points like a reset, keeps the clean streak like a wreck (it used to reset it), and its card reads CAUGHT. Checked in Play by script: a 239 tall ride with no tricks paid 356 cash; a car launched off the hub ramp into a tornado was caught at 144 up, the cut run paid 196 as "carried", the streak stayed at 3, CAUGHT showed, and the throw from the top scored its own run. Not checked: what the live score shows during a ride after a mid-flight catch (the client's run keeps going until the throw resets it).
4. The look on each client: a twisting translucent funnel to its height, debris circling, a dust ring on the ground, touchdown and lift-off. Written Nov 25 (TornadoLook, Tuning.Tornado.Look); the server's grey stand-in is gone, so the server sends only a Base part and three attributes. Each tornado is 12 see-through funnel pieces with 6 dark spiral bands each, a cloud cap plus haze, 10 bits of junk and a dust emitter, about 98 parts, moved in one BulkMoveTo a frame; past 2500 studs only the funnel and cloud draw. Bands lean to match the twist so they join up, and only the near side's bands draw (the far side's showed through and made a lattice). Seen by Claude in Play screenshots: spiral funnel, cloud, brown dust at the base, and a rider tumbling inside with the driver showing. Found: the HUD shows "air" time counting during a ride even for a car caught on the ground.
5. Sound and feel: a wind roar that grows as you get close, a whoosh on the throw, the chase camera pulled back during the ride. Written Nov 25, with a new look Brian asked for after step 4 ("more chaotic, like a cartoon whirlwind: a fast rotating cloud with fast horizontal-ish lines popping up"):
   - Look: the even spiral bands are gone. The body is 10 rings of 3 see-through puffs of mixed sizes, each whirling at its own fast speed, bobbing and wobbling; 44 swoosh lines (4 curved pieces each, mostly dark) pop up at random heights, whip round for 0.25 to 0.6 s, fade, and pop up elsewhere; the cloud cap is 5 whirling lumps. About 119 parts per tornado. With the camera in or right beside a funnel its puffs thin to 0.85 so a riding car shows.
   - Sound: a roar loop (Pro Sound Effects "Clouds Swirl Swirling Steamy Rumble Churning", 9125443744) from the funnel's middle at the camera's height, heard from 900 studs; a whoosh (Pro Sound Effects "Whoosh By Fast Airy", 9126229255) where each car is thrown (TornadoService counts Throws and sets ThrowAt on the tornado). Both picked by Claude; Brian to judge by ear.
   - Camera: TornadoCamera sits outside the funnel looking in at the car while the car's Tornado attribute names the tornado it rides (tornados are now named Tornado1, Tornado2 and on).
   - HUD: the air timer no longer counts while the car is held (anchored), and a run a tornado cuts short ends as "carried" on the client too, so its card shows at once.
   - Checked in Play: screenshots of the new look from outside and of the ride camera (car clear inside the thinned funnel), the roar loaded and playing, one whoosh on the throw, the camera back to the chase camera after. Not heard by a person yet.
6. Replays: show the ride before the throw and draw the tornado in the replay. Written Nov 25. The ride was already in the clip (a carried car reads as airborne, so catch to landing is one flight); what was missing was the tornado. TornadoLook now records each tornado's model and Base (ReplayWorld.follow), and during a replay draws only the tornados recorded over that clip (new ReplayWorld.recorded), from the recording, on the replay's clock, with a whoosh as it passes a throw. A tornado the server took away keeps its drawing hidden for replays, the last KeepGone (12). Checked in Play: a 5.2 s ride and its fall made one 11.3 s clip with 7.8 s of air, and the replay showed the tornado round the ghost car. Not checked: a replay of a tornado that has since gone, and the whoosh during a replay.

After-steps fixes (Nov 25, Brian's first look):

- Catching sooner: Brian saw cars drive into the funnel before being caught. The catch now reaches CatchScale (1.25) of the funnel's width, about as wide as it is drawn, and judges a moving car where it will be Lead (0.2) seconds on, since the server sees it late. Checked in Play: a car held still 24 studs from the middle (outside the old reach) was caught in 0.35 s.
- Smooth ride: the car looked blurry in the tornado but not in the replay. The server moved the anchored car every step, and clients got those moves in jumps. Now the server leaves the car where it caught it and sets RideAt, RideAngle and RideUp; every client places the car each frame before the camera from Tornado.rideAfter (TornadoRiders). Checked: 101 riding frames with no frame standing still.
- Flailing arms: while a car rides, every client turns its driver's shoulder and elbow joints over the head each physics step after the animations (Tuning.Tornado.Flail). This avatar uses AnimationConstraint joints; turning the rig attachment did nothing, setting Transform in PreSimulation works (Motor6D too). R15 only. Seen in a close screenshot: both arms up. Fixed Nov 25 on branch ghost-flail, after Brian merged replay-avatar (the ghost driver) into main: the recorder notes a Riding flip while the car's Tornado attribute is set, ReplayPlayer saves the driver's arm joints before stripping them and turns the arm parts from them while the replay is inside a ride, and the shared Flail module gives both the same swings. Checked in a real replay: hand above the shoulders and moving in 77 of 91 frames (the rest the lead-in before the catch), and a close screenshot with both arms up.
- Closer ride camera (Nov 25, branch ghost-flail): Brian asked for the view 50% closer. TornadoCamera now comes Zoom (0.5) of the way back toward the car from its outside spot. Measured in Play: 28 studs from the car on average, was 56.
- Players on foot (Nov 26, Brian's picks: no pay, land on foot): a tornado catches a player out of their car too, holding their root part, with the same ride attributes on their character, so every client whirls them round and flails their arms. They are thrown out upright and land on foot, never hurt, with no run. No tornado catches them again for WalkerRest (15 s), since on foot they can't outrun one (found in Play: the same tornado caught a walker twice). The player's own camera follows their ride through TornadoCamera and goes back to the normal camera after. The T-Rex now leaves alone a player whose root is anchored. Checked in Play: caught 3.1 s after touchdown, thrown at 575, landed 3.7 s later, health 100 throughout, states only Freefall, Landed and Running; held in a tornado after the throw, caught again at 15.0 s. Open: this Studio session has no PlayerModule in PlayerScripts, so the normal camera does not follow a player on foot at all; check whether a live server has it.

## Store page art

The icon and thumbnails are the first thing a player sees on Roblox, and they looked blurry.

What was wrong (checked Nov 20 against the live game and the Desktop YeetStreetImages files):

- The only home page thumbnail is the 512x512 square icon (v2_side_icon_512). Roblox stretches every thumbnail to 16:9, so it shows squashed sideways and blown up. The 1920x1080 files were never put up.
- Every shot came from Studio's screen capture, which draws the viewport at 1x on a Retina Mac and sends back a 1920 wide JPEG. The October shots held about 960x500 of real detail, and the thumbnails were then stretched another 8% to reach 1080 tall.
- At 150x150, where Roblox often shows the icon, the car is small against a pale sky and road.

Roblox specs (docs checked Nov 20): icon square, 512x512 or larger, shown as small as 150x150. Thumbnails 16:9, 1920x1080, .png or .jpg, under 3 MB for the home page. Thumbnail personalization (A/B) starts with 2 to 5 active home page thumbnails. Keep text off the bottom, where the player count can cover it.

### Store art picks (Nov 20, 2026)

Brian's picks:

- **Capture:** Claude stages and grabs the shots by script in Studio Play, like the October icon.
- **Shots:** three thumbnails: jets mid-air off a Mega Booster, a big crash in Downtown, and a car flying through the obby with Jets.
- **Numbers:** none. HUD and all GUIs hidden.
- **Text:** Claude adds it.

Claude's calls:

- Capture through a 3840x2160 custom device in Studio's device simulator (ThumbShot4K). Studio then renders 4K and the frame is scaled down to 1920x1080, so it is sharp. Studio's own quality set to the top level for the shoot.
- Grab frames losslessly from the Studio window (macOS screencapture) rather than the JPEG screen capture.
- The car is posed and held still on the client for each shot: jets lit, GUIs off, camera placed by script. Nothing is saved to the place, and Play is stopped after.
- Text: the title on the hero shot, and one short line on each of the others, placed top or middle, never bottom. A new icon from the hero shot with the car filling most of the square, checked at 150x150.
- Files go to Desktop/YeetStreetImages/v3, nothing in the repo.

Steps:

1. Hero thumbnail: jets mid-air off a Mega Booster. Done Nov 20: the Speed Car climbing over Downtown with a long flame, the YEET STREET street sign below. Mega Boosters have no look of their own, so it is a high launch.
2. Crash thumbnail: Downtown. Done Nov 20: the car bursting out of the YEET STREET billboard, tiles flying.
3. Obby thumbnail: through a ring stage with Jets. Done Nov 20: Stage 19's first ring, booster ahead.
4. Text on all three, export 1920x1080 PNGs under 3 MB. Done Nov 20: "YEET STREET / LAUNCH YOUR CAR!", "SMASH / FOR POINTS!", "CAR OBBY! / FLY THROUGH THE RINGS", in LuckiestGuy (the game's font), all about 1 MB.
5. New 512x512 icon, checked at 150x150. Done Nov 20: the hero car up close with "YEET!".
6. Brian uploads: the icon, then the three thumbnails as active on the Home Page tab, which starts personalization. Remove the stretched square thumbnail. Done Nov 21, also on the Experience Detail Page tab, a separate list that feeds the game page's carousel and the blurred background behind the title.

Files: Desktop/YeetStreetImages/v3 (thumb1_launch, thumb2_crash, thumb3_obby, icon_512, icon_1024, and the shots without text in clean/).

Shoot notes: the Phoenix, Comet, and Eclipse are too dark to read small, so the shots use the Speed Car. The Roblox menu buttons stay on screen in Studio Play, so the top left corner is filled in from the sky. After a long Play session the city's buildings started drawing black with specks, and a fresh Play fixed it; cause unknown.

## Separate Studio and live saves

Studio and the live game saved player progress to the same stores (PlayerData1 and InviteCredits1), so test cash and admin gifts from Studio went into real players' data, and live servers posted those bests to the live boards. Leaderboards and launcher records already had Studio stores of their own. This has to be fixed before ads bring in real players (see Kids and Select below).

### Save split picks (Nov 21, 2026)

Brian's picks:

- **Saves:** the live game starts fresh. Studio keeps PlayerData1 and InviteCredits1, so all test progress stays. Everyone who played the live game before (testers, Brian's and his sons' real accounts, the NeonGlow test purchase) starts over.
- **Boards:** the live leaderboards and launcher records start over too. Studio's are untouched.

Claude's calls:

- One game, split by RunService:IsStudio(), like the boards and records. No dev copy of the game.
- Store names live in Tuning.Save next to the other save settings. SaveRecord.storeNames picks them, so it is tested outside Roblox.
- Live names: PlayerData2, InviteCredits2, Boards2, LaunchRecords2.

Steps:

1. Test, then SaveRecord.storeNames and the Tuning.Save names; PlayerData uses them. Done Nov 21.
2. Bump the live boards and records to Boards2 and LaunchRecords2. Done Nov 21.
3. Check in Studio Play that the Studio save still loads with its progress.
4. Brian publishes, then joins the live game: fresh save, empty boards and record signs. Before the ads start, so ad players never save into the old store.

Kids and Select: the game shows Ages 16+ until it passes Roblox's evaluation, 100 unique plays from highly engaged age-checked players within 60 days. Brian paid the 1,000 Robux publishing fee on Nov 20. Ads Manager's Qualify for Kids and Select objective reaches only those players and counts toward the 100; a 5 day campaign is set up with the three store thumbnails.

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
- A 7-day daily reward: cash and double cash launches, a DAILY panel with a badge, and week prizes: a gold muscle body any car can wear, a rainbow jet flame, and a rainbow trail, switched in the garage. Built Nov 17, not yet tested with a real account across days.

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
- Limiteds are given by admins or sold for Robux during a time window, and rebirth keeps them (Nov 18).

## Open questions

- [ ] Which stunt parks ship at launch, and in what order the rest arrive
- [ ] Monetization: game passes (2x cash, extra jet fuel), or none at launch. Some body styles will sell for Robux (decided 2026-10-17).
- [ ] Launch scope: what has to be in for the first public release, and what waits (raised in the Nov 1 audit).
- [ ] The Dino Mystery Box gives random cars, which goes against "no random car rolls." Keep it as is (it costs bones, not Robux) or change it?
- [ ] Rebirth car numbers: the Phoenix, Comet, and Eclipse prices, caps, and free levels are placeholders.
