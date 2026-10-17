--!strict
-- WreckSparks (LocalScript) -> StarterPlayerScripts.WreckSparks
-- Bursts sparks wherever a car wrecks. The server says where on
-- ReplicatedStorage.CarWrecked; particles are drawn on each client, so the
-- burst is made here.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local SPARK_COLOR = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 120, 30))
local SPARK_LIFE = 2 -- seconds before the emitter is removed, past the longest spark

local function burst(position: Vector3)
	local part = Instance.new("Part")
	part.Name = "WreckSparks"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.new(position)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Enabled = false
	sparks.Speed = NumberRange.new(30, 70)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(0.4, 0.9)
	sparks.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
	sparks.LightEmission = 1
	sparks.Color = SPARK_COLOR
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Parent = part
	part.Parent = workspace
	sparks:Emit(Tuning.Toughness.WreckSparks)
	Debris:AddItem(part, SPARK_LIFE)
end

local remote = ReplicatedStorage:WaitForChild("CarWrecked")
if remote:IsA("RemoteEvent") then
	remote.OnClientEvent:Connect(burst)
else
	warn("WreckSparks: ReplicatedStorage.CarWrecked is not a RemoteEvent; no wreck sparks")
end
