--!strict
-- VolcanoEruption (LocalScript) -> StarterPlayerScripts.VolcanoEruption
-- Dino Valley's volcano erupts whenever a car flies up off its vent
-- (Parks.Dino), anyone's car this client can see: lava spray and smoke
-- burst out of the vent, a glow flashes and fades, and glowing lava rocks
-- are thrown up out of the crater and fall back. In between, smoke rises
-- from the whole crater all the time. Only for looks, built on each
-- client: the rocks are in the Props collision group, so they never touch
-- a car, and cars' rays skip them. Numbers are in
-- Tuning.Dino.Volcano.Eruption and Tuning.Dino.Volcano.Smoke.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local Tunnel = require(ReplicatedStorage.Tunnel)
local Volcano = require(ReplicatedStorage.Volcano)

local V = Tuning.Dino.Volcano
local E = V.Eruption

local LAVA_COLORS = { Color3.fromRGB(255, 96, 24), Color3.fromRGB(255, 140, 40), Color3.fromRGB(230, 60, 20) }
local GLOW_COLOR = Color3.fromRGB(255, 120, 40)
-- How high over the lip the rocks start, clear of the ramp.
local ROCK_START = 8

local area = MapLayout.find(Tuning.Map.Areas :: any, "Dino")
if not area then
	return
end

-- The vent in the volcano's own space (Tunnel.volcano): its foot on the
-- crater floor Run past the tube's mouth, its lip up the curve from there.
local base = CFrame.new(area.X + V.X, Tuning.Map.FloorTop, area.Z + V.Z) * CFrame.Angles(0, math.rad(V.Heading), 0)
local tube = Tunnel.volcano(V.Climb :: any, Tuning.City.Tunnels :: any)
local vent = V.Crater.Vent
local footZ = tube.mouth.z - vent.Run
local lipZ, lipUp = Volcano.lip(footZ, vent.Radius, vent.Angle)
local ventX = tube.mouth.x
local halfWidth = V.Crater.PathWidth / 2

-- An invisible anchor at the lip for the spray, the smoke and the glow.
local anchor = Instance.new("Part")
anchor.Name = "VolcanoVent"
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.Transparency = 1
anchor.Size = Vector3.new(halfWidth, 1, 10)
anchor.CFrame = base * CFrame.new(ventX, tube.floor + lipUp, lipZ)
anchor.Parent = workspace

local spray = Instance.new("ParticleEmitter")
spray.Rate = 0
spray.LightEmission = 1
spray.Color = ColorSequence.new(LAVA_COLORS[2], LAVA_COLORS[3])
spray.Size = NumberSequence.new(4, 1)
spray.Lifetime = NumberRange.new(2, 3.5)
spray.Speed = NumberRange.new(E.MinSpeed * 0.5, E.MaxSpeed * 0.8)
spray.SpreadAngle = Vector2.new(E.Spread, E.Spread)
spray.Acceleration = Vector3.new(0, -workspace.Gravity * 0.6, 0)
spray.Parent = anchor

local smoke = Instance.new("ParticleEmitter")
smoke.Rate = 0
smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
smoke.Color = ColorSequence.new(Color3.fromRGB(70, 60, 56), Color3.fromRGB(40, 36, 34))
smoke.Size = NumberSequence.new(12, 40)
smoke.Transparency = NumberSequence.new(0.2, 1)
smoke.Lifetime = NumberRange.new(4, 6)
smoke.Speed = NumberRange.new(30, 70)
smoke.SpreadAngle = Vector2.new(20, 20)
smoke.RotSpeed = NumberRange.new(-30, 30)
smoke.Acceleration = Vector3.new(0, 4, 0)
smoke.Parent = anchor

local glow = Instance.new("PointLight")
glow.Brightness = 0
glow.Range = 60
glow.Color = GLOW_COLOR
glow.Parent = anchor

-- Smoke rising from the whole crater floor, all the time, from an
-- invisible slab across the crater.
local S = V.Smoke
local rim = V.Cone.TopRadius - V.Cone.Shell
local crater = Instance.new("Part")
crater.Name = "VolcanoCrater"
crater.Anchored = true
crater.CanCollide = false
crater.CanQuery = false
crater.CanTouch = false
crater.Transparency = 1
crater.Size = Vector3.new(rim * 1.4, 1, rim * 1.4)
crater.CFrame = base * CFrame.new(0, tube.floor + 5, 0)
crater.Parent = workspace

-- The :dino admin command puts the park away; the volcano hides with it.
local enabled = ReplicatedStorage:WaitForChild("DinoValleyEnabled", 30)
if enabled then
	local function setShown(shown: boolean)
		anchor.Parent = if shown then workspace else nil
		crater.Parent = if shown then workspace else nil
	end
	setShown(enabled.Value)
	enabled.Changed:Connect(setShown)
end

local plume = Instance.new("ParticleEmitter")
plume.Rate = S.Rate
plume.Texture = "rbxasset://textures/particles/smoke_main.dds"
plume.Color = ColorSequence.new(Color3.fromRGB(96, 86, 80), Color3.fromRGB(60, 54, 50))
plume.Size = NumberSequence.new(S.MinSize, S.MaxSize)
plume.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.15, S.Thickness),
	NumberSequenceKeypoint.new(1, 1),
})
plume.Lifetime = NumberRange.new(S.Lifetime * 0.8, S.Lifetime * 1.2)
plume.Speed = NumberRange.new(S.MinRise, S.MaxRise)
plume.SpreadAngle = Vector2.new(10, 10)
plume.RotSpeed = NumberRange.new(-15, 15)
plume.Rotation = NumberRange.new(0, 360)
plume.Acceleration = Vector3.new(S.Drift, 1, 0)
plume.LightInfluence = 1
plume.Parent = crater

local random = Random.new()

local function throwRock()
	local size = random:NextNumber(E.MinRock, E.MaxRock)
	local rock = Instance.new("Part")
	rock.Name = "LavaRock"
	rock.Size = Vector3.new(size, size * random:NextNumber(0.6, 1), size * random:NextNumber(0.6, 1))
	rock.Color = LAVA_COLORS[random:NextInteger(1, #LAVA_COLORS)]
	rock.Material = Enum.Material.Neon
	rock.CanQuery = false
	rock.CanTouch = false
	-- Props never touch cars or drivers. Without the group (unexpected), the
	-- rock passes through everything instead.
	if not pcall(function()
		rock.CollisionGroup = "Props"
	end) then
		rock.CanCollide = false
	end
	rock.CFrame = anchor.CFrame
		* CFrame.new(random:NextNumber(-halfWidth / 2, halfWidth / 2), ROCK_START, random:NextNumber(-5, 5))
		* CFrame.Angles(random:NextNumber(0, math.pi), random:NextNumber(0, math.pi), 0)
	rock.Parent = workspace
	local tilt = math.rad(random:NextNumber(0, E.Spread))
	local around = random:NextNumber(0, 2 * math.pi)
	local direction = base:VectorToWorldSpace(
		Vector3.new(math.sin(tilt) * math.cos(around), math.cos(tilt), math.sin(tilt) * math.sin(around))
	)
	rock.AssemblyLinearVelocity = direction * random:NextNumber(E.MinSpeed, E.MaxSpeed)
	rock.AssemblyAngularVelocity =
		Vector3.new(random:NextNumber(-6, 6), random:NextNumber(-6, 6), random:NextNumber(-6, 6))
	Debris:AddItem(rock, E.RockTime)
end

local function erupt()
	spray:Emit(E.Spray)
	smoke:Emit(E.Smoke)
	glow.Brightness = E.Glow
	TweenService:Create(glow, TweenInfo.new(E.GlowTime), { Brightness = 0 }):Play()
	for _ = 1, E.Rocks do
		throwRock()
	end
end

-- A car on the vent's upper half or just off its lip, going up fast.
local function erupting(hull: BasePart): boolean
	local p = base:PointToObjectSpace(hull.Position)
	return math.abs(p.X - ventX) < halfWidth
		and p.Z < footZ
		and p.Z > lipZ - 30
		and p.Y > tube.floor
		and p.Y < tube.floor + lipUp + 40
		and hull.AssemblyLinearVelocity.Y > E.UpSpeed
end

local carsFolder = workspace:WaitForChild("Cars")
local lastErupted: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

RunService.Heartbeat:Connect(function()
	if not (enabled and enabled.Value) then
		return
	end
	local now = os.clock()
	for _, car in carsFolder:GetChildren() do
		local hull = car:FindFirstChild("Hull")
		if hull and hull:IsA("BasePart") and now - (lastErupted[car] or -math.huge) > E.Cooldown and erupting(hull) then
			lastErupted[car] = now
			erupt()
		end
	end
end)
