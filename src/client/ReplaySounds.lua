--!strict
-- ReplaySounds (ModuleScript) -> StarterPlayerScripts.ReplaySounds
-- The ghost's sounds while ReplayPlayer plays a replay: the engine loop
-- following the ghost's speed (EngineSound, with no gas, which the tape
-- doesn't keep), the jet loop while the clip's jets burn, and a wreck crunch
-- as the replay plays over the moment the car wrecked (the clip's Wrecked
-- flip). They follow the replay's clock like the flames: lower and slower in
-- slow motion, silent while paused, and a seek over the wreck doesn't crunch.
-- The engine and jets go quiet once the car has wrecked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EngineSound = require(ReplicatedStorage.EngineSound)
local ReplayClock = require(ReplicatedStorage.ReplayClock)
local ReplayTape = require(ReplicatedStorage.ReplayTape)
local Tuning = require(ReplicatedStorage.Tuning)
local CarSounds = require(script.Parent.CarSounds)

local E = Tuning.EngineSound
local SPEC = Tuning.CarSounds.Engine
local JET = Tuning.CarSounds.Jet

local ReplaySounds = {}

export type Sounds = {
	part: BasePart, -- moved to the ghost's pose, carrying its loops
	engine: Sound,
	jet: Sound,
	pitch: number, -- where the engine has glided to, before SPEC.Pitch
	volume: number, -- before SPEC.Volume
	jetVolume: number, -- before JET.Volume
	topSpeed: number,
	wreckAt: number?, -- clip time the car wrecked, nil if it didn't
	time: number, -- the clip time last shown
	ground: RaycastParams,
}

-- The ghost's sounds for `clip`, in `ghost`, so they go when it does. `look`
-- is the replay's car attributes, and `ground` leaves out the ghost and cars.
function ReplaySounds.start(
	ghost: Model,
	clip: ReplayTape.Clip<CFrame>,
	look: { [string]: any },
	ground: RaycastParams
): Sounds
	local part = Instance.new("Part")
	part.Name = "Sounds"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Parent = ghost
	local topSpeed = look.TopSpeed
	return {
		part = part,
		engine = CarSounds.loop("Engine", SPEC, true, part),
		jet = CarSounds.loop("Jet", JET, true, part),
		pitch = E.IdlePitch,
		volume = 0,
		jetVolume = 0,
		topSpeed = if typeof(topSpeed) == "number" then topSpeed else 0,
		wreckAt = ReplayTape.switchedOn(clip, "Wrecked"),
		time = 0,
		ground = ground,
	}
end

-- Plays the ghost's sounds at the clock's time. `pose` is where the ghost is
-- and `speed` how fast it goes along its nose there; `dt` is real time.
function ReplaySounds.show(
	s: Sounds,
	clip: ReplayTape.Clip<CFrame>,
	clock: ReplayClock.Clock,
	pose: CFrame,
	speed: number,
	dt: number
)
	s.part.CFrame = pose
	local wreckAt = s.wreckAt
	if wreckAt and ReplayClock.passed(clock, s.time, wreckAt, dt) then
		CarSounds.crunch(pose.Position)
	end
	s.time = clock.time

	local running = not (wreckAt and clock.time >= wreckAt)
	local pitch, volume = s.pitch, 0
	if running then
		local airborne = workspace:Raycast(pose.Position, -pose.UpVector * E.GroundProbe, s.ground) == nil
		pitch, volume = EngineSound.target(speed, s.topSpeed, 0, airborne, true, E)
	end
	local jetPitch, jetVolume = EngineSound.jet(running and ReplayTape.lit(clip, "JetsBurning", clock.time), true, E)
	s.pitch = EngineSound.approach(s.pitch, pitch, E.PitchRate, dt)
	s.volume = EngineSound.approach(s.volume, volume, E.VolumeRate, dt)
	s.jetVolume = EngineSound.approach(s.jetVolume, jetVolume, E.JetFadeRate, dt)
	if clock.paused then
		s.volume = 0
		s.jetVolume = 0
	end
	CarSounds.play(s.engine, SPEC, s.pitch * clock.speed, s.volume)
	CarSounds.play(s.jet, JET, jetPitch * clock.speed, s.jetVolume)
end

return ReplaySounds
