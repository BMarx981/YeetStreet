--!strict
-- PteroLook (LocalScript) -> StarterPlayerScripts.PteroLook
-- Draws Dino Valley's pterodactyl on this client, in blocks like the T-Rex:
-- a brown body with a pale belly, a long pale beak, an orange crest swept
-- back off its head, yellow eyes, and wide rust-red wings with dark bones
-- along their front edges. Only for looks: cars pass through it.
--
-- The server moves one invisible part in workspace.Parks.Dino.Pterodactyl
-- (Parks.DinoPtero): Talons, where its feet are, level and facing the way it
-- flies. This client glides its drawing after it, Look.Smooth per second,
-- banks it into turns and tips it up or down with its climb. The wings beat
-- slowly circling, hard carrying a car, spread for the warning before a
-- swoop, swept back in the dive, and folded on its perch. Its legs hang
-- down to its feet: tucked back in flight, gripping the car's roof or the
-- nest. While it carries a car (CarriedCar), it is drawn where the car's
-- roof is, so the car never drifts from its feet on screen. A dark shadow
-- lies on the ground under it, darker the lower it flies. It screeches as
-- it starts a swoop.
-- While the park is put away (the :dino admin command), so is the drawing.
-- The model and Talons are recorded for replays (ReplayWorld.follow).
-- During one it is drawn from the recording, jumping there
-- (Tuning.Replay.Jump) as the replay starts or scrubs, with its wings beating
-- on the replay's clock; it carries the ghost car if it carried the replayed
-- car, and screeches as the replay passes the start of a swoop. Its screech
-- comes from its body.
-- Numbers are in Tuning.Dino.Ptero (Look).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)
local ReplayWorld = require(script.Parent.ReplayWorld)

local P = Tuning.Dino.Ptero
local L = P.Look

local BODY_COLOR = Color3.fromRGB(150, 104, 70)
local BELLY_COLOR = Color3.fromRGB(214, 180, 132)
local WING_COLOR = Color3.fromRGB(176, 84, 58)
local BONE_COLOR = Color3.fromRGB(104, 66, 44)
local CREST_COLOR = Color3.fromRGB(232, 120, 40)
local BEAK_COLOR = Color3.fromRGB(232, 204, 120)
local EYE_COLOR = Color3.fromRGB(250, 200, 40)
local DARK_COLOR = Color3.fromRGB(20, 20, 20)

-- The body's middle is BODY_UP over its feet. Points below are in the
-- body's frame (facing -Z) unless they say otherwise.
local BODY_UP = 9
local HEAD_AT = CFrame.new(0, 4, -12.5)
local SHOULDER = Vector3.new(3, 1.8, -3.5)
local HIP = Vector3.new(1.6, -2.6, 4)
-- Each wing: the arm from shoulder to wrist, then the long finger.
local INNER = 16
local OUTER = 22
-- Where a foot is in flight, tucked back under the tail.
local FOOT_TUCKED = Vector3.new(1.6, -3.5, 9)
-- Where a foot is on a car's roof or the nest, in the talons' frame.
local FOOT_GRIP = Vector3.new(1.6, 0.4, 0)
-- How the wings sit and beat in each mode: beat angle each way (degrees)
-- and beats a second, then the angle they beat about, how far each arm and
-- finger sweeps back.
type Pose = { angle: number, rate: number, base: number, sweep: number, finger: number }
local FOLDED: Pose = { angle = 0, rate = 0, base = -25, sweep = 70, finger = 120 }
local CIRCLING: Pose = { angle = L.FlapAngle, rate = L.FlapRate, base = 6, sweep = 5, finger = 5 }
local HOMING: Pose = { angle = L.FlapAngle, rate = L.FlapRate * 1.2, base = 6, sweep = 5, finger = 5 }
local WARNING: Pose = { angle = 10, rate = 1.2, base = 12, sweep = 0, finger = 0 }
local DIVING: Pose = { angle = 0, rate = 0, base = 10, sweep = 40, finger = 40 }
local CARRYING: Pose = { angle = L.CarryFlapAngle, rate = L.CarryFlapRate, base = 4, sweep = 0, finger = 10 }
-- Falling faster than this in a swoop, it is diving, not warning.
local DIVE_FROM = 20
-- How quickly the wings change pose, per second.
local POSE_CHANGE = 4
-- The body rises this much per degree of wing beat on each downstroke.
local BOB = 0.04
-- Its head tips down this much diving and carrying.
local HEAD_DOWN = math.rad(20)
-- Below this speed it is hovering: no pitch from its climb.
local PITCH_FROM = 20
-- The shadow is this see-through on the ground and this see-through
-- SHADOW_FADE studs up and higher.
local SHADOW_NEAR = 0.35
local SHADOW_FAR = 0.85
local SHADOW_FADE = 400

local pterodactyl = workspace:WaitForChild("Parks"):WaitForChild("Dino"):WaitForChild("Pterodactyl")
local serverTalons = pterodactyl:WaitForChild("Talons") :: BasePart
ReplayWorld.follow(pterodactyl)
ReplayWorld.follow(serverTalons)
local carsFolder = workspace:WaitForChild("Cars")

-- Rojo has synced some scripts into Studio twice; only one copy draws.
if workspace:FindFirstChild("PteroLook") then
	return
end
local model = Instance.new("Model")
model.Name = "PteroLook"
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

-- Body.
local torso = add("body", Vector3.new(6, 5.5, 14), CFrame.identity, BODY_COLOR)
add("body", Vector3.new(4.6, 0.6, 11), CFrame.new(0, -2.9, 0.5), BELLY_COLOR)
add("body", Vector3.new(3, 3, 7), CFrame.new(0, 2, -8.5) * CFrame.Angles(math.rad(25), 0, 0), BODY_COLOR) -- neck
add("body", Vector3.new(1, 1, 7), CFrame.new(0, 0.5, 10.5), BODY_COLOR) -- tail

-- Head, facing -Z: a long beak in front, the crest swept back.
add("head", Vector3.new(4, 4, 6), CFrame.identity, BODY_COLOR)
add("head", Vector3.new(2.2, 1.4, 13), CFrame.new(0, -0.4, -9), BEAK_COLOR)
add("head", Vector3.new(1.8, 0.9, 11), CFrame.new(0, -1.5, -8), BEAK_COLOR)
add("head", Vector3.new(1, 4.5, 11), CFrame.new(0, 2.6, 5.5) * CFrame.Angles(math.rad(-20), 0, 0), CREST_COLOR)
for _, x in { -1, 1 } do
	add("head", Vector3.new(0.6, 1.4, 1.4), CFrame.new(x * 2.05, 0.8, -1), EYE_COLOR)
	add("head", Vector3.new(0.4, 1, 0.6), CFrame.new(x * 2.3, 0.8, -1.2), DARK_COLOR) -- pupil
end

-- Wings: each bone at its joint, the wing reaching out along its side's X.
for _, side in { "L", "R" } do
	local x = if side == "L" then -1 else 1
	add("arm" .. side, Vector3.new(INNER, 0.6, 11), CFrame.new(x * INNER / 2, 0, 2.5), WING_COLOR)
	add("arm" .. side, Vector3.new(INNER, 1.4, 1.4), CFrame.new(x * INNER / 2, 0.3, -3.2), BONE_COLOR)
	add("finger" .. side, Vector3.new(13, 0.5, 8), CFrame.new(x * 6.5, 0, 1), WING_COLOR)
	add(
		"finger" .. side,
		Vector3.new(OUTER - 13, 0.5, 4.5),
		CFrame.new(x * (13 + (OUTER - 13) / 2), 0, -0.5),
		WING_COLOR
	)
	add("finger" .. side, Vector3.new(OUTER, 1, 1), CFrame.new(x * OUTER / 2, 0.2, -3.2), BONE_COLOR)
	add("finger" .. side, Vector3.new(1.2, 1.2, 2), CFrame.new(x * 0.5, 0.4, -4.5), DARK_COLOR) -- thumb claw
end

-- Legs, sized each frame to reach the feet, and the feet.
local legs: { [string]: Part } = {}
for _, side in { "L", "R" } do
	legs[side] = add("leg" .. side, Vector3.new(0.9, 0.9, 1), CFrame.identity, BONE_COLOR)
	add("foot" .. side, Vector3.new(2.6, 0.8, 3), CFrame.identity, DARK_COLOR)
end

-- The shadow: a dark disc lying on the ground.
local shadow = Instance.new("Part")
shadow.Name = "Shadow"
shadow.Shape = Enum.PartType.Cylinder
shadow.Anchored = true
shadow.CanCollide = false
shadow.CanQuery = false
shadow.CanTouch = false
shadow.CastShadow = false
shadow.Size = Vector3.new(0.2, L.ShadowSize, L.ShadowSize)
shadow.Color = DARK_COLOR
shadow.Material = Enum.Material.SmoothPlastic
shadow.Parent = model

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { model, pterodactyl, carsFolder }

local cframes: { CFrame } = table.create(#parts)

-- A frame lying along a to b (-Z toward b), with X along `right`.
local function along(a: Vector3, b: Vector3, right: Vector3): CFrame
	local back = (a - b).Unit
	return CFrame.fromMatrix((a + b) / 2, right, back:Cross(right), back)
end

local function poseFor(mode: any, vy: number): Pose
	if mode == "perch" then
		return FOLDED
	elseif mode == "carry" or mode == "recover" then
		return CARRYING
	elseif mode == "swoop" then
		return if vy < -DIVE_FROM then DIVING else WARNING
	elseif mode == "home" then
		return HOMING
	end
	return CIRCLING
end

-- It screeches as it starts a swoop, from its body. While a replay plays,
-- the screech comes from the recording instead.
local screech = Instance.new("Sound")
screech.SoundId = L.Screech
screech.PlaybackSpeed = L.ScreechPitch
screech.Volume = L.ScreechVolume
screech.RollOffMaxDistance = L.ScreechHearing
screech.Parent = torso
local lastMode = pterodactyl:GetAttribute("Mode")
pterodactyl:GetAttributeChangedSignal("Mode"):Connect(function()
	local mode = pterodactyl:GetAttribute("Mode")
	if mode == "swoop" and lastMode ~= "swoop" and not ReplayWorld.isWatching() then
		screech:Play()
	end
	lastMode = mode
end)

-- Screeches if the replay went past it starting a swoop since the frame
-- before.
local function replayScreech()
	local mode, fromMode = ReplayWorld.lastChange(pterodactyl, "Mode")
	if mode and mode.value == "swoop" and fromMode ~= "swoop" and #ReplayWorld.passed(pterodactyl, "Mode") > 0 then
		screech:Play()
	end
end

local talons = serverTalons.CFrame
local lastClock = ReplayWorld.time()
local velocity = Vector3.zero
local yawRate = 0
local pose: Pose = table.clone(FOLDED)
local beat = 0
local headDown = 0
local bones: { [string]: CFrame } = {}

RunService.RenderStepped:Connect(function(dt: number)
	if dt <= 0 then
		return
	end
	local shown = pterodactyl:IsDescendantOf(workspace)
	if (model.Parent ~= nil) ~= shown then
		model.Parent = if shown then workspace else nil
	end
	if not shown then
		return
	end
	-- In a replay it is drawn from the recording (ReplayWorld), and its
	-- wings beat on the replay's clock, so they stop while it is paused.
	local watching = ReplayWorld.isWatching()
	local clock = ReplayWorld.time()
	local tick = if watching then math.max(clock - lastClock, 0) else dt
	lastClock = clock
	if watching then
		replayScreech()
	end
	local mode = ReplayWorld.attribute(pterodactyl, "Mode")
	local smooth = 1 - math.exp(-L.Smooth * dt)
	local target = ReplayWorld.cframe(serverTalons)
	if (target.Position - talons.Position).Magnitude > Tuning.Replay.Jump then
		talons = target
	end
	local last = talons
	local carriedName = ReplayWorld.attribute(pterodactyl, "CarriedCar")
	local carrying = typeof(carriedName) == "string" and carriedName ~= ""
	local ghost = if carrying then ReplayWorld.car(carriedName) else nil
	local carried = if carrying and not watching then carsFolder:FindFirstChild(carriedName) else nil
	if ghost then
		talons = ghost * CFrame.new(0, P.CarTop, 0)
	elseif carried and carried:IsA("Model") and carried.PrimaryPart and carried.PrimaryPart.Anchored then
		talons = carried:GetPivot() * CFrame.new(0, P.CarTop, 0)
	else
		talons = talons:Lerp(target, if mode == "swoop" then 1 - math.exp(-2 * L.Smooth * dt) else smooth)
	end
	if (talons.Position - last.Position).Magnitude > Tuning.Replay.Jump then
		last = talons
	end
	velocity = velocity:Lerp((talons.Position - last.Position) / dt, smooth)
	local turned = math.atan2(last.LookVector:Cross(talons.LookVector).Y, last.LookVector:Dot(talons.LookVector))
	yawRate += (turned / dt - yawRate) * smooth

	-- Flying: banked into turns as a turn at its speed needs, tipped with its
	-- climb once it is moving.
	local flat = Vector2.new(velocity.X, velocity.Z).Magnitude
	local bank = math.clamp(math.atan(flat * yawRate / workspace.Gravity), -math.rad(L.MostBank), math.rad(L.MostBank))
	local pitch = math.clamp(math.atan2(velocity.Y, math.max(flat, 1)), -math.rad(L.MostPitch), math.rad(L.MostPitch))
		* math.clamp(flat / PITCH_FROM, 0, 1)
	if mode == "perch" then
		bank, pitch = 0, 0
	end

	-- Wings ease into the mode's pose and beat.
	local goal = poseFor(mode, velocity.Y)
	local change = 1 - math.exp(-POSE_CHANGE * dt)
	local current = pose :: any
	for key, value in goal :: any do
		current[key] += (value - current[key]) * change
	end
	beat = (beat + pose.rate * tick) % 1
	local wave = math.sin(2 * math.pi * beat)
	local flap = math.rad(pose.base + pose.angle * wave)
	local fingerFlap = math.rad(pose.base * 0.3 + pose.angle * 0.6 * math.sin(2 * math.pi * beat - 0.8))

	local body = talons * CFrame.new(0, BODY_UP - BOB * pose.angle * wave, 0) * CFrame.Angles(pitch, 0, bank)
	bones.body = body
	local down = if mode == "swoop" or mode == "carry" then HEAD_DOWN else 0
	headDown += (down - headDown) * change
	bones.head = body * HEAD_AT * CFrame.Angles(-headDown, 0, 0)

	local gripping = mode == "perch" or ghost ~= nil or carried ~= nil
	for _, side in { "L", "R" } do
		local x = if side == "L" then -1 else 1
		local arm = body
			* CFrame.new(x * SHOULDER.X, SHOULDER.Y, SHOULDER.Z)
			* CFrame.Angles(0, -x * math.rad(pose.sweep), 0)
			* CFrame.Angles(0, 0, x * flap)
		bones["arm" .. side] = arm
		bones["finger" .. side] = arm
			* CFrame.new(x * INNER, 0, 0)
			* CFrame.Angles(0, -x * math.rad(pose.finger), 0)
			* CFrame.Angles(0, 0, x * fingerFlap)

		local hip = body:PointToWorldSpace(Vector3.new(x * HIP.X, HIP.Y, HIP.Z))
		local foot = if gripping
			then talons:PointToWorldSpace(Vector3.new(x * FOOT_GRIP.X, FOOT_GRIP.Y, FOOT_GRIP.Z))
			else body:PointToWorldSpace(Vector3.new(x * FOOT_TUCKED.X, FOOT_TUCKED.Y, FOOT_TUCKED.Z))
		local reach = (foot - hip).Magnitude
		bones["leg" .. side] = if reach > 1e-3 then along(hip, foot, body.RightVector) else CFrame.new(hip)
		legs[side].Size = Vector3.new(0.9, 0.9, math.max(reach, 0.1))
		bones["foot" .. side] = CFrame.new(foot) * body.Rotation
	end

	for i, piece in pieces do
		cframes[i] = bones[piece.bone] * piece.offset
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

	local hit = workspace:Raycast(talons.Position, Vector3.new(0, -2000, 0), rayParams)
	if hit then
		local up = talons.Position.Y - hit.Position.Y
		shadow.Transparency = SHADOW_NEAR + (SHADOW_FAR - SHADOW_NEAR) * math.clamp(up / SHADOW_FADE, 0, 1)
		shadow.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	else
		shadow.Transparency = 1
	end
end)
