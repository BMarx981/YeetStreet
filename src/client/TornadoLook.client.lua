--!strict
-- TornadoLook (LocalScript) -> StarterPlayerScripts.TornadoLook
-- Draws every tornado in workspace.Tornados (TornadoService) on this client,
-- from its Base part and its Height, Phase and PhaseAt attributes, and plays
-- its sounds. Nothing here touches physics or decides anything: catches and
-- throws are the server's.
--
-- Each one is drawn like a cartoon whirlwind. Its body is Levels rings of
-- Puffs see-through cloud puffs of mixed sizes, each whirling fast round the
-- middle at its own speed, bobbing, its distance off the middle wobbling, so
-- the outline churns; the whole funnel is as wide as Tornado.radiusAt says,
-- its top swaying round the base. Swoosh lines, a few pieces curving round the outside, nearly level,
-- pop up at random heights, whip round for a moment and fade, then pop up
-- somewhere else. Lumps of dark storm cloud whirl on top, bits of junk circle
-- and climb inside, and dust blows out where it touches the ground. While it
-- touches down the funnel grows down from the cloud, and while it lifts it
-- draws back up into it. Past Far from the camera the swooshes and junk stop;
-- with the camera in or right beside it, its puffs thin to PuffInside.
--
-- It roars from the middle of the funnel at the camera's height, and when it
-- throws a car out (its Throws attribute goes up) a whoosh plays at ThrowAt.
-- Numbers are in Tuning.Tornado.Look.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tornado = require(ReplicatedStorage.Tornado)
local Tuning = require(ReplicatedStorage.Tuning)

local T: Tornado.Tuning = Tuning.Tornado :: any
local L = Tuning.Tornado.Look
local TOUCH_TIME: number = Tuning.Tornado.TouchTime
local LIFT_TIME: number = Tuning.Tornado.LiftTime
local TAU = 2 * math.pi
local NO_AREA: Tornado.Area = { X = 0, Z = 0, Width = 0, Depth = 0 }

-- Rojo has synced some LocalScripts twice; one drawing is enough.
if workspace:FindFirstChild("TornadoLook") then
	return
end
local lookFolder = Instance.new("Folder")
lookFolder.Name = "TornadoLook"
lookFolder.Parent = workspace

local rolls = Random.new()

type Puff = {
	part: Part,
	level: number,
	angle: number,
	spin: number,
	wobble: number,
	wobbleRate: number,
	bob: number,
	bobRate: number,
}

type Swoosh = {
	parts: { Part },
	wait: number, -- seconds until it pops up, while hidden
	age: number,
	life: number, -- 0 while hidden
	up: number,
	angle: number,
	arc: number,
	spin: number,
	tilt: number,
	out: number,
}

type Lump = { part: Part, angle: number, spin: number, offset: number, lift: number }

type Junk = { part: Part, up: number, angle: number, out: number, tumble: Vector3 }

type Drawing = {
	model: Model,
	base: BasePart,
	height: number,
	shape: Tornado.State,
	folder: Folder,
	at: Vector3?,
	seed: number,
	puffs: { Puff },
	swooshes: { Swoosh },
	lumps: { Lump },
	junk: { Junk },
	dust: ParticleEmitter,
	dustPart: Part,
	voice: Part, -- where the roar plays from
}

local drawings: { [Model]: Drawing } = {}

local function piece(parent: Instance, color: Color3, size: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function setShown(part: BasePart, shown: boolean, transparency: number)
	local want = if shown then transparency else 1
	if part.Transparency ~= want then
		part.Transparency = want
	end
end

local function roll(range: { number }): number
	return rolls:NextNumber(range[1], range[2])
end

local function pick<V>(list: { V }): V
	return list[rolls:NextInteger(1, #list)]
end

local function sound(parent: Instance, settings: any): Sound
	local s = Instance.new("Sound")
	s.SoundId = settings.Id
	s.Volume = settings.Volume
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = settings.Near
	s.RollOffMaxDistance = settings.Reach
	s.Parent = parent
	return s
end

local function whoosh(at: Vector3)
	local spot = piece(lookFolder, Color3.new(), Vector3.one)
	spot.CFrame = CFrame.new(at)
	local s = sound(spot, L.Whoosh)
	s:Play()
	Debris:AddItem(spot, 4)
end

local function build(model: Model): Drawing?
	local base = model:FindFirstChild("Base")
	local height = model:GetAttribute("Height")
	if not (base and base:IsA("BasePart") and typeof(height) == "number") then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "Tornado"
	folder.Parent = lookFolder
	local shape = Tornado.new(0, 0, height, 0, NO_AREA)
	local tall = height / L.Levels

	local puffs = {}
	for level = 1, L.Levels do
		local radius = Tornado.radiusAt(shape, (level - 0.5) * tall, T)
		for _ = 1, L.Puffs do
			local width = 2 * radius * roll(L.PuffSize)
			-- A cylinder's length runs along its X, so it is turned to stand up.
			local part = piece(folder, pick(L.PuffColors), Vector3.new(tall * 1.3, width, width))
			part.Shape = Enum.PartType.Cylinder
			table.insert(puffs, {
				part = part,
				level = level,
				angle = rolls:NextNumber(0, TAU),
				spin = roll(L.PuffSpin),
				wobble = rolls:NextNumber(0, TAU),
				wobbleRate = roll(L.PuffWobbleRate),
				bob = rolls:NextNumber(0, TAU),
				bobRate = roll(L.PuffBobRate),
			})
		end
	end

	local swooshes = {}
	for _ = 1, L.Swooshes do
		local parts = {}
		local color = pick(L.SwooshColors)
		for _ = 1, L.SwooshSegments do
			table.insert(parts, piece(folder, color, Vector3.one))
		end
		table.insert(swooshes, {
			parts = parts,
			wait = roll(L.SwooshGap),
			age = 0,
			life = 0,
			up = 0,
			angle = 0,
			arc = 0,
			spin = 0,
			tilt = 0,
			out = 0,
		})
	end

	local top = Tornado.radiusAt(shape, height, T)
	local lumps = {}
	for i = 1, L.CloudPuffs do
		local width = 2 * top * L.CloudScale * rolls:NextNumber(0.6, 1.2)
		local part = piece(folder, L.CloudColor, Vector3.new(L.CloudThick * rolls:NextNumber(0.6, 1.2), width, width))
		part.Shape = Enum.PartType.Cylinder
		table.insert(lumps, {
			part = part,
			angle = rolls:NextNumber(0, TAU),
			spin = roll(L.CloudSpin),
			offset = top * rolls:NextNumber(0.1, 0.5),
			lift = (i - 1) * 3,
		})
	end

	local junk = {}
	for i = 1, L.Debris do
		local size = Vector3.new(rolls:NextNumber(2, 6), rolls:NextNumber(0.5, 2), rolls:NextNumber(2, 8))
		local part = piece(folder, L.DebrisColors[(i - 1) % #L.DebrisColors + 1], size)
		table.insert(junk, {
			part = part,
			up = rolls:NextNumber(0, height),
			angle = rolls:NextNumber(0, TAU),
			out = L.DebrisOut * rolls:NextNumber(0.8, 1.1),
			tumble = Vector3.new(rolls:NextNumber(-3, 3), rolls:NextNumber(-3, 3), rolls:NextNumber(-3, 3)),
		})
	end

	-- Dust blows out round the base from the edge of a flat disc.
	local base0 = Tornado.radiusAt(shape, 0, T)
	local dustPart = piece(folder, L.DustColor, Vector3.new(1, 2 * base0, 2 * base0))
	dustPart.Shape = Enum.PartType.Cylinder
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(L.DustColor)
	dust.Shape = Enum.ParticleEmitterShape.Disc
	dust.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, L.DustSize * 0.3),
		NumberSequenceKeypoint.new(1, L.DustSize),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, L.DustTransparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(2, 3)
	dust.Speed = NumberRange.new(30, 50)
	dust.Drag = 1
	dust.Acceleration = Vector3.new(0, 15, 0)
	dust.RotSpeed = NumberRange.new(-60, 60)
	dust.Rate = L.DustRate
	dust.LightEmission = 0
	dust.Enabled = false
	dust.Parent = dustPart

	local voice = piece(folder, Color3.new(), Vector3.one)
	local roar = sound(voice, L.Roar)
	roar.Looped = true
	roar:Play()

	local thrown = model:GetAttribute("Throws")
	model:GetAttributeChangedSignal("Throws"):Connect(function()
		local now = model:GetAttribute("Throws")
		local at = model:GetAttribute("ThrowAt")
		if now ~= thrown and typeof(at) == "Vector3" then
			whoosh(at)
		end
		thrown = now
	end)

	return {
		model = model,
		base = base,
		height = height,
		shape = shape,
		folder = folder,
		at = nil,
		seed = rolls:NextNumber(0, TAU),
		puffs = puffs,
		swooshes = swooshes,
		lumps = lumps,
		junk = junk,
		dust = dust,
		dustPart = dustPart,
		voice = voice,
	}
end

-- How far up the funnel is not yet down (touching down) or already gone
-- back up (lifting), and how solid the cloud is, from 0 to 1.
local function reach(d: Drawing, now: number): (number, number)
	local phase = d.model:GetAttribute("Phase")
	local phaseAt = d.model:GetAttribute("PhaseAt")
	local age = if typeof(phaseAt) == "number" then now - phaseAt else math.huge
	if phase == "touchdown" then
		local f = math.clamp(age / TOUCH_TIME, 0, 1)
		return d.height * (1 - f), math.clamp(2 * f, 0, 1)
	elseif phase == "lift" then
		local f = math.clamp(age / LIFT_TIME, 0, 1)
		return d.height * f, math.clamp(2 - 2 * f, 0, 1)
	elseif phase == "gone" then
		return d.height, 0
	end
	return 0, 1
end

-- How far the funnel's middle sits off the base `frac` of the way up.
local function sway(d: Drawing, frac: number, t: number): Vector3
	local amount = L.Sway * d.height * frac * frac
	local a = t * L.SwayRate + d.seed
	return Vector3.new(amount * math.sin(a), 0, amount * math.cos(a * 0.8 + d.seed))
end

local standUp = CFrame.Angles(0, 0, math.pi / 2)

-- Pops a hidden swoosh line up somewhere on the funnel.
local function popUp(d: Drawing, s: Swoosh, downFrom: number)
	s.age = 0
	s.life = roll(L.SwooshLife)
	s.up = rolls:NextNumber(math.max(downFrom, 0), d.height * 0.95)
	s.angle = rolls:NextNumber(0, TAU)
	s.arc = roll(L.SwooshArc)
	s.spin = roll(L.SwooshSpin)
	s.tilt = rolls:NextNumber(-L.SwooshTilt, L.SwooshTilt)
	s.out = roll(L.SwooshOut)
	local radius = Tornado.radiusAt(d.shape, s.up, T) * s.out
	local thick = math.max(radius * 2 * L.SwooshThick, L.SwooshThickMin)
	local chord = 2 * radius * math.sin(s.arc / (2 * L.SwooshSegments)) * 1.1
	for _, part in s.parts do
		part.Size = Vector3.new(chord, thick, thick * 0.4)
	end
end

local function drawSwoosh(
	d: Drawing,
	s: Swoosh,
	dt: number,
	at: Vector3,
	t: number,
	downFrom: number,
	near: boolean,
	parts: { BasePart },
	frames: { CFrame }
)
	if s.life <= 0 then
		s.wait -= dt
		if s.wait <= 0 and near and downFrom < d.height * 0.9 then
			popUp(d, s, downFrom)
		else
			return
		end
	end
	s.age += dt
	if s.age >= s.life or s.up < downFrom or not near then
		s.life = 0
		s.wait = roll(L.SwooshGap)
		for _, part in s.parts do
			setShown(part, false, 0)
		end
		return
	end
	s.angle += s.spin * dt
	local fade = math.clamp((s.age / s.life - 0.5) * 2, 0, 1)
	local transparency = L.SwooshTransparency + (1 - L.SwooshTransparency) * fade
	local radius = Tornado.radiusAt(d.shape, s.up, T) * s.out
	local center = at + sway(d, s.up / d.height, t)
	local step = s.arc / L.SwooshSegments
	for k, part in s.parts do
		-- The line trails behind its head, so it reads as whipping round.
		local behind = (k - 0.5) * step
		local a = s.angle - behind
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local along = Vector3.new(-out.Z, 0, out.X)
		local rise = -math.tan(s.tilt) * radius * behind
		local spot = center + out * radius + Vector3.new(0, s.up + rise, 0)
		part.Transparency = transparency
		table.insert(parts, part)
		table.insert(frames, CFrame.fromMatrix(spot, along, Vector3.yAxis) * CFrame.Angles(0, 0, s.tilt))
	end
end

local function draw(
	d: Drawing,
	dt: number,
	now: number,
	t: number,
	camera: Vector3,
	parts: { BasePart },
	frames: { CFrame }
)
	local target = d.base.Position
	local at = d.at
	at = if at then at:Lerp(target, 1 - math.exp(-L.Smooth * dt)) else target
	d.at = at

	local downFrom, cloudFade = reach(d, now)
	local near = (camera - at).Magnitude < L.Far
	local tall = d.height / L.Levels
	local cameraOff = Vector3.new(camera.X - at.X, 0, camera.Z - at.Z).Magnitude
	local inside = camera.Y - at.Y < d.height + L.CloudThick
		and cameraOff < Tornado.radiusAt(d.shape, camera.Y - at.Y, T) * L.PuffInsideReach
	local puffTransparency = if inside then L.PuffInside else L.PuffTransparency

	for _, p in d.puffs do
		local mid = (p.level - 0.5 + L.PuffBob * math.sin(t * p.bobRate + p.bob)) * tall
		p.angle = (p.angle + p.spin * dt) % TAU
		local radius = Tornado.radiusAt(d.shape, mid, T)
		local off = radius * L.PuffOffset * (1 + L.PuffWobble * math.sin(t * p.wobbleRate + p.wobble))
		local center = at + sway(d, mid / d.height, t)
		local spot = center + Vector3.new(math.cos(p.angle) * off, mid, math.sin(p.angle) * off)
		setShown(p.part, mid >= downFrom, puffTransparency)
		table.insert(parts, p.part)
		table.insert(frames, CFrame.new(spot) * CFrame.Angles(0, p.angle, 0) * standUp)
	end

	for _, s in d.swooshes do
		drawSwoosh(d, s, dt, at, t, downFrom, near, parts, frames)
	end

	local topAt = at + sway(d, 1, t) + Vector3.new(0, d.height + L.CloudThick / 2 - 5, 0)
	for _, lump in d.lumps do
		lump.angle = (lump.angle + lump.spin * dt) % TAU
		local spot = topAt
			+ Vector3.new(math.cos(lump.angle) * lump.offset, lump.lift, math.sin(lump.angle) * lump.offset)
		setShown(lump.part, cloudFade > 0, 1 - (1 - L.CloudTransparency) * cloudFade)
		table.insert(parts, lump.part)
		table.insert(frames, CFrame.new(spot) * standUp)
	end

	for _, j in d.junk do
		j.up += L.DebrisClimb * dt
		if j.up > d.height * 0.9 then
			j.up = 0
		end
		j.angle = (j.angle + L.DebrisSpin * dt) % TAU
		local shown = near and j.up >= downFrom
		setShown(j.part, shown, 0)
		if shown then
			local radius = Tornado.radiusAt(d.shape, j.up, T) * j.out
			local center = at + sway(d, j.up / d.height, t)
			local spot = center + Vector3.new(math.cos(j.angle) * radius, j.up, math.sin(j.angle) * radius)
			local turn = j.tumble * t
			table.insert(parts, j.part)
			table.insert(frames, CFrame.new(spot) * CFrame.Angles(turn.X, turn.Y, turn.Z))
		end
	end

	-- The dust blows only while the funnel reaches the ground.
	local touching = downFrom < tall
	if d.dust.Enabled ~= touching then
		d.dust.Enabled = touching
	end
	table.insert(parts, d.dustPart)
	table.insert(frames, CFrame.new(at + Vector3.new(0, 1, 0)) * standUp)

	-- The roar comes from the funnel's middle level with the camera.
	local voiceUp = math.clamp(camera.Y - at.Y, downFrom, d.height)
	table.insert(parts, d.voice)
	table.insert(frames, CFrame.new(at + sway(d, voiceUp / d.height, t) + Vector3.new(0, voiceUp, 0)))
end

local function forget(model: Model)
	local d = drawings[model]
	if d then
		drawings[model] = nil
		d.folder:Destroy()
	end
end

local function watch(folder: Instance)
	local function add(child: Instance)
		if child:IsA("Model") and not drawings[child] then
			-- Its parts and attributes may arrive a moment after the model.
			child:WaitForChild("Base", 10)
			if child.Parent ~= folder then
				return
			end
			local d = build(child)
			if d then
				drawings[child] = d
			end
		end
	end
	folder.ChildAdded:Connect(function(child)
		task.spawn(add, child)
	end)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			forget(child)
		end
	end)
	for _, child in folder:GetChildren() do
		task.spawn(add, child)
	end
end

task.spawn(function()
	watch(workspace:WaitForChild("Tornados"))
end)

RunService.RenderStepped:Connect(function(dt: number)
	local camera = workspace.CurrentCamera
	local cameraAt = if camera then camera.CFrame.Position else Vector3.zero
	local now = workspace:GetServerTimeNow()
	local t = os.clock()
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for model, d in drawings do
		if model.Parent == nil then
			forget(model)
		else
			draw(d, dt, now, t, cameraAt, parts, frames)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
