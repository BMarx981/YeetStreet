--!strict
-- TRexLook (LocalScript) -> StarterPlayerScripts.TRexLook
-- Draws Dino Valley's T-Rex on this client, in blocks like the brontosaurus:
-- dark green with a tan belly and jaw, dark stripes down its back and tail,
-- yellow eyes, teeth, little arms, two big legs and a long tail. Only for
-- looks: cars pass through it.
--
-- The server moves two invisible parts in workspace.Parks.Dino.TRex
-- (Parks.DinoRex): Root under its hips and Head. This client glides its
-- drawing after them, Look.Smooth per second, and animates the rest. The
-- legs walk with each foot planted on the ground while it pushes back, then
-- lifted forward, their strides growing with its speed, the knees bending
-- to reach the feet. The neck stretches from the chest to wherever the head
-- is. The jaw opens wide for a lunge and snaps shut on the bite, grips a
-- held car and chomps while Chewing. The tail sways and swings out on turns.
-- While the T-Rex holds a car (HeldCar) or a player on foot (HeldPlayer),
-- the head is drawn where their spot in its jaws is, so they never drift
-- from them on screen.
-- Numbers are in Tuning.Dino.Rex (Head, Look).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local R = Tuning.Dino.Rex
local H = R.Head
local L = R.Look

local SKIN_COLOR = Color3.fromRGB(58, 92, 48)
local STRIPE_COLOR = Color3.fromRGB(34, 56, 30)
local BELLY_COLOR = Color3.fromRGB(196, 172, 120)
local MOUTH_COLOR = Color3.fromRGB(150, 58, 58)
local TOOTH_COLOR = Color3.fromRGB(245, 240, 225)
local EYE_COLOR = Color3.fromRGB(250, 200, 40)
local DARK_COLOR = Color3.fromRGB(20, 20, 20)

-- The held car's middle in the head's frame, as the server holds it.
local HELD_AT = CFrame.new(0, -H.CarDrop, -(H.Size.Z / 2 + Tuning.Chassis.HullSize.Z / 2 - H.CarIn))
-- A held player's root: where a car's middle goes, turned across the jaws.
local HELD_PERSON = HELD_AT * CFrame.Angles(0, math.pi / 2, 0)

-- The body hangs from its hips HIP_HEIGHT over the ground. Points below are
-- in the body's frame (facing -Z) unless they say otherwise.
local HIP_HEIGHT = 60
local NECK_BASE = Vector3.new(0, 22, -46)
-- The back of the head, in the head's frame, where the neck meets it.
local NECK_TOP = Vector3.new(0, 0, H.Size.Z / 2 - 6)
local NECK_SIZE = Vector2.new(16, 18)
-- Each leg: hip joint (x is its side), thigh and shin lengths, and the
-- ankle's spot over the ball of its foot.
local HIP = Vector3.new(16, -4, 6)
local THIGH = 28
local SHIN = 26
local ANKLE_OVER_BALL = Vector3.new(0, 12, 5)
-- Where a standing foot's ball is, in the root's frame (x is its side).
local FOOT_HOME = Vector3.new(16, 2, 2)
local JAW_HINGE = CFrame.new(0, -3, 10)
local TAIL_BASE = CFrame.new(0, 4, 20)
-- Tail blocks from the hips back: width, height, length.
local TAIL = {
	Vector3.new(24, 22, 20),
	Vector3.new(20, 18, 18),
	Vector3.new(15, 14, 18),
	Vector3.new(11, 10, 16),
	Vector3.new(7, 6, 16),
}
local TAIL_DROOP = math.rad(2)
-- The tail swings out from a turn this much per radian per second, at most
-- TAIL_SWING_MOST radians a block.
local TAIL_SWING = 0.03
local TAIL_SWING_MOST = 0.08
-- The jaw opens this many times its widest a second, and snaps shut this many.
local JAW_OPENING = 6
local JAW_CLOSING = 20
-- Chasing, it keeps its jaw a little open.
local JAW_CHASE = 6
-- Running, it leans forward up to this, and bobs and rolls this much.
local RUN_LEAN = math.rad(5)
local BOB = 1.5
local ROLL = math.rad(2)
-- Below this speed its feet settle home.
local WALK_FROM = 8

local rex = workspace:WaitForChild("Parks"):WaitForChild("Dino"):WaitForChild("TRex")
local serverRoot = rex:WaitForChild("Root") :: BasePart
local serverHead = rex:WaitForChild("Head") :: BasePart
local carsFolder = workspace:WaitForChild("Cars")

-- Rojo has synced some scripts into Studio twice; only one copy draws.
if workspace:FindFirstChild("TRexLook") then
	return
end
local model = Instance.new("Model")
model.Name = "TRexLook"
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

-- A block lying on top of another, as a stripe.
local function stripe(bone: string, under: CFrame, underSize: Vector3, z: number, width: number?)
	add(
		bone,
		Vector3.new(width or underSize.X + 0.4, 0.6, 3),
		under * CFrame.new(0, underSize.Y / 2 + 0.2, z),
		STRIPE_COLOR
	)
end

-- Body.
local PELVIS = CFrame.new(0, 2, 6)
local PELVIS_SIZE = Vector3.new(30, 28, 30)
local TORSO = CFrame.new(0, 6, -20) * CFrame.Angles(math.rad(8), 0, 0)
local TORSO_SIZE = Vector3.new(32, 32, 44)
local CHEST = CFrame.new(0, 12, -42) * CFrame.Angles(math.rad(18), 0, 0)
local CHEST_SIZE = Vector3.new(26, 28, 22)
add("body", PELVIS_SIZE, PELVIS, SKIN_COLOR)
add("body", TORSO_SIZE, TORSO, SKIN_COLOR)
add("body", CHEST_SIZE, CHEST, SKIN_COLOR)
add("body", Vector3.new(22, 3, 46), TORSO * CFrame.new(0, -TORSO_SIZE.Y / 2 - 0.5, 0), BELLY_COLOR)
add("body", Vector3.new(18, 3, 18), CHEST * CFrame.new(0, -CHEST_SIZE.Y / 2 - 0.5, 0), BELLY_COLOR)
for _, z in { -15, -5, 5, 15 } do
	stripe("body", TORSO, TORSO_SIZE, z)
end
for _, z in { -6, 6 } do
	stripe("body", PELVIS, PELVIS_SIZE, z)
end

-- Neck: sized each frame to reach the head.
local neck = add("neck", Vector3.new(NECK_SIZE.X, NECK_SIZE.Y, 1), CFrame.identity, SKIN_COLOR)
local throat = add("neck", Vector3.new(12, 1, 1), CFrame.new(0, -NECK_SIZE.Y / 2 - 0.3, 0), BELLY_COLOR)

-- Head, facing -Z, its front at -Size.Z / 2.
local CRANIUM = CFrame.new(0, 3, 9)
local CRANIUM_SIZE = Vector3.new(22, 12, 16)
add("head", CRANIUM_SIZE, CRANIUM, SKIN_COLOR)
add("head", Vector3.new(18, 9, 22), CFrame.new(0, 1.5, -7), SKIN_COLOR)
add("head", Vector3.new(16, 1, 20), CFrame.new(0, -3.2, -7), MOUTH_COLOR)
for _, z in { 6, 11 } do
	stripe("head", CRANIUM, CRANIUM_SIZE, z - CRANIUM.Z)
end
for _, side in { -1, 1 } do
	add("head", Vector3.new(6, 2.5, 7), CFrame.new(side * 7, 9.5, 4), STRIPE_COLOR) -- brow
	add("head", Vector3.new(1, 3.5, 3.5), CFrame.new(side * 11.1, 6, 6), EYE_COLOR)
	add("head", Vector3.new(1, 3, 1), CFrame.new(side * 11.5, 6, 6), DARK_COLOR) -- pupil
	add("head", Vector3.new(2.5, 1, 2), CFrame.new(side * 4.5, 6.1, -15), DARK_COLOR) -- nostril
	for _, z in { -16, -12.5, -9, -5.5, -2 } do
		add("head", Vector3.new(1.4, 2.5, 1.4), CFrame.new(side * 8, -4.2, z), TOOTH_COLOR)
	end
	add("head", Vector3.new(1.4, 2.5, 1.4), CFrame.new(side * 3, -4.2, -17.5), TOOTH_COLOR)
end

-- Lower jaw, hinged at the back of the mouth, reaching to the snout's front.
add("jaw", Vector3.new(16, 5, 28), CFrame.new(0, -2.5, -14), BELLY_COLOR)
add("jaw", Vector3.new(10, 1, 18), CFrame.new(0, 0.3, -14), MOUTH_COLOR) -- tongue
for _, side in { -1, 1 } do
	for _, z in { -25, -21, -17, -13, -9 } do
		add("jaw", Vector3.new(1.2, 2.2, 1.2), CFrame.new(side * 6.8, 1.1, z), TOOTH_COLOR)
	end
end

-- Little arms, from the chest, each a bone pointing along -Z.
for _, side in { "L", "R" } do
	add("upperArm" .. side, Vector3.new(4, 4, 10), CFrame.new(0, 0, -5), SKIN_COLOR)
	add("foreArm" .. side, Vector3.new(3, 3, 8), CFrame.new(0, 0, -4), SKIN_COLOR)
	for _, x in { -0.8, 0.8 } do
		add("foreArm" .. side, Vector3.new(1, 1, 3), CFrame.new(x, 0, -9.5), TOOTH_COLOR)
	end
end

-- Legs: each bone lies along its segment (-Z toward the far end).
for _, side in { "L", "R" } do
	add("thigh" .. side, Vector3.new(13, 18, THIGH + 6), CFrame.identity, SKIN_COLOR)
	add("thigh" .. side, Vector3.new(14, 22, 16), CFrame.new(0, 2, -THIGH * 0.2), SKIN_COLOR)
	add("shin" .. side, Vector3.new(9, 10, SHIN + 4), CFrame.identity, SKIN_COLOR)
	add("meta" .. side, Vector3.new(7, 7, ANKLE_OVER_BALL.Magnitude + 3), CFrame.identity, SKIN_COLOR)
	add("foot" .. side, Vector3.new(12, 4, 16), CFrame.new(0, 0, -4), SKIN_COLOR)
	for _, x in { -4, 0, 4 } do
		add("foot" .. side, Vector3.new(2.4, 2.4, 5), CFrame.new(x, -0.4, -13.5), TOOTH_COLOR)
	end
end

-- Tail blocks, each bone at the block's front end pointing back along +Z.
for i, size in TAIL do
	local block = CFrame.new(0, 0, size.Z / 2)
	add("tail" .. i, size, block, SKIN_COLOR)
	stripe("tail" .. i, block, size, 0, size.X + 0.4)
end

local cframes: { CFrame } = table.create(#parts)

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

local root = serverRoot.CFrame
local head = serverHead.CFrame
local speed = 0
local yawRate = 0
local cycle = 0
local open = 0
local chewStart = 0
local bones: { [string]: CFrame } = {}

rex:GetAttributeChangedSignal("Chewing"):Connect(function()
	chewStart = os.clock()
end)

RunService.RenderStepped:Connect(function(dt: number)
	if dt <= 0 then
		return
	end
	local mode = rex:GetAttribute("Mode")
	local smooth = 1 - math.exp(-L.Smooth * dt)
	local lastRoot = root
	root = root:Lerp(serverRoot.CFrame, smooth)
	local heldName = rex:GetAttribute("HeldCar")
	local held = if typeof(heldName) == "string" and heldName ~= "" then carsFolder:FindFirstChild(heldName) else nil
	local playerName = rex:GetAttribute("HeldPlayer")
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
	local running = math.clamp(speed / R.RunSpeed, 0, 1)
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

		local wiggle = math.rad(10) * math.sin(os.clock() * 4 + k)
		local shoulder = body * CFrame.new(x * 12, 2, -46) * CFrame.Angles(math.rad(-60) + wiggle, 0, 0)
		bones["upperArm" .. side] = shoulder
		bones["foreArm" .. side] = shoulder * CFrame.new(0, 0, -10) * CFrame.Angles(math.rad(70), 0, 0)
	end

	-- Neck, from the chest to the back of the head.
	local base = body:PointToWorldSpace(NECK_BASE)
	local top = head:PointToWorldSpace(NECK_TOP)
	local reach = (top - base).Magnitude
	bones.neck = CFrame.lookAt((base + top) / 2, top, head.UpVector)
	neck.Size = Vector3.new(NECK_SIZE.X, NECK_SIZE.Y, reach + 8)
	throat.Size = Vector3.new(12, 1, reach)

	-- Jaw.
	local chewing = rex:GetAttribute("Chewing") == true
	local goal = 0
	if mode == "lunge" then
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
	local bone = body * TAIL_BASE
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
end)
