--!strict
-- PedestrianLook (LocalScript) -> StarterPlayerScripts.PedestrianLook
-- Draws Downtown's walkers (Parks.CityPedestrians) on this client, in
-- blocks: each its own skin, shirt, pants and hair, carrying a coffee, a
-- briefcase, a phone, a newspaper or a small dog on a lead, all picked from
-- its number so every client draws it the same. Only for looks: nothing
-- touches them.
--
-- Every walker's place comes from the server's clock (Pedestrians) and its
-- Configuration in workspace.Parks.City.Pedestrians (Pedestrian.State as
-- attributes), so nothing is sent each frame. Only the nearest DrawCount
-- within DrawRange of the camera are drawn, by a fixed set of figures; a
-- walker keeps its figure while it stays among the nearest.
--
-- Walking, its legs and arms swing with the distance it walks, apart from
-- the arm holding its things. Diving, it leaps face first and lands on its
-- front. Knocked flat, it flies onto its back, arms and legs flailing, and
-- what it carries flies off and lands (a coffee spills); its dog stays and
-- hops about. Getting up, and shaking a fist, it says something in a
-- bubble: about what it carried, if it was knocked flat. It whooshes as it
-- dives, grunts as it is knocked flat and thuds as it lands, and its dog
-- yaps while it is busy.
-- Numbers are in Tuning.City.Pedestrians.Look.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Pedestrian = require(ReplicatedStorage.Pedestrian)
local Pedestrians = require(ReplicatedStorage.Pedestrians)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)

local C = Tuning.City
local P = C.Pedestrians
local D = P.Dodge
local L = P.Look
local FLOOR = Tuning.Map.FloorTop

local SKINS = {
	Color3.fromRGB(255, 220, 185),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 134, 94),
	Color3.fromRGB(141, 85, 54),
	Color3.fromRGB(96, 60, 40),
}
local SHIRTS = {
	Color3.fromRGB(200, 60, 60),
	Color3.fromRGB(60, 110, 200),
	Color3.fromRGB(70, 160, 90),
	Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(150, 80, 180),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(240, 140, 60),
}
local PANTS = {
	Color3.fromRGB(40, 50, 80),
	Color3.fromRGB(60, 60, 60),
	Color3.fromRGB(120, 95, 70),
	Color3.fromRGB(30, 30, 35),
}
local HAIRS = {
	Color3.fromRGB(30, 25, 20),
	Color3.fromRGB(90, 60, 30),
	Color3.fromRGB(200, 170, 90),
	Color3.fromRGB(150, 60, 30),
	Color3.fromRGB(180, 180, 180),
}
local DARK = Color3.fromRGB(30, 30, 30)
local SHOE = Color3.fromRGB(45, 35, 30)

type Prop = "Coffee" | "Briefcase" | "Phone" | "Newspaper" | "Dog"
local PROPS: { Prop } = { "Coffee", "Briefcase", "Phone", "Newspaper", "Dog" }

-- Joints in the figure's frame: its feet, facing -Z.
local HIP_Y, HIP_X = 2.2, 0.45
local SHOULDER_Y, SHOULDER_X = 4.0, 1.25
local NECK_Y = 4.1
local ARM = 1.85 -- shoulder to hand
local HALF_DEPTH = 0.45 -- lying down, its middle this far off the ground
local NEWSPAPER = CFrame.new(0, 3.9, -1.95)
local COLLAR = CFrame.new(0, 1.2, -0.7) -- in the dog's frame
local LEAD_REACH = 7 -- further than this from its dog, it has dropped the lead
local HIDDEN = CFrame.new(0, -500, 0)

local model = workspace:WaitForChild("Parks"):WaitForChild("City"):WaitForChild("Pedestrians")
local carsFolder = workspace:WaitForChild("Cars")

-- Rojo has synced some scripts into Studio twice; only one copy draws.
if workspace:FindFirstChild("PedestrianLook") then
	return
end
local folder = Instance.new("Folder")
folder.Name = "PedestrianLook"
folder.Parent = workspace

local areaX = model:GetAttribute("AreaX") :: number
local areaZ = model:GetAttribute("AreaZ") :: number

local routes = Pedestrians.routes(Pedestrians.layout(C :: any), P)
local walkers = Pedestrians.walkers(routes, P, Rng.new(P.Seed))

-- Each walker's state, kept up from its Configuration's attributes.
local states: { Pedestrian.State } = {}
local function read(config: Instance, s: Pedestrian.State)
	local function number(name: string, default: number): number
		local value = config:GetAttribute(name)
		return if typeof(value) == "number" then value else default
	end
	local mode = config:GetAttribute("Mode")
	s.mode = if mode == "dive" or mode == "flop" then mode else "walk"
	s.since = number("Since", 0)
	s.startX, s.startZ = number("StartX", 0), number("StartZ", 0)
	s.anchorX, s.anchorZ = number("AnchorX", 0), number("AnchorZ", 0)
	s.dirX, s.dirZ = number("DirX", 1), number("DirZ", 0)
	s.delay = number("Delay", 0)
end

type Style = { skin: Color3, shirt: Color3, pants: Color3, hair: Color3, prop: Prop }
local styles: { Style } = {}
for i in walkers do
	local s = Pedestrian.new()
	states[i] = s
	local rng = Rng.new(P.Seed * 1000 + i)
	styles[i] = {
		skin = SKINS[rng.int(1, #SKINS)],
		shirt = SHIRTS[rng.int(1, #SHIRTS)],
		pants = PANTS[rng.int(1, #PANTS)],
		hair = HAIRS[rng.int(1, #HAIRS)],
		prop = PROPS[rng.int(1, #PROPS)],
	}
	task.spawn(function()
		local config = model:WaitForChild(tostring(i))
		read(config, s)
		config.AttributeChanged:Connect(function()
			read(config, s)
		end)
	end)
end

type Bone = "body" | "head" | "armL" | "armR" | "legL" | "legR" | "prop" | "dog" | "lead" | "puddle"
type Paint = "skin" | "shirt" | "pants" | "hair"
type Piece = {
	part: BasePart,
	bone: Bone,
	offset: CFrame,
	paint: Paint?,
	prop: Prop?, -- shown only for a walker carrying this
}
type Figure = {
	pieces: { Piece },
	walker: number?,
	head: BasePart,
	bubble: BillboardGui,
	text: TextLabel,
	lead: BasePart,
	whoosh: Sound,
	grunt: Sound,
	thud: Sound,
	yap: Sound,
	heard: Pedestrian.Phase?, -- the phase its sounds last saw, nil until drawn once
	heardSince: number,
	yapAt: number,
}

local function newFigure(index: number): Figure
	local figureModel = Instance.new("Model")
	figureModel.Name = `Walker{index}`
	local pieces: { Piece } = {}
	local function add(bone: Bone, size: Vector3, offset: CFrame, color: Color3, paint: Paint?, prop: Prop?): Part
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = HIDDEN
		part.Parent = figureModel
		table.insert(pieces, { part = part, bone = bone, offset = offset, paint = paint, prop = prop })
		return part
	end
	local white = Color3.new(1, 1, 1)

	add("body", Vector3.new(1.8, 1.9, 0.9), CFrame.new(0, 3.15, 0), white, "shirt")
	local head = add("head", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 0.55, 0), white, "skin")
	add("head", Vector3.new(1.16, 0.3, 1.16), CFrame.new(0, 1.15, 0.03), white, "hair")
	add("head", Vector3.new(1.16, 0.6, 0.2), CFrame.new(0, 0.85, 0.5), white, "hair")
	for _, side in { -1, 1 } do
		add("head", Vector3.new(0.15, 0.2, 0.05), CFrame.new(side * 0.25, 0.65, -0.56), DARK)
	end
	for _, arm: Bone in { "armL", "armR" } do
		add(arm, Vector3.new(0.6, 0.9, 0.6), CFrame.new(0, -0.4, 0), white, "shirt")
		add(arm, Vector3.new(0.55, 1.0, 0.55), CFrame.new(0, -1.35, 0), white, "skin")
	end
	for _, leg: Bone in { "legL", "legR" } do
		add(leg, Vector3.new(0.85, 2.0, 0.85), CFrame.new(0, -1.0, 0), white, "pants")
		add(leg, Vector3.new(0.85, 0.25, 1.05), CFrame.new(0, -2.075, -0.1), SHOE)
	end

	-- What it carries, in the "prop" bone: its right hand, held upright, or
	-- for the newspaper in front of it in both hands.
	add("prop", Vector3.new(0.45, 0.6, 0.45), CFrame.new(0, 0.3, 0), white, nil, "Coffee")
	add("prop", Vector3.new(0.48, 0.25, 0.48), CFrame.new(0, 0.3, 0), Color3.fromRGB(190, 150, 100), nil, "Coffee")
	add("prop", Vector3.new(0.5, 0.12, 0.5), CFrame.new(0, 0.65, 0), Color3.fromRGB(90, 55, 35), nil, "Coffee")
	add("prop", Vector3.new(1.3, 0.95, 0.35), CFrame.new(0, -0.55, 0), Color3.fromRGB(110, 70, 40), nil, "Briefcase")
	add("prop", Vector3.new(0.5, 0.1, 0.12), CFrame.new(0, 0, 0), DARK, nil, "Briefcase")
	add("prop", Vector3.new(0.45, 0.8, 0.08), CFrame.new(0, 0.2, 0), DARK, nil, "Phone")
	local screen = add(
		"prop",
		Vector3.new(0.38, 0.65, 0.02),
		CFrame.new(0, 0.2, 0.05),
		Color3.fromRGB(140, 200, 255),
		nil,
		"Phone"
	)
	screen.Material = Enum.Material.Neon
	add(
		"prop",
		Vector3.new(2.4, 1.7, 0.08),
		CFrame.Angles(math.rad(10), 0, 0),
		Color3.fromRGB(225, 225, 215),
		nil,
		"Newspaper"
	)
	for _, y in { 0.45, 0.15, -0.15, -0.45 } do
		add(
			"prop",
			Vector3.new(2.0, 0.1, 0.02),
			CFrame.Angles(math.rad(10), 0, 0) * CFrame.new(0, y, -0.05),
			Color3.fromRGB(110, 110, 110),
			nil,
			"Newspaper"
		)
	end

	-- A small dog, its frame on the ground under its middle, facing -Z.
	local fur, ear = Color3.fromRGB(170, 120, 70), Color3.fromRGB(90, 60, 35)
	local dogBody = add("dog", Vector3.new(0.7, 0.6, 1.4), CFrame.new(0, 0.75, 0), fur, nil, "Dog")
	add("dog", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 1.15, -0.85), fur, nil, "Dog")
	add("dog", Vector3.new(0.35, 0.25, 0.3), CFrame.new(0, 1.05, -1.25), ear, nil, "Dog")
	for _, side in { -1, 1 } do
		add("dog", Vector3.new(0.15, 0.3, 0.15), CFrame.new(side * 0.22, 1.5, -0.8), ear, nil, "Dog")
		for _, z in { -0.5, 0.5 } do
			add("dog", Vector3.new(0.18, 0.45, 0.18), CFrame.new(side * 0.22, 0.225, z), fur, nil, "Dog")
		end
	end
	add("dog", Vector3.new(0.12, 0.12, 0.6), CFrame.new(0, 1.0, 0.85) * CFrame.Angles(0.6, 0, 0), fur, nil, "Dog")
	local lead = add("lead", Vector3.new(0.08, 0.08, 1), CFrame.new(), Color3.fromRGB(200, 40, 40), nil, "Dog")

	-- Spilled coffee, flat on the ground where the cup lands.
	local puddle = add(
		"puddle",
		Vector3.new(0.1, 3, 3),
		CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(100, 60, 30),
		nil,
		"Coffee"
	)
	puddle.Shape = Enum.PartType.Cylinder

	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromOffset(220, 46)
	bubble.StudsOffset = Vector3.new(0, 2.4, 0)
	bubble.MaxDistance = L.BubbleDistance
	bubble.LightInfluence = 0
	bubble.AlwaysOnTop = true
	bubble.Enabled = false
	bubble.Adornee = head
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.new(1, 1, 1)
	text.TextColor3 = Color3.fromRGB(20, 20, 20)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = text
	bubble.Parent = figureModel

	figureModel.Parent = folder
	local function sound(parent: Instance, spec: { Id: string, Pitch: number, Volume: number }): Sound
		local made = Instance.new("Sound")
		made.SoundId = spec.Id
		made.PlaybackSpeed = spec.Pitch
		made.Volume = spec.Volume
		made.RollOffMaxDistance = L.Hearing
		made.Parent = parent
		return made
	end

	return {
		pieces = pieces,
		walker = nil,
		head = head,
		bubble = bubble,
		text = text,
		lead = lead,
		whoosh = sound(head, L.Whoosh),
		grunt = sound(head, L.Grunt),
		thud = sound(head, L.Thud),
		yap = sound(dogBody, L.Yap),
		heard = nil,
		heardSince = 0,
		yapAt = 0,
	}
end

local figures: { Figure } = {}
for i = 1, P.DrawCount do
	figures[i] = newFigure(i)
end

-- Dresses a figure as walker i.
local function dress(figure: Figure, i: number)
	local style = styles[i]
	for _, piece in figure.pieces do
		if piece.paint then
			piece.part.Color = (style :: any)[piece.paint]
		end
		local shown = piece.prop == nil or piece.prop == style.prop
		piece.part.Transparency = if shown then 0 else 1
		if not shown then
			piece.part.CFrame = HIDDEN
		end
	end
	figure.bubble.Enabled = false
	figure.heard = nil
end

local function hide(figure: Figure)
	for _, piece in figure.pieces do
		piece.part.CFrame = HIDDEN
	end
	figure.bubble.Enabled = false
end

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Exclude

-- The floor or curve under (x, z), world coordinates.
local function groundAt(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, FLOOR + 30, z), Vector3.new(0, -40, 0), ground)
	return if hit then hit.Position.Y else FLOOR
end

local function flat(x: number, z: number): Vector3
	local v = Vector3.new(x, 0, z)
	return if v.Magnitude > 1e-3 then v.Unit else Vector3.new(0, 0, -1)
end

-- What the walker says in its bubble.
local function line(s: Pedestrian.State, style: Style): string
	if s.mode == "flop" then
		return L.PropLines[style.prop] or L.Lines[1]
	end
	return L.Lines[math.floor(s.since * 10) % #L.Lines + 1]
end

-- How long what it carries flies after it is knocked flat.
local FLY_TIME = D.FlopTime + L.FlyExtra

local function draw(figure: Figure, i: number, now: number)
	local walker = walkers[i]
	local route = routes[walker.route]
	local s = states[i]
	local style = styles[i]
	local clock = Pedestrian.clock(s, now, D)
	-- Where its loop has it: walking, where it is; otherwise where it left.
	local pose = Pedestrians.at(walker, route, clock)
	local where = Pedestrian.where(s, now, D)
	local phase = where.phase
	local x, z, facing = pose.x, pose.z, flat(pose.headingX, pose.headingZ)
	if phase ~= "walk" then
		x, z, facing = where.x, where.z, flat(where.facingX, where.facingZ)
	end
	local wx, wz = areaX + x, areaZ + z
	local feet = Vector3.new(wx, groundAt(wx, wz), wz)

	local deg = math.rad
	local lean, hop, bob, nod = 0, 0, 0, 0
	local legL, legR, armL, armR, outL, outR = 0, 0, 0, 0, deg(4), deg(4)
	local holding = true
	local function walking(cycle: number)
		local swing = math.sin(cycle)
		legL, legR = deg(L.LegSwing) * swing, -deg(L.LegSwing) * swing
		armL, armR = -deg(L.ArmSwing) * swing, deg(L.ArmSwing) * swing
		bob = math.abs(math.cos(cycle)) * L.Bob
	end
	local flopped = s.mode == "flop"
	local lying = if flopped then deg(90) else -deg(90)
	if phase == "walk" then
		walking(Pedestrians.distance(walker, route, clock) / L.Stride * 2 * math.pi)
	elseif phase == "dive" then
		local p = where.progress
		lean, hop = lying * p, math.sin(math.pi * p) * L.DiveHop
		armL, armR, legL, legR = deg(170), deg(170), -deg(15), -deg(15)
	elseif phase == "flop" then
		local p = where.progress
		lean, hop = lying * p, math.sin(math.pi * p) * L.FlopHop
		local flail = math.sin(now * 30)
		armL, armR = deg(70) * flail, -deg(70) * flail
		legL, legR = deg(40) * flail, -deg(40) * flail
		outL, outR = deg(40), deg(40)
		holding = false
	elseif phase == "down" then
		lean = lying
		if flopped then
			armL, armR, outL, outR = deg(10), deg(10), deg(70), deg(70)
			holding = false
		else
			armL, armR = deg(170), deg(170)
		end
	elseif phase == "up" then
		lean = lying * (1 - where.progress)
		holding = not flopped
	elseif phase == "fist" then
		armR = deg(165) + deg(12) * math.sin(now * 20)
		outR = deg(15)
		armL, outL = deg(-20), deg(35)
		bob = math.abs(math.sin(now * 10)) * 0.2
		holding = false
	else -- back
		walking(now * D.ReturnSpeed / L.Stride * 2 * math.pi)
	end

	-- Its things change how it holds its arms, while it holds them.
	local prop = style.prop
	if holding and (phase == "walk" or phase == "back") then
		if prop == "Coffee" then
			armR = deg(50)
		elseif prop == "Briefcase" then
			armR = deg(8) * math.sin(Pedestrians.distance(walker, route, clock) / L.Stride * 2 * math.pi)
		elseif prop == "Phone" then
			armR, nod = deg(100), deg(15)
		elseif prop == "Newspaper" then
			armL, armR = deg(80), deg(80)
			outL, outR = deg(-12), deg(-12)
		elseif prop == "Dog" then
			armR = deg(25)
		end
	end

	local lift = hop + bob + HALF_DEPTH * math.abs(math.sin(lean))
	local root = CFrame.lookAt(feet, feet + facing)
	local body = root * CFrame.new(0, lift, 0) * CFrame.Angles(lean, 0, 0)
	local frames: { [Bone]: CFrame } = {
		body = body,
		head = body * CFrame.new(0, NECK_Y, 0) * CFrame.Angles(nod, 0, 0),
		armL = body * CFrame.new(-SHOULDER_X, SHOULDER_Y, 0) * CFrame.Angles(armL, 0, 0) * CFrame.Angles(0, 0, -outL),
		armR = body * CFrame.new(SHOULDER_X, SHOULDER_Y, 0) * CFrame.Angles(armR, 0, 0) * CFrame.Angles(0, 0, outR),
		legL = body * CFrame.new(-HIP_X, HIP_Y, 0) * CFrame.Angles(legL, 0, 0),
		legR = body * CFrame.new(HIP_X, HIP_Y, 0) * CFrame.Angles(legR, 0, 0),
	}
	local hand = (frames.armR * CFrame.new(0, -ARM, 0)).Position
	-- The newspaper is held open in both hands, or waved in one.
	local propFrame = if prop == "Newspaper" and holding then body * NEWSPAPER else CFrame.new(hand) * body.Rotation

	-- Knocked flat, its things fly off and land, until it has them back
	-- while it shakes its fist.
	local puddle: CFrame? = nil
	if flopped and prop ~= "Dog" and (phase == "flop" or phase == "down" or phase == "up") then
		local t = now - s.since
		local from = Vector3.new(areaX + s.startX, feet.Y + SHOULDER_Y, areaZ + s.startZ)
		local reach = D.FlopDistance + L.FlyFurther
		local lx, lz = areaX + s.startX + s.dirX * reach, areaZ + s.startZ + s.dirZ * reach
		local to = Vector3.new(lx, groundAt(lx, lz) + 0.3, lz)
		local yaw = CFrame.Angles(0, math.atan2(s.dirX, s.dirZ), 0)
		if t < FLY_TIME then
			local p = t / FLY_TIME
			local at = from:Lerp(to, p) + Vector3.new(0, L.FlyHeight * 4 * p * (1 - p), 0)
			propFrame = CFrame.new(at) * yaw * CFrame.Angles(p * 4 * math.pi, p * 2 * math.pi, 0)
		else
			propFrame = CFrame.new(to) * yaw * CFrame.Angles(0, 0, math.pi / 2)
			if prop == "Coffee" then
				puddle = CFrame.new(to.X, to.Y - 0.25, to.Z) * CFrame.Angles(0, 0, math.pi / 2)
			end
		end
	end
	frames.prop = propFrame

	-- The dog walks beside it; while it is busy, the dog stays where it
	-- left its loop and hops about, facing it.
	local loop = CFrame.lookAt(
		Vector3.new(areaX + pose.x, feet.Y, areaZ + pose.z),
		Vector3.new(areaX + pose.x + pose.headingX, feet.Y, areaZ + pose.z + pose.headingZ)
	)
	local dog = loop * CFrame.new(L.DogSide, 0, -L.DogAhead)
	if phase ~= "walk" then
		local spot = dog.Position
		local toward = flat(feet.X - spot.X, feet.Z - spot.Z)
		dog = CFrame.lookAt(spot, spot + toward) * CFrame.new(0, math.abs(math.sin(now * 12)) * 0.6, 0)
	else
		dog *= CFrame.new(0, math.abs(math.sin(now * 14)) * 0.1, 0)
	end
	frames.dog = dog
	frames.puddle = puddle or HIDDEN

	for _, piece in figure.pieces do
		if piece.prop == nil or piece.prop == prop then
			local frame = frames[piece.bone]
			if frame then
				piece.part.CFrame = frame * piece.offset
			end
		end
	end

	-- The lead from its hand to the dog's collar, unless it has let go.
	if prop == "Dog" then
		local collar = (dog * COLLAR).Position
		local gap = collar - hand
		if holding and gap.Magnitude < LEAD_REACH and gap.Magnitude > 1e-3 then
			figure.lead.Size = Vector3.new(0.08, 0.08, gap.Magnitude)
			figure.lead.CFrame = CFrame.lookAt(hand + gap / 2, collar)
		else
			figure.lead.CFrame = HIDDEN
		end
	end

	-- Sounds as it changes what it is doing, not for whatever it was doing
	-- when this figure took it on.
	local heard = figure.heard
	if heard and (phase ~= heard or s.since ~= figure.heardSince) then
		if phase == "dive" then
			figure.whoosh:Play()
		elseif phase == "flop" then
			figure.grunt:Play()
		elseif phase == "down" and (heard == "dive" or heard == "flop") then
			figure.thud:Play()
		end
	end
	figure.heard, figure.heardSince = phase, s.since
	if phase == "walk" then
		figure.yapAt = 0
	elseif prop == "Dog" and now >= figure.yapAt then
		figure.yap:Play()
		figure.yapAt = now + L.YapEvery
	end

	local talking = phase == "up" or phase == "fist"
	if talking and not figure.bubble.Enabled then
		figure.text.Text = line(s, style)
	end
	figure.bubble.Enabled = talking
end

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = workspace:GetServerTimeNow()
	local eye = camera.CFrame.Position

	-- The nearest DrawCount walkers in range.
	local near: { { gap: number, index: number } } = {}
	local range2 = P.DrawRange * P.DrawRange
	for i, walker in walkers do
		local s = states[i]
		local x, z
		if s.mode == "walk" then
			local pose = Pedestrians.at(walker, routes[walker.route], Pedestrian.clock(s, now, D))
			x, z = pose.x, pose.z
		else
			x, z = s.anchorX, s.anchorZ
		end
		local dx, dz = areaX + x - eye.X, areaZ + z - eye.Z
		local gap = dx * dx + dz * dz
		if gap <= range2 then
			table.insert(near, { gap = gap, index = i })
		end
	end
	table.sort(near, function(a, b)
		return a.gap < b.gap
	end)
	local wanted: { [number]: boolean } = {}
	for k = 1, math.min(#near, #figures) do
		wanted[near[k].index] = true
	end

	-- Figures keep their walkers while still wanted; free ones take the rest.
	local drawn: { [number]: boolean } = {}
	for _, figure in figures do
		local i = figure.walker
		if i and not wanted[i] then
			figure.walker = nil
			hide(figure)
		elseif i then
			drawn[i] = true
		end
	end
	for i in wanted do
		if not drawn[i] then
			for _, figure in figures do
				if not figure.walker then
					figure.walker = i
					dress(figure, i)
					break
				end
			end
		end
	end

	local ignore: { Instance } = { folder, carsFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	ground.FilterDescendantsInstances = ignore

	for _, figure in figures do
		local i = figure.walker
		if i then
			draw(figure, i, now)
		end
	end
end)
