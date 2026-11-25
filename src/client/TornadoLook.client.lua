--!strict
-- TornadoLook (LocalScript) -> StarterPlayerScripts.TornadoLook
-- Draws every tornado in workspace.Tornados (TornadoService) on this client,
-- from its Base part and its Height, Phase and PhaseAt attributes. Nothing
-- here touches physics or decides anything: catches and throws are the
-- server's.
--
-- Each tornado is a see-through funnel of Slices pieces, as wide as
-- Tornado.radiusAt says, its top swaying round the base; Streaks dark bands
-- round each piece spin, turning a little more higher up and leaning to match
-- so they join into a spiral;
-- a dark cloud cap with a fainter haze sits on top; Debris bits of junk
-- circle and climb inside; and a ring of dust blows out where it touches
-- the ground. While it touches down the funnel grows down from the cloud,
-- and while it lifts it draws back up into it. Past Far from the camera
-- only the funnel and cloud draw. Numbers are in Tuning.Tornado.Look.

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

type Junk = { part: Part, up: number, angle: number, out: number, tumble: Vector3 }

type Drawing = {
	model: Model,
	base: BasePart,
	height: number,
	shape: Tornado.State,
	folder: Folder,
	at: Vector3?,
	seed: number,
	slices: { Part },
	streaks: { Part },
	leans: { CFrame }, -- each piece's band lean
	cloud: Part,
	haze: Part, -- a fainter, wider layer round the cloud
	junk: { Junk },
	dust: ParticleEmitter,
	dustPart: Part,
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
	local tall = height / L.Slices

	local slices, streaks, leans = {}, {}, {}
	for i = 1, L.Slices do
		local radius = Tornado.radiusAt(shape, (i - 0.5) * tall, T)
		-- A cylinder's length runs along its X, so it is turned to stand up.
		local slice = piece(folder, L.CoreColor, Vector3.new(tall * 1.05, 2 * radius, 2 * radius))
		slice.Shape = Enum.PartType.Cylinder
		table.insert(slices, slice)
		-- A band leans as far along the spin as the twist carries it each
		-- stud up, so the bands of one piece meet those of the next.
		local lean = math.atan(L.Twist * radius)
		table.insert(leans, CFrame.Angles(0, 0, -lean))
		local width = TAU * radius / L.Streaks * L.StreakWidth
		for _ = 1, L.Streaks do
			table.insert(streaks, piece(folder, L.StreakColor, Vector3.new(width, tall / math.cos(lean) * 1.05, 1)))
		end
	end

	local top = Tornado.radiusAt(shape, height, T)
	local cloud = piece(folder, L.CloudColor, Vector3.new(L.CloudThick, 2 * top * L.CloudScale, 2 * top * L.CloudScale))
	cloud.Shape = Enum.PartType.Cylinder
	local hazeWidth = 2 * top * L.CloudScale * L.HazeScale
	local haze = piece(folder, L.CloudColor, Vector3.new(L.CloudThick * 0.6, hazeWidth, hazeWidth))
	haze.Shape = Enum.PartType.Cylinder

	local rolls = Random.new()
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

	return {
		model = model,
		base = base,
		height = height,
		shape = shape,
		folder = folder,
		at = nil,
		seed = rolls:NextNumber(0, TAU),
		slices = slices,
		streaks = streaks,
		leans = leans,
		cloud = cloud,
		haze = haze,
		junk = junk,
		dust = dust,
		dustPart = dustPart,
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
	local flat = Vector3.new(camera.X - at.X, 0, camera.Z - at.Z)
	local toCamera = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	local tall = d.height / L.Slices

	for i, slice in d.slices do
		local mid = (i - 0.5) * tall
		local center = at + sway(d, mid / d.height, t) + Vector3.new(0, mid, 0)
		local shown = mid >= downFrom
		setShown(slice, shown, L.CoreTransparency)
		table.insert(parts, slice)
		table.insert(frames, CFrame.new(center) * standUp)

		local radius = Tornado.radiusAt(d.shape, mid, T) * 1.01
		for k = 1, L.Streaks do
			local streak = d.streaks[(i - 1) * L.Streaks + k]
			local a = t * L.StreakSpin + k * TAU / L.Streaks + mid * L.Twist + d.seed
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			-- Bands on the far side would show through the funnel leaning the
			-- other way, so only the near side's draw.
			local facing = out:Dot(toCamera) > -0.2
			setShown(streak, shown and near and facing, L.StreakTransparency)
			if shown and near and facing then
				local along = Vector3.new(-out.Z, 0, out.X)
				table.insert(parts, streak)
				table.insert(frames, CFrame.fromMatrix(center + out * radius, along, Vector3.yAxis) * d.leans[i])
			end
		end
	end

	local topAt = at + sway(d, 1, t) + Vector3.new(0, d.height + L.CloudThick / 2 - 5, 0)
	setShown(d.cloud, cloudFade > 0, 1 - (1 - L.CloudTransparency) * cloudFade)
	table.insert(parts, d.cloud)
	table.insert(frames, CFrame.new(topAt) * CFrame.Angles(0, t * L.CloudSpin, 0) * standUp)
	setShown(d.haze, cloudFade > 0, 1 - (1 - L.HazeTransparency) * cloudFade)
	table.insert(parts, d.haze)
	table.insert(frames, CFrame.new(topAt + Vector3.new(0, 4, 0)) * standUp)

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
