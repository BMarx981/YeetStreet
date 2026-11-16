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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EngineSound = require(ReplicatedStorage.EngineSound)
local Tuning = require(ReplicatedStorage.Tuning)

local CarSounds = {}

local E = Tuning.EngineSound
local SPEC = Tuning.CarSounds.Engine
local JET = Tuning.CarSounds.Jet

local HULL_WAIT = 30 -- seconds to wait for a new car's hull to replicate

type Spec = { Id: string, Pitch: number, Volume: number }

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

-- Called by CarController every step while the local player drives.
function CarSounds.drive(throttle: number, inAir: boolean)
	gas = throttle
	airborne = inAir
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
local function loop(name: string, spec: Spec, own: boolean, hull: BasePart): Sound
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
local function play(sound: Sound, spec: Spec, pitch: number, volume: number)
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
		sound = loop("Engine", SPEC, own, hull),
		pitch = E.IdlePitch,
		volume = 0,
		jet = loop("Jet", JET, own, hull),
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
		local on = if e.own then driven(e) else playing[e] == true
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
		play(e.sound, SPEC, e.pitch, e.volume)

		local jetPitch, jetVolume = EngineSound.jet(on and e.car:GetAttribute("JetsBurning") == true, e.own, E)
		e.jetVolume = EngineSound.approach(e.jetVolume, jetVolume, E.JetFadeRate, dt)
		play(e.jet, JET, jetPitch, e.jetVolume)
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
end

return CarSounds
