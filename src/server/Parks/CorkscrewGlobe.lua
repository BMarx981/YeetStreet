--!strict
-- CorkscrewGlobe (ModuleScript) -> ServerScriptService.Parks.CorkscrewGlobe
-- The Corkscrew park's globe (Globe, GlobeRide, Tuning.Corkscrew.Globe): a
-- huge closed ball of planks on the ground, on a base wall so nobody drives
-- under it, with an orb of light in the middle. Inside, a yellow stripe runs
-- round the equator, a blue one round through both poles, and windows of
-- glass planks sit above the equator. A tube comes in from a wide mouth,
-- dives under the ground, and climbs up under the bottom, where it is cut
-- off under the hatch: the bottom bands of planks, tagged GlobeHatch, which
-- each driver's client lets its own car through on the way up (GlobeHatch).
-- The tube, its funnel, and its launch pads are built like the gravitron's
-- (Parks.CorkscrewGravitron).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Globe = require(ReplicatedStorage.Globe)
local GlobeRide = require(ReplicatedStorage.GlobeRide)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Railway = require(ReplicatedStorage.Railway)
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
}
local ORB_COLOR = Color3.fromRGB(255, 240, 200)
local BASE_THICKNESS = 2
local GROUND_THICKNESS = 1 -- ParkBuilder's floor

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

-- Every plank of the shell, its inner face on Globe.plank's, the hatch's in
-- their own model.
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
			if kind == "window" then
				part.Material = Enum.Material.Glass
				part.Transparency = 0.5
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

-- A wall round under the globe, from the floor's underside up into its
-- shell's outside, short of its inside.
local function buildBase(model: Instance, ground: CFrame)
	local S, n = G.Base.Radius, G.Base.Slices
	local outside = G.Radius + G.Thickness
	if S >= outside then
		warn("CorkscrewGlobe: the base is wider than the globe")
		return
	end
	local top = G.Clearance + outside - math.sqrt(outside * outside - S * S) + 1
	local bottom = -GROUND_THICKNESS
	local width = 2 * (S + BASE_THICKNESS) * math.sin(math.pi / n) + 0.4
	for i = 0, n - 1 do
		block(
			model,
			"Base",
			Vector3.new(width, top - bottom, BASE_THICKNESS),
			ground
				* CFrame.Angles(0, 2 * math.pi * (i + 0.5) / n, 0)
				* CFrame.new(0, (top + bottom) / 2, -(S + BASE_THICKNESS / 2)),
			COLORS.plain
		)
	end
end

-- The tube from its mouth to under the hatch, its funnel, and launch pads
-- near the start of its climb.
local function buildTube(model: Instance, ground: CFrame)
	local strand = GlobeRide.strand
	local options = CorkscrewGravitron.OPTIONS
	local tube = Instance.new("Model")
	tube.Name = "GlobeTube"
	tube.Parent = model
	Tube.build(tube, ground, strand.approach, T.SliceAngle, options, { finishMouth = false })
	Tube.build(tube, ground, strand.twist, T.SliceAngle, options, {
		startMouth = false,
		finishMouth = false,
		cutAbove = G.Clearance,
	})
	CorkscrewGravitron.buildBoost(tube, ground, strand, GlobeRide.respawn() :: CFrame)
	CorkscrewGravitron.buildFunnel(tube, ground, strand)
end

-- Holes in the ground where the tube dives, with the floor closed back
-- round it, and where it climbs up through the ground under the globe,
-- inside the base, left open.
local function buildGroundHoles(model: Instance, folder: Folder, ground: CFrame)
	local strand = GlobeRide.strand
	local holes: { Railway.Rect } = {}
	local dive = CorkscrewGravitron.buildDiveHole(model, ground, strand)
	if dive then
		table.insert(holes, dive)
	end
	local outside = Tube.outsideOf(CorkscrewGravitron.OPTIONS, CorkscrewGravitron.OPTIONS.Radius)
	local climb = Tunnel.above(strand.twist[1], outside, CorkscrewGravitron.GROUND_BOTTOM)
	if climb then
		local far = math.sqrt(math.max(climb.x1 ^ 2, climb.x2 ^ 2) + math.max(climb.z1 ^ 2, climb.z2 ^ 2))
		if far > G.Base.Radius then
			warn("CorkscrewGlobe: the hole for the climb reaches past the base; raise Depth or ExitAngle")
		end
		table.insert(holes, CorkscrewGravitron.worldRect(ground, climb.x1, climb.x2, climb.z1, climb.z2))
	end
	CorkscrewGravitron.cutGround(CorkscrewGravitron.groundParts(folder), holes)
end

function CorkscrewGlobe.build(folder: Folder, _area: MapLayout.Area)
	local ground, center = GlobeRide.ground, GlobeRide.center
	if not ground or not center then
		return
	end
	if G.Heading % 90 ~= 0 then
		warn("CorkscrewGlobe: Heading must be a multiple of 90, or the ground holes come out wrong")
	end
	local model = Instance.new("Model")
	model.Name = "Globe"
	model.Parent = folder

	buildShell(model, center)
	buildOrb(model, center)
	buildBase(model, ground)
	buildTube(model, ground)
	buildGroundHoles(model, folder, ground)
end

return CorkscrewGlobe
