--!strict
-- CarSounds (ModuleScript) -> StarterPlayerScripts.CarSounds
-- The engine loop on every car in workspace.Cars that has a driver, made on
-- this client from Tuning.CarSounds.Engine. Its pitch and volume follow the
-- car's speed (EngineSound), and the local player's car also revs with the
-- gas CarController passes to CarSounds.drive. Other players' cars play
-- lower and quieter, fade in from Tuning.EngineSound.Reach, and only the
-- closest few play. Their gas isn't known here, and a short ray along each
-- one's down says whether it is in the air.
-- Each of those cars also plays the jet loop (Tuning.CarSounds.Jet) while
-- its JetsBurning attribute is true, the same way lower and quieter on
-- other players' cars.
-- A wreck anywhere plays one of the Wreck crunches at random where it
-- happened (ReplicatedStorage.CarWrecked), and the local player's hard hits
-- thud, louder the harder they are (CarImpact, CrashSound).
-- During a replay the local player's car goes quiet (hideOwn), and the
-- ghost's sounds (ReplaySounds) use loop, play, and crunch from here.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local CrashSound = require(ReplicatedStorage.CrashSound)
local EngineSound = require(ReplicatedStorage.EngineSound)
local Tuning = require(ReplicatedStorage.Tuning)

local CarSounds = {}

local E = Tuning.EngineSound
local C = Tuning.CrashSound
local SPEC = Tuning.CarSounds.Engine
local JET = Tuning.CarSounds.Jet
local WRECKS = Tuning.CarSounds.Wreck
local HIT = Tuning.CarSounds.Hit

local HULL_WAIT = 30 -- seconds to wait for a new car's hull to replicate
local WRECK_LIFE = 6 -- seconds before a wreck's sound is removed, past the longest crunch

export type Spec = { Id: string, Pitch: number, Volume: number }

type Engine = {
	car: Model,
	hull: BasePart,
	own: boolean,
	sound: Sound,
	pitch: number, -- where the engine has glided to, before SPEC.Pitch
	volume: number, -- before SPEC.Volume
	jet: Sound,
	jetVolume: number, -- before JET.Volume
}

local player = Players.LocalPlayer
local engines: { Engine } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- The local player's gas and whether their car is in the air, from CarController.
local gas = 0
local airborne = false

-- Whether the local player's car is hidden for a replay, which has its own sounds.
local ownHidden = false

-- Called by CarController every step while the local player drives.
function CarSounds.drive(throttle: number, inAir: boolean)
	gas = throttle
	airborne = inAir
end

-- Fades the local player's car out while a replay hides it (ReplayPlayer),
-- and back in after.
function CarSounds.hideOwn(hidden: boolean)
	ownHidden = hidden
end

local function driven(e: Engine): boolean
	local seat = e.car:FindFirstChild("DriverSeat")
	return seat ~= nil and seat:IsA("Seat") and seat.Occupant ~= nil
end

local function flying(e: Engine): boolean
	return workspace:Raycast(e.hull.Position, -e.hull.CFrame.UpVector * E.GroundProbe, rayParams) == nil
end

-- A silent looped sound on the hull that fades out by Reach (OwnReach for
-- the local player's car).
function CarSounds.loop(name: string, spec: Spec, own: boolean, hull: BasePart): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = spec.Id
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = if own then E.OwnFullDistance else E.OthersFullDistance
	sound.RollOffMaxDistance = if own then E.OwnReach else E.Reach
	sound.Parent = hull
	return sound
end

-- Sets a loop's pitch and volume, playing it only while it can be heard.
function CarSounds.play(sound: Sound, spec: Spec, pitch: number, volume: number)
	if volume > 0 then
		sound.PlaybackSpeed = spec.Pitch * pitch
		sound.Volume = spec.Volume * volume
		if not sound.Playing then
			sound.Playing = true
		end
	elseif sound.Playing then
		sound.Playing = false
	end
end

local random = Random.new()

-- One of the Wreck crunches, heard by everyone near where the car wrecked.
-- `pitch` multiplies the crunch's own, 1 if not given.
function CarSounds.crunch(position: Vector3, pitch: number?)
	local spec = WRECKS[CrashSound.pick(#WRECKS, random:NextNumber())]
	local part = Instance.new("Part")
	part.Name = "WreckSound"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.new(position)
	local sound = Instance.new("Sound")
	sound.SoundId = spec.Id
	sound.PlaybackSpeed = spec.Pitch * (pitch or 1)
	sound.Volume = spec.Volume
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = C.WreckFullDistance
	sound.RollOffMaxDistance = C.WreckReach
	sound.Parent = part
	part.Parent = workspace
	sound:Play()
	Debris:AddItem(part, WRECK_LIFE)
end

-- The local player's thud, made up front so it has loaded by the first hit,
-- and played again for each hard hit.
local thud = Instance.new("Sound")
thud.Name = "CarHit"
thud.SoundId = HIT.Id
thud.PlaybackSpeed = HIT.Pitch
thud.Parent = SoundService
local thudAt = -math.huge

local function hit(strength: number)
	local now = os.clock()
	local volume = CrashSound.hitVolume(strength, now - thudAt, C)
	if volume <= 0 then
		return
	end
	thudAt = now
	thud.Volume = HIT.Volume * volume
	thud.TimePosition = 0
	thud:Play()
end

local function add(car: Model)
	local hull = car:WaitForChild("Hull", HULL_WAIT)
	if not (hull and hull:IsA("BasePart")) or car.Parent == nil then
		return
	end
	local own = car:GetAttribute("OwnerUserId") == player.UserId
	table.insert(engines, {
		car = car,
		hull = hull,
		own = own,
		sound = CarSounds.loop("Engine", SPEC, own, hull),
		pitch = E.IdlePitch,
		volume = 0,
		jet = CarSounds.loop("Jet", JET, own, hull),
		jetVolume = 0,
	})
end

local function update(dt: number)
	for i = #engines, 1, -1 do
		if engines[i].car.Parent == nil then
			table.remove(engines, i)
		end
	end

	-- Only the closest few other cars with a driver play.
	local camera = workspace.CurrentCamera
	local listener = if camera then camera.CFrame.Position else Vector3.zero
	local others: { Engine } = {}
	local distances: { number } = {}
	for _, e in engines do
		if not e.own and driven(e) then
			table.insert(others, e)
			table.insert(distances, (e.hull.Position - listener).Magnitude)
		end
	end
	local picked = EngineSound.nearest(distances, E.MaxOthers, E.Reach)
	local playing: { [Engine]: boolean } = {}
	for i, e in others do
		if picked[i] then
			playing[e] = true
		end
	end

	for _, e in engines do
		local on = if e.own then driven(e) and not ownHidden else playing[e] == true
		local pitch, volume = e.pitch, 0
		if on then
			local topSpeed = e.car:GetAttribute("TopSpeed")
			local speed = e.hull.AssemblyLinearVelocity:Dot(e.hull.CFrame.LookVector)
			pitch, volume = EngineSound.target(
				speed,
				if typeof(topSpeed) == "number" then topSpeed else 0,
				if e.own then gas else 0,
				if e.own then airborne else flying(e),
				e.own,
				E
			)
		end
		e.pitch = EngineSound.approach(e.pitch, pitch, E.PitchRate, dt)
		e.volume = EngineSound.approach(e.volume, volume, E.VolumeRate, dt)
		CarSounds.play(e.sound, SPEC, e.pitch, e.volume)

		local jetPitch, jetVolume = EngineSound.jet(on and e.car:GetAttribute("JetsBurning") == true, e.own, E)
		e.jetVolume = EngineSound.approach(e.jetVolume, jetVolume, E.JetFadeRate, dt)
		CarSounds.play(e.jet, JET, jetPitch, e.jetVolume)
	end
end

function CarSounds.start()
	task.spawn(function()
		local folder = workspace:WaitForChild("Cars")
		rayParams.FilterDescendantsInstances = { folder }
		folder.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				add(child)
			end
		end)
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				task.spawn(add, child)
			end
		end
		RunService.RenderStepped:Connect(update)
	end)
	task.spawn(function()
		local wrecked = ReplicatedStorage:WaitForChild("CarWrecked")
		if not wrecked:IsA("RemoteEvent") then
			warn("CarSounds: ReplicatedStorage.CarWrecked is not a RemoteEvent; wrecks stay silent")
			return
		end
		wrecked.OnClientEvent:Connect(function(position: any)
			if typeof(position) == "Vector3" then
				CarSounds.crunch(position)
			end
		end)
	end)
	task.spawn(function()
		local impact = ReplicatedStorage:WaitForChild("CarImpact")
		if not impact:IsA("RemoteEvent") then
			warn("CarSounds: ReplicatedStorage.CarImpact is not a RemoteEvent; hits stay silent")
			return
		end
		impact.OnClientEvent:Connect(function(strength: any)
			if typeof(strength) == "number" then
				hit(strength)
			end
		end)
	end)
end

return CarSounds
