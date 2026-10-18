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

Tuning.Contact = {
	ProbeMargin = 0.6, -- extra ray length past the wheel radius
	AirDelay = 0.1,
	LandWheels = 2,
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

return Tuning
