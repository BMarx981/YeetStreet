--!strict
-- CrusherLook (LocalScript) -> StarterPlayerScripts.CrusherLook
-- Makes and moves the Scrapyard crusher's head, its piston, and its pressure
-- gauge on this client, from the server's clock and the crusher's CycleAt and
-- CrushTime attributes (Parks.ScrapyardCrusher), so every player sees the
-- same slam. The head is solid on this client, as cars are driven here.
-- While the FillAt attribute is set, the gauge counts down to the slam.
--
-- Every car with the Crushing attribute is flattened to fit under the head
-- (Crusher.squash): its visible parts come off their welds and are anchored
-- here, then squashed down toward the bed each frame. Parts knocked off on
-- the way fly as usual (CarVisuals unanchors them). Its driver is hidden
-- until the car is gone, as nobody is ever hurt.
--
-- The head hisses as it starts down and again as it opens, slams as it
-- meets the cars, and grinds while it crushes (Crusher.cues); the gauge
-- beeps each second of the countdown. During a replay the head and gauge
-- are as they were at the moment being watched (ReplayWorld), sounds too;
-- the cars it squashes stay as they are now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Crusher = require(ReplicatedStorage.Crusher)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local CrusherCamera = require(script.Parent.CrusherCamera)
local OneShot = require(script.Parent.OneShot)
local ReplayWorld = require(script.Parent.ReplayWorld)

local C = Tuning.Scrapyard.Crusher
local S = Tuning.Scrapyard.Sounds
-- Seconds; a longer jump in time between frames (a replay starting or
-- scrubbing) plays no sounds.
local CUE_GAP = 0.5
local CONFIG: Crusher.Config = C :: any

if not MapLayout.find(Tuning.Map.Areas :: any, "Scrapyard") then
	return
end

local frame = CrusherCamera.frame

local IDLE_TEXT = "CRUSHER"
local IDLE_COLOR = Color3.fromRGB(255, 196, 0)
local CRUSH_COLOR = Color3.fromRGB(255, 70, 40)

local folder = Instance.new("Folder")
folder.Name = "CrusherLook"
folder.Parent = workspace

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

local head =
	part("Head", Vector3.new(C.BedWidth - 1, C.HeadThickness, C.BedLength - 2), C.HeadColor, Enum.Material.Metal)
local piston = part("Piston", Vector3.new(1, C.PistonWidth, C.PistonWidth), C.SteelColor, Enum.Material.Metal)
piston.Shape = Enum.PartType.Cylinder
piston.CanCollide = false

-- On the beam's front, facing cars driving in.
local gauge = part("Gauge", Vector3.new(C.BedWidth, C.BeamDepth - 1, 0.4), C.SteelColor, Enum.Material.SmoothPlastic)
gauge.CanCollide = false
gauge.CFrame = frame
	* CFrame.new(0, C.FrameHeight + C.BeamDepth / 2, C.BedLength / 2 + 0.3)
	* CFrame.Angles(0, math.pi, 0)
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Front
gui.PixelsPerStud = 20
gui.Parent = gauge
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
label.Font = Enum.Font.FredokaOne
label.TextScaled = true
label.TextColor3 = IDLE_COLOR
label.Text = IDLE_TEXT
label.Parent = gui

local hiss = OneShot.make(S.CrusherHiss, S.Near, S.Far, head)
local slam = OneShot.make(S.CrusherSlam, S.Near, S.Far, head)
local grind = OneShot.make(S.CrusherGrind, S.Near, S.Far, head)
grind.Looped = true
local beep = OneShot.make(S.CrusherBeep, S.Near, S.Far, gauge)

local function placeHead(height: number)
	head.CFrame = frame * CFrame.new(0, height + C.HeadThickness / 2, 0)
	local from = height + C.HeadThickness
	local length = math.max(C.FrameHeight - from, 0.2)
	piston.Size = Vector3.new(length, C.PistonWidth, C.PistonWidth)
	piston.CFrame = frame * CFrame.new(0, from + length / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
end
placeHead(C.TopHeight)

-- A car being flattened: each visible part where it started, and which of
-- its own axes is most upright.
type Piece = { part: BasePart, start: CFrame, size: Vector3, axis: "X" | "Y" | "Z" }
type Squashed = { pieces: { Piece }, top: number, hidden: { Instance } }

local squashed: { [Model]: Squashed } = {}

local function uprightAxis(cframe: CFrame): "X" | "Y" | "Z"
	local x, y, z = math.abs(cframe.RightVector.Y), math.abs(cframe.UpVector.Y), math.abs(cframe.LookVector.Y)
	if x >= y and x >= z then
		return "X"
	end
	return if y >= z then "Y" else "Z"
end

local function setHidden(things: { Instance }, hidden: boolean)
	for _, thing in things do
		if thing:IsA("BasePart") or thing:IsA("Decal") then
			thing.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function startSquash(car: Model)
	local bedY = frame.Position.Y
	local visible: { [BasePart]: boolean } = {}
	for _, thing in car:GetDescendants() do
		if thing:IsA("BasePart") and thing.Transparency < 1 then
			visible[thing] = true
		end
	end
	-- Unweld them, so each can be moved on its own.
	for _, thing in car:GetDescendants() do
		if thing:IsA("WeldConstraint") or thing:IsA("JointInstance") then
			local a, b = (thing :: any).Part0, (thing :: any).Part1
			if (a and visible[a]) or (b and visible[b]) then
				thing:Destroy()
			end
		end
	end
	local pieces: { Piece } = {}
	local top = 0
	for p in visible do
		p.Anchored = true
		local cf, size = p.CFrame, p.Size
		local reach = math.abs(cf.RightVector.Y) * size.X
			+ math.abs(cf.UpVector.Y) * size.Y
			+ math.abs(cf.LookVector.Y) * size.Z
		top = math.max(top, cf.Position.Y + reach / 2 - bedY)
		table.insert(pieces, { part = p, start = cf, size = size, axis = uprightAxis(cf) })
	end
	local hidden: { Instance } = {}
	local owner = Players:GetPlayerByUserId(car:GetAttribute("OwnerUserId") :: any or 0)
	if owner and owner.Character then
		hidden = owner.Character:GetDescendants()
		setHidden(hidden, true)
	end
	squashed[car] = { pieces = pieces, top = top, hidden = hidden }
end

local function squash(car: Model, state: Squashed, height: number)
	local bedY = frame.Position.Y
	local keep = Crusher.squash(CONFIG, state.top, height)
	for _, piece in state.pieces do
		local p = piece.part
		if not p:IsDescendantOf(car) then
			continue
		end
		local size = piece.size
		if piece.axis == "X" then
			size = Vector3.new(size.X * keep, size.Y, size.Z)
		elseif piece.axis == "Y" then
			size = Vector3.new(size.X, size.Y * keep, size.Z)
		else
			size = Vector3.new(size.X, size.Y, size.Z * keep)
		end
		local at = piece.start.Position
		p.Size = size
		p.CFrame = piece.start.Rotation + Vector3.new(at.X, bedY + (at.Y - bedY) * keep, at.Z)
	end
end

local function crusherModel(): Instance?
	local parks = workspace:FindFirstChild("Parks")
	local yard = parks and parks:FindFirstChild("Scrapyard")
	return yard and yard:FindFirstChild("Crusher")
end

local followed: Instance? = nil
local lastTime = 0
local lastCycleAt: number? = nil
local lastCount: number? = nil

RunService.RenderStepped:Connect(function()
	local model = crusherModel()
	if model and model ~= followed then
		followed = model
		ReplayWorld.follow(model)
	end
	local cycleAt = model and ReplayWorld.attribute(model, "CycleAt")
	local crushTime = model and ReplayWorld.attribute(model, "CrushTime")
	local fillAt = model and ReplayWorld.attribute(model, "FillAt")
	local now = ReplayWorld.serverTime()
	local step = now - lastTime
	local cueing = step > 0 and step <= CUE_GAP
	lastTime = now
	local grinding = false
	local count: number? = nil
	local height = C.TopHeight
	if typeof(cycleAt) == "number" and typeof(crushTime) == "number" then
		local elapsed = now - cycleAt
		height = Crusher.headHeight(CONFIG, elapsed, crushTime)
		label.Text = `{math.floor(Crusher.tons(CONFIG, elapsed, crushTime))} TONS`
		label.TextColor3 = CRUSH_COLOR
		if cueing then
			-- A cycle seen for the first time hisses only if it just started.
			local from = if cycleAt == lastCycleAt then elapsed - step elseif elapsed < CUE_GAP then -1e-3 else elapsed
			for _, cue in Crusher.cues(CONFIG, from, elapsed, crushTime) do
				if cue == "slam" then
					OneShot.play(slam, S.CrusherSlam)
				else
					OneShot.play(hiss, S.CrusherHiss)
				end
			end
			grinding = Crusher.phase(CONFIG, elapsed, crushTime) == "crushing"
		end
	elseif typeof(fillAt) == "number" then
		count = Crusher.countdown(CONFIG, now - fillAt)
		label.Text = `CRUSHING IN {count}`
		label.TextColor3 = CRUSH_COLOR
		if cueing and count ~= lastCount and (count :: number) > 0 then
			OneShot.play(beep, S.CrusherBeep)
		end
	else
		label.Text = IDLE_TEXT
		label.TextColor3 = IDLE_COLOR
	end
	lastCycleAt = if typeof(cycleAt) == "number" then cycleAt else nil
	lastCount = count
	if grinding and not grind.Playing then
		grind:Play()
	elseif not grinding and grind.Playing then
		grind:Stop()
	end
	placeHead(height)

	for car, state in squashed do
		if not car.Parent then
			setHidden(state.hidden, false)
			squashed[car] = nil
		end
	end
	local cars = workspace:FindFirstChild("Cars")
	if not cars then
		return
	end
	for _, car in cars:GetChildren() do
		if car:IsA("Model") and car:GetAttribute("Crushing") then
			local state = squashed[car]
			if not state then
				startSquash(car)
				state = squashed[car]
			end
			if state then
				squash(car, state, height)
			end
		end
	end
end)
