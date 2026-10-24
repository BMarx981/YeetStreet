--!strict
-- KaijuLook (LocalScript) -> StarterPlayerScripts.KaijuLook
-- Draws Downtown's kaiju on this client, in blocks like the T-Rex: charcoal
-- with a pale grey belly, standing upright on two thick legs, little arms,
-- a long tail dragging behind, pale blue plates down its back and tail, and
-- pale blue eyes. Only for looks: cars pass through it.
--
-- The server moves two invisible parts in workspace.Parks.City.Kaiju
-- (Parks.CityKaiju): Root under its feet and Head. This client glides its
-- drawing after them, Look.Smooth per second, and animates the rest as
-- TRexLook does the T-Rex: planted feet, knees bending to reach them, a
-- neck stretched to the head, the jaw for lunges, grips and chomps, and the
-- tail swaying and swinging out on turns. While it holds a car (HeldCar) or
-- a player (HeldPlayer) the head is drawn where their spot in its jaws is.
-- It roars, jaw open, as it spots a car and gives chase.
--
-- While its eyes charge a laser (LaserCharge) they pulse hot and light up
-- round the head, the back plates glow one after another from the tail's
-- tip up to the head, a faint line runs to where it aims (LaserAim), and a
-- charge hums. Each shot (LaserShots) flashes a beam from each eye to where
-- it stopped (LaserEnd), fading over BeamTime, with a blast sound.
-- Numbers are in Tuning.City.Kaiju (Head, Look, Laser).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tuning = require(ReplicatedStorage.Tuning)

local K = Tuning.City.Kaiju
local H = K.Head
local L = K.Look
local LASER = K.Laser

local SKIN_COLOR = Color3.fromRGB(52, 54, 60)
local DARK_COLOR = Color3.fromRGB(30, 31, 36)
local BELLY_COLOR = Color3.fromRGB(150, 152, 158)
local SPINE_COLOR = Color3.fromRGB(150, 205, 235)
local EYE_COLOR = Color3.fromRGB(120, 220, 255)
local HOT_COLOR = Color3.fromRGB(235, 250, 255)
local MOUTH_COLOR = Color3.fromRGB(70, 40, 55)
local TOOTH_COLOR = Color3.fromRGB(235, 235, 225)

-- The held car's middle in the head's frame, as the server holds it.
local HELD_AT = CFrame.new(0, -H.CarDrop, -(H.Size.Z / 2 + Tuning.Chassis.HullSize.Z / 2 - H.CarIn))
-- A held player's root: where a car's middle goes, turned across the jaws.
local HELD_PERSON = HELD_AT * CFrame.Angles(0, math.pi / 2, 0)

-- The body stands HIP_HEIGHT over the ground. Points below are in the
-- body's frame (facing -Z, its back toward +Z) unless they say otherwise.
local HIP_HEIGHT = 44
local NECK_BASE = Vector3.new(0, 80, -14)
-- The back of the head, in the head's frame, where the neck meets it.
local NECK_TOP = Vector3.new(0, 0, 9)
local NECK_SIZE = Vector2.new(18, 20)
-- Each leg: hip joint (x is its side), thigh and shin lengths, and the
-- ankle's spot over the ball of its foot.
local HIP = Vector3.new(17, -2, 4)
local THIGH = 28
local SHIN = 24
local ANKLE_OVER_BALL = Vector3.new(0, 9, 5)
-- Where a standing foot's ball is, in the root's frame (x is its side).
local FOOT_HOME = Vector3.new(17, 3, 0)
local JAW_HINGE = CFrame.new(0, -4, 6)
local TAIL_BASE = CFrame.new(0, 0, 14) * CFrame.Angles(math.rad(9), 0, 0)
-- Tail blocks from the hips back: width, height, length.
local TAIL = {
	Vector3.new(28, 26, 24),
	Vector3.new(24, 22, 24),
	Vector3.new(20, 18, 22),
	Vector3.new(16, 14, 22),
	Vector3.new(12, 10, 20),
	Vector3.new(8, 7, 18),
}
local TAIL_DROOP = math.rad(2.5)
-- The tail swings out from a turn this much per radian per second, at most
-- TAIL_SWING_MOST radians a block.
local TAIL_SWING = 0.03
local TAIL_SWING_MOST = 0.08
-- The jaw opens this many times its widest a second, and snaps shut this many.
local JAW_OPENING = 6
local JAW_CLOSING = 20
local JAW_CHASE = 6
-- Running, it leans forward up to this, and bobs and rolls this much.
local RUN_LEAN = math.rad(6)
local BOB = 2
local ROLL = math.rad(2)
-- Below this speed its feet settle home.
local WALK_FROM = 8
-- Charging, the eyes pulse this many times a second, the light round the
-- head grows to GLOW_BRIGHTNESS, and the plates light up the back over the
-- first SPINE_RISE of the charge.
local PULSE_RATE = 6
local GLOW_BRIGHTNESS = 6
local GLOW_RANGE = 40
local SPINE_RISE = 0.8
local BEAM_WIDTH = 3

local kaiju = workspace:WaitForChild("Parks"):WaitForChild("City"):WaitForChild("Kaiju")
local serverRoot = kaiju:WaitForChild("Root") :: BasePart
local serverHead = kaiju:WaitForChild("Head") :: BasePart
local carsFolder = workspace:WaitForChild("Cars")

-- Rojo has synced some scripts into Studio twice; only one copy draws.
if workspace:FindFirstChild("KaijuLook") then
	return
end
local model = Instance.new("Model")
model.Name = "KaijuLook"
model.Parent = workspace

type Piece = { part: BasePart, bone: string, offset: CFrame }
local pieces: { Piece } = {}
local parts: { BasePart } = {}

local function add(bone: string, size: Vector3, offset: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	table.insert(pieces, { part = part, bone = bone, offset = offset })
	table.insert(parts, part)
	return part
end

-- The back plates, from the tail's tip up to the head, in the order they
-- light up.
local spines: { BasePart } = {}

-- A plate standing `size` out of a block's face at `at` (in the bone's
-- frame), turned to a diamond so its point sticks out along `out`.
local function spine(bone: string, at: CFrame, size: number, out: "up" | "back")
	local turn = if out == "up" then CFrame.Angles(math.rad(45), 0, 0) else CFrame.Angles(math.rad(-45), 0, 0)
	local part = add(bone, Vector3.new(2.5, size, size), at * turn, SPINE_COLOR)
	table.insert(spines, part)
end

-- Tail blocks, each bone at the block's front end pointing back along +Z,
-- their plates along the top, built first so the plates light from the tip.
local tailSpines: { { bone: string, at: CFrame, size: number } } = {}
for i, size in TAIL do
	local block = CFrame.new(0, 0, size.Z / 2)
	add("tail" .. i, size, block, SKIN_COLOR)
	add("tail" .. i, Vector3.new(size.X * 0.7, 1, size.Z), block * CFrame.new(0, -size.Y / 2 - 0.3, 0), BELLY_COLOR)
	table.insert(tailSpines, { bone = "tail" .. i, at = block * CFrame.new(0, size.Y / 2, 0), size = size.Y * 0.45 })
end
for i = #tailSpines, 1, -1 do
	local s = tailSpines[i]
	spine(s.bone, s.at, s.size, "up")
end

-- Body: hips, belly and chest, leaning a little forward.
local PELVIS = CFrame.new(0, 4, 4)
local PELVIS_SIZE = Vector3.new(40, 30, 34)
local BELLY = CFrame.new(0, 38, -2) * CFrame.Angles(math.rad(-10), 0, 0)
local BELLY_SIZE = Vector3.new(38, 44, 32)
local CHEST = CFrame.new(0, 70, -10) * CFrame.Angles(math.rad(-18), 0, 0)
local CHEST_SIZE = Vector3.new(36, 30, 30)
add("body", PELVIS_SIZE, PELVIS, SKIN_COLOR)
add("body", BELLY_SIZE, BELLY, SKIN_COLOR)
add("body", CHEST_SIZE, CHEST, SKIN_COLOR)
add("body", Vector3.new(28, 40, 2), BELLY * CFrame.new(0, 0, -BELLY_SIZE.Z / 2 - 0.5), BELLY_COLOR)
add("body", Vector3.new(26, 26, 2), CHEST * CFrame.new(0, 0, -CHEST_SIZE.Z / 2 - 0.5), BELLY_COLOR)
for _, y in { -12, -4, 4, 12 } do
	add("body", Vector3.new(28.4, 0.6, 0.6), BELLY * CFrame.new(0, y, -BELLY_SIZE.Z / 2 - 1.4), DARK_COLOR)
end
spine("body", PELVIS * CFrame.new(0, 6, PELVIS_SIZE.Z / 2), 12, "back")
for _, y in { -10, 8 } do
	spine("body", BELLY * CFrame.new(0, y, BELLY_SIZE.Z / 2), 16, "back")
end
for _, y in { -4, 9 } do
	spine("body", CHEST * CFrame.new(0, y, CHEST_SIZE.Z / 2), 14, "back")
end

-- Neck: sized each frame to reach the head.
local neck = add("neck", Vector3.new(NECK_SIZE.X, NECK_SIZE.Y, 1), CFrame.identity, SKIN_COLOR)
local throat = add("neck", Vector3.new(14, 1, 1), CFrame.new(0, -NECK_SIZE.Y / 2 - 0.3, 0), BELLY_COLOR)

-- Head, facing -Z, its front at -Size.Z / 2.
local CRANIUM = CFrame.new(0, 4, 6)
add("head", Vector3.new(22, 16, 18), CRANIUM, SKIN_COLOR)
add("head", Vector3.new(18, 11, 18), CFrame.new(0, 1, -10), SKIN_COLOR)
add("head", Vector3.new(22, 3.5, 5), CFrame.new(0, 10, -1), DARK_COLOR) -- brow
add("head", Vector3.new(16, 1, 18), CFrame.new(0, -4.2, -9), MOUTH_COLOR)
local eyes: { { part: BasePart, at: Vector3 } } = {}
for _, side in { -1, 1 } do
	local at = Vector3.new(side * 7, 7, -3.6)
	local eye = add("head", Vector3.new(3.5, 3, 1), CFrame.new(at), EYE_COLOR)
	eye.Material = Enum.Material.Neon
	table.insert(eyes, { part = eye, at = at })
	add("head", Vector3.new(2.5, 1, 2), CFrame.new(side * 4, 6.6, -18), DARK_COLOR) -- nostril
	for _, z in { -17, -13.5, -10, -6.5 } do
		add("head", Vector3.new(1.3, 2.4, 1.3), CFrame.new(side * 8, -4.6, z), TOOTH_COLOR)
	end
end
spine("head", CRANIUM * CFrame.new(0, 8, 2), 8, "up")

-- Lower jaw, hinged at the back of the mouth, reaching to the snout's front.
add("jaw", Vector3.new(16, 5, 24), CFrame.new(0, -2.5, -12), BELLY_COLOR)
add("jaw", Vector3.new(10, 1, 16), CFrame.new(0, 0.3, -12), MOUTH_COLOR) -- tongue
for _, side in { -1, 1 } do
	for _, z in { -22, -18, -14, -10 } do
		add("jaw", Vector3.new(1.2, 2.2, 1.2), CFrame.new(side * 6.8, 1.1, z), TOOTH_COLOR)
	end
end

-- Little arms, from the chest, each a bone pointing along -Z.
for _, side in { "L", "R" } do
	add("upperArm" .. side, Vector3.new(7, 7, 16), CFrame.new(0, 0, -8), SKIN_COLOR)
	add("foreArm" .. side, Vector3.new(6, 6, 14), CFrame.new(0, 0, -7), SKIN_COLOR)
	for _, x in { -1.6, 0, 1.6 } do
		add("foreArm" .. side, Vector3.new(1.2, 1.2, 4), CFrame.new(x, 0, -15.5), TOOTH_COLOR)
	end
end

-- Legs: each bone lies along its segment (-Z toward the far end).
for _, side in { "L", "R" } do
	add("thigh" .. side, Vector3.new(16, 20, THIGH + 6), CFrame.identity, SKIN_COLOR)
	add("thigh" .. side, Vector3.new(18, 24, 18), CFrame.new(0, 2, -THIGH * 0.2), SKIN_COLOR)
	add("shin" .. side, Vector3.new(12, 13, SHIN + 4), CFrame.identity, SKIN_COLOR)
	add("meta" .. side, Vector3.new(10, 9, ANKLE_OVER_BALL.Magnitude + 3), CFrame.identity, SKIN_COLOR)
	add("foot" .. side, Vector3.new(18, 6, 22), CFrame.new(0, 0, -4), SKIN_COLOR)
	for _, x in { -6, 0, 6 } do
		add("foot" .. side, Vector3.new(3, 3, 6), CFrame.new(x, -1, -17), TOOTH_COLOR)
	end
end

local cframes: { CFrame } = table.create(#parts)

-- The laser's look: a light round the head, the faint aiming line and a
-- beam from each eye, all cylinders lying along their length.
local glow = Instance.new("PointLight")
glow.Color = EYE_COLOR
glow.Range = GLOW_RANGE
glow.Brightness = 0
glow.Parent = eyes[1].part

local function beam(name: string, width: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = EYE_COLOR
	p.Size = Vector3.new(1, width, width)
	p.Transparency = 1
	p.Parent = model
	return p
end
local aimLine = beam("AimLine", 0.6)
local beams = { beam("Beam", BEAM_WIDTH), beam("Beam", BEAM_WIDTH) }
local laserParts: { BasePart } = {}
local laserFrames: { CFrame } = {}

-- A cylinder's frame from `from` to `to`: its length runs along its X.
local function span(part: Part, from: Vector3, to: Vector3): CFrame
	local length = math.max((to - from).Magnitude, 0.1)
	part.Size = Vector3.new(length, part.Size.Y, part.Size.Z)
	return CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0)
end

-- A frame lying along a to b (-Z toward b), with X along `right`.
local function along(a: Vector3, b: Vector3, right: Vector3): CFrame
	local back = (a - b).Unit
	return CFrame.fromMatrix((a + b) / 2, right, back:Cross(right), back)
end

-- The knee between hip and ankle (in the root's frame) that keeps the thigh
-- and shin their lengths, bent forward; and the ankle it can reach.
local function knee(hip: Vector3, ankle: Vector3): (Vector3, Vector3)
	local d = Vector2.new(ankle.Y - hip.Y, ankle.Z - hip.Z)
	local far = math.clamp(d.Magnitude, math.abs(THIGH - SHIN) + 0.01, THIGH + SHIN - 0.01)
	local dir = if d.Magnitude > 1e-6 then d.Unit else Vector2.new(-1, 0)
	local a = (THIGH * THIGH - SHIN * SHIN + far * far) / (2 * far)
	local h = math.sqrt(math.max(THIGH * THIGH - a * a, 0))
	local perp = Vector2.new(-dir.Y, dir.X)
	if perp.Y > 0 then
		perp = -perp
	end
	local k = Vector2.new(hip.Y, hip.Z) + dir * a + perp * h
	local reached = Vector2.new(hip.Y, hip.Z) + dir * far
	return Vector3.new(hip.X, k.X, k.Y), Vector3.new(ankle.X, reached.X, reached.Y)
end

local function approach(value: number, goal: number, up: number, down: number, dt: number): number
	if goal > value then
		return math.min(value + up * dt, goal)
	end
	return math.max(value - down * dt, goal)
end

local function sound(id: string, pitch: number, volume: number, hearing: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = pitch
	s.Volume = volume
	s.RollOffMaxDistance = hearing
	s.Parent = serverHead
	return s
end

local root = serverRoot.CFrame
local head = serverHead.CFrame
local speed = 0
local yawRate = 0
local cycle = 0
local open = 0
local chewStart = 0
local roarUntil = 0
local chargeStart = 0
local shotAt = -math.huge
local bones: { [string]: CFrame } = {}

kaiju:GetAttributeChangedSignal("Chewing"):Connect(function()
	chewStart = os.clock()
end)

-- It roars as it spots a car and gives chase.
local roar = sound(L.Roar, L.RoarPitch, L.RoarVolume, L.RoarHearing)
local lastMode = kaiju:GetAttribute("Mode")
kaiju:GetAttributeChangedSignal("Mode"):Connect(function()
	local mode = kaiju:GetAttribute("Mode")
	if lastMode == "roam" and mode == "chase" then
		roar:Play()
		roarUntil = os.clock() + L.RoarJaw
	end
	lastMode = mode
end)

local charge = sound(L.Charge, 1, L.LaserVolume, L.LaserHearing)
local shot = sound(L.Shot, 1, L.LaserVolume, L.LaserHearing)
kaiju:GetAttributeChangedSignal("LaserCharge"):Connect(function()
	if kaiju:GetAttribute("LaserCharge") == true then
		chargeStart = os.clock()
		charge:Play()
	else
		charge:Stop()
	end
end)
kaiju:GetAttributeChangedSignal("LaserShots"):Connect(function()
	shotAt = os.clock()
	shot:Play()
end)

RunService.RenderStepped:Connect(function(dt: number)
	if dt <= 0 then
		return
	end
	-- An admin command can put the park away; while it is gone the drawing
	-- goes with it, and comes back when the park does.
	local shown = kaiju:IsDescendantOf(workspace)
	if (model.Parent ~= nil) ~= shown then
		model.Parent = if shown then workspace else nil
	end
	if not shown then
		return
	end
	local mode = kaiju:GetAttribute("Mode")
	local smooth = 1 - math.exp(-L.Smooth * dt)
	local lastRoot = root
	root = root:Lerp(serverRoot.CFrame, smooth)
	local heldName = kaiju:GetAttribute("HeldCar")
	local held = if typeof(heldName) == "string" and heldName ~= "" then carsFolder:FindFirstChild(heldName) else nil
	local playerName = kaiju:GetAttribute("HeldPlayer")
	local person = if typeof(playerName) == "string" and playerName ~= ""
		then Players:FindFirstChild(playerName)
		else nil
	local character = if person and person:IsA("Player") then person.Character else nil
	local personRoot = character and character:FindFirstChild("HumanoidRootPart")
	if held and held:IsA("Model") and held.PrimaryPart and held.PrimaryPart.Anchored then
		head = held:GetPivot() * HELD_AT:Inverse()
	elseif personRoot and personRoot:IsA("BasePart") and personRoot.Anchored then
		head = personRoot.CFrame * HELD_PERSON:Inverse()
	else
		head = head:Lerp(serverHead.CFrame, if mode == "lunge" then 1 - math.exp(-2 * L.Smooth * dt) else smooth)
	end
	local moved = (root.Position - lastRoot.Position).Magnitude
	speed += (moved / dt - speed) * smooth
	local turned = math.atan2(lastRoot.LookVector:Cross(root.LookVector).Y, lastRoot.LookVector:Dot(root.LookVector))
	yawRate += (turned / dt - yawRate) * smooth

	-- Walking.
	local walk = math.clamp(speed / WALK_FROM, 0, 1)
	local stride = math.clamp(L.MinStride + speed * L.StridePerSpeed, L.MinStride, L.MaxStride)
	cycle = (cycle + moved / (2 * stride)) % 1
	local running = math.clamp(speed / K.RunSpeed, 0, 1)
	local bob = BOB * walk * math.cos(4 * math.pi * cycle)
	local body = root
		* CFrame.new(0, HIP_HEIGHT + bob, 0)
		* CFrame.Angles(-RUN_LEAN * running, 0, ROLL * walk * math.sin(2 * math.pi * cycle))
	bones.body = body
	bones.head = head
	local right = root.RightVector
	for k, side in { "L", "R" } do
		local x = if side == "L" then -1 else 1
		local phase = (cycle + (k - 1) * 0.5) % 1
		local z, y
		if phase < 0.5 then
			z, y = -stride / 2 + stride * phase / 0.5, 0
		else
			local q = (phase - 0.5) / 0.5
			z = stride / 2 - stride * (q * q * (3 - 2 * q))
			y = L.Lift * math.sin(math.pi * q)
		end
		local ball = Vector3.new(x * FOOT_HOME.X, FOOT_HOME.Y + y * walk, FOOT_HOME.Z + z * walk)
		local hip = root:PointToObjectSpace(body:PointToWorldSpace(Vector3.new(x * HIP.X, HIP.Y, HIP.Z)))
		local kneeAt, ankle = knee(hip, ball + ANKLE_OVER_BALL)
		ball = ankle - ANKLE_OVER_BALL
		local hipW, kneeW = root:PointToWorldSpace(hip), root:PointToWorldSpace(kneeAt)
		local ankleW, ballW = root:PointToWorldSpace(ankle), root:PointToWorldSpace(ball)
		bones["thigh" .. side] = along(hipW, kneeW, right)
		bones["shin" .. side] = along(kneeW, ankleW, right)
		bones["meta" .. side] = along(ankleW, ballW, right)
		bones["foot" .. side] = CFrame.new(ballW) * root.Rotation

		local wiggle = math.rad(8) * math.sin(os.clock() * 3 + k)
		local shoulder = body * CFrame.new(x * 20, 62, -18) * CFrame.Angles(math.rad(-50) + wiggle, 0, 0)
		bones["upperArm" .. side] = shoulder
		bones["foreArm" .. side] = shoulder * CFrame.new(0, 0, -16) * CFrame.Angles(math.rad(60), 0, 0)
	end

	-- Neck, from between the shoulders to the back of the head.
	local base = body:PointToWorldSpace(NECK_BASE)
	local top = head:PointToWorldSpace(NECK_TOP)
	local reach = (top - base).Magnitude
	bones.neck = CFrame.lookAt((base + top) / 2, top, head.UpVector)
	neck.Size = Vector3.new(NECK_SIZE.X, NECK_SIZE.Y, reach + 8)
	throat.Size = Vector3.new(14, 1, reach)

	-- Jaw.
	local chewing = kaiju:GetAttribute("Chewing") == true
	local goal = 0
	if mode == "lunge" or os.clock() < roarUntil then
		goal = L.JawOpen
	elseif mode == "hold" and chewing then
		goal = L.ChompOpen * (1 - math.abs(math.sin(math.pi * L.ChompRate * (os.clock() - chewStart))))
	elseif mode == "hold" then
		goal = L.Grip
	elseif mode == "chase" then
		goal = JAW_CHASE
	end
	open = approach(open, goal, JAW_OPENING * L.JawOpen, JAW_CLOSING * L.JawOpen, dt)
	bones.jaw = head * JAW_HINGE * CFrame.Angles(-math.rad(open), 0, 0)

	-- Tail.
	local swing = math.clamp(-yawRate * TAIL_SWING, -TAIL_SWING_MOST, TAIL_SWING_MOST)
	local sway = math.rad(L.TailSway) * (1 - 0.5 * running)
	local bone = body * PELVIS * TAIL_BASE
	for i, size in TAIL do
		local yaw = sway * math.sin(2 * math.pi * L.TailRate * os.clock() - 0.8 * i) + swing
		bone = bone * CFrame.Angles(TAIL_DROOP, yaw, 0)
		bones["tail" .. i] = bone
		bone = bone * CFrame.new(0, 0, size.Z)
	end

	for i, piece in pieces do
		cframes[i] = bones[piece.bone] * piece.offset
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

	-- Charging: the eyes pulse hotter, the plates light up the back, and
	-- the line shows where they aim.
	local charging = kaiju:GetAttribute("LaserCharge") == true
	local heat = if charging then 0.5 + 0.5 * math.sin(os.clock() * PULSE_RATE * 2 * math.pi) else 0
	for _, eye in eyes do
		eye.part.Color = EYE_COLOR:Lerp(HOT_COLOR, heat)
	end
	glow.Brightness = heat * GLOW_BRIGHTNESS
	local risen = if charging then (os.clock() - chargeStart) / (LASER.Charge * SPINE_RISE) else -1
	for k, plate in spines do
		local lit = risen >= (k - 1) / #spines
		plate.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		plate.Color = if lit then EYE_COLOR:Lerp(HOT_COLOR, heat) else SPINE_COLOR
	end
	table.clear(laserParts)
	table.clear(laserFrames)
	local aim = kaiju:GetAttribute("LaserAim")
	aimLine.Transparency = if charging and typeof(aim) == "Vector3" then 0.75 else 1
	if typeof(aim) == "Vector3" then
		table.insert(laserParts, aimLine)
		table.insert(laserFrames, span(aimLine, head:PointToWorldSpace(LASER.Eyes), aim))
	end

	-- A shot: a beam from each eye to where it stopped, fading out.
	local since = os.clock() - shotAt
	local finish = kaiju:GetAttribute("LaserEnd")
	local beaming = since < LASER.BeamTime and typeof(finish) == "Vector3"
	for i, eye in eyes do
		local part = beams[i]
		part.Transparency = if beaming then since / LASER.BeamTime else 1
		if beaming and typeof(finish) == "Vector3" then
			table.insert(laserParts, part)
			table.insert(laserFrames, span(part, head:PointToWorldSpace(eye.at), finish))
		end
	end
	workspace:BulkMoveTo(laserParts, laserFrames, Enum.BulkMoveMode.FireCFrameChanged)
end)
