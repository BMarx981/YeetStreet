--!strict
-- VolcanoEruption (LocalScript) -> StarterPlayerScripts.VolcanoEruption
-- Dino Valley's volcano erupts whenever a car flies up off its vent
-- (Parks.Dino), anyone's car this client can see, or the ghost in a replay:
-- lava spray and smoke burst out of the vent, and just after, behind the car,
-- the crater blows: a flash, a shock ring and a boom, then a fountain of lava,
-- glowing rocks, and a column of fire cooling to smoke. In between, smoke rises
-- from the whole crater all the time. Only for looks, built on each client:
-- the rocks are in the Props collision group, so they never touch a car, and
-- cars' rays skip them. Numbers are in Tuning.Dino.Volcano.Eruption and
-- Tuning.Dino.Volcano.Smoke.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local Tunnel = require(ReplicatedStorage.Tunnel)
local Volcano = require(ReplicatedStorage.Volcano)

local ReplayWorld = require(script.Parent.ReplayWorld)

local V = Tuning.Dino.Volcano
local E = V.Eruption

local LAVA_COLORS = { Color3.fromRGB(255, 96, 24), Color3.fromRGB(255, 140, 40), Color3.fromRGB(230, 60, 20) }
local GLOW_COLOR = Color3.fromRGB(255, 120, 40)
-- How far across the crater's middle the rocks and the fire start.
local BLAST_REACH = 60

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
local zone = Volcano.boostZone(tube.mouth.x, tube.mouth.z, tube.floor, vent :: any)

-- An invisible anchor at the lip for the spray and the smoke.
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

-- The eruption's parts, the fountain at the crater's middle among them.
local blast = Instance.new("Folder")
blast.Name = "VolcanoBlast"
blast.Parent = workspace

local middle = Instance.new("Part")
middle.Name = "VolcanoFountain"
middle.Anchored = true
middle.CanCollide = false
middle.CanQuery = false
middle.CanTouch = false
middle.Transparency = 1
middle.Size = Vector3.new(BLAST_REACH * 2, 1, BLAST_REACH * 2)
middle.CFrame = base * CFrame.new(0, tube.floor + 5, 0)
middle.Parent = blast

local fountain = Instance.new("ParticleEmitter")
fountain.Rate = 0
fountain.LightEmission = 1
fountain.Color = ColorSequence.new(LAVA_COLORS[2], LAVA_COLORS[3])
fountain.Size = NumberSequence.new(E.FountainSize, E.FountainSize / 3)
fountain.Lifetime = NumberRange.new(3, 5)
fountain.Speed = NumberRange.new(E.FountainMinSpeed, E.FountainMaxSpeed)
fountain.SpreadAngle = Vector2.new(E.Spread, E.Spread)
fountain.Acceleration = Vector3.new(0, -workspace.Gravity * 0.6, 0)
fountain.Parent = middle

local glow = Instance.new("PointLight")
glow.Brightness = 0
glow.Range = E.GlowRange
glow.Color = GLOW_COLOR
glow.Parent = middle

-- The :dino admin command puts the park away; the volcano hides with it.
local enabled = ReplicatedStorage:WaitForChild("DinoValleyEnabled", 30)
if enabled then
	local function setShown(shown: boolean)
		anchor.Parent = if shown then workspace else nil
		crater.Parent = if shown then workspace else nil
		blast.Parent = if shown then workspace else nil
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
	rock.CFrame = middle.CFrame
		* CFrame.new(random:NextNumber(-BLAST_REACH, BLAST_REACH), 0, random:NextNumber(-BLAST_REACH, BLAST_REACH))
		* CFrame.Angles(random:NextNumber(0, math.pi), random:NextNumber(0, math.pi), 0)
	rock.Parent = blast
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

-- A part that only shows, from the same few lines as SiloBlast's.
local function ghost(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = "Blast"
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Parent = blast
	return part
end

local function flash()
	local at = middle.Position
	local ball = ghost(Enum.PartType.Ball, Vector3.one * 20, CFrame.new(at), E.Fire)
	TweenService:Create(ball, TweenInfo.new(E.FlashTime, Enum.EasingStyle.Quad), {
		Size = Vector3.one * E.FlashSize,
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, E.FlashTime + 0.1)
	-- A cylinder lying flat, its axis up, at the rim.
	local rimAt = base:PointToWorldSpace(Vector3.new(0, V.Cone.Height, 0))
	local ring = ghost(
		Enum.PartType.Cylinder,
		Vector3.new(1, 20, 20),
		CFrame.new(rimAt) * CFrame.Angles(0, 0, math.pi / 2),
		E.Fire
	)
	TweenService:Create(ring, TweenInfo.new(E.RingTime, Enum.EasingStyle.Quad), {
		Size = Vector3.new(1, E.RingSize, E.RingSize),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, E.RingTime + 0.1)
	local sound = Instance.new("Sound")
	sound.SoundId = E.BoomId
	sound.Volume = E.BoomVolume
	sound.RollOffMaxDistance = E.BoomReach
	sound.Parent = middle
	sound:Play()
	Debris:AddItem(sound, 10)
end

-- A ball of fire that climbs the column, growing and cooling to smoke.
local function puff()
	local start = middle.Position
		+ Vector3.new(random:NextNumber(-BLAST_REACH, BLAST_REACH), 0, random:NextNumber(-BLAST_REACH, BLAST_REACH))
	local part = ghost(Enum.PartType.Ball, Vector3.one * 30, CFrame.new(start), E.Fire)
	local spread = E.PuffSpread
	local to = start
		+ Vector3.new(
			random:NextNumber(-spread, spread),
			E.PuffRise * random:NextNumber(0.6, 1),
			random:NextNumber(-spread, spread)
		)
	TweenService:Create(part, TweenInfo.new(E.PuffTime, Enum.EasingStyle.Quad), {
		CFrame = CFrame.new(to),
		Size = Vector3.one * E.PuffSize * random:NextNumber(0.6, 1),
	}):Play()
	TweenService:Create(part, TweenInfo.new(E.PuffTime * 0.3, Enum.EasingStyle.Sine), { Color = E.PuffSmoke }):Play()
	task.delay(E.PuffTime * 0.6, function()
		TweenService:Create(part, TweenInfo.new(E.PuffTime * 0.4, Enum.EasingStyle.Sine), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(part, E.PuffTime + 0.1)
end

local eruptingUntil = 0

-- The burst at the vent now, and the crater blowing behind the car just
-- after. Another launch while it erupts only makes it last longer.
local function erupt()
	spray:Emit(E.Spray)
	smoke:Emit(E.Smoke)
	task.delay(E.Delay, function()
		local now = os.clock()
		if now >= eruptingUntil then
			flash()
		end
		eruptingUntil = now + E.Duration
	end)
end

local carsFolder = workspace:WaitForChild("Cars")
local lastErupted: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local wasErupting = false
local rocksDue, puffsDue = 0, 0
local ghostInZone = false

local function inVentZone(position: Vector3): boolean
	local p = base:PointToObjectSpace(position)
	return Volcano.inZone(zone, p.X, p.Y, p.Z)
end

RunService.Heartbeat:Connect(function(dt: number)
	if not (enabled and enabled.Value) then
		return
	end
	local now = os.clock()
	for _, car in carsFolder:GetChildren() do
		local hull = car:FindFirstChild("Hull")
		if
			hull
			and hull:IsA("BasePart")
			and now - (lastErupted[car] or -math.huge) > E.Cooldown
			and hull.AssemblyLinearVelocity.Y > E.UpSpeed
			and inVentZone(hull.Position)
		then
			lastErupted[car] = now
			erupt()
		end
	end

	-- A replay's ghost has no speed to read, so it erupts as it comes in.
	local pose = ReplayWorld.ghost()
	local ghostIn = pose ~= nil and inVentZone(pose.Position)
	if ghostIn and not ghostInZone then
		erupt()
	end
	ghostInZone = ghostIn

	local erupting = now < eruptingUntil
	if erupting ~= wasErupting then
		wasErupting = erupting
		fountain.Rate = if erupting then E.FountainRate else 0
		plume.Rate = if erupting then S.EruptRate else S.Rate
		if erupting then
			glow.Brightness = E.Glow
		else
			TweenService:Create(glow, TweenInfo.new(E.GlowTime), { Brightness = 0 }):Play()
		end
	end
	if erupting then
		rocksDue += E.RockRate * dt
		puffsDue += E.PuffRate * dt
		while rocksDue >= 1 do
			rocksDue -= 1
			throwRock()
		end
		while puffsDue >= 1 do
			puffsDue -= 1
			puff()
		end
	end
end)
