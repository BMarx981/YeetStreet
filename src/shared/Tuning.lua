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
}

-- Economy: a run's server score pays out as cash.
Tuning.Cash = {
	PerPoint = 1,
	-- For development: in Studio only, each player's cash is topped up to this
	-- when they join. 0 turns it off. Studio saves to the same store as the game.
	StudioCash = 1_000_000,
}

-- Upgrade levels start at 0, which is Tuning.StarterCar. Each level adds Steps
-- to the real stats its upgrade drives: Speed drives TopSpeed; Jets drives
-- JetPower, JetFuel, FuelRecharge, and TurnRate; Toughness and Grip drive
-- their own. Friction is capped at 2 (rear wheels get Grip times
-- Chassis.RearGripFactor), so Grip steps stay small.
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
		Caps = { Speed = 10, Jets = 10, Toughness = 10, Grip = 10 },
		Seed = 1,
		Archetype = "pickup",
		Tier = "Junker",
	},
	{
		Id = "Hatchback",
		Name = "Hatchback",
		Price = 15000,
		Bonus = 4,
		Caps = { Speed = 20, Jets = 20, Toughness = 20, Grip = 20 },
		Seed = 1,
		Archetype = "hatch",
		Tier = "Street",
	},
	{
		Id = "Muscle",
		Name = "Muscle Car",
		Price = 75000,
		Bonus = 8,
		Caps = { Speed = 30, Jets = 24, Toughness = 30, Grip = 24 },
		Seed = 1,
		Archetype = "muscle",
		Tier = "Sports",
	},
	{
		Id = "Speed",
		Name = "Speed Car",
		Price = 100000,
		Bonus = 12,
		Caps = { Speed = 40, Jets = 30, Toughness = 36, Grip = 30 },
		Seed = 1,
		Archetype = "wedge",
		Tier = "Supercar",
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
}

Tuning.Righting = {
	StartUpY = 0.5, -- lying with no wheels down and tipped past this starts righting
	EndUpY = 0.95, -- righting stops here, or when LandWheels wheels touch
	LandWheels = 2,
	GroundProbe = 3.5, -- ground within this far below the hull counts as lying
	Rate = 4, -- radians per second
	SlowAngle = math.rad(30), -- eases off inside this angle of upright
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
}

-- Knockable props, like the distance boards. They never touch cars.
Tuning.Props = {
	HitRadius = 4, -- a car's hull center passing this close to a prop knocks it
	CarSpeedShare = 0.5, -- a knocked prop flies off at this fraction of the car's velocity
	Pop = 25, -- plus this much straight up, studs per second
	Spin = 6, -- tumble rate tipping it away from the car, radians per second
	ResetTime = 2.5, -- seconds until a knocked prop is back in place
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
	-- Wide buildings with a tunnel through: in from the avenue, an S of
	-- turns, and out onto the next cross street. Each takes the Columns by
	-- Rows lots nearest the avenue at the top of its block (1 is the first
	-- block past the arrival plaza). Side 1 is +X; the other side is the
	-- mirror image. The tunnel's walls are the building's foot curve, running
	-- on in through the mouths.
	Tunnels = {
		Floor = 40, -- flat between the curves
		Height = 40, -- floor to ceiling
		Columns = 2,
		Rows = 3,
		Slices = 6, -- per turn
		-- From the street side of the building back to where the middle line
		-- comes in from the avenue. The segments must end on the street side.
		EntryBack = 480,
		Segments = {
			{ Straight = 60 },
			{ Turn = -90, Radius = 80 }, -- toward the cross street
			{ Straight = 100 },
			{ Turn = 90, Radius = 80 },
			{ Turn = -90, Radius = 80 },
			{ Straight = 140 },
		},
		Places = {
			{ Side = 1, Block = 2 },
			{ Side = -1, Block = 3 },
			{ Side = 1, Block = 4 },
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

return Tuning
