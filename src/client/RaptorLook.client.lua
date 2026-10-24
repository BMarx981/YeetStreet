--!strict
-- RaptorLook (LocalScript) -> StarterPlayerScripts.RaptorLook
-- Draws Dino Valley's velociraptors on this client, in blocks like the
-- little ones riding the Velociraptor car (CarVisuals): green with a paler
-- belly, dark stripes down the back, amber eyes and jaw. Only for looks:
-- nothing touches them.
--
-- The server moves one invisible part per raptor in
-- workspace.Parks.Dino.Raptors (Parks.DinoRaptors), at the middle of its
-- body. This client glides each drawing after its part, Look.Smooth per
-- second. Running, its legs swing, its body bobs and its tail sways; hiding
-- and standing still, it crouches. Chasing, it keeps its jaw a little open,
-- and each bite (the part's Bites attribute) snaps it. Latched on (Mode
-- latch), it is drawn on its spot (Tuning.Dino.Raptors.Slots) on the car or
-- player its Target points at, as this client sees them, so it never trails
-- behind a fast car. Each screeches as its pack springs an ambush (Mode hide
-- to chase), and each bite snaps.
-- Numbers are in Tuning.Dino.Raptors.Look.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local R = Tuning.Dino.Raptors
local L = R.Look
local S = L.Scale

local GREEN = Color3.fromRGB(90, 140, 60)
local BELLY = Color3.fromRGB(130, 160, 70)
local AMBER = Color3.fromRGB(200, 120, 40)
local STRIPE = Color3.fromRGB(52, 86, 36)
local CLAW = Color3.fromRGB(235, 225, 200)

local SLOTS: { [string]: Vector3 } = {
	roof = R.Slots.Roof,
	hood = R.Slots.Hood,
	trunk = R.Slots.Trunk,
	left = R.Slots.Left,
	right = R.Slots.Right,
	pin = R.Slots.Pin,
}

-- Joints, in the body's frame (its middle, facing -Z), in the riding
-- raptors' sizes times Scale.
local NECK = CFrame.new(0, 0.55 * S, -0.7 * S)
local JAW_HINGE = CFrame.new(0, -0.15 * S, -0.5 * S) -- in the head's frame
local TAIL_BASE = CFrame.new(0, 0.2 * S, 0.75 * S)
local TAIL_MID = CFrame.new(0, -0.05 * S, 0.85 * S) -- in the first tail block's frame
local HIP = Vector3.new(0.3 * S, -0.25 * S, 0.1 * S)
local LEG = 0.8 * S -- hip to sole

local raptorsFolder = workspace:WaitForChild("Parks"):WaitForChild("Dino"):WaitForChild("Raptors")

-- Rojo has synced some scripts into Studio twice; only one copy draws.
if workspace:FindFirstChild("RaptorLook") then
	return
end
local folder = Instance.new("Folder")
folder.Name = "RaptorLook"
folder.Parent = workspace

type Piece = { part: BasePart, bone: string, offset: CFrame }
type Look = {
	marker: BasePart,
	model: Model,
	pieces: { Piece },
	frame: CFrame,
	speed: number,
	phase: number,
	crouch: number,
	jaw: number,
	bites: number,
	biteAt: number,
	latchAt: number,
	wasLatched: boolean,
	sway: number, -- its own tail beat, so the pack's tails differ
	snap: Sound,
}

local looks: { Look } = {}
local random = Random.new()

local function sound(parent: Instance, id: string, volume: number): Sound
	local made = Instance.new("Sound")
	made.SoundId = id
	made.Volume = volume
	made.RollOffMaxDistance = L.Hearing
	made.Parent = parent
	return made
end

local function newLook(marker: BasePart, index: number): Look
	local model = Instance.new("Model")
	model.Name = marker.Name
	local pieces: { Piece } = {}
	local function add(bone: string, size: Vector3, offset: CFrame, color: Color3): Part
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = size * S
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		table.insert(pieces, { part = part, bone = bone, offset = offset })
		return part
	end
	local lean = CFrame.Angles(math.rad(12), 0, 0)

	-- Body, leaning like a sprinting raptor, with a paler belly and stripes.
	add("body", Vector3.new(0.9, 0.8, 1.7), lean, GREEN)
	add("body", Vector3.new(0.7, 0.1, 1.4), lean * CFrame.new(0, -0.38 * S, 0), BELLY)
	for _, z in { -0.5, -0.1, 0.3 } do
		add("body", Vector3.new(0.94, 0.06, 0.14), lean * CFrame.new(0, 0.39 * S, z * S), STRIPE)
	end
	-- Little arms tucked forward, with claws.
	for _, side in { -1, 1 } do
		local arm = CFrame.new(side * 0.5 * S, 0.1 * S, -0.45 * S) * CFrame.Angles(math.rad(30), 0, 0)
		add("body", Vector3.new(0.14, 0.4, 0.14), arm, GREEN)
		add("body", Vector3.new(0.12, 0.08, 0.16), arm * CFrame.new(0, -0.22 * S, -0.04 * S), CLAW)
	end
	-- Head with amber eyes and a stripe, and an amber jaw that opens.
	local head = CFrame.new(0, 0.25 * S, -0.35 * S) * CFrame.Angles(math.rad(18), 0, 0)
	add("head", Vector3.new(0.7, 0.55, 1.1), head, GREEN)
	add("head", Vector3.new(0.72, 0.06, 0.3), head * CFrame.new(0, 0.28 * S, 0.2 * S), STRIPE)
	for _, side in { -1, 1 } do
		local eye = add("head", Vector3.new(0.18, 0.18, 0.18), CFrame.new(side * 0.26 * S, 0.38 * S, -0.62 * S), AMBER)
		eye.Shape = Enum.PartType.Ball
	end
	add("jaw", Vector3.new(0.5, 0.18, 0.6), CFrame.new(0, 0, -0.3 * S), AMBER)
	-- Tail in two blocks, lifted behind.
	add("tail1", Vector3.new(0.45, 0.45, 0.9), CFrame.new(0, 0, 0.45 * S), GREEN)
	add("tail1", Vector3.new(0.47, 0.06, 0.14), CFrame.new(0, 0.23 * S, 0.45 * S), STRIPE)
	add("tail2", Vector3.new(0.3, 0.3, 0.9), CFrame.new(0, 0, 0.45 * S), GREEN)
	-- Legs, each swinging from its hip, with a foot and a claw.
	for _, side in { "legL", "legR" } do
		add(side, Vector3.new(0.28, 0.75, 0.4), CFrame.new(0, -0.38 * S, 0), BELLY)
		add(side, Vector3.new(0.32, 0.1, 0.6), CFrame.new(0, -0.75 * S, -0.12 * S), BELLY)
		add(side, Vector3.new(0.1, 0.12, 0.18), CFrame.new(0, -0.72 * S, -0.48 * S), CLAW)
	end
	model.Parent = folder

	local body = pieces[1].part
	local screech = sound(body, L.Screech, L.ScreechVolume)
	local mode = marker:GetAttribute("Mode")
	marker:GetAttributeChangedSignal("Mode"):Connect(function()
		local now = marker:GetAttribute("Mode")
		if mode == "hide" and now == "chase" then
			task.delay(random:NextNumber(0, L.ScreechDelay), function()
				screech.PlaybackSpeed = random:NextNumber(L.MinPitch, L.MaxPitch)
				screech:Play()
			end)
		end
		mode = now
	end)

	return {
		marker = marker,
		model = model,
		pieces = pieces,
		frame = marker.CFrame,
		speed = 0,
		phase = index * 1.3,
		crouch = 0,
		jaw = 0,
		bites = marker:GetAttribute("Bites") or 0,
		biteAt = -math.huge,
		latchAt = -math.huge,
		wasLatched = false,
		sway = index * 2.1,
		snap = sound(body, L.Snap, L.SnapVolume),
	}
end

local function addMarker(marker: Instance)
	if marker:IsA("BasePart") then
		table.insert(looks, newLook(marker, #looks + 1))
	end
end
for _, marker in raptorsFolder:GetChildren() do
	addMarker(marker)
end
raptorsFolder.ChildAdded:Connect(addMarker)

-- Where a latched raptor's car or player is on this client, if it can see
-- them.
local function targetFrame(marker: BasePart): CFrame?
	local target = marker:FindFirstChild("Target")
	local thing = if target and target:IsA("ObjectValue") then target.Value else nil
	if not (thing and thing:IsA("Model") and thing:IsDescendantOf(workspace)) then
		return nil
	end
	local rootPart = thing:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.CFrame
	end
	return if thing.PrimaryPart then thing.PrimaryPart.CFrame else nil
end

local cframes: { CFrame } = {}

RunService.RenderStepped:Connect(function(dt: number)
	if dt <= 0 then
		return
	end
	-- The :dino command can put the park away; the drawings go with it.
	local shown = raptorsFolder:IsDescendantOf(workspace)
	if (folder.Parent ~= nil) ~= shown then
		folder.Parent = if shown then workspace else nil
	end
	if not shown then
		return
	end
	local now = os.clock()
	local smooth = 1 - math.exp(-L.Smooth * dt)
	table.clear(cframes)
	local parts: { BasePart } = {}

	for _, look in looks do
		local marker = look.marker
		local mode = marker:GetAttribute("Mode")
		local slot = marker:GetAttribute("Slot")
		local riding = mode == "latch" and typeof(slot) == "string" and SLOTS[slot] ~= nil
		local onCar = if riding then targetFrame(marker) else nil
		local last = look.frame

		if onCar and riding then
			if not look.wasLatched then
				look.latchAt = now
			end
			local goal = onCar * CFrame.new(SLOTS[slot :: string])
			local blend = math.clamp((now - look.latchAt) / L.LatchBlend, 0, 1)
			look.frame = if blend >= 1 then goal else look.frame:Lerp(goal, math.max(blend, smooth))
		else
			look.frame = look.frame:Lerp(marker.CFrame, smooth)
		end
		look.wasLatched = onCar ~= nil

		local moved = Vector3.new(look.frame.X - last.X, 0, look.frame.Z - last.Z).Magnitude
		look.speed += (moved / dt - look.speed) * smooth
		local perched = onCar ~= nil and slot ~= "left" and slot ~= "right"
		local running = if perched then 0 else math.clamp(look.speed / L.FullSpeed, 0, 1)
		look.phase += look.speed * dt / L.Stride * 2 * math.pi

		local crouchGoal = if mode == "hide" and look.speed < 3 or perched then 1 else 0
		look.crouch += (crouchGoal - look.crouch) * smooth

		local bites = marker:GetAttribute("Bites")
		if typeof(bites) == "number" and bites > look.bites then
			look.biteAt = now
			look.snap:Play()
		end
		look.bites = if typeof(bites) == "number" then bites else look.bites
		local sinceBite = now - look.biteAt
		local jawGoal = if sinceBite < L.BiteOpen
			then 1
			elseif mode == "chase" then 0.35
			elseif mode == "latch" then 0.2
			else 0
		local jawRate = if sinceBite < L.BiteOpen + L.BiteSnap and sinceBite >= L.BiteOpen then 40 else 12
		look.jaw += (jawGoal - look.jaw) * (1 - math.exp(-jawRate * dt))

		local swing = math.sin(look.phase) * math.rad(L.LegSwing) * running
		local bob = math.abs(math.sin(look.phase)) * L.Bob * running
		local drop = look.crouch * L.Crouch
		local body = look.frame * CFrame.new(0, bob - drop, 0)
		local nod = if sinceBite < L.BiteOpen + L.BiteSnap then math.rad(15) else look.crouch * math.rad(10)
		local headBone = body * NECK * CFrame.Angles(-nod, 0, 0)
		local jawBone = headBone * JAW_HINGE * CFrame.Angles(-look.jaw * math.rad(L.JawOpen), 0, 0)
		local wag = math.sin(now * L.TailRate * 2 * math.pi + look.sway) * math.rad(L.TailSway) * (1 + running)
		local tail1 = body * TAIL_BASE * CFrame.Angles(math.rad(-14), wag, 0)
		local tail2 = tail1 * TAIL_MID * CFrame.Angles(math.rad(-6), wag * 1.5, 0)
		-- A crouching leg bends back so its foot stays on the ground.
		local bend = math.acos(math.clamp((LEG - drop) / LEG, -1, 1))
		local bones: { [string]: CFrame } = {
			body = body,
			head = headBone,
			jaw = jawBone,
			tail1 = tail1,
			tail2 = tail2,
			legL = body * CFrame.new(-HIP.X, HIP.Y, HIP.Z) * CFrame.Angles(swing - bend, 0, 0),
			legR = body * CFrame.new(HIP.X, HIP.Y, HIP.Z) * CFrame.Angles(-swing - bend, 0, 0),
		}
		for _, piece in look.pieces do
			table.insert(parts, piece.part)
			table.insert(cframes, bones[piece.bone] * piece.offset)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
