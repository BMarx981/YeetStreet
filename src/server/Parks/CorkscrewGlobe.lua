--!strict
-- CorkscrewGlobe (ModuleScript) -> ServerScriptService.Parks.CorkscrewGlobe
-- The Corkscrew park's face (Globe, GlobeRide, Tuning.Corkscrew.Globe): two
-- huge closed balls of planks up in the air for eyes, each with an orb of
-- light in its middle glowing through a round pupil of dark glass on its
-- front. Inside each, a yellow stripe runs round the equator, a blue one
-- round through both poles, and windows of glass planks sit above the
-- equator. A tube comes in from a wide mouth on the ground and forks: each
-- branch turns out under its eye and climbs to its bottom, the two making a
-- smile, and is cut off there under the hatch: the bottom bands of planks,
-- tagged GlobeHatch, which each driver's client lets its own car through on
-- the way up (GlobeHatch). Through the fork each branch is cut back where
-- it runs into the other (Tube's trim). The tube, its funnel, and its
-- launch pads are built like the gravitron's (Parks.CorkscrewGravitron).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Globe = require(ReplicatedStorage.Globe)
local GlobeRide = require(ReplicatedStorage.GlobeRide)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tunnel = require(ReplicatedStorage.Tunnel)
local Tuning = require(ReplicatedStorage.Tuning)
local CorkscrewGravitron = require(ServerScriptService.Parks.CorkscrewGravitron)
local Tube = require(ServerScriptService.Pieces.Tube)

local G = Tuning.Corkscrew.Globe
local T = Tuning.Corkscrew.Gravitron.Tubes

local COLORS: { [Globe.Kind]: Color3 } = {
	plain = Color3.fromRGB(200, 200, 205),
	equator = Color3.fromRGB(255, 200, 40),
	meridian = Color3.fromRGB(40, 120, 255),
	hatch = Color3.fromRGB(255, 150, 40), -- the gravitron's funnels'
	window = Color3.fromRGB(170, 220, 255),
	pupil = Color3.fromRGB(25, 25, 35),
}
local GLASS: { [Globe.Kind]: number } = { window = 0.5, pupil = 0.35 } -- transparency
local ORB_COLOR = Color3.fromRGB(255, 240, 200)

local CorkscrewGlobe = {}

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Every plank of an eye's shell, its inner face on Globe.plank's, the
-- hatch's in their own model.
local function buildShell(model: Instance, center: CFrame)
	local shell = Instance.new("Model")
	shell.Name = "Shell"
	shell.Parent = model
	local hatch = Instance.new("Model")
	hatch.Name = "Hatch"
	hatch.Parent = model
	local shape = GlobeRide.shape
	for band = 0, G.Bands - 1 do
		for slice = 0, G.Slices - 1 do
			local kind = Globe.kind(shape, band, slice)
			local plank = Globe.plank(shape, band, slice)
			local right = Vector3.new(plank.rx, plank.ry, plank.rz)
			local up = Vector3.new(plank.ux, plank.uy, plank.uz)
			local out = right:Cross(up)
			local face = Vector3.new(plank.x, plank.y, plank.z)
			local part = block(
				if kind == "hatch" then hatch else shell,
				"Plank",
				Vector3.new(plank.width + G.Overlap, plank.height + G.Overlap, G.Thickness),
				center * CFrame.fromMatrix(face + out * (G.Thickness / 2), right, up, out),
				COLORS[kind]
			)
			if GLASS[kind] then
				part.Material = Enum.Material.Glass
				part.Transparency = GLASS[kind]
			elseif kind == "hatch" then
				CollectionService:AddTag(part, GlobeRide.HATCH_TAG)
			end
		end
	end
end

local function buildOrb(model: Instance, center: CFrame)
	local orb = block(model, "Orb", Vector3.one * G.Orb.Size, center, ORB_COLOR)
	orb.Shape = Enum.PartType.Ball
	orb.Material = Enum.Material.Neon
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	local light = Instance.new("PointLight")
	light.Range = G.Orb.LightRange
	light.Brightness = G.Orb.LightBrightness
	light.Color = ORB_COLOR
	light.Parent = orb
end

-- How far into `other`'s planks a point is, past TrimMargin inside them, or
-- -1 alongside neither end of it: a branch's trim where it runs into the
-- other branch.
local function trimBy(ground: CFrame, other: { Tunnel.Piece }): (Vector3) -> number
	local options = CorkscrewGravitron.OPTIONS
	local inner = options.Radius * math.cos(math.pi / options.Sides) - G.Smile.TrimMargin
	return function(p: Vector3): number
		local q = ground:PointToObjectSpace(p)
		local distance = Tunnel.distance(other, q.X, q.Y, q.Z)
		return if distance then inner - distance else -1
	end
end

-- The stem from its mouth to the fork, both branches up to the cut under
-- the eyes, launch pads near the start of each climb, and the funnel.
local function buildSmile(model: Instance, ground: CFrame)
	local face = GlobeRide.face
	local options = CorkscrewGravitron.OPTIONS
	local tube = Instance.new("Model")
	tube.Name = "Smile"
	tube.Parent = model
	Tube.build(tube, ground, face.stem, T.SliceAngle, options, { finishMouth = false })
	for _, branch in { { face.left, face.right }, { face.right, face.left } } do
		Tube.build(tube, ground, branch[1], G.Smile.SliceAngle, options, {
			startMouth = false,
			finishMouth = false,
			cutAbove = face.cut,
			trim = trimBy(ground, branch[2]),
		})
	end
	local respawn = GlobeRide.respawn() :: CFrame
	for _, strand in GlobeRide.strands do
		CorkscrewGravitron.buildBoost(tube, ground, strand, respawn)
	end
	CorkscrewGravitron.buildFunnel(tube, ground, GlobeRide.strands[1])
end

function CorkscrewGlobe.build(folder: Folder, _area: MapLayout.Area)
	local ground = GlobeRide.ground
	if not ground then
		return
	end
	if G.Heading % 90 ~= 0 then
		warn("CorkscrewGlobe: Heading must be a multiple of 90")
	end
	local model = Instance.new("Model")
	model.Name = "Face"
	model.Parent = folder

	for i, center in GlobeRide.eyes do
		local eye = Instance.new("Model")
		eye.Name = if i == 1 then "LeftEye" else "RightEye"
		eye.Parent = model
		buildShell(eye, center)
		buildOrb(eye, center)
	end
	buildSmile(model, ground)
end

return CorkscrewGlobe
