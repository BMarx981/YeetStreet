--!strict
-- GunFx (ModuleScript) -> StarterPlayerScripts.GunFx
-- Draws a PlaneCar's shots: a glowing streak from the muzzle to where the
-- shot stopped, and sparks there if it hit a car. The shooter's game draws
-- its own shots at once (CarController); everyone else's come from the
-- server on ReplicatedStorage.GunShot.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local G = Tuning.Guns

local TRACER_COLOR = Color3.fromRGB(255, 220, 90)
local SPARK_COLOR = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 120, 30))
local SPARK_LIFE = 1 -- seconds before the sparks' part is removed, past the longest spark

local GunFx = {}

local function sparks(position: Vector3)
	local part = Instance.new("Part")
	part.Name = "ShotSparks"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Speed = NumberRange.new(20, 40)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.2, 0.5)
	emitter.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
	emitter.LightEmission = 1
	emitter.Color = SPARK_COLOR
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = part
	part.Parent = workspace
	emitter:Emit(G.HitSparks)
	Debris:AddItem(part, SPARK_LIFE)
end

function GunFx.shot(from: Vector3, to: Vector3, hit: boolean)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local tracer = Instance.new("Part")
	tracer.Name = "Tracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = TRACER_COLOR
	tracer.Size = Vector3.new(0.3, 0.3, length)
	tracer.CFrame = CFrame.lookAt((from + to) / 2, to)
	tracer.Parent = workspace
	Debris:AddItem(tracer, G.TracerTime)
	if hit then
		sparks(to)
	end
end

function GunFx.start()
	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild("GunShot")
		if not remote:IsA("RemoteEvent") then
			warn("GunFx: ReplicatedStorage.GunShot is not a RemoteEvent; other players' shots stay hidden")
			return
		end
		remote.OnClientEvent:Connect(GunFx.shot)
	end)
end

return GunFx
