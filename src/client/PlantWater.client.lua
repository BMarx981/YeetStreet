--!strict
-- PlantWater (LocalScript) -> StarterPlayerScripts.PlantWater
-- Draws the hot water in the nuclear plant's cooling towers from the server's
-- clock (CoolingTower.eruption), so every player sees the same thing: calm, then
-- boiling harder and whiter as a warning, then a jet up through the top of the
-- tower, with sounds to match. In a replay it shows the moment being watched
-- (ReplayWorld). CarController throws its own car. The water parts are tagged
-- TowerWater (Parks.Plant). Particles are drawn on each client, so they are made
-- here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoolingTower = require(ReplicatedStorage.CoolingTower)
local Tuning = require(ReplicatedStorage.Tuning)
local ReplayWorld = require(script.Parent.ReplayWorld)

local W = Tuning.Plant.Water
local L = W.Look
local WATER: CoolingTower.Water = W :: any

local WHITE = Color3.fromRGB(245, 250, 250)
local JET_CLEAR = 0.15 -- the jet's transparency at its thickest

type Look = {
	part: BasePart,
	tower: number,
	bubbles: ParticleEmitter,
	steam: ParticleEmitter,
	spray: ParticleEmitter,
	jet: Part,
	boil: Sound,
	boom: Sound,
	hiss: Sound,
	lastBurst: number?,
}

local looks: { [Instance]: Look } = {}

local function jetPart(): Part
	local jet = Instance.new("Part")
	jet.Name = "TowerJet"
	jet.Shape = Enum.PartType.Cylinder
	jet.Anchored = true
	jet.CanCollide = false
	jet.CanQuery = false
	jet.CanTouch = false
	jet.CastShadow = false
	jet.Material = Enum.Material.Neon
	jet.Color = WHITE
	jet.Transparency = 1
	jet.Size = Vector3.new(1, 2 * L.Jet.Radius, 2 * L.Jet.Radius)
	jet.Parent = workspace
	return jet
end

-- The part's +X is straight up, as it is a cylinder on its side.
local function emitter(part: BasePart): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = Enum.NormalId.Right
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 0
	e.LightEmission = 0.3
	e.Parent = part
	return e
end

local function sound(part: BasePart, id: string, pitch: number, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = pitch
	s.Volume = volume
	s.RollOffMaxDistance = L.Sound.Hearing
	s.Parent = part
	return s
end

local function track(instance: Instance)
	local tower = instance:GetAttribute("Tower")
	if not instance:IsA("BasePart") or typeof(tower) ~= "number" then
		return
	end

	local bubbles = emitter(instance)
	bubbles.Color = ColorSequence.new(WHITE)
	bubbles.Size = NumberSequence.new(2.5, 0.5)
	bubbles.Transparency = NumberSequence.new(0.2, 0.8)
	bubbles.Lifetime = NumberRange.new(0.3, 0.7)
	bubbles.Speed = NumberRange.new(4, 14)
	bubbles.SpreadAngle = Vector2.new(20, 20)

	local steam = emitter(instance)
	steam.Color = ColorSequence.new(WHITE)
	steam.Size = NumberSequence.new(8, 26)
	steam.Transparency = NumberSequence.new(0.6, 1)
	steam.Lifetime = NumberRange.new(2, 3.5)
	steam.Speed = NumberRange.new(20, 45)
	steam.SpreadAngle = Vector2.new(15, 15)

	local spray = emitter(instance)
	spray.Color = ColorSequence.new(WHITE)
	spray.Size = NumberSequence.new(6, 2)
	spray.Transparency = NumberSequence.new(0.1, 0.9)
	spray.Lifetime = NumberRange.new(1.5, 3)
	spray.Speed = NumberRange.new(150, 320)
	spray.SpreadAngle = Vector2.new(12, 12)
	spray.Acceleration = Vector3.new(0, -workspace.Gravity * 0.6, 0)

	local S = L.Sound
	local boil = sound(instance, S.Boil.Id, S.Boil.CalmPitch, S.Boil.CalmVolume)
	boil.Looped = true
	boil:Play()

	looks[instance] = {
		part = instance,
		tower = tower,
		bubbles = bubbles,
		steam = steam,
		spray = spray,
		jet = jetPart(),
		boil = boil,
		boom = sound(instance, S.Boom.Id, S.Boom.Pitch, S.Boom.Volume),
		hiss = sound(instance, S.Hiss.Id, S.Hiss.Pitch, S.Hiss.Volume),
		lastBurst = nil,
	}
end

CollectionService:GetInstanceAddedSignal("TowerWater"):Connect(track)
CollectionService:GetInstanceRemovedSignal("TowerWater"):Connect(function(instance: Instance)
	local look = looks[instance]
	if look then
		look.jet:Destroy()
		looks[instance] = nil
	end
end)
for _, instance in CollectionService:GetTagged("TowerWater") do
	track(instance)
end

local function drawJet(look: Look, since: number)
	local J = L.Jet
	local jet = look.jet
	local life = J.Rise + J.Fade
	if since >= life then
		if jet.Transparency < 1 then
			jet.Transparency = 1
		end
		return
	end
	local height = math.max(1, J.Height * math.min(since / J.Rise, 1))
	local base = look.part.Position
	jet.Size = Vector3.new(height, 2 * J.Radius, 2 * J.Radius)
	jet.CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local fading = math.clamp((since - J.Rise) / J.Fade, 0, 1)
	jet.Transparency = JET_CLEAR + (1 - JET_CLEAR) * fading
end

RunService.Heartbeat:Connect(function()
	local now = ReplayWorld.serverTime()
	local B = L.Sound.Boil
	for _, look in looks do
		local phase, progress, number = CoolingTower.eruption(WATER, now, look.tower)
		local heat = if phase == "calm" then 0 elseif phase == "boil" then progress else 1
		look.part.Color = L.Calm:Lerp(L.Hot, heat)
		look.bubbles.Rate = L.Bubbles.Calm + (L.Bubbles.Boil - L.Bubbles.Calm) * heat
		look.steam.Rate = L.Steam.Calm + (L.Steam.Boil - L.Steam.Calm) * heat
		if phase == "burst" and look.lastBurst ~= number then
			look.lastBurst = number
			look.spray:Emit(L.Spray)
			look.boom:Play()
			look.hiss:Play()
		end
		look.boil.Volume = B.CalmVolume + (B.Volume - B.CalmVolume) * heat
		look.boil.PlaybackSpeed = B.CalmPitch + (B.Pitch - B.CalmPitch) * heat
		drawJet(look, CoolingTower.sinceBurst(WATER, now, look.tower))
	end
end)
