--!strict
-- Tuning (ModuleScript) -> ReplicatedStorage.Tuning
-- Every M0 feel number in one place. Distances are studs, times are seconds,
-- angles are degrees unless a name says otherwise.

local Tuning = {}

Tuning.World = {
	-- Roblox default is 196.2. Lower means more hang time per launch.
	Gravity = 130,
	-- The client resets its car below this height.
	FallResetY = -100,
}

-- Every car's stats at upgrade level 0; Tuning.Upgrades adds to them. The
-- server writes the result onto the car as attributes and the client reads
-- them from there, never from here.
-- Deliberately weak: the M0 car (TopSpeed 110, JetPower 150, JetFuel 3,
-- FuelRecharge 1.5, TurnRate 4, Grip 1.3, Toughness 100) is about level 15.
Tuning.StarterCar = {
	TopSpeed = 80, -- ground speed the wheels drive toward
	JetPower = 80, -- push along the nose, as acceleration
	JetFuel = 1.5, -- seconds of burn in a full tank
	FuelRecharge = 0.8, -- seconds of burn regained per second on the ground
	TurnRate = 2.5, -- air spin rate at full input, radians per second
	Grip = 1.0, -- wheel friction
	RollUnlocked = true,
	Toughness = 60, -- damage a car takes in one run before it wrecks
	-- Slowing on top of the wheel brake (Tuning.Drive.BrakeTorque), studs per
	-- second squared. 0 leaves the wheel brake alone.
	BrakePower = 0,
}

-- Economy: a run's server score pays out as cash.
Tuning.Cash = {
	PerPoint = 1,
	-- For development: in Studio only, each player's cash is topped up to this
	-- when they join. 0 turns it off. Studio saves to the same store as the game.
	StudioCash = 1_000_000,
}

-- Invite rewards (see Invites). A friend counts once they have never played,
-- join from the player's invite, and do their first launch.
Tuning.Invites = {
	PerFriend = 5000,
	WelcomeCash = 1500,
	Milestones = {
		{ Friends = 1, Kind = "Cash", Amount = 5000, Label = "$5,000 bonus" },
		{ Friends = 3, Kind = "Cash", Amount = 15000, Label = "$15,000 bonus" },
		{ Friends = 5, Kind = "Cash", Amount = 40000, Label = "$40,000 bonus" },
		{ Friends = 10, Kind = "Car", CarId = "Squad", Label = "the Squad Hover car" },
	},
	-- Each Roblox friend in the same server adds this to run payouts, up to
	-- SquadBoostMaxFriends friends.
	SquadBoostPerFriend = 0.1,
	SquadBoostMaxFriends = 3,
	-- Seconds between checks for credits a MessagingService message missed.
	CheckInterval = 300,
}

-- The car obby, world 1 (see Obby). Stage cash pays on every visit, so it is
-- kept small; the world prize pays once ever.
Tuning.Obby = {
	Stages = 20,
	StageCash = 100,
	StageCashStep = 25,
	WorldPrize = 50000,
	-- Every stage must be clearable at this Jets level (a maxed Hatchback).
	DesignJets = 20,
	-- A hull up to this high over a checkpoint pad touches it.
	CheckpointReach = 12,
	-- A car this far below the lowest pad has fallen, and respawns.
	FallDepth = 60,
	-- Every road, ramp, corner and pad has an invisible strip this wide along
	-- each side that holds up wheels but not hulls (ObbyBuilder). A car's
	-- wheels reach 3.05 to 4.15 out from its middle (Chassis TrackHalf and
	-- WheelWidth) and its hull 3, so with 3.05 its outside wheels stay up until
	-- its middle crosses the edge. Then it tips off, rather than hanging on its
	-- hull with the wheels off.
	ShoulderWidth = 3.05,
	SelectGap = 1, -- the server ignores checkpoint picks closer together than this
	-- Stage cash floats up as a green balloon of text beside the pad just
	-- reached (CashBalloon): Side studs out from the pad's right edge, Ahead
	-- past its far end and Height over its top, rising Rise over Time
	-- seconds, the last FadeTime of it fading. Width and TextHeight are in
	-- studs; a world prize balloon is PrizeScale times bigger.
	Balloon = {
		Side = 6,
		Ahead = 30,
		Height = 6,
		Rise = 16,
		Time = 2.2,
		FadeTime = 0.6,
		Width = 16,
		TextHeight = 5,
		PrizeScale = 1.8,
	},
	-- A stage's road color, by stage number, round and round (ObbyBuilder,
	-- ObbyMovers).
	StageColors = {
		Color3.fromRGB(80, 160, 255),
		Color3.fromRGB(255, 120, 60),
		Color3.fromRGB(170, 90, 230),
		Color3.fromRGB(255, 80, 140),
		Color3.fromRGB(60, 200, 210),
	},
	-- World 1's course (ObbyCourse), high over the hub and heading north.
	-- Stages 1 to 7 are driving and small hops, clearable by a car with no
	-- upgrades and no jets, but only with steering and speed control. Stages
	-- 8 to 10 add boosters, whose gaps are sized so a car at the booster's
	-- speed lands 10 to 20 studs onto the far side. Cars land about 10 short
	-- of a gravity 130 throw from the edge, so measure in Play. Stages 11 to
	-- 14 add moving platforms (ObbyMover), each held in line long enough to
	-- cross at 80, with a 1 stud gap at each end so it can move. A rising
	-- platform with Move under sqrt(6 * |Travel| / 130) stops faster than
	-- gravity and throws the car off its top. Stages 15 to 17 need jets (at
	-- full power, Jets 20 pushes 180 against gravity's 130, for 3.5 s): First
	-- Flight's gap is too long without them, Climb lands higher than the
	-- booster throws, and Long Haul is long. At Jets 20 each takes under a
	-- third of a tank with the nose held 15 to 35 degrees up from the lip.
	-- Stages 18 to 20 add rings to fly through. A booster sets the car's
	-- speed, so a ring on the booster's own path needs no jets: from a 24
	-- long, 8 high booster ramp at 130, the car's middle is 11 over the lip
	-- 40 on (measured in Play), its wheels 4 below that and its hull top 2.5
	-- above when nosed up off the ramp. A car is 8.3 across its wheels. A
	-- booster throws straight, so a hole off to the side needs a long enough
	-- flight to slide over on jets.
	World1 = {
		X = 0,
		Y = 1000,
		Z = 700,
		Heading = 0,
		Thickness = 2,
		PadLength = 24,
		-- A ring's wall reaches this far past its hole all round, so going
		-- round it costs far more fuel and steering than going through.
		RingBorder = 50,
		Stages = {
			{
				Name = "Warm Up",
				Width = 28,
				Segments = {
					{ Kind = "Road", Length = 120 },
					{ Kind = "Ramp", Length = 30, Rise = 5 },
					{ Kind = "Gap", Length = 14, Rise = -5 },
					{ Kind = "Road", Length = 60 },
					{ Kind = "Ramp", Length = 30, Rise = 5 },
					{ Kind = "Gap", Length = 16, Rise = -5, Offset = 10 },
					{ Kind = "Road", Length = 70, Width = 20 },
				},
			},
			{
				Name = "Zigzag",
				Width = 20,
				Segments = {
					{ Kind = "Road", Length = 60 },
					{ Kind = "Turn", Angle = 90 },
					{ Kind = "Road", Length = 40 },
					{ Kind = "Turn", Angle = -90 },
					{ Kind = "Road", Length = 40 },
					{ Kind = "Turn", Angle = -90 },
					{ Kind = "Road", Length = 40 },
					{ Kind = "Turn", Angle = 90 },
					{ Kind = "Road", Length = 40, Width = 14 },
					{ Kind = "Turn", Angle = 90, Width = 14 },
					{ Kind = "Road", Length = 30, Width = 14 },
					{ Kind = "Turn", Angle = -90, Width = 14 },
					{ Kind = "Road", Length = 50 },
				},
			},
			{
				Name = "Hop Hop Hop",
				Width = 22,
				Segments = {
					{ Kind = "Road", Length = 100 },
					{ Kind = "Ramp", Length = 24, Rise = 5 },
					{ Kind = "Gap", Length = 18, Rise = -5 },
					{ Kind = "Road", Length = 24, Width = 18 },
					{ Kind = "Ramp", Length = 24, Rise = 5 },
					{ Kind = "Gap", Length = 20, Rise = -5 },
					{ Kind = "Road", Length = 24, Width = 16 },
					{ Kind = "Ramp", Length = 24, Rise = 5 },
					{ Kind = "Gap", Length = 22, Rise = -5 },
					{ Kind = "Road", Length = 60 },
				},
			},
			{
				Name = "Stairway",
				Width = 18,
				Segments = {
					{ Kind = "Road", Length = 60 },
					{ Kind = "Ramp", Length = 50, Rise = 14 },
					{ Kind = "Road", Length = 24 },
					{ Kind = "Ramp", Length = 50, Rise = 14, Width = 14 },
					{ Kind = "Road", Length = 24, Width = 14 },
					{ Kind = "Ramp", Length = 50, Rise = 14 },
					{ Kind = "Road", Length = 30 },
					{ Kind = "Ramp", Length = 100, Rise = -42 },
					{ Kind = "Road", Length = 50 },
					{ Kind = "Turn", Angle = 90, Width = 24 },
					{ Kind = "Road", Length = 50 },
				},
			},
			{
				Name = "Tightrope",
				Width = 22,
				Segments = {
					{ Kind = "Road", Length = 40 },
					{ Kind = "Road", Length = 100, Width = 10 },
					{ Kind = "Turn", Angle = -45, Width = 10 },
					{ Kind = "Road", Length = 80, Width = 10 },
					{ Kind = "Turn", Angle = 45, Width = 10 },
					{ Kind = "Road", Length = 80, Width = 8 },
					{ Kind = "Road", Length = 40 },
				},
			},
			{
				Name = "Island Hop",
				Width = 18,
				Segments = {
					{ Kind = "Road", Length = 80 },
					{ Kind = "Ramp", Length = 24, Rise = 5 },
					{ Kind = "Gap", Length = 12, Rise = -5, Offset = 18 },
					{ Kind = "Road", Length = 40 },
					{ Kind = "Ramp", Length = 24, Rise = 5 },
					{ Kind = "Gap", Length = 12, Rise = -5, Offset = -18 },
					{ Kind = "Road", Length = 40 },
					{ Kind = "Ramp", Length = 24, Rise = 5 },
					{ Kind = "Gap", Length = 14, Rise = -5, Offset = 18 },
					{ Kind = "Road", Length = 60 },
				},
			},
			{
				Name = "Big Air",
				Width = 22,
				Segments = {
					{ Kind = "Road", Length = 160 },
					{ Kind = "Ramp", Length = 40, Rise = 10 },
					{ Kind = "Gap", Length = 34, Rise = -10 },
					{ Kind = "Road", Length = 30, Width = 16 },
					{ Kind = "Turn", Angle = -90, Width = 16 },
					{ Kind = "Road", Length = 40, Width = 16 },
				},
			},
			{
				Name = "Kick Start",
				Width = 18,
				Segments = {
					{ Kind = "Road", Length = 80 },
					{ Kind = "Road", Length = 24, Boost = 150 },
					{ Kind = "Gap", Length = 92, Rise = -30 },
					{ Kind = "Road", Length = 60, Width = 14 },
					{ Kind = "Road", Length = 50, Width = 10 },
				},
			},
			{
				Name = "Slingshot",
				Width = 16,
				Segments = {
					{ Kind = "Road", Length = 70 },
					{ Kind = "Ramp", Length = 24, Rise = 10, Boost = 150 },
					{ Kind = "Gap", Length = 40, Rise = 8 },
					{ Kind = "Road", Length = 120, Width = 14 },
					{ Kind = "Turn", Angle = 90, Width = 22 },
					{ Kind = "Road", Length = 50, Width = 12 },
				},
			},
			{
				Name = "Booster Chain",
				Width = 16,
				Segments = {
					{ Kind = "Road", Length = 60 },
					{ Kind = "Road", Length = 16, Boost = 130 },
					{ Kind = "Gap", Length = 32, Rise = -15, Offset = 10 },
					{ Kind = "Road", Length = 120 },
					{ Kind = "Road", Length = 16, Boost = 140 },
					{ Kind = "Gap", Length = 37, Rise = -15, Offset = -10 },
					{ Kind = "Road", Length = 120 },
					{ Kind = "Road", Length = 16, Boost = 150 },
					{ Kind = "Gap", Length = 42, Rise = -15, Offset = 10 },
					{ Kind = "Road", Length = 120 },
				},
			},
			{
				Name = "Sliders",
				Width = 18,
				Segments = {
					{ Kind = "Road", Length = 60 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Mover", Length = 40, Axis = "Side", Travel = 26, Move = 1.2, Hold = 2 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Road", Length = 40 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Mover", Length = 40, Axis = "Side", Travel = -26, Move = 1.2, Hold = 2, Phase = 0.5 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Road", Length = 40 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Mover", Length = 40, Axis = "Side", Travel = 26, Move = 1, Hold = 1.6, Phase = 0.25 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Road", Length = 60 },
				},
			},
			{
				Name = "Pistons",
				Width = 18,
				Segments = {
					{ Kind = "Road", Length = 60 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Mover", Length = 30, Axis = "Up", Travel = -24, Move = 1.1, Hold = 2.5 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Mover", Length = 30, Axis = "Up", Travel = -24, Move = 1.1, Hold = 2.5, Phase = 0.92 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Mover", Length = 30, Axis = "Up", Travel = -24, Move = 1.1, Hold = 2.5, Phase = 0.84 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Mover", Length = 30, Axis = "Up", Travel = -24, Move = 1.1, Hold = 2.5, Phase = 0.76 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Road", Length = 60 },
				},
			},
			{
				Name = "Shuffle",
				Width = 16,
				Segments = {
					{ Kind = "Road", Length = 50 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Mover", Length = 36, Axis = "Side", Travel = 22, Move = 1, Hold = 1.5 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Road", Length = 24 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Mover", Length = 30, Axis = "Up", Travel = -20, Move = 1, Hold = 1.5, Phase = 0.3 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Road", Length = 24 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Mover", Length = 36, Axis = "Side", Travel = -22, Move = 1, Hold = 1.5, Phase = 0.6 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Road", Length = 50 },
				},
			},
			{
				Name = "Moving Target",
				Width = 18,
				Segments = {
					{ Kind = "Road", Length = 60 },
					{ Kind = "Road", Length = 16, Boost = 130 },
					{ Kind = "Gap", Length = 32, Rise = -15 },
					{ Kind = "Mover", Length = 70, Width = 20, Axis = "Side", Travel = 30, Move = 1.5, Hold = 2.5 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Road", Length = 60 },
				},
			},
			{
				Name = "First Flight",
				Width = 20,
				Segments = {
					{ Kind = "Road", Length = 80 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 130 },
					{ Kind = "Gap", Length = 160 },
					{ Kind = "Road", Length = 200 },
					{ Kind = "Turn", Angle = 90 },
					{ Kind = "Road", Length = 40, Width = 14 },
				},
			},
			{
				Name = "Climb",
				Width = 18,
				Segments = {
					-- Each landing's front is a lip, 4 long, sloping 1 stud down
					-- toward the jump, so a car arriving a little low rides up
					-- onto it instead of hitting the edge.
					{ Kind = "Road", Length = 60 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 130 },
					{ Kind = "Gap", Length = 140, Rise = -1 },
					{ Kind = "Ramp", Length = 4, Rise = 1 },
					{ Kind = "Road", Length = 236 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 130 },
					{ Kind = "Gap", Length = 160, Rise = 9 },
					{ Kind = "Ramp", Length = 4, Rise = 1 },
					{ Kind = "Road", Length = 236 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 130 },
					{ Kind = "Gap", Length = 160, Rise = 14 },
					{ Kind = "Ramp", Length = 4, Rise = 1 },
					{ Kind = "Road", Length = 236 },
				},
			},
			{
				Name = "Long Haul",
				Width = 18,
				Segments = {
					{ Kind = "Road", Length = 80 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 150 },
					{ Kind = "Gap", Length = 440, Rise = -20, Offset = 40 },
					{ Kind = "Road", Length = 160, Width = 16 },
					{ Kind = "Road", Length = 40, Width = 12 },
				},
			},
			{
				Name = "Hoops",
				Width = 20,
				Segments = {
					{ Kind = "Road", Length = 50 },
					{ Kind = "Turn", Angle = 90 },
					{ Kind = "Road", Length = 80 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 130 },
					{ Kind = "Gap", Length = 40 },
					{ Kind = "Ring", Length = 4, Width = 28, Height = 18, Lift = 1 },
					{ Kind = "Gap", Length = 40, Rise = -10 },
					{ Kind = "Road", Length = 100 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 130 },
					{ Kind = "Gap", Length = 60 },
					{ Kind = "Ring", Length = 4, Width = 28, Height = 18, Lift = 18 },
					{ Kind = "Gap", Length = 60, Rise = 15 },
					{ Kind = "Road", Length = 100 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 130 },
					{ Kind = "Gap", Length = 70 },
					{ Kind = "Ring", Length = 4, Width = 28, Height = 18, Lift = 2, Offset = 14 },
					{ Kind = "Gap", Length = 60, Rise = -5, Offset = 14 },
					{ Kind = "Road", Length = 80 },
				},
			},
			{
				Name = "Needle",
				Width = 16,
				Segments = {
					{ Kind = "Road", Length = 80 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 130 },
					{ Kind = "Gap", Length = 40 },
					{ Kind = "Ring", Length = 4, Width = 14, Height = 10, Lift = 5 },
					{ Kind = "Gap", Length = 40, Rise = -10 },
					{ Kind = "Road", Length = 100 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 130 },
					{ Kind = "Gap", Length = 100 },
					{ Kind = "Ring", Length = 4, Width = 14, Height = 10, Lift = 16, Offset = -10 },
					{ Kind = "Gap", Length = 60, Offset = -10 },
					{ Kind = "Road", Length = 100, Width = 24 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 130 },
					{ Kind = "Gap", Length = 50 },
					{ Kind = "Ring", Length = 4, Width = 14, Height = 10, Lift = 5 },
					{ Kind = "Gap", Length = 50 },
					{ Kind = "Ring", Length = 4, Width = 14, Height = 10, Lift = -8, Offset = 6 },
					{ Kind = "Gap", Length = 50, Rise = -40, Offset = 6 },
					{ Kind = "Road", Length = 80 },
					{ Kind = "Road", Length = 40, Width = 12 },
				},
			},
			{
				Name = "Final Exam",
				Width = 18,
				Segments = {
					{ Kind = "Road", Length = 80 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 130 },
					{ Kind = "Gap", Length = 40 },
					{ Kind = "Ring", Length = 4, Width = 20, Height = 14, Lift = 3 },
					{ Kind = "Gap", Length = 40, Rise = -10 },
					{ Kind = "Road", Length = 120 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Mover", Length = 50, Axis = "Side", Travel = 24, Move = 1.2, Hold = 2 },
					{ Kind = "Gap", Length = 1 },
					{ Kind = "Road", Length = 80 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 130 },
					{ Kind = "Gap", Length = 80 },
					{ Kind = "Ring", Length = 4, Width = 20, Height = 14, Lift = 22 },
					{ Kind = "Gap", Length = 80, Rise = 10 },
					{ Kind = "Road", Length = 100 },
					{ Kind = "Ramp", Length = 24, Rise = 8, Boost = 150 },
					{ Kind = "Gap", Length = 160 },
					{ Kind = "Ring", Length = 4, Width = 18, Height = 12, Lift = 0, Offset = 12 },
					{ Kind = "Gap", Length = 120, Rise = -50, Offset = 12 },
					{ Kind = "Road", Length = 160, Width = 22 },
					{ Kind = "Road", Length = 40, Width = 12 },
				},
			},
		},
	},
}

-- Upgrade levels start at 0, which is Tuning.StarterCar. Each level adds Steps
-- to the real stats its upgrade drives: Speed drives TopSpeed; Jets drives
-- JetPower, JetFuel, FuelRecharge, and TurnRate; Toughness and Grip drive
-- their own; Brakes drives BrakePower. Friction is capped at 2 (rear wheels
-- get Grip times Chassis.RearGripFactor), so Grip steps stay small.
-- Prices: level 1 is 300, level 10 about 1,140, level 20 about 5,030, level
-- 30 about 22,200. All four stats to 10 cost about 25,600.
Tuning.Upgrades = {
	CostBase = 300, -- price of level 1
	CostGrowth = 1.16, -- each level costs this times the last
	CostRound = 10, -- prices round to the nearest multiple of this
	Steps = {
		TopSpeed = 2,
		JetPower = 5,
		JetFuel = 0.1,
		FuelRecharge = 0.05,
		TurnRate = 0.1,
		Toughness = 4,
		Grip = 0.02,
		BrakePower = 5,
	},
}

Tuning.Garage = {
	RequestGap = 0.25, -- the server ignores purchases closer together than this
	Reach = 20, -- studs from a Garage-tagged model's pivot within which the panel opens
}

-- The teleport menu (TeleportService). A car sent to a garage arrives this
-- far in front of the garage model's pivot, facing it, inside Garage.Reach.
Tuning.Teleport = {
	RequestGap = 1, -- the server ignores teleports closer together than this
	GarageDistance = 14,
}

-- Saving player data (PlayerData, SaveRecord).
Tuning.Save = {
	AutosaveInterval = 60,
	-- A lock with no write for this long belongs to a server that is gone.
	-- Several autosaves, so a slow DataStore never makes a live lock look stale.
	LockTimeout = 300,
	-- Joining while another server still holds the lock (the player just left
	-- it) retries this many times, this far apart, then takes the lock anyway.
	LoadAttempts = 5,
	LoadRetryGap = 6,
}

-- The car ladder, cheapest first. A new player owns the first car. Caps are the
-- highest level of each upgrade the car can use, and Bonus is free levels on
-- every stat on top of those. Each car costs less than the last levels of the
-- car before it, so players save for it while still upgrading. Seed,
-- Archetype, and Tier pick its looks from the car generator (CarKit, and
-- ServerStorage.Dev.CarGallery to browse seeds).
Tuning.Ladder = {
	{
		Id = "Junker",
		Name = "Junker",
		Price = 0,
		Bonus = 0,
		Caps = { Speed = 10, Jets = 10, Toughness = 10, Grip = 10, Brakes = 10 },
		Seed = 1,
		Archetype = "pickup",
		Tier = "Junker",
	},
	{
		Id = "Hatchback",
		Name = "Hatchback",
		Price = 15000,
		Bonus = 4,
		Caps = { Speed = 20, Jets = 20, Toughness = 20, Grip = 20, Brakes = 20 },
		Seed = 1,
		Archetype = "hatch",
		Tier = "Street",
	},
	{
		Id = "Muscle",
		Name = "Muscle Car",
		Price = 75000,
		Bonus = 8,
		Caps = { Speed = 30, Jets = 24, Toughness = 30, Grip = 24, Brakes = 24 },
		Seed = 1,
		Archetype = "muscle",
		Tier = "Sports",
		Bodies = {
			{ Seed = 7, Archetype = "muscle" },
			{ Seed = 8, Archetype = "muscle" },
			{ Seed = 2, Archetype = "wedge" },
			{ Seed = 3, Archetype = "wedge" },
			{ Seed = 4, Archetype = "hover" },
			{ Seed = 5, Archetype = "hover" },
			{ Seed = 9, Archetype = "buggy" },
			{ Seed = 10, Archetype = "buggy" },
			{ Seed = 13, Archetype = "jeep" },
			{ Seed = 15, Archetype = "jeep" },
			{ Seed = 19, Archetype = "hatch" },
			{ Seed = 20, Archetype = "hatch" },
			{ Seed = 11, Archetype = "pickup" },
			{ Seed = 17, Archetype = "pickup" },
			{ Seed = 14, Archetype = "bus" },
		},
		BodyPrice = 10000,
	},
	{
		Id = "Speed",
		Name = "Speed Car",
		Price = 100000,
		Bonus = 12,
		Caps = { Speed = 40, Jets = 30, Toughness = 36, Grip = 30, Brakes = 30 },
		Seed = 1,
		Archetype = "wedge",
		Tier = "Supercar",
	},
	-- Won by bringing in Tuning.Invites' last milestone of friends.
	{
		Id = "Squad",
		Name = "Squad Hover",
		Price = 0,
		Bonus = 10,
		Caps = { Speed = 34, Jets = 28, Toughness = 32, Grip = 28, Brakes = 28 },
		Seed = 1,
		Archetype = "hover",
		Tier = "Squad",
		ForSale = false,
	},
	-- Dino cars: only obtainable from the Dino Mystery Box at the Bone Trader.
	{
		Id = "Velociraptor",
		Name = "Velociraptor",
		Price = 0,
		Bonus = 8,
		Caps = { Speed = 34, Jets = 26, Toughness = 26, Grip = 30, Brakes = 30 },
		Seed = 11,
		Archetype = "buggy",
		Tier = "Dino",
		ForSale = false,
	},
	{
		Id = "Triceratops",
		Name = "Triceratops",
		Price = 0,
		Bonus = 10,
		Caps = { Speed = 30, Jets = 24, Toughness = 44, Grip = 30, Brakes = 30 },
		Seed = 12,
		Archetype = "triceratops",
		Tier = "Dino",
		ForSale = false,
	},
	{
		Id = "Brachiosaurus",
		Name = "Brachiosaurus",
		Price = 0,
		Bonus = 12,
		Caps = { Speed = 28, Jets = 32, Toughness = 48, Grip = 28, Brakes = 28 },
		Seed = 13,
		Archetype = "brachiosaurus",
		Tier = "Dino",
		ForSale = false,
	},
	{
		Id = "Spinosaurus",
		Name = "Spinosaurus",
		Price = 0,
		Bonus = 14,
		Caps = { Speed = 44, Jets = 36, Toughness = 40, Grip = 36, Brakes = 36 },
		Seed = 14,
		Archetype = "spinosaurus",
		Tier = "Dino",
		ForSale = false,
	},
	{
		Id = "TRex",
		Name = "T-Rex",
		Price = 0,
		Bonus = 16,
		Caps = { Speed = 50, Jets = 40, Toughness = 50, Grip = 40, Brakes = 40 },
		Seed = 7,
		Archetype = "trex",
		Tier = "Dino",
		ForSale = false,
	},
}

-- Limited edition items, purchasable in the store's Limiteds tab. Each has a
-- stock that decreases as players buy it; when stock hits zero it's sold out.
Tuning.Limiteds = {
	{
		Id = "FrogCar",
		Name = "Frog Car",
		Price = 0,
		Stock = 0,
		Description = "A special car that jumps instead of using jets. Admin-only.",
		AdminOnly = true,
	},
	{
		Id = "NeonGlow",
		Name = "Neon Underglow",
		Price = 25000,
		Stock = 100,
		Description = "Glowing neon lights beneath your car.",
		AdminOnly = true,
	},
	{
		Id = "GoldRims",
		Name = "Gold Rims",
		Price = 50000,
		Stock = 50,
		Description = "Premium gold-plated wheels.",
		AdminOnly = true,
	},
	{
		Id = "RainbowTrail",
		Name = "Rainbow Trail",
		Price = 100000,
		Stock = 25,
		AdminOnly = true,
		Description = "A rainbow trail follows your car through the air.",
	},
	{
		Id = "Crown",
		Name = "Royal Crown",
		Price = 250000,
		Stock = 10,
		Description = "A golden crown floats above your car.",
		AdminOnly = true,
	},
}

-- Items sold by the Bone Trader NPC during bone rain, priced in BoneCoins
-- (the leaderstat that goes up when players collect falling bones). Each item
-- exchanges bones for cash; Stock of -1 means unlimited.
Tuning.BoneShop = {
	{
		Id = "BoneCashSmall",
		Name = "Pocket Change",
		BonePrice = 25,
		CashReward = 5000,
		Description = "Swap 25 bones for $5,000 cash.",
		Stock = -1,
	},
	{
		Id = "BoneCashMedium",
		Name = "Bone Bundle",
		BonePrice = 75,
		CashReward = 20000,
		Description = "Swap 75 bones for $20,000 cash.",
		Stock = -1,
	},
	{
		Id = "BoneCashLarge",
		Name = "Bone Fortune",
		BonePrice = 150,
		CashReward = 50000,
		Description = "Swap 150 bones for $50,000 cash.",
		Stock = -1,
	},
	{
		Id = "DinoMysteryBox",
		Name = "Dino Mystery Box",
		BonePrice = 50,
		Mystery = true,
		Description = "A mysterious dino egg. It could hatch into cash, bones... or a Velociraptor, Triceratops, Brachiosaurus, Spinosaurus, or the mighty T-Rex car!",
		Stock = -1,
	},
}

-- Rewards from the Dino Mystery Box. Weight is how likely each reward is
-- (higher = more common). The five dino cars run from the Velociraptor (most
-- common) up to the T-Rex, the rare jackpot.
Tuning.DinoMystery = {
	Rewards = {
		{ Weight = 8,  Kind = "Car",   CarId = "Velociraptor", Label = "a VELOCIRAPTOR car! Quick and nimble!" },
		{ Weight = 6,  Kind = "Car",   CarId = "Triceratops",  Label = "a TRICERATOPS car! Built like a tank!" },
		{ Weight = 4,  Kind = "Car",   CarId = "Brachiosaurus", Label = "a BRACHIOSAURUS car! The biggest of them all!" },
		{ Weight = 2,  Kind = "Car",   CarId = "Spinosaurus",  Label = "a SPINOSAURUS car! Fierce and fast!" },
		{ Weight = 1,  Kind = "Car",   CarId = "TRex",        Label = "the T-REX CAR! The king of the dinosaurs is yours!" },
		{ Weight = 20, Kind = "Cash",  Amount = 20000, Label = "$20,000 cash" },
		{ Weight = 30, Kind = "Cash",  Amount = 8000,  Label = "$8,000 cash" },
		{ Weight = 40, Kind = "Bones", Amount = 25,    Label = "25 bones back" },
	},
}

Tuning.Chassis = {
	HullSize = Vector3.new(6, 1.6, 11),
	HullDensity = 1,
	HullFriction = 0.3, -- low, so a car on its roof slides instead of sticking
	WheelRadius = 1.4,
	WheelWidth = 1.1,
	WheelDensity = 0.8,
	HubSize = 0.8,
	HubDensity = 2,
	TrackHalf = 3.6, -- wheel center distance from the middle, sideways
	WheelbaseHalf = 3.8, -- wheel center distance from the middle, lengthways
	MountY = -0.2, -- suspension mount height on the hull
	-- Suspension travel along the mount, relative to the mount point.
	SlideLow = -1,
	SlideHigh = 0.3,
	SpringTop = 2.5, -- spring anchor height above the mount
	-- Stiffness is derived from car mass and gravity so the car rests this far
	-- above full droop. Damping is this fraction of critical damping.
	SuspensionSag = 0.7,
	DampingRatio = 0.35,
	SeatOffset = Vector3.new(0, 0.9, 0.8),
	RearGripFactor = 1.2, -- rear wheel friction as a multiple of Grip; 1 for even grip
}

-- How generated cars (CarDesign) sit on the chassis, in studs from the hull's
-- center. A stat's look steps up at each StatSteps level.
Tuning.CarLooks = {
	BodyBottom = -0.6,
	TrackHalf = Tuning.Chassis.TrackHalf,
	WheelbaseHalf = Tuning.Chassis.WheelbaseHalf,
	WheelRadius = Tuning.Chassis.WheelRadius,
	WheelY = Tuning.Chassis.MountY + Tuning.Chassis.SlideLow + Tuning.Chassis.SuspensionSag,
	WheelWidth = Tuning.Chassis.WheelWidth,
	StatSteps = { 5, 12, 20, 30 },
}

Tuning.Drive = {
	DriveTorque = 2000,
	BrakeTorque = 5000,
	CoastTorque = 150,
	ReverseFraction = 0.4, -- reverse top speed as a fraction of TopSpeed
	BrakeSpeed = 2, -- below this speed, brake turns into reverse
	MaxSteerAngle = 32,
	HighSpeedSteerFactor = 0.35, -- fraction of full lock left at top speed
	-- Steering is capped so a turn uses at most this fraction of the front
	-- tires' grip (Grip times gravity, as sideways acceleration).
	SteerGrip = 0.9,
	-- Flips wheel spin direction if the car drives backward on gas.
	SpinSign = -1,
}

Tuning.Air = {
	AngularAccel = 18, -- radians per second squared toward the target spin
	IdleDamping = 0.6, -- how fast spin bleeds off with no input
	TorquePerMass = 400, -- AirSpin max torque is this times car mass
	PitchScale = 1,
	YawScale = 1,
	RollScale = 1.2,
	InvertPitch = false,
}

Tuning.Jets = {
	RelightFuel = 0.25, -- fuel needed to start a new burn
}

-- A PlaneCar flying with its wings out (Glide). At Lift 0.02 a flat fall
-- slows to about 100 studs/s. At Camber 0.016 the wings hold it up at about
-- 110 studs/s, where it takes off, and above that it climbs.
Tuning.Glide = {
	Lift = 0.02,
	Side = 0.015,
	Drag = 0.05,
	MaxAccel = 300, -- about one and a half gravities
	Camber = 0.016,
	MaxCamber = 255, -- about 1.3 gravities, a gentle climb at full speed
	EngineTopSpeed = 250, -- the engine (jets with the wings out) fades out here
}

-- A PlaneCar's air control with its wings out (PlaneFlight): up and down
-- hold the nose this far from level, steering banks this far, and no input
-- flies level.
Tuning.PlaneFlight = {
	MaxPitch = math.rad(30),
	MaxBank = math.rad(35),
	Gain = 3, -- spin per radian off the held angle, per second
	YawShare = 0.5, -- of the car's turn rate, swinging the nose at full steer
}

-- A PlaneCar's guns (Guns, ShotPath). Each hit takes ShotDamage of the car's
-- full toughness off the side it hit, run or not (ScoreService).
Tuning.Guns = {
	Rate = 5, -- shots a second, the two guns taking turns
	Slack = 0.75, -- the server takes a shot this much of a shot's time early
	Range = 400, -- studs
	HitRadius = 4, -- a shot passing this close to a car hits it
	ShotDamage = 0.1, -- ten hits wreck a car
	WreckBonus = 300, -- cash to the shooter whose shot wrecks a car, paid at once
	BountyGap = 20, -- seconds before wrecking the same player pays again
	TracerTime = 0.08, -- seconds a shot's streak shows
	HitSparks = 15,
}

-- The admin-only Frog Car. Built by CarBuilder with these stats, and the jet
-- button (Left Shift) triggers a jump instead of jets. Given via :frog command.
Tuning.FrogCar = {
	TopSpeed = 90,
	JetPower = 0, -- no jets; the jet button triggers a jump instead
	JetFuel = 1,
	FuelRecharge = 1,
	TurnRate = 3,
	Grip = 1.5,
	RollUnlocked = true,
	Toughness = 200,
	JumpPower = 100, -- upward velocity impulse in studs/second
	JumpCooldown = 1.0, -- seconds between jumps
}

-- What burning jets look like on each thruster (CarVisuals). Each list runs
-- by Jets look step (CarLooks.StatSteps), from none reached to all four.
Tuning.JetFlames = {
	FlameLength = { 3, 4.5, 6, 8, 11 }, -- studs the flame reaches behind the thruster
	FlameWidth = { 1, 1.15, 1.3, 1.5, 1.8 }, -- at the nozzle, times the thruster's width
	FlameRate = { 80, 100, 130, 160, 200 }, -- particles per second
	FlameLife = 0.2, -- seconds; the flame stays on the thruster as the car moves
	SmokeRate = { 4, 8, 14, 22, 32 }, -- smoke is left behind in the air as a trail
	SmokeSize = { 1.5, 2, 2.6, 3.4, 4.4 },
	SmokeLife = 1.6,
	SmokeColor = Color3.fromRGB(70, 70, 75),
	GlowRange = { 0, 4, 6, 8, 11 }, -- light around the thruster, 0 for none
	GlowBrightness = 2,
}

Tuning.Contact = {
	ProbeMargin = 0.6, -- extra ray length past the wheel radius
	AirDelay = 0.1,
	LandWheels = 2,
}

-- Launch pads (CarController). A pad pushes only a car whose velocity points
-- at least this much along the pad (the cosine of the angle between them:
-- 0.65 is within about 50 degrees).
Tuning.Launch = {
	MinHeading = 0.65,
	AnyWayLeast = 2, -- studs a second across the ground before an any-way pad knows which way to throw
	AnyWayReach = 10, -- an any-way pad this far under the hull arms a run (CarSensor)
}

Tuning.Run = {
	ArmTime = 1, -- seconds after leaving a launch pad that lift off still starts a run
	StopSpeed = 4, -- a run off its wheels and slower than this for StopTime ends
	StopTime = 1,
	CleanUpY = 0.7, -- up vector Y at touchdown needed for a clean landing
	-- A flying car that moves farther than this in one step was moved, not
	-- flown, and its run ends there as a reset. Well above what jets and a
	-- network hitch can cover.
	TeleportDistance = 250,
}

-- Starting values, tuned by playtesting. A plain jump off the test ramp scores
-- about 440; two different tricks and a clean landing about 2100.
Tuning.Score = {
	AirtimePerSecond = 50,
	DistancePerStud = 0.25,
	HeightPerStud = 1,
	FlipPoints = 250,
	SpinPoints = 200, -- spins are the easiest trick to land
	RollPoints = 250,
	RepeatFalloff = 0.5, -- each repeat of a trick pays this times the last
	RepeatFloor = 0.1, -- repeats never drop below this fraction of full points
	ComboStep = 0.5, -- combo gained per different trick after the first
	ComboMax = 4,
	CleanMultiplier = 1.5,
	SmashPoints = 100, -- per part knocked off the car
	GrindPerSecond = 120, -- per second on a rail
	GapPoints = 500, -- per gap cleared, such as across the skate park's bowl
	SwingPoints = 300, -- coming down on a swing seat
	-- A run landing with a part tagged Helipad this far under the hull's
	-- middle counts the Helipad target (ScoreService).
	HelipadReach = 8,
	-- Smashing through a target during a run, by the target's kind (its Target
	-- attribute, PropService).
	TargetPoints = {
		Billboard = 500,
		["Water tower"] = 300,
		Helipad = 500, -- a run landing clean on a Downtown roof's helipad (ScoreService)
		Pool = 300, -- a run coming down in a Downtown roof's pool (ScoreService)
		["Palm tree"] = 200,
		Lava = 300, -- coming down in lava (ScoreService)
		["T-Rex"] = 400, -- caught by the T-Rex in the air (ScoreService)
		["Wrecking ball"] = 300, -- smacked by one of Downtown's (ScoreService)
		Kaiju = 500, -- caught by Downtown's kaiju in the air (ScoreService)
		Zapped = 300, -- blasted by the kaiju's laser (ScoreService)
		-- Flung over the gravitron's rim, by how fast it spun (ScoreService)
		Gravitron = 200,
		["Gravitron Fast"] = 400,
		["Gravitron Ludicrous"] = 800,
	},
}

-- Grinding rails (Grind, GrindRide). A rail is a part tagged GrindRail.
Tuning.Grind = {
	GrindHeight = 1.6, -- the hull's center above the rail's, sitting on it
	CaptureRadius = 6, -- the hull this close to the grind line gets on
	HoldTolerance = 2, -- the server counts a hull this close as grinding
	MinAlign = 0.8, -- moving within about 37 degrees of the rail
	MinSpeed = 20, -- along the rail, to get on
	RideMinSpeed = 40, -- a car rides the rail at its speed getting on, held to these
	RideMaxSpeed = 160,
	Cooldown = 2, -- seconds before a rail can catch a car that just left it
	EndPop = 15, -- straight up off the end of a rail
	Hop = 40, -- straight up when jets hop the car off
	SlipSpeed = 35, -- sideways, falling off toward the marker's side, clear of the rail
	-- The balance bar runs from -1 to 1.
	ZoneHalf = 0.2,
	ZoneSpeed = 0.5,
	RetargetMin = 0.5, -- seconds between the zone picking a new spot
	RetargetMax = 1.5,
	Tip = 1.5, -- the marker tips away from the middle
	Wobble = 2, -- gust strength getting on
	WobbleGrowth = 0.15, -- gusts grow by this fraction per second on the rail
	GustTime = 0.25,
	SteerForce = 8,
	Damping = 3,
	Grace = 0.5, -- seconds outside the zone before slipping off
	StartGrace = 1.5, -- seconds after getting on before the zone moves, gusts blow, or the car can slip off
}

-- Giant swings (Swing, SwingRide, SwingService). A car on a seat sticks to
-- it, even upside down, and drives around on it; gas pumps it the way the
-- nose points, driving off an edge or jets get off it.
Tuning.Swing = {
	Gravity = Tuning.World.Gravity,
	Length = 70, -- pivot to the seat's top face; over the top takes about 191 studs/s at the bottom
	BaseAngle = 35, -- how high every swing keeps swinging by itself
	BaseDrive = 0.5,
	PumpAccel = 0.35, -- pumping in time goes over the top in about 10 seconds
	Damping = 0.02, -- slowly settles a swing back to BaseAngle once pumping stops
	MaxSpeed = 230, -- studs per second at the seat
	SeatWidth = 40,
	SeatDepth = 40,
	SeatThickness = 2,
	HoldHeight = 6, -- a hull this close above the seat's top face gets on
	CaptureUp = 0.5, -- and its up vector at least this much along the seat's
	-- Slow, so gas held through half a swing (about 2.3 s) takes the car
	-- most of the way across the seat instead of off it.
	DriveSpeed = 16,
	DriveAccel = 40,
	SteerRate = 2.5, -- radians per second of turn at DriveSpeed
	Hop = 40, -- off the seat's face when jets launch the car
	Cooldown = 1, -- seconds before a seat can catch the car that just left it
	SendRate = 15, -- times per second the rider's client and the server send the swing
	RiderTimeout = 0.5, -- seconds without word from the rider before the server lets go
	HoldSlack = 15, -- studs of leeway when the server checks a hull is on its seat
	Follow = 3, -- how fast a client pulls a swing it doesn't ride toward the server's
}

Tuning.Hud = {
	TrickPopupTime = 1.2, -- seconds a trick name stays on screen
	ResultTime = 4, -- seconds the run card stays up after a run ends
	-- The server's card replaces the client's. If the server's comes first, a
	-- client card this many seconds later is dropped instead of covering it.
	OfficialHold = 1,
	ImpactTime = 3, -- seconds the hardest recent hit stays on screen
	CashEarnedTime = 3, -- seconds the "+N" under the cash stays on screen
	-- How the run card names a target, if not "<kind> smash".
	TargetLabels = {
		Lava = "Lava splash",
		["T-Rex"] = "T-Rex snack",
		["Wrecking ball"] = "Wrecking ball",
		Kaiju = "Kaiju snack",
		Zapped = "Zapped",
		Helipad = "Helipad landing",
		Pool = "Pool splash",
	},
}

-- Sounds the menus play, only for the player using them (UiStyle).
Tuning.MenuSounds = {
	Open = { Id = "rbxassetid://12222200", Pitch = 1.1, Volume = 0.5 }, -- swoosh
	Close = { Id = "rbxassetid://12222200", Pitch = 0.8, Volume = 0.4 },
	Click = { Id = "rbxassetid://9119717523", Pitch = 1.2, Volume = 0.5 },
	Buy = { Id = "rbxassetid://18264787819", Pitch = 1, Volume = 0.6 }, -- cash register ding
	Denied = { Id = "rbxassetid://87519554692663", Pitch = 1, Volume = 0.5 }, -- can't press or afford
}

Tuning.Righting = {
	StartUpY = 0.5, -- lying with no wheels down and tipped past this starts righting
	EndUpY = 0.95, -- righting stops here, or when LandWheels wheels touch
	LandWheels = 2,
	GroundProbe = 3.5, -- ground within this far below the hull counts as lying
	Rate = 4, -- radians per second
	SlowAngle = math.rad(30), -- eases off inside this angle of upright
	TubeExit = 2, -- seconds after leaving a tube's pull that a tipped car in the air rights itself
	-- Needs to beat the car's weight lifting it off its side (about gravity
	-- times half the hull width per unit mass), so well above air control.
	TorquePerMass = 1200,
}

-- Hits are measured as a sudden change in the car's velocity, in studs per
-- second (Impact). Measured in playtests: wheel landings 31 to 79, roof 64,
-- nose 74, a hard side hit 93, gentle bumps under 20. Only body hits during a
-- run do damage (Toughness).
Tuning.Toughness = {
	ShowImpact = 20, -- hits at least this hard show on the HUD and in Output
	HitThreshold = 30, -- body hits up to this do nothing
	DamagePerSpeed = 1, -- toughness lost per stud per second over HitThreshold
	BreakDamage = 20, -- every this much damage to one slot breaks a part there
	WreckSmashes = 8, -- a wreck knocks off every part but pays Smash points for at most this many
	BreakPop = 20, -- broken parts fly off the car this fast, studs per second
	PartLifetime = 5, -- seconds a broken part lies around before it is removed
	WreckSparks = 120, -- sparks in the burst when a car wrecks
	WreckBeat = 1, -- seconds a wreck stays on screen before the fresh car appears
	-- Lava burns all of a car's toughness in this many seconds, breaking
	-- parts as it goes, then the car wrecks. Run or not.
	LavaBurnTime = 3,
	LavaFireSize = 10, -- the fire on a burning car (CarVisuals)
	-- A car still counts as burning this long after it last touched lava,
	-- so a bounce does not put its fire out, and it can pass the boulders
	-- at the lake's edge on its way out. It only takes damage on the lava.
	LavaFireHold = 0.5,
	-- Smashing through a boulder faster than its BreakSpeed costs this much
	-- toughness per stud per second over it, run or not.
	BoulderDamagePerSpeed = 1,
}

-- Knockable props, like the distance boards. They never touch cars.
Tuning.Props = {
	HitRadius = 4, -- a car's hull center passing this close to a prop knocks it
	CarSpeedShare = 0.5, -- a knocked prop flies off at this fraction of the car's velocity
	Pop = 25, -- plus this much straight up, studs per second
	Spin = 6, -- tumble rate tipping it away from the car, radians per second
	ResetTime = 2.5, -- seconds until a knocked prop is back in place
	-- Props in a Model with Shatter set all fly when one is hit, each also
	-- thrown this fast out from the hit, studs per second.
	ShatterBurst = 40,
	-- A car faster than a boulder's BreakSpeed is let through boulders
	-- within LookAhead seconds of its speed plus Margin studs, until Hold
	-- seconds after it was last (CarController).
	Boulders = { LookAhead = 0.25, Margin = 20, Hold = 1 },
}

Tuning.Reset = {
	-- Where a reset or wreck puts the car: RespawnCFrame on the last launch
	-- pad it touched, in lanes this far apart so cars do not land on each other.
	RespawnLanes = 4,
	RespawnLaneSpacing = 12,
	RequestGap = 1, -- the server ignores reset requests closer together than this
	RetryTime = 2, -- the client asks again if no new car arrived after this
	-- While a respawn swaps cars, the client holds the camera and HUD this long
	-- waiting for the new one before giving up on driving.
	RespawnWait = 1,
	StuckUpY = 0.3, -- up vector Y below this counts as on its roof or side
	StuckSpeed = 4,
	StuckTime = 2.5,
	-- Before its first launch pad a car respawns where it was built, so lava
	-- within this far of that spot does not burn it, or a wreck would only
	-- bring it back into the lava.
	LavaSpawnClear = 40,
}

Tuning.Input = {
	StickDeadzone = 0.15,
	TriggerDeadzone = 0.05,
}

Tuning.Camera = {
	Distance = 22,
	Height = 6,
	FocusHeight = 2,
	TurnSharpness = 6, -- higher follows the car's heading faster
	FollowVelocityAbove = 20, -- in the air, look along travel above this speed
	MaxPitch = 0.6, -- limits how far above or below the car the camera swings
	Fov = 70,
	FovBoost = 20,
	FovFullSpeed = 300, -- speed where the FOV boost is fully applied
}

-- Watching the last run again (ReplayTape, ReplayRecorder).
Tuning.Replay = {
	LeadIn = 1.5, -- seconds of the clip before liftoff
	Tail = 2, -- seconds of the clip after the run ends
	MaxLength = 20, -- longest clip in seconds, keeping the end; also how much the tape keeps
	MinAirtime = 1, -- seconds from liftoff a run lasts to replace the last clip
	-- Where the camera starts (ReplayPlayer), then the player circles it
	-- round the ghost car (ReplayCamera, ReplayOrbit).
	CameraDistance = 42, -- studs from the ghost car
	CameraPitch = 17, -- degrees above level
	CameraAngle = 35, -- degrees round from side on toward behind the way the run went
	MinPitch = 5, -- degrees; lower would put the camera under the ground
	MaxPitch = 80,
	MinDistance = 12,
	MaxDistance = 200,
	MouseTurn = 0.008, -- radians per pixel dragged
	TouchTurn = 0.01, -- radians per pixel dragged
	StickTurn = 3, -- radians per second with the right stick all the way over
	WheelZoom = 0.85, -- distance times this per wheel notch toward the screen
	StreamSpacing = 256, -- studs between the places along a replay's path asked to stream in
	StreamRefresh = 1, -- seconds between asking again for the map round the ghost car
	StreamAhead = 1, -- replay seconds ahead of the ghost car also asked for
	-- Studs a creature is drawn from where the replay has it past which it
	-- jumps there instead of gliding, as a replay starts or scrubs (KaijuLook,
	-- TRexLook, RaptorLook, PteroLook).
	Jump = 50,
	EndHold = 1, -- seconds the last frame holds before the replay closes
	Speeds = { 1, 0.5, 0.25 }, -- what the speed button steps through (ReplayControls)
	-- Parts breaking off the ghost car (ReplayDebris). They are thrown like
	-- real ones (Tuning.Toughness BreakPop) and gone after PartLifetime.
	DebrisStep = 1 / 30, -- seconds between the points of a broken part's path
	DebrisSpin = 8, -- radians per second a broken part tumbles
	DebrisBounce = 0.35, -- share of its speed into a surface a part bounces back with
	DebrisFriction = 0.15, -- share of its speed along a surface a part loses each bounce
	DebrisRest = 4, -- studs per second below which a bouncing part stops
	-- The ghost's wheels come off when its last part does, as in a wreck, and
	-- roll where they land.
	RollFriction = 0.01, -- share of its speed a rolling wheel loses each DebrisStep
	RollUpright = 0.25, -- share of the way a landed wheel turns up onto its tread each DebrisStep
	RollGround = 0.7, -- how level a surface must be to roll on (1 is flat)
}

Tuning.TestPark = {
	-- Ground rectangle, tiled because a part is at most 2048 studs on a side.
	-- Jets can carry a run well past 4000 studs from the lip.
	GroundBackZ = 900, -- edge behind the spawn
	GroundFrontZ = -6000, -- far edge past the ramp
	GroundHalfWidth = 3000,
	GroundTile = 2048,
	-- Curved wall around the ground's edge: flat, vertical at the edge, then on
	-- to WallEndAngle degrees so the top leans back over the ground. Past 90 a
	-- car leaving the lip heads back inside instead of straight up.
	WallRadius = 60,
	WallEndAngle = 120,
	WallSteps = 13,
	WallThickness = 2,
	WallCornerRadius = 200, -- corner sweep radius, to where the curve starts
	WallCornerSlices = 12,
	RunwayWidth = 60,
	SpawnZ = 700,
	SpawnHeight = 2.6,
	SpawnLanes = 5,
	SpawnLaneSpacing = 12,
	-- Resets and wrecks put the car here, at the back end of the runway, just
	-- ahead of the spawn lanes so a respawn never lands on a parked car.
	RespawnZ = 680,
	RampStartZ = 200,
	RampWidth = 40,
	RampThickness = 2,
	RampPlanks = 12,
	RampPlankLength = 10,
	RampStartAngle = 3,
	RampEndAngle = 35,
	PadPlanks = 4, -- the last planks of the ramp push the car to LaunchSpeed
	LaunchSpeed = 300,
	BoardSpacing = 100,
	BoardCount = 50,
	BoardX = 70,
}

-- The map seen from above (MapLayout). The hub is the saved test park's back
-- end around the spawn and runway; the long jump's landing field runs on down
-- the middle and stays clear. Parks sit to either side. ParkService warns at
-- startup if areas come closer than Gap or leave Bounds, which is the test
-- park ground inside its edge wall.
Tuning.Map = {
	FloorTop = 0.1, -- park floors sit just above the grass, so the two never flicker
	Gap = 100,
	Bounds = { MinX = -2900, MaxX = 2900, MinZ = -5900, MaxZ = 800 },
	Areas = {
		{
			Id = "Hub",
			Name = "Hub",
			Kind = "Hub",
			X = 0,
			Z = 400,
			Width = 800,
			Depth = 800,
			ArriveX = 0,
			ArriveZ = 680, -- the hub launcher's respawn point, clear of the spawn lanes
			Heading = 0,
		},
		{
			Id = "LongJump",
			Name = "Long Jump",
			Kind = "Open",
			X = 0,
			Z = -3000,
			Width = 1000,
			Depth = 5800,
			ArriveX = 0,
			ArriveZ = -200,
			Heading = 0,
		},
		{
			Id = "Skate",
			Name = "Skate Park",
			Kind = "Park",
			X = 1800,
			Z = -100,
			Width = 2000,
			Depth = 1800,
			ArriveX = 1500,
			ArriveZ = 700,
			Heading = 0,
		},
		{
			Id = "Corkscrew",
			Name = "Corkscrew",
			Kind = "Park",
			X = -1700,
			Z = -1300,
			Width = 2000,
			Depth = 4000,
			ArriveX = -820,
			ArriveZ = 650,
			Heading = 0,
		},
		{
			Id = "City",
			Name = "Downtown",
			Kind = "Park",
			X = 1750,
			Z = -3000,
			Width = 2100,
			Depth = 3600,
			ArriveX = 1750,
			ArriveZ = -1300,
			Heading = 0,
		},
		{
			Id = "Dino",
			Name = "Dino Valley",
			Kind = "Park",
			X = -1750,
			Z = -4650,
			Width = 2300,
			Depth = 2500,
			ArriveX = -2800,
			ArriveZ = -3490, -- behind the brontosaurus's tail, facing up it
			Heading = -42,
		},
	},
}

-- The long jump (ServerScriptService.Parks.LongJump): bigger launchers beside
-- the hub launcher on its east side, all firing down the long jump field. X
-- is world X. Each kicker's lip sits at LipZ, the hub ramp's lip, so the
-- distance boards measure every launcher. Every plank of a kicker is a pad,
-- so a car too slow to climb it is still carried up and over. PayScale cuts
-- the cash per point so a straight jump pays a little more than the hub
-- launcher's 430, not two or three times as much (score and Best are not cut).
Tuning.LongJump = {
	LipZ = 88,
	RunwayZ = 730, -- where every runway starts, level with the hub spawn
	WallThickness = 2,
	Launchers = {
		-- With Radius 160 and Angle 40, a lip about 37 high, like the hub
		-- ramp. A straight jump scores about 770, so pays about 500.
		{
			Name = "BigKicker",
			X = 170,
			Width = 50,
			Radius = 160,
			Angle = 40,
			Steps = 14,
			LaunchSpeed = 380,
			PayScale = 0.65,
		},
		-- With Radius 260 and Angle 45, a lip about 76 high. A straight jump
		-- scores about 1030, so pays about 520.
		{
			Name = "SkyRamp",
			X = 320,
			Width = 70,
			Radius = 260,
			Angle = 45,
			Steps = 18,
			LaunchSpeed = 450,
			PayScale = 0.5,
		},
	},
}

-- The corkscrew park (ServerScriptService.Parks.Corkscrew). X and Z are
-- studs from the park's center. A straight ramp climbs Rise over Run toward
-- -Z from X, StartZ to a kicker at the top, and a corkscrew track loops
-- around it, entered from the ground on the right and leaving partway up the
-- left wall of its last loop, which throws the car out to the left. Both have
-- boosters all the way up.
Tuning.Corkscrew = {
	X = 700,
	StartZ = 1800, -- where the middle ramp leaves the ground
	Run = 1500,
	Rise = 260,
	Thickness = 2,
	PayScale = 0.5,
	Ramp = {
		Width = 30, -- the flat middle
		-- Each side curves up WallRadius to vertical, WallRadius beyond the
		-- flat middle, in WallSteps strips (7.5 degree folds at 12), so a car
		-- steering into it rides up and comes back down instead of over.
		-- 15 turns back about 60 studs/s sideways; the tops stay about 4
		-- studs inside cars riding the corkscrew's lips.
		WallRadius = 15,
		WallSteps = 12,
		-- Up the ramp from its foot, where the walls curl up from flat on
		-- the floor, so the mouth at the foot is about 77 wide.
		EntryLength = 100,
		EntryRows = 16,
		BoostEvery = 150, -- studs between booster strips
		BoostLength = 30,
		BoostSpeed = 200,
		-- On the end of the ramp, so it leaves about 10 + Angle degrees up.
		KickRadius = 120,
		KickAngle = 30,
		KickSteps = 10,
		LaunchSpeed = 380,
	},
	Track = {
		Radius = 50, -- from the middle ramp's line to the track
		Loops = 9,
		StepsPerLoop = 48,
		-- Along the ramp. Under the gap between loops (about 124), or the
		-- loops close into a tube.
		Width = 80,
		-- Each side curls LipHeight up toward the ramp over its outer
		-- LipWidth, so the track is a gutter that pushes a drifting car back
		-- to the flat middle.
		LipWidth = 15,
		LipHeight = 8,
		ExitAngle = 45, -- how far up the wall past the last loop it ends
		EndGap = 20, -- along the ramp, from the track's end to the kicker
		BoostEvery = 4, -- every this many planks is a booster
		BoostSpeed = 220, -- well over the 76 a car needs to stay on at the top
		ExitPlanks = 6, -- the last planks, which launch
		ExitSpeed = 320,
		-- From flat floor into the track's first plank, whose edge slopes
		-- with the ramp; the last rows are boosters.
		RunwayLength = 300,
		RunwayRows = 12,
		RunwayBoostRows = 2,
	},
	-- The gravitron (Parks.CorkscrewGravitron, Gravitron, GravitronRide): a
	-- huge bowl that spins, open at the top, its floor's middle over X, Z.
	-- Its high side faces -Z turned Heading degrees the way
	-- CFrame.Angles(0, Heading, 0) turns: -90 faces +X, toward the open
	-- field between it and the middle ramp. Heading must be a multiple of 90.
	Gravitron = {
		X = -450,
		Z = -810,
		Heading = -90,
		FloorRadius = 260,
		CurveRadius = 40,
		CurveSteps = 8,
		Lean = 15, -- degrees the wall leans out from the axis
		Height = 300, -- the rim, up the axis from the floor
		Tilt = 20,
		Thickness = 2,
		Clearance = 1, -- under the bowl's lowest point
		Slices = 144, -- round the bowl
		FloorStrip = 10, -- the floor is strips this wide
		-- A wall round under the bowl, Radius out from under the floor's
		-- middle, up to the floor's underside, so nobody drives under it.
		Skirt = { Radius = 190, Slices = 72 },
		Margin = 4, -- a car's middle this far under the surface is still in the bowl
		-- A car on the surface higher than this up the axis is armed like on
		-- a launch pad: leaving the surface starts a run, and leaving over
		-- the rim pays a Gravitron target by how fast it spins.
		ArmHeight = 120,
		RimReach = 60, -- out past the rim, a car over it has gone over the rim
		HitGrace = 0.3, -- seconds after leaving the bowl that hits still do no damage
		PayScale = 0.5,
		Spin = {
			Direction = 1, -- the way the tubes twist, counterclockwise from above
			-- Studs per second at the wall's foot, held Hold seconds each, in
			-- a cycle on the server's clock.
			Stops = {
				{ Speed = 90, Hold = 20 },
				{ Speed = 200, Hold = 12 },
				{ Speed = 360, Hold = 8 },
			},
			Ramp = 6, -- seconds easing from each stop to the next
			MinGrip = 0.3, -- times the tyres' grip at the fastest stop
			Carry = 1.5, -- per second: how quickly the surface brings a car to its speed
		},
		-- The target a run pays for leaving over the rim, by the spin's level
		-- (Gravitron.level) when it left: the first whose Level it reaches.
		Targets = {
			{ Level = 0.8, Target = "Gravitron Ludicrous" },
			{ Level = 0.3, Target = "Gravitron Fast" },
			{ Level = 0, Target = "Gravitron" },
		},
		-- Two tubes (Tunnel.gravitron) from mouths at either end, along the
		-- way the high side faces turned a quarter, that dive under the bowl
		-- and twist round each other up into its floor. The rest of the tube's
		-- shape is Tuning.City.Tunnels'.
		Tubes = {
			TwistRadius = 80,
			Pitch = 180, -- the strands are half this apart
			Loops = 1,
			TwistEase = 0.1,
			TopGap = 6,
			ExitAngle = 50,
			DiveSlope = 28,
			Level = 140, -- over FlareLength, so the tube starts past the mouth
			Dip = 20,
			DipLength = 150,
			Outside = 33,
			SliceAngle = 6,
			-- Each mouth is wide, with a curved wall each side of a funnel in
			-- front of it that lies flat on the ground at its open end,
			-- FunnelSpread wider each side, and curls up into the mouth.
			MouthFloor = 120,
			MouthCurve = 24,
			FlareLength = 120,
			FlareRows = 10,
			FunnelLength = 200,
			FunnelSpread = 100,
			FunnelRows = 16,
			-- A ring of launch pads at the start of each exit, so a car makes
			-- the climb up through the floor.
			BoostAt = 0.1, -- of the way along the exit
			BoostLength = 24,
			BoostSpeed = 220,
		},
	},
	-- The face (Parks.CorkscrewGlobe, Globe, GlobeRide): two huge closed
	-- balls for eyes, held up over the ground by the tube into them, which
	-- forks under them into a smile (Tunnel.face). Each eye is driven round
	-- inside with ordinary gravity, so a loop over the top takes jets: about
	-- sqrt(gravity times Radius), 140 studs per second, at the top. The face
	-- stands across the park, its middle over X, Z, with the mouth in front
	-- along the way Heading turns -X the way CFrame.Angles(0, Heading, 0)
	-- does: 90 puts the mouth to +Z, facing the park's arrival. Heading must
	-- be a multiple of 90.
	Globe = {
		X = -400,
		Z = 850,
		Heading = 90,
		Radius = 150, -- to the inside
		Thickness = 4,
		EyeGap = 100, -- between the eyes' outsides
		Slices = 96, -- round; a multiple of 4
		Bands = 48, -- bottom to top
		Overlap = 0.3, -- each plank this much wider and taller, so the seams stay closed
		EquatorBands = 2,
		MeridianSlices = 2,
		-- The stripes and the hatch are painted on the inside only: their
		-- planks are this much of the Thickness in their color, the rest the
		-- shell's.
		PaintDepth = 1,
		-- Degrees round the front of each eye, toward the mouth, that its
		-- pupil of dark glass reaches, with the orb glowing through it.
		Pupil = 25,
		-- The bottom bands all the way round are the hatch the tube comes up
		-- through: solid, but for a car coming up the tube, on its own
		-- driver's client, until HatchHold seconds after it leaves the tube.
		-- It must reach past where the tube's floor comes up through the
		-- bottom, the tube's Radius over sin(ExitAngle) out, plus a car, or
		-- cars hit the shell on the way in (the builder warns).
		HatchBands = 6,
		HatchHold = 1,
		-- The way out: a car stopped (under Speed) on the hatch, within Reach
		-- of its middle and Height up from the bottom, for Wait seconds drops
		-- through it into the tube, on its own driver's client, and rides the
		-- tube back down and out of the funnel. The hatch flashes FlashRate times a
		-- second while it waits, on that client only.
		Exit = { Speed = 3, Wait = 2, Reach = 20, Height = 10, FlashRate = 4 },
		Windows = { Count = 8, Slices = 3, Bands = 3, Above = 5 },
		Margin = 4, -- a car's middle this far past the inside is still in an eye
		HitGrace = 0.3, -- seconds after leaving an eye that hits still do no damage
		Orb = { Size = 45, LightRange = 60, LightBrightness = 5 },
		-- The smile's layout (Tunnel.face); the eyes' bottoms are where its
		-- branches are cut off. The rest of the tube's shape, its funnel,
		-- and the launch pads near the start of each climb are the
		-- gravitron's Tubes'. Through the fork each branch has a ring every
		-- SliceAngle degrees of its turn, short so each is cut back closely
		-- along the seam where it runs into the other, at TrimMargin inside
		-- the other's planks.
		-- Where the branches still overlap past the fork, a car is pushed
		-- sideways ForkPush (studs per second per second) into the branch it
		-- goes (Globe.forkSide, level within ForkLevel studs), so one driven
		-- straight does not run into the ridge between them.
		Smile = {
			TurnRadius = 120,
			ExitAngle = 50,
			Stem = 200,
			SliceAngle = 2,
			TrimMargin = 0.1,
			ForkPush = 150,
			ForkLevel = 1,
		},
	},
}

-- The dense city (ServerScriptService.Parks.City). X and Z are studs from the
-- park's center; the arrival point is at X 0, Z 1700, facing -Z, at the top
-- of the avenue down the middle. Cross streets split the rest into blocks of
-- buildings, with open plazas at both ends. The Highway Overpass climbs
-- straight down the avenue from just ahead of the arrival to a broken end,
-- a kicker that throws the car on down the avenue.
Tuning.City = {
	Avenue = {
		Width = 160,
		DashLength = 30,
		DashEvery = 80,
	},
	Streets = {
		Width = 100,
		Z = { 1000, 200, -600, -1400 }, -- each one's middle, running across the park
	},
	-- Along both edges of the avenue and every cross street, Every apart and
	-- Inset in from the edge, with an arm Reach out over the road. Knocked
	-- flying by a car (PropService), back up after ResetTime.
	StreetLights = {
		Every = 100,
		Inset = 4,
		Height = 22,
		Reach = 8,
		ResetTime = 3,
		CarSpeedShare = 1, -- a knocked light flies off at the car's speed
	},
	Buildings = {
		Seed = 7, -- the same seed builds the same skyline every time
		TopZ = 1500, -- the first block starts here; the arrival plaza is ahead of it
		Setback = 20, -- from the street to the first building, room for its curve
		Lot = 160, -- each building's footprint, square
		Alley = 50, -- between neighbors: both curves, with 10 flat between
		-- Around each building's foot, rising to straight up the wall.
		CurveRadius = 20,
		CurveSteps = 10,
		CornerSlices = 4,
		MinHeight = 40,
		MaxHeight = 260,
		EmptyChance = 0.15, -- some lots stay empty, as parking lots to land in
	},
	-- Twisting round tube tunnels in chains of two buildings, laid out by
	-- Tunnel.layout. Each building takes Columns by Rows lots; a chain's two
	-- stand side by side across the alley between them, against the Street
	-- at the Top or Bottom of their Block (Block 1 is the first past the
	-- arrival plaza), on Side 1 (+X) or -1 (the mirror image). A chain's tube
	-- comes in on the ground from the avenue, Offset in from that street,
	-- snakes and climbs through the first building (Climb), crosses the alley
	-- high enough to drive under, then sweeps and drops through the second
	-- (Drop) and out onto the street. Turns are degrees, positive left;
	-- Rise is studs, eased so the tube never folds. Inside a tube a driver's
	-- car is pulled toward the nearest wall instead of down (CarController),
	-- so it can drive round the walls and along the roof, and climb, at any
	-- speed. Dim lights hang along the roof.
	Tunnels = {
		Radius = 30, -- from the middle line to the planks
		Sides = 24, -- planks around the ring
		Pull = 1, -- toward the wall inside a tube, times world gravity
		-- Over FlareLength at each end on the ground the tube opens out into
		-- a mouth with a flat floor (and roof) MouthFloor wide and curves
		-- MouthCurve around up each side, like the corkscrew's middle ramp,
		-- so a car can get in off center or at an angle. Climb must start, and
		-- Drop end, with a level straight at least FlareLength long.
		MouthFloor = 68,
		MouthCurve = 18,
		FlareLength = 80,
		FlareRows = 8,
		AboveTunnel = 20, -- every tunnel building rises at least this far above its tube
		SliceAngle = 5, -- degrees of turn per slice of tube
		StepLength = 12, -- studs per ring of planks where a straight climbs
		LightEvery = 60, -- studs along the middle line
		LightBrightness = 0.6,
		LightRange = 30,
		Columns = 2,
		Rows = 2,
		Offset = 230,
		-- Right, left, right: a snake that ends back on its line, 32 up, so the
		-- tube's bottom crosses the alley about 30 above it.
		Climb = {
			{ Straight = 80 },
			{ Turn = -60, Radius = 70, Rise = 8 },
			{ Turn = 120, Radius = 70, Rise = 16 },
			{ Turn = -60, Radius = 70, Rise = 8 },
		},
		-- A long sweep round toward the street, back down to the ground.
		Drop = {
			{ Straight = 40 },
			{ Turn = -90, Radius = 150, Rise = -32 },
		},
		Places = {
			{ Side = 1, Block = 2, Street = "Top" },
			{ Side = -1, Block = 2, Street = "Bottom" },
			{ Side = 1, Block = 3, Street = "Bottom" },
			{ Side = -1, Block = 3, Street = "Top" },
			{ Side = 1, Block = 4, Street = "Top" },
			{ Side = -1, Block = 4, Street = "Bottom" },
		},
	},
	-- Spiral towers, laid out by Tunnel.spirals: a hollow building Columns
	-- by Rows lots from lot Column of its Block, on Side of the avenue,
	-- against the Street at the Top or Bottom of the block. A round tube (like
	-- the chains', with the same pull) comes in on the ground from that
	-- street, Radius out from the building's middle, runs Inset in, and
	-- climbs Loops round the middle, Pitch up each loop. The last half loop
	-- climbs gently on up through the roof, under a hut HutHeight tall over
	-- the roof's far half, and comes out level on the roof heading back toward
	-- the street. The tube ends in a mouth LevelRun on, and the rest of the
	-- roof is a runway to a kicker at its street edge that throws the car off.
	-- Outside is from the tube's middle line to its outside.
	Spirals = {
		Radius = 105,
		Pitch = 72,
		Loops = 2,
		Inset = 225,
		LevelRun = 80, -- just the mouth, so the rest of the roof is runway to settle and line up
		Outside = 33,
		RoofThickness = 2,
		Columns = 2,
		Rows = 2,
		SliceAngle = 7.5, -- degrees of turn per ring of planks, coarser than the chains' to save parts
		HutHeight = 72,
		Kick = {
			Radius = 60,
			Angle = 25,
			Steps = 8,
			Width = 120,
			LaunchSpeed = 220,
		},
		Places = {
			{ Side = 1, Block = 1, Column = 1, Street = "Bottom" },
			{ Side = -1, Block = 1, Column = 1, Street = "Bottom" },
			{ Side = 1, Block = 1, Column = 3, Street = "Bottom" },
			{ Side = -1, Block = 1, Column = 3, Street = "Bottom" },
		},
	},
	-- The train line (Railway, built by Parks.CityRailway): one loop,
	-- elevated High over the first of StreetZ, down a ramp along the strip
	-- outside the last lots at StripX either side, through an open cutting
	-- and under the ground Low along the second street, with turns Corner
	-- round. Heights are the deck's top, from the floor. The deck is
	-- DeckWidth flat with a curve EdgeRadius round up to straight on each
	-- side, like the corkscrew's middle ramp, so a drifting car rides up and
	-- back. Where a ramp passes the ground, the curves lie flat for
	-- CurlLength on the uphill side so a car can drive on from the side.
	Railway = {
		High = 40,
		Low = -34,
		Corner = 120,
		StreetZ = { 200, -600 },
		StripX = 980,
		DeckWidth = 30,
		EdgeRadius = 15,
		EdgeSteps = 10,
		Thickness = 2,
		StepLength = 12, -- studs per piece of deck where it climbs
		SliceAngle = 5, -- degrees of turn per piece of deck
		PillarEvery = 120,
		PillarSize = 8,
		FillBelow = 12, -- below this much clearance the deck sits on a solid fill, so no car gets under it
		RoofClear = 22, -- the cutting stays open until the deck is this far under the ground
		CurlLength = 40,
		CurlRows = 8,
		TurnWall = 30, -- on the elevated turns, a wall this high above each curve's top
		-- then curving on to TurnLipAngle degrees, leaning in over the track like the map's edge wall
		TurnLipRadius = 30,
		TurnLipAngle = 120,
		TurnLipSteps = 6,
		TurnWallRun = 60, -- along the straights either side, where it tapers down to the curve
		LightEvery = 60, -- along the subway's roof
		-- Each player's client moves the trains from the server's clock
		-- (TrainSet), so everyone sees them in the same place. They never
		-- touch anything; a train's nose that reaches a car pushes it, and
		-- a car beside or inside a train is passed by it (Railway.push).
		Trains = {
			Count = 2,
			Carriages = 4,
			Length = 40,
			Gap = 4,
			Width = 20,
			Height = 14,
			Speed = 60,
		},
		Push = {
			Margin = 6, -- from the carriage's sides to the car's middle, about half a car
			Depth = 6, -- a car's middle this far inside the train's nose still gets pushed out ahead
			Ahead = 1.25, -- times the train's speed
			Side = 8,
		},
		-- A push is never a hit (ScoreService). The car's motion reaches the
		-- server late, so a hit counts as a push when a train's nose was
		-- where it pushes the car any time in the last Lag seconds, Slack
		-- further out, and no hit is measured for HitGrace after.
		Server = {
			Lag = 0.5,
			Slack = 4,
			HitGrace = 0.3,
		},
	},
	Overpass = {
		StartZ = 1550, -- where it leaves the ground, 150 ahead of the arrival
		Run = 900,
		Rise = 110,
		Width = 50,
		Thickness = 2,
		BarrierHeight = 4, -- straight up, so a car hits it instead of riding over
		BarrierWidth = 3,
		PillarEvery = 150,
		PillarSize = 12,
		BoostEvery = 150,
		BoostLength = 30,
		BoostSpeed = 200,
		-- On the broken end, so it leaves about 7 + KickAngle degrees up.
		KickRadius = 120,
		KickAngle = 25,
		KickSteps = 8,
		LaunchSpeed = 320,
	},
	-- A YEET STREET billboard across the avenue in the overpass kicker's
	-- flight path, where a plain launch passes about 234 high. Its face is
	-- Columns by Rows tiles that all shatter when a car flies through it
	-- (PropService), paying Tuning.Score.TargetPoints.Billboard on the run.
	-- It stands on two posts just inside the avenue's edges, past the cross
	-- street and clear of the street lights.
	Billboard = {
		Z = 280,
		Bottom = 200, -- the face's lower edge above the floor
		Width = 140,
		Height = 56,
		Columns = 10,
		Rows = 4,
		Thickness = 2,
		PostSize = 6,
		Beam = 2, -- the frame along the top and bottom, which cars pass through
		ResetTime = 6, -- long enough to watch the pieces land
		CarSpeedShare = 0.6,
		-- TextScaled stops at 100 pixel text, so few enough pixels that the
		-- two lines fill the board.
		PixelsPerStud = 4,
	},
	-- Tower cranes on roofs by the streets, each with a wrecking ball
	-- swinging from its jib's tip across the street (WreckingBall). Each
	-- player's client moves the balls from the server's clock
	-- (WreckingBallSet). They never touch anything, but a ball that reaches a
	-- car smacks it across the street and up: that starts a run like a launch
	-- pad, and pays Tuning.Score.TargetPoints["Wrecking ball"] on the run
	-- (ScoreService). A crane stands on the building nearest each Spot
	-- (WreckingBall.Spot), no more than MaxShift along from it, with its
	-- ball Phase (a share of a whole swing) along its swing at time 0.
	Cranes = {
		MastHeight = 60, -- above the roof
		MastSize = 6,
		MastBack = 25, -- in from the roof's street edge
		JibSize = 4,
		CounterJib = 40,
		CounterweightSize = 10,
		MaxShift = 220,
		Margin = 6, -- from the ball to the street's edge at the end of its swing
		Gap = 1.5, -- under the ball at the bottom of its swing
		Spots = {
			{ Along = -370, Side = -1, Phase = 0 }, -- over the avenue
			{ Along = -1170, Side = 1, Phase = 0.5 },
			{ Street = -600, Along = -600, Side = -1, Phase = 0.25 },
			{ Street = -1400, Along = 600, Side = 1, Phase = 0.75 },
		},
		-- At Period 3 the avenue's balls cross the middle at about 130
		-- studs/s and the cross streets' at about 67, as they swing less far.
		Ball = {
			Period = 3,
			Radius = 12,
			Reach = 5,
			Smack = 140,
			Lift = 110,
			MinShare = 0.5,
			Outrun = 1.25,
		},
		-- The car's motion reaches the server late, so the server checks a
		-- smack against where the ball was over the last Lag seconds, Slack
		-- further out. Only a jump in the car's speed of at least Kick counts,
		-- once every Cooldown, and no hit is measured for HitGrace after.
		Server = {
			Lag = 0.5,
			Slack = 4,
			Kick = 40,
			Cooldown = 1,
			HitGrace = 0.4,
		},
	},
	-- What goes on the roofs (Roofs): a lip along every edge, and one kind
	-- each, picked by Weight from Seed, its footprint Width along x by Depth
	-- along z (or turned) placed near the roof's middle.
	Roofs = {
		Seed = 26,
		LipHeight = 3,
		LipLength = 6,
		Clearance = 4,
		Step = 2,
		Kinds = {
			{ Name = "Plain", Weight = 1, Width = 0, Depth = 0 },
			{ Name = "Pool", Weight = 1, Width = 80, Depth = 50 },
			{ Name = "Garden", Weight = 2, Width = 100, Depth = 100 },
			{ Name = "Solar", Weight = 2, Width = 100, Depth = 80 },
			{ Name = "WaterTower", Weight = 2, Width = 30, Depth = 30 },
			{ Name = "Helipad", Weight = 1, Width = 70, Depth = 70 },
		},
		-- A wooden tank of Staves on four legs under a stepped roof. Every
		-- part is a knockable prop in one Shatter model with Target "Water
		-- tower", so flying through any of it bursts it all (PropService).
		WaterTower = {
			Radius = 9,
			TankHeight = 14,
			Staves = 18,
			StaveThickness = 1,
			LegHeight = 14,
			LegSize = 1.5,
			RoofRise = 5, -- the stepped roof's height above the tank
			ResetTime = 6,
			CarSpeedShare = 0.6,
		},
		-- Rows of panels (Roofs.solarRows) on a frame a car drives up. Each
		-- row is panels Panel wide along it, Seam apart.
		Solar = {
			Height = 3,
			Run = 9,
			Back = 9, -- as long as Run: steeper, a car driving up it flips
			Gap = 10,
			Panel = 6,
			Seam = 0.4,
		},
		-- A pad the size of the kind's footprint, a yellow Ring (its middle
		-- Ring - RingWidth out) round a white H, Letter tall with Stroke wide
		-- bars, and Lights round the edge. Only the pad is solid.
		Helipad = {
			Ring = 30,
			RingWidth = 3,
			Letter = 26,
			Stroke = 4,
			Lights = 12,
		},
		-- A raised pool deck (Roofs.poolLayout), its water WaterBelow under
		-- the deck's top. Cars drive on the basin's floor under the water.
		Pool = {
			Height = 4,
			Ramp = 8,
			Rim = 4,
			Shallow = 12,
			Side = 8,
			WaterBelow = 0.6,
		},
		-- A lawn with crossing paths, and in each corner a tree, a flower bed
		-- and two seats (Roofs.gardenLayout). Trees, beds and seats are
		-- knockable props, back after ResetTime; the seats are tagged
		-- GardenSeat.
		Garden = {
			Path = 6,
			TreeInset = 8,
			BedLength = 26,
			BedWidth = 5,
			BedInset = 2,
			SeatOut = 16,
			SeatAlong = { 12, 22 },
			TreeHeight = 10,
			Canopy = 6, -- the treetop's radius
			BedHeight = 1.5,
			ResetTime = 4,
		},
		-- While the game runs: a hull's middle inside a pool's water, or up
		-- to Margin above it, is in the pool (ScoreService). Falling in faster
		-- than Speed throws a splash of Drops and Mist on each client
		-- (WaterTowerSplash).
		PoolSplash = {
			Margin = 4, -- high enough that wheels landing on a slope by the wall still count
			Speed = 30,
			Drops = 150,
			Mist = 40,
		},
		-- While the game runs (CityRoofs.start): a car coming down onto a
		-- solar row faster than Speed cracks the panels within Radius of it,
		-- mended after Time seconds.
		Crack = {
			Speed = 40,
			Reach = 6, -- below the hull's middle, where a falling car is about to land
			Radius = 8,
			Time = 8,
		},
		-- Drawn on each client when a water tower bursts (WaterTowerSplash).
		Splash = {
			Drops = 120,
			Mist = 30,
		},
	},
	-- A kaiju about 150 tall that walks the streets and hunts cars the way
	-- Dino Valley's T-Rex does (Rex, run by Parks.CityKaiju through
	-- Parks.DinoRex): the numbers below mean what they do in
	-- Tuning.Dino.Rex. It keeps to Streets (park coordinates), the avenue
	-- south of the elevated train, the two cross streets under it and the
	-- plaza at the end, and starts at X, Z facing Heading.
	Kaiju = {
		X = 0,
		Z = -1000,
		Heading = 0,
		Seed = 11,
		Streets = {
			{ MinX = -80, MaxX = 80, MinZ = -1500, MaxZ = 150 },
			{ MinX = -900, MaxX = 900, MinZ = -650, MaxZ = -550 },
			{ MinX = -900, MaxX = 900, MinZ = -1450, MaxZ = -1350 },
			{ MinX = -1000, MaxX = 1000, MinZ = -1770, MaxZ = -1440 },
		},
		WalkSpeed = 25,
		RunSpeed = 60, -- slower than every car
		Accel = 40,
		TurnRate = 45,
		Sight = 450,
		Lose = 650,
		RoamRadius = 600,
		GoalReach = 30,
		GoalTime = 40,
		Body = 30,
		Neck = 15,
		Reach = 90,
		BiteHeight = 160,
		Cone = 45,
		WindUp = 0.7,
		AirWindUp = 0.3,
		Snap = 0.25,
		Recover = 1.5,
		Rest = 3,
		Grip = 1.5,
		EscapeJets = 0.6,
		SlipChance = 0.3,
		Stun = 3,
		Chew = 2,
		Bite = 18,
		AirHeight = 8,
		Gravity = Tuning.World.Gravity,
		-- Where its head goes, in the frame of its feet on the ground facing
		-- -Z, as in Tuning.Dino.Rex.Head. It stands upright, so its head
		-- rests high over its feet.
		Head = {
			Size = Vector3.new(22, 20, 34),
			Rest = Vector3.new(0, 140, -30),
			Back = Vector3.new(0, 148, -12),
			Shoulders = Vector3.new(0, 130, -15),
			Hold = Vector3.new(0, 120, -45),
			HoldTip = -20,
			CarDrop = 4,
			CarIn = 2,
		},
		-- How it is drawn on each client (KaijuLook), only for looks, as in
		-- Tuning.Dino.Rex.Look. It roars as it spots a car (the raptors'
		-- screech at RoarPitch, deeper still), its jaw open for RoarJaw
		-- seconds. Its eyes hum Charge as a laser charges and Shot plays as
		-- it fires, heard out to LaserHearing.
		Look = {
			ChompRate = 3,
			Smooth = 15,
			MinStride = 18,
			MaxStride = 56,
			StridePerSpeed = 0.7,
			Lift = 12,
			JawOpen = 35,
			Grip = 8,
			ChompOpen = 25,
			TailSway = 6,
			TailRate = 0.4,
			Roar = "rbxassetid://9125474229",
			RoarPitch = 0.35,
			RoarVolume = 1,
			RoarHearing = 900,
			RoarJaw = 1.2,
			Charge = "rbxassetid://9125973984",
			Shot = "rbxassetid://9116227010",
			LaserVolume = 1,
			LaserHearing = 700,
		},
		-- Its eye lasers (Laser, run by Parks.CityKaiju), at cars too far
		-- to bite that its eyes can see past the buildings, ground or air.
		-- The eyes glow over Charge; the aim locks Lock before the shot, so
		-- a swerve dodges it. A struck car is blasted up and away, which
		-- starts a run like a launch pad and pays
		-- Tuning.Score.TargetPoints.Zapped on it (ScoreService), with no
		-- damage: the server keeps the run armed and measures no hit for
		-- Grace while the blast reaches the driver's game. Eyes is the spot
		-- between the eyes in the head's frame; the beam shows for BeamTime
		-- (KaijuLook).
		Laser = {
			MinRange = 140,
			MaxRange = 500,
			Charge = 1.5,
			Lock = 0.4,
			Cooldown = 5,
			Cancel = 1.5,
			BeamRadius = 10,
			Lift = 200,
			Push = 60,
			Keep = 0.5,
			Gravity = Tuning.World.Gravity,
			Eyes = Vector3.new(0, 7, -4),
			BeamTime = 0.35,
			Grace = 1.5,
		},
	},
	-- Walkers on the curbs who dive out of a car's way (Pedestrians, run by
	-- Parks.CityPedestrians). Each goes round a loop at the bottom of the
	-- curve in front of the buildings, a lane in from the road, crossing the
	-- road at corners: round each cross street out to the FarAlley-th alley,
	-- and round the avenue beside each of AvenueBlocks (not block 1, where
	-- the overpass is low over the avenue).
	Pedestrians = {
		Lanes = { 2, 6 },
		FarAlley = 3,
		CornerIn = 10, -- clear of the railway's and overpass's pillars
		AvenueBlocks = { 2, 3, 4 },
		Count = 80,
		Seed = 23,
		MinSpeed = 5,
		MaxSpeed = 7,
		Rate = 10, -- server steps a second
		EyeHeight = 5, -- what a walker sees past the buildings from
		AirHeight = 8, -- a car's middle higher than this above the floor is in the air, unseen
		NearMissBonus = 50, -- cash, paid at once (ScoreService)
		-- What each walker does about a car (Pedestrian): times in seconds,
		-- distances in studs.
		Dodge = {
			SeeDistance = 80,
			SeeTime = 1.2,
			SeeSpeed = 15,
			DiveRadius = 12,
			NearMiss = 12,
			HitRadius = 5,
			HitHeight = 10,
			DiveTime = 0.35,
			DiveDistance = 7,
			DiveDown = 0.6,
			FlopTime = 0.4,
			FlopDistance = 10,
			FlopDown = 1.2,
			GetUp = 0.6,
			Fist = 1.4,
			ReturnSpeed = 6,
			Cooldown = 10,
			-- Downtown's kaiju this near makes it run round its loop FleeRate
			-- times as fast, away, until the kaiju is CalmRadius off.
			FleeRadius = 120,
			CalmRadius = 180,
			FleeRate = 2.5,
		},
		-- Each client draws only the nearest DrawCount walkers within
		-- DrawRange of its camera (PedestrianLook).
		DrawCount = 10,
		DrawRange = 300,
		-- People sitting in Downtown's roof gardens (CityRoofs' GardenSeat
		-- seats): a Share of the seats, picked from Seed, each dodging cars
		-- like a walker whose loop never moves (CityPedestrians).
		Sitters = {
			Share = 0.6,
			Seed = 5,
		},
		-- How they are drawn (PedestrianLook): angles in degrees.
		Look = {
			Recline = 55, -- leaning back on a lounger
			SitArms = 20, -- sitting, hands forward on the lap
			Stride = 4, -- studs walked per step with each foot
			LegSwing = 30,
			ArmSwing = 25,
			Bob = 0.15,
			DiveHop = 1.5, -- how high a dive arcs
			FlopHop = 3, -- how high being knocked flat throws it
			-- What it carries flies FlyFurther on past where it lands, FlyHeight
			-- up at the top, and lands FlyExtra seconds after it does.
			FlyFurther = 6,
			FlyHeight = 8,
			FlyExtra = 0.35,
			LieReach = 6, -- lying down, feet to fingertips: how far it checks the ground rises
			DogSide = 1.8, -- to its right
			DogAhead = 1,
			BubbleDistance = 150,
			-- Sounds, all Pro Sound Effects, from each walker: a whoosh as it
			-- dives, a grunt as it is knocked flat, a thud as it lands from
			-- either, and its dog yapping while it is busy (a coyote's bark,
			-- sped up), every YapEvery seconds.
			Hearing = 150,
			Whoosh = { Id = "rbxassetid://9120711172", Pitch = 1.2, Volume = 0.6 },
			Grunt = { Id = "rbxassetid://9120417632", Pitch = 1.1, Volume = 0.8 },
			Thud = { Id = "rbxassetid://9113480917", Pitch = 1, Volume = 0.8 },
			Yap = { Id = "rbxassetid://9113955728", Pitch = 1.6, Volume = 0.6 },
			YapEvery = 0.8,
			-- Fleeing the kaiju: a scream as it starts to run, its legs swinging
			-- FleeSwing times as far, and one of FleeLines in its bubble.
			Scream = { Id = "rbxassetid://9125905021", Pitch = 1.1, Volume = 0.5 },
			FleeSwing = 1.5,
			FleeLines = { "RUN!", "KAIJU!", "AAAH!", "NOT AGAIN!", "SAVE YOURSELVES!" },
			-- Said getting up from a dive, picked by when it dived.
			Lines = { "WATCH IT!", "I'M WALKING HERE!", "HEY!", "LEARN TO DRIVE!", "ROAD HOG!", "SLOW DOWN!" },
			-- Said getting up after being knocked flat, about what it carried.
			PropLines = {
				Coffee = "MY COFFEE!",
				Briefcase = "MY PAPERS!",
				Phone = "I'M ON A CALL!",
				Newspaper = "I WAS READING THAT!",
				Dog = "WATCH THE DOG!",
			},
		},
	},
}

-- The skate park (ServerScriptService.Parks.Skate). X and Z are studs from
-- the park's center; the arrival point is at X -300, Z 800, facing -Z. Each
-- launcher has a runway from RunwayZ toward -Z, and resets put the car at its
-- start. Ramps are CurvedWall pieces: Radius and Angle shape the curve.
Tuning.Skate = {
	WallThickness = 2,
	-- Straight ahead of the arrival: a kicker over a gap onto a long landing
	-- ramp. At 220 a straight launch comes down on the landing ramp.
	Mega = {
		X = -300,
		LipZ = 450,
		Width = 40,
		RunwayZ = 860,
		KickRadius = 60,
		KickAngle = 35,
		KickSteps = 10,
		PadPlanks = 4,
		LaunchSpeed = 220,
		Gap = 260, -- from the kicker's lip to the top of the landing ramp
		LandWidth = 60,
		LandRadius = 500,
		LandAngle = 20,
		LandSteps = 16,
		DeckDepth = 10, -- flat top on the landing ramp
	},
	-- A pad strip into a vertical quarter pipe: straight up, then back down.
	Vert = {
		X = -700,
		BaseZ = 400, -- where the curve starts
		Width = 50,
		RunwayZ = 750,
		Radius = 40,
		Steps = 12,
		PadLength = 50,
		LaunchSpeed = 200,
		DeckDepth = 20,
	},
	-- A ramp all around the outside leads up to the rim from any side, with
	-- booster pads at its foot. Drop in, ride up any part of the wall, and the
	-- pads around its top launch the car up and out over the lip.
	Bowl = {
		X = 400,
		Z = -280,
		FloorRadius = 240,
		Radius = 120, -- with Angle 80, a wall about 99 studs high
		Angle = 80,
		-- Many small planks, so a car riding the wall crosses folds of about
		-- 3 degrees instead of bumping over bigger ones.
		Steps = 24,
		Slices = 144,
		PadPlanks = 4, -- per slice, at the top of the wall
		LaunchSpeed = 220,
		BermRun = 213, -- the outside ramp, from its foot in to the rim: about 25 degrees
		BermSteps = 8,
		BermSlices = 96,
		BoostSpeed = 190, -- the bottom ring of the outside ramp
		-- The Bowl Gap: take off anywhere from GapInside below the rim out to
		-- GapOutside past the outside ramp's foot, and come down in the same
		-- ring at least GapAngle degrees around.
		GapInside = 60,
		GapOutside = 60,
		GapAngle = 120,
	},
	-- A swing set: Count giant swings (Tuning.Swing) in a row, a kicker in
	-- front aiming at the seats, and a deck at each end of the row lined up
	-- with an end seat at the bottom of its swing. Unturned, the row runs
	-- along X and the kicker is on the +Z side; Turn turns the whole set
	-- about the middle of its pivot line (90 puts the kicker on the +X side,
	-- -90 on the -X side, which then needs X moved about 200 east).
	Swings = {
		X = -480,
		Z = -500, -- the middle of the pivot line
		Turn = 90, -- degrees
		Count = 3,
		Spacing = 60, -- between seat centers
		SeatHeight = 12, -- the seat's top face above the floor, hanging still
		StartAngles = { 35, -15, 20 }, -- degrees, so the seats swing out of step
		LegGap = 20, -- from the outer seats' edges to the legs
		LegSpread = 60, -- each leg's foot, out from the pivot line along Z
		LipDistance = 76, -- from the pivot line to the kicker's lip
		KickRadius = 40,
		KickAngle = 35,
		KickSteps = 8,
		PadPlanks = 3,
		LaunchSpeed = 110, -- lands about LipDistance on, near the bottom of the seats' swing
		RunwayLength = 200,
		DeckGap = 2, -- from the end seats' edges
		DeckLength = 40,
		DeckWidth = 30,
		RampLength = 60,
	},
	-- Tall walls with pads along the bottom of both, so a car rolling toward
	-- either wall is boosted up it and into the air, then comes back down and
	-- across to the other: back and forth.
	HalfPipe = {
		X = -700,
		Z = -470,
		FlatWidth = 60,
		Radius = 70,
		Angle = 110, -- leaning back past vertical keeps launches over the pipe
		Steps = 14,
		Length = 800,
		PadPlanks = 3, -- per wall, from the bottom
		LaunchSpeed = 220,
		DeckDepth = 20,
	},
	-- Knocked flying by a car, back in place after Tuning.Props.ResetTime.
	Props = {
		ConeSpacing = 40,
		ConeStartZ = 820,
		ConeEndZ = 520,
		ConeX = 26, -- either side of the Mega Ramp's runway
		Benches = {
			{ X = -360, Z = 770, Turn = 0 },
			{ X = -240, Z = 770, Turn = 0 },
			{ X = -560, Z = 600, Turn = 90 },
			{ X = -440, Z = 600, Turn = 90 },
			{ X = -40, Z = 560, Turn = 90 },
			{ X = -600, Z = -30, Turn = 0 },
		},
	},
	Rails = {
		X = -500,
		StartZ = 650,
		Length = 500,
		Count = 3,
		Spacing = 30,
		Height = 3,
		PostSpacing = 50,
	},
	-- A ramp up to a deck, then stairs down toward -Z with a handrail to grind
	-- along each side. TopZ is where the stairs start, at the deck's edge.
	Stairs = {
		X = 450,
		TopZ = 700,
		Height = 30,
		Steps = 20,
		StepDepth = 6,
		Width = 40,
		DeckDepth = 40,
		RampLength = 140,
		RailHeight = 3, -- above the line of the step noses
		RailInset = 3, -- in from each side of the stairs
	},
	-- Two small kickers back to back with a flat deck between, for free play.
	Funbox = {
		X = -100,
		Z = 500,
		Width = 40,
		Radius = 60,
		Angle = 25,
		Steps = 8,
		DeckLength = 30,
	},
}

-- Dino Valley (ServerScriptService.Parks.Dino), the prehistoric park. X and
-- Z are studs from the park's center.
Tuning.Dino = {
	Thickness = 2,
	PayScale = 0.6,
	-- The brontosaurus (Bronto): drive up its tail from the ground, over its
	-- back and up its neck, and launch off the top of its head. The path
	-- leaves the tail tip at X, StartZ facing Heading degrees (0 faces -Z,
	-- positive turns left), from the park's northwest corner across to its
	-- southeast corner, the longest way to land. Its planks are its skin;
	-- the body hangs Depth under them, on legs at Hips and Shoulders (studs
	-- along the path). Every BoostEvery planks is a booster; the head's
	-- planks launch.
	Bronto = {
		X = -950,
		StartZ = 1050,
		Heading = -42,
		Step = 5,
		Start = { Width = 30, Depth = 2 },
		Segments = {
			{ Length = 150, Angle = 15, Width = 40, Depth = 14 }, -- the tail lifts off the ground
			{ Length = 150, Angle = 15, Width = 50, Depth = 30 },
			-- Over the hips, easing off 11 degrees over 150, a crest radius of
			-- about 780, so a car at 200 studs/s stays on.
			{ Length = 150, Angle = 4, Width = 60, Depth = 50 },
			{ Length = 250, Angle = 4, Width = 60, Depth = 55 }, -- the back
			{ Length = 300, Angle = 40, Width = 32, Depth = 22 }, -- the neck curves up
			{ Length = 36, Angle = 40, Width = 36, Depth = 20 }, -- the top of the head
		},
		Hips = 400,
		Shoulders = 670,
		LegSize = 24,
		BoostEvery = 6,
		BoostSpeed = 200,
		LaunchSpeed = 320,
		-- The back is rounded (Bronto.crown): flat over the middle Flat of
		-- its width, rolling down over Strips strips each side to Drop times
		-- the width below at the edges, so 6 down on the 60-wide back.
		Crown = { Flat = 0.5, Drop = 0.1, Strips = 3 },
		-- Cars pass through that skin and drive on an invisible track: flat
		-- over the middle Flat of the width, then a straight lip up each edge
		-- like the corkscrew track's, Height times the width high: 9 up on
		-- the back and about 5 on the neck, 37 degrees (the corkscrew's are
		-- 28), so it pushes a drifting car back in. More Strips curve it.
		-- The lips start flat at From studs along the path, where the tail
		-- starts to lift, and grow to full height over Grow, so a car still
		-- on the ground never meets them.
		Lip = { Flat = 0.6, Height = 0.15, Strips = 1, From = 30, Grow = 60 },
		-- Only for looks. Spots on the back from the tail tip to the neck,
		-- wrinkle bands across the neck from WrinklesFrom (studs along the
		-- path) every WrinkleEvery planks, and round scales along both edges
		-- every ScaleEvery studs.
		Spots = { Count = 70, From = 30, To = 700, MinSize = 3, MaxSize = 9, Seed = 65 },
		WrinklesFrom = 700,
		WrinkleEvery = 3,
		ScaleEvery = 12,
		-- The tail's tip, lying on the ground Height tall and swishing side to
		-- side (DinoTail, on each client). It starts where the path has risen
		-- to Height, as wide as the back there, and runs Length past the
		-- path's start in blocks about Length / Segments long, narrowing to
		-- TipWidth. Past the path's start it bends up to Swing degrees at the
		-- tip, once each way every Period seconds. Spots of the back's dark
		-- spots lie on it, and the back's booster stripes carry on along it.
		Tail = { Length = 90, Segments = 9, TipWidth = 4, Height = 1, Swing = 50, Period = 4, Spots = 6 },
	},
	-- Palm trees dotted about the park (Scatter): Count of them at least Gap
	-- apart, Edge in from the park's edges, and clear of the brontosaurus
	-- (BrontoClear from its line, tail to head) and the arrival point. Each
	-- trunk is solid, bending over by up to Lean at the top; its fronds are
	-- only for looks. Driving or flying into a tree drops its coconuts onto
	-- the car (PropService): an invisible box round the trunk, Hit across so a car
	-- brushing it counts, and one round the fronds. In the air on a run it
	-- pays Tuning.Score.TargetPoints["Palm tree"]. Everything is back up
	-- after ResetTime seconds.
	Palms = {
		Count = 45,
		Seed = 12,
		Gap = 100,
		Edge = 80,
		BrontoClear = 80,
		ArrivalClear = 120,
		MinHeight = 40,
		MaxHeight = 62,
		Lean = 10,
		TrunkSize = 4,
		TrunkSegments = 6,
		Fronds = 8,
		FrondLength = 22,
		Coconuts = 4,
		CoconutSize = 3,
		Hit = 14,
		ResetTime = 6,
		VolcanoClear = 30, -- past the volcano's lava lake
	},
	-- Bushes the raptors hide in, as many as Palms.Count, scattered with
	-- their own Seed over the same ground as the palms, so they fall near a
	-- tree only by chance. Each is Blobs leafy balls, MinWidth to MaxWidth
	-- across and MinHeight to MaxHeight tall. Cars drive straight through,
	-- and each client rustles a bush a car moves through (Bush).
	Bushes = {
		Seed = 31,
		Gap = 60,
		MinWidth = 18,
		MaxWidth = 26,
		MinHeight = 9,
		MaxHeight = 13,
		Blobs = 6,
		Rustle = {
			MinSpeed = 4,
			Rise = 5,
			Fade = 1.5,
			Tilt = 12,
			Rate = 2.5,
		},
	},
	-- Mounds of dirt with a flat top TopWidth by TopLength, Top high (Mound):
	-- Count of them scattered with their own Seed over the palms' ground,
	-- Gap apart, facing any way. Each reaches Spread out from its top in
	-- Rings, rounding each corner in CornerSteps, so a car drives up from any
	-- side. The top is an any-way launch pad, throwing a car whichever way it
	-- is going at LaunchSpeed, LaunchPitch degrees up. Nothing else stands
	-- within Room of its middle, and no palm within Room + PalmClear. A wreck
	-- or reset puts the car Approach studs out from the mound, facing its
	-- end. Bushes and dinos keep Clear from the mound.
	Mounds = {
		Count = 6,
		Seed = 47,
		Gap = 400,
		TopLength = 44,
		TopWidth = 14,
		Top = 8,
		Spread = 30,
		Rings = 5,
		CornerSteps = 2,
		LaunchSpeed = 200,
		LaunchPitch = 25,
		Approach = 30,
		Room = 90,
		PalmClear = 10,
		Clear = 10,
	},
	-- The volcano in the park's southwest corner (Volcano): a hollow blocky
	-- cone of Tiers, each a ring of blocks at most BlockWidth across, Shell
	-- thick, stepping in from BaseRadius at the foot to TopRadius at the rim,
	-- Height up. Tops stand up to Jitter higher, so the ledges look rocky.
	-- Its middle is at X, Z in the park, its front facing Heading (degrees,
	-- 0 faces -Z, positive turns left), toward the park's middle. A round
	-- tube shaped like Tuning.City.Tunnels climbs inside (Tunnel.volcano,
	-- Climb; SliceAngle degrees of turn per ring of planks). Its mouth is
	-- set into the foot in front, Climb.Inset from the middle, on the line
	-- Climb.Radius to the right of it, at the end of a rock Causeway across
	-- the lava lake that rings the foot out to Lake.Radius. Round the tube
	-- the cone's blocks are left out Slot.Half each side, on the tiers
	-- below Slot.Top, and rebuilt in blocks at most Slot.Column wide, with a
	-- face on each tier's step that fits round the tube. The tube comes up
	-- through the crater floor under a rock dome that steps in DomeStep at
	-- a time as the tube inside sinks, and out level along a rock path
	-- PathWidth wide to the vent, which erupts the car out of the crater;
	-- the rest of the floor is lava, in strips StripWidth wide. Rivers run
	-- lava down the outside from the rim, Down tiers, at Yaw degrees round
	-- from the back.
	Volcano = {
		X = -520,
		Z = -620,
		Heading = -135,
		Seed = 7,
		Cone = {
			BaseRadius = 400,
			TopRadius = 230,
			Height = 285,
			TierHeight = 18,
			Shell = 40,
			BlockWidth = 50,
			Jitter = 5,
		},
		Climb = {
			Radius = 100,
			Pitch = 72,
			Loops = 2,
			Inset = 368, -- the foot, where the slot's far side meets it
			LevelRun = 80, -- just the mouth on the crater floor
			Outside = 33,
			FloorThickness = 2,
			SliceAngle = 7.5,
		},
		Crater = {
			PathWidth = 80,
			StripWidth = 12,
			DomeStep = 12,
			-- The vent: a ramp on the path Run past the tube's mouth, curving
			-- up to Angle degrees round Radius in Steps planks. Its planks
			-- steeper than PadFrom degrees are pads pushing the car up the
			-- curve to LaunchSpeed, so it leaves the lip Angle degrees up
			-- however fast it came, out over the rim and the lake (at 80 it
			-- comes down in the lake). The lip must stay inside the rim
			-- (Cone.TopRadius less Cone.Shell from the middle).
			Vent = { Run = 15, Radius = 30, Angle = 70, Steps = 12, PadFrom = 30, LaunchSpeed = 320 },
		},
		Slot = { Half = 56, Top = 63, Column = 10 },
		-- In front of the vent the crater wall above the floor is only Shell
		-- thick (Cone.Shell elsewhere), Half degrees either side of where the
		-- vent's line meets the rim, so it stands back from an eruption.
		Breach = { Half = 30, Shell = 15 },
		-- Only for looks, on each client (VolcanoEruption): when a car flies
		-- up off the vent faster than UpSpeed, the crater erupts. Spray
		-- drops of lava and Smoke puffs burst out of the vent, a light
		-- flashes Glow bright and fades over GlowTime, and Rocks glowing
		-- lumps MinRock to MaxRock across fly up at MinSpeed to MaxSpeed,
		-- within Spread degrees of straight up, and are gone after
		-- RockTime seconds. Each car erupts it at most every Cooldown
		-- seconds.
		-- Smoke rising from the whole crater all the time (VolcanoEruption,
		-- on each client): Rate puffs a second, MinSize to MaxSize across as
		-- they grow, rising at MinRise to MaxRise studs a second, drifting
		-- Drift studs a second faster each second toward +X, lasting about
		-- Lifetime seconds. Thickness is how see-through they are at their
		-- thickest, 0 solid to 1 gone.
		Smoke = {
			Rate = 3,
			MinSize = 30,
			MaxSize = 90,
			MinRise = 8,
			MaxRise = 18,
			Drift = 1.5,
			Lifetime = 12,
			Thickness = 0.45,
		},
		Eruption = {
			UpSpeed = 120,
			Spray = 120,
			Smoke = 30,
			Glow = 8,
			GlowTime = 2,
			Rocks = 14,
			MinRock = 2,
			MaxRock = 6,
			MinSpeed = 120,
			MaxSpeed = 280,
			Spread = 25,
			RockTime = 5,
			Cooldown = 2,
		},
		Causeway = { Width = 110 },
		Lake = { Radius = 500, BlockWidth = 60 },
		-- A ring of boulders round the lake's outside edge, Depth deep and
		-- MinHeight to MaxHeight tall, at most Width across, with no gaps a
		-- car fits through, open at the causeway. A car slower than BreakSpeed
		-- bumps off; a faster one smashes through (PropService), taking
		-- Tuning.Toughness.BoulderDamagePerSpeed over it, and the boulder is
		-- back after ResetTime.
		Boulders = {
			Width = 14,
			Depth = 10,
			MinHeight = 5,
			MaxHeight = 10,
			BreakSpeed = 120,
			ResetTime = 5,
		},
		Rivers = {
			{ Yaw = 125, Down = 9 },
			{ Yaw = 215, Down = 6 },
			{ Yaw = 290, Down = 11 },
		},
	},
	-- The T-Rex (Rex, run by Parks.DinoRex on the server): roams wherever
	-- the palm trees may stand, starting at X, Z facing Heading, picking
	-- spots to walk to from Seed, and hunts cars. Rex says what each number
	-- does. Speeds are studs per second; RunSpeed is under every car's top
	-- speed (80 at the bottom of the ladder), so a car that keeps going gets
	-- away. Body is how far its middle stays from the trees' edges and
	-- keep-outs. Reach and BiteHeight are how far ahead of its hips and how
	-- high its jaws snap. A car it catches is lifted and shaken for Grip
	-- seconds with no harm done: EscapeJets seconds of jets in that time, or
	-- a SlipChance roll at its end, drop it free and level, and the T-Rex
	-- rests Stun seconds. Otherwise it is chewed for Chew seconds, its
	-- toughness draining evenly to a wreck (ScoreService), and the T-Rex
	-- rests Rest seconds once it is gone.
	Rex = {
		X = 550,
		Z = 650,
		Heading = 45,
		Seed = 3,
		WalkSpeed = 20,
		RunSpeed = 70,
		Accel = 40,
		TurnRate = 50,
		Sight = 300,
		Lose = 500,
		RoamRadius = 500,
		GoalReach = 30,
		GoalTime = 40,
		Body = 60,
		Neck = 40,
		Reach = 120,
		BiteHeight = 110,
		Cone = 40,
		WindUp = 0.6,
		AirWindUp = 0.25,
		Snap = 0.2,
		Recover = 1.2,
		Rest = 2,
		Grip = 1.5,
		EscapeJets = 0.6,
		SlipChance = 0.3,
		Stun = 3,
		Chew = 2,
		Bite = 16,
		AirHeight = 8,
		Gravity = Tuning.World.Gravity,
		-- Where its head goes, in the frame of its hips on the ground facing
		-- -Z (Parks.DinoRex moves it; TRexLook draws it). It stands at Rest,
		-- looking away from Shoulders; pulls Back over a lunge's wind-up; and
		-- holds a car lower, at Hold, tipped HoldTip degrees nose down. A
		-- held car's middle is CarDrop under the head and as far out its
		-- front as leaves the back CarIn studs of the car in its mouth; a
		-- snap brings that spot to the bite.
		Head = {
			Size = Vector3.new(20, 17, 36),
			Rest = Vector3.new(0, 90, -76),
			Back = Vector3.new(0, 102, -58),
			Shoulders = Vector3.new(0, 86, -44),
			Hold = Vector3.new(0, 78, -80),
			HoldTip = -20,
			CarDrop = 4,
			CarIn = 2,
		},
		-- How it is drawn on each client (TRexLook), only for looks. It
		-- glides after the server's T-Rex, Smooth per second. Each foot
		-- steps Stride studs (MinStride standing, growing StridePerSpeed for
		-- each stud per second to MaxStride), lifting Lift high. The jaw
		-- opens JawOpen degrees for a lunge, Grip holding a car and ChompOpen
		-- at the top of each chomp, ChompRate times a second. The tail
		-- sways TailSway degrees each way TailRate times a second. Spotting a
		-- car, it roars: the raptors' screech (Raptors.Look.Screech) played
		-- RoarPitch times as fast, so deeper, heard out to RoarHearing studs.
		Look = {
			Roar = "rbxassetid://9125474229",
			RoarPitch = 0.5,
			RoarVolume = 1,
			RoarHearing = 600,
			Smooth = 15,
			MinStride = 16,
			MaxStride = 50,
			StridePerSpeed = 0.6,
			Lift = 10,
			JawOpen = 35,
			Grip = 8,
			ChompOpen = 25,
			ChompRate = 3,
			TailSway = 8,
			TailRate = 0.5,
		},
	},
	-- The pterodactyl (Ptero; Parks.DinoPtero runs it). It perches on a
	-- rock spire at X, Z in the park facing Heading degrees, takes off after
	-- PerchTime and circles CruiseHeight up at CruiseSpeed, over the same
	-- ground as the T-Rex. It swoops on a car on the ground within Sight:
	-- Warn seconds of warning, then a dive up to DiveSpeed that drops up to
	-- DiveDrop studs a second; its talons within Grab of the car's top grab
	-- it. A car that takes off, gets past Lose or lasts SwoopTime of diving
	-- gets away, and it flies Recover seconds before hunting again. A grabbed
	-- car is carried round a spiral CarryRadius across, kept CarryEdge
	-- inside the park, at CarrySpeed, climbing CarryClimb studs a second to
	-- CarryHeight above the floor, and dropped there. EscapeJets seconds of
	-- jets drop it sooner, and FumbleChance of grabs fumble it somewhere
	-- between FumbleFrom and FumbleTo up. The drop starts a run, its height
	-- counted from the ground, paying PayScale of its cash, and no hits count
	-- for DropGrace seconds while the driver's game takes the car back. Then
	-- it flies home and perches.
	-- The spire stands Spire.Height, in Tiers of rock blocks from
	-- BaseWidth to TopWidth across, a nest NestWidth across on top; the
	-- T-Rex and the palms keep Clear past its foot.
	Ptero = {
		X = 950,
		Z = 700,
		Heading = 55,
		Seed = 4,
		Spire = {
			Height = 250,
			Tiers = 10,
			BaseWidth = 90,
			TopWidth = 40,
			Twist = 25, -- most degrees a tier turns from the one below
			NestWidth = 50,
			NestSticks = 10,
			Clear = 40,
		},
		CruiseHeight = 300,
		CruiseSpeed = 70,
		TurnRate = 40,
		Accel = 60,
		ClimbRate = 40,
		Edge = 250,
		GoalReach = 60,
		GoalTime = 30,
		Sight = 400,
		AirHeight = 8,
		Warn = 1.5,
		DiveSpeed = 150,
		DiveTurnRate = 90,
		DiveDrop = 150,
		SwoopTime = 6,
		Lose = 600,
		Grab = 14,
		CarTop = Tuning.Chassis.HullSize.Y / 2,
		Recover = 5,
		CarryHeight = 800,
		CarryClimb = 110,
		CarrySpeed = 90,
		CarryRadius = 150,
		CarryEdge = 450,
		EscapeJets = 0.6,
		FumbleChance = 0.3,
		FumbleFrom = 250,
		FumbleTo = 650,
		PerchTime = 10,
		PerchReach = 20,
		PayScale = 0.6,
		DropGrace = 1,
		-- How it is drawn on each client (PteroLook), only for looks. It
		-- glides after the server's pterodactyl, Smooth per second, banks
		-- into turns up to MostBank degrees and tips up or down with its
		-- climb up to MostPitch. Its wings beat FlapRate times a second,
		-- FlapAngle degrees each way, faster and harder carrying a car, swept
		-- back in a dive and folded on its perch. Its shadow, ShadowSize
		-- across, lies on the ground under it, darker the lower it flies.
		-- Starting a swoop, it screeches (Screech, a Pro Sound Effects
		-- pterodactyl screech, played ScreechPitch times as fast), heard out
		-- to ScreechHearing studs.
		Look = {
			Screech = "rbxassetid://9125474505",
			ScreechPitch = 1,
			ScreechVolume = 1,
			ScreechHearing = 800,
			Smooth = 12,
			MostBank = 40,
			MostPitch = 35,
			FlapRate = 0.9,
			FlapAngle = 22,
			CarryFlapRate = 1.8,
			CarryFlapAngle = 35,
			ShadowSize = 36,
		},
	},
	-- Packs of three velociraptors that hide behind the mounds or in the
	-- bushes and ambush cars (Raptors; Parks.DinoRaptors runs them). Speeds
	-- are studs a second: WalkSpeed between covers, SneakSpeed slipping
	-- round a mound or heading back, RunSpeed chasing, all at most Accel
	-- studs a second faster each second and turning TurnRate degrees a
	-- second. Distances are studs. A raptor stays Body inside the palms'
	-- ground and clear of its keep-outs, though not of the mounds. Seconds:
	-- BiteEvery, PinTime, ChaseTime, Rest, Cooldown (how long a pack leaves
	-- a car it attacked alone), and StayMin to StayMax (how long it stays at
	-- a cover with no car near). A car is in the air with nothing
	-- under its middle within AirProbe. A latched raptor sits at its
	-- Slots spot in its car's frame (a pinned player's root's for Pin), its
	-- middle Stand above the ground otherwise. Each bite takes BiteDamage of
	-- the car's full toughness (ScoreService). Shaking a pack off pays
	-- ShakeBonus cash at once, and surviving its bites SurviveBonus.
	Raptors = {
		Packs = 3,
		Seed = 21,
		WalkSpeed = 30,
		SneakSpeed = 45,
		RunSpeed = 110,
		Accel = 300,
		TurnRate = 540,
		Body = 4,
		Watch = 400,
		Ambush = 120,
		HideGap = 8,
		Spacing = 9,
		Wide = 12,
		ViaReach = 8,
		Lead = 0.3,
		LatchReach = 10,
		ChaseTime = 6,
		Lose = 250,
		StopSpeed = 4,
		BiteEvery = 1,
		Bites = 5,
		PinTime = 2.5,
		Rest = 5,
		Cooldown = 20,
		StayMin = 30,
		StayMax = 60,
		BiteDamage = 0.05,
		ShakeBonus = 150,
		SurviveBonus = 100,
		AirProbe = 6,
		Stand = 3.5,
		Slots = {
			Roof = Vector3.new(0, 3.5, 0),
			Hood = Vector3.new(0, 3, -4.5),
			Trunk = Vector3.new(0, 3, 4.5),
			Left = Vector3.new(-7, 0.5, 0),
			Right = Vector3.new(7, 0.5, 0),
			Pin = Vector3.new(0, 0, -3),
		},
		-- How each client draws them (RaptorLook): the riding raptors' blocks
		-- (CarVisuals) Scale times bigger, gliding after the server's part
		-- Smooth per second, and onto a car over LatchBlend seconds. Running,
		-- a stride is Stride studs, the legs swing LegSwing degrees and the
		-- body bobs Bob studs, both full by FullSpeed. The tail sways TailSway
		-- degrees TailRate times a second, more running. Crouching drops the
		-- body Crouch studs. A bite opens the jaw JawOpen degrees for BiteOpen
		-- seconds, then snaps it shut over BiteSnap. Springing an ambush, each
		-- screeches (Screech, played MinPitch to MaxPitch times as fast, up to
		-- ScreechDelay seconds apart); each bite snaps (Snap, played
		-- SnapMinPitch to SnapMaxPitch times as fast). Both are Pro Sound
		-- Effects sounds, heard out to Hearing studs.
		Look = {
			Scale = 3.2,
			Smooth = 15,
			LatchBlend = 0.2,
			Stride = 10,
			LegSwing = 40,
			Bob = 0.5,
			FullSpeed = 60,
			TailSway = 12,
			TailRate = 1.2,
			Crouch = 0.9,
			JawOpen = 40,
			BiteOpen = 0.15,
			BiteSnap = 0.1,
			Screech = "rbxassetid://9125474229",
			ScreechVolume = 0.8,
			MinPitch = 1.15,
			MaxPitch = 1.45,
			ScreechDelay = 0.3,
			Snap = "rbxassetid://9119056795",
			SnapVolume = 0.35,
			SnapMinPitch = 0.75,
			SnapMaxPitch = 0.9,
			Hearing = 300,
		},
	},
}

return Tuning
