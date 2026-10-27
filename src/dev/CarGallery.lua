--!strict
-- CarGallery (ModuleScript) -> ServerStorage.Dev.CarGallery
-- A Studio tool for picking car seeds. Run it from the command bar in edit
-- mode. Each call clears workspace.CarGallery and builds cars in rows, nose
-- toward -z, each with stand-in wheels, the collision hull as a faint box, and
-- a label. It selects the folder and points the camera at the cars.
--
--   local G = require(game.ServerStorage.Dev.CarGallery:Clone())
--   G.show("muscle", "Sports", 1, 12)       seeds 1 to 12, every stat at 0
--   G.show("muscle", "Sports", 1, 12, 20)   the same with every stat at 20
--   G.levels("muscle", "Sports", 7)         seed 7, a row per stat, a column per look step
--   G.clear()
--
-- show also takes a table of levels: { Speed = 30, Jets = 0, Toughness = 0, Grip = 0, Brakes = 0 }.
-- Archetypes: hatch, pickup, muscle, buggy, wedge, hover, jeep, bus.
-- Tiers: Junker, Street, Sports, Supercar, Rebirth.
--
-- The command bar may hand back an old copy of a module after Rojo syncs a
-- change. Requiring a Clone of this module avoids that, and each call loads
-- fresh clones of the modules it uses, so CarKit edits show on the next call.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

local CarDesign = require(ReplicatedStorage.CarDesign) -- for its types; calls use a fresh copy

type Modules = {
	CarDesign: typeof(CarDesign),
	CarKit: CarDesign.Kit,
	Rng: typeof(require(ReplicatedStorage.Rng)),
	CarParts: typeof(require(ReplicatedStorage.CarParts)),
	Tuning: typeof(require(ReplicatedStorage.Tuning)),
}

local CarGallery = {}

local FOLDER_NAME = "CarGallery"
local ORIGIN = CFrame.new(0, 100, 0) -- the floor's top, above whatever the place holds
local SPACING = 10 -- between car centers, sideways
local ROW_SPACING = 18 -- between rows
local PER_ROW = 10
local WHEEL_COLOR = Color3.fromRGB(30, 30, 32)
local STATS = { "Speed", "Jets", "Toughness", "Grip", "Brakes", "All" }

local function fresh(name: string): any
	local module = ReplicatedStorage:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), `CarGallery: no ReplicatedStorage.{name}`)
	return (require :: any)(module:Clone())
end

local function load(): Modules
	return {
		CarDesign = fresh("CarDesign"),
		CarKit = fresh("CarKit"),
		Rng = fresh("Rng"),
		CarParts = fresh("CarParts"),
		Tuning = fresh("Tuning"),
	}
end

-- Every stat at level, or only `stat` ("All" for every stat).
local function raise(stat: string, level: number): CarDesign.Levels
	local function at(name: string): number
		return if stat == name or stat == "All" then level else 0
	end
	return {
		Speed = at("Speed"),
		Jets = at("Jets"),
		Toughness = at("Toughness"),
		Grip = at("Grip"),
		Brakes = at("Brakes"),
	}
end

local function toLevels(levels: (number | CarDesign.Levels)?): CarDesign.Levels
	if typeof(levels) == "number" then
		return raise("All", levels)
	end
	return levels or raise("All", 0)
end

local function anchored(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

-- Clears the gallery and lays a floor under a grid of cars.
local function reset(columns: number, rows: number): Folder
	CarGallery.clear()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Archivable = false -- never saved with the place or copied into Play
	local size = Vector3.new(columns * SPACING + 10, 1, rows * ROW_SPACING + 10)
	local center = CFrame.new((columns - 1) * SPACING / 2, -0.5, (rows - 1) * ROW_SPACING / 2)
	local floor = anchored("Floor", size, ORIGIN * center, folder)
	floor.Color = Color3.fromRGB(90, 95, 100)
	folder.Parent = workspace
	return folder
end

-- Where a car's hull center goes, with its wheels on the floor. Columns and
-- rows count from 1.
local function spot(m: Modules, column: number, row: number): CFrame
	local C = m.Tuning.Chassis
	local wheelY = C.MountY + C.SlideLow + C.SuspensionSag
	return ORIGIN * CFrame.new((column - 1) * SPACING, C.WheelRadius - wheelY, (row - 1) * ROW_SPACING)
end

local function buildCar(
	m: Modules,
	folder: Folder,
	name: string,
	label: string,
	design: CarDesign.Design,
	origin: CFrame
)
	local C = m.Tuning.Chassis
	local model = Instance.new("Model")
	model.Name = name

	local hull = anchored("Hull", C.HullSize, origin, model)
	hull.Transparency = 0.9
	model.PrimaryPart = hull

	m.CarParts.build(design, origin, model)

	if not design.hideWheels then
		local wheelY = C.MountY + C.SlideLow + C.SuspensionSag
		local size = Vector3.new(C.WheelWidth, 2 * C.WheelRadius, 2 * C.WheelRadius)
		for _, side in { -1, 1 } do
			for _, ends in { -1, 1 } do
				local cframe = origin * CFrame.new(side * C.TrackHalf, wheelY, ends * C.WheelbaseHalf)
				local wheel = anchored("Wheel", size, cframe, model)
				wheel.Shape = Enum.PartType.Cylinder
				wheel.Color = WHEEL_COLOR
				wheel.Material = Enum.Material.SmoothPlastic
			end
		end
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(10, 2.5)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	billboard.LightInfluence = 0
	billboard.Parent = hull
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Text = label
	text.Parent = billboard

	model.Parent = folder
end

local function design(m: Modules, archetype: string, tier: string, seed: number, levels: CarDesign.Levels)
	local input = { archetype = archetype, tier = tier, levels = levels }
	return m.CarDesign.design(m.Rng.new(seed), input, m.CarKit, m.Tuning.CarLooks)
end

-- Selects the gallery and points the Studio camera at it from in front.
local function finish(folder: Folder, count: number)
	Selection:Set({ folder })
	local floor = folder:FindFirstChild("Floor") :: Part
	local center = floor.Position
	local away = math.max(floor.Size.X, floor.Size.Z) * 0.7 + 20
	local camera = workspace.CurrentCamera
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, away * 0.4, -away), center)
	camera.Focus = CFrame.new(center)
	print(`CarGallery: built {count} cars.`)
end

-- Seeds firstSeed to firstSeed + count - 1, all at the same levels.
function CarGallery.show(
	archetype: string,
	tier: string,
	firstSeed: number,
	count: number,
	levels: (number | CarDesign.Levels)?
)
	assert(count >= 1, "CarGallery: count must be at least 1")
	local m = load()
	local lv = toLevels(levels)
	local folder = reset(math.min(count, PER_ROW), math.ceil(count / PER_ROW))
	for k = 1, count do
		local seed = firstSeed + k - 1
		local d = design(m, archetype, tier, seed, lv)
		local where = spot(m, (k - 1) % PER_ROW + 1, math.floor((k - 1) / PER_ROW) + 1)
		buildCar(m, folder, `Seed{seed}`, `seed {seed}\n{d.name}`, d, where)
	end
	finish(folder, count)
end

-- One seed with each stat raised alone, then all together, from level 0
-- through each look step: a row per stat, a column per step.
function CarGallery.levels(archetype: string, tier: string, seed: number)
	local m = load()
	local columns = { 0 }
	for _, level in m.Tuning.CarLooks.StatSteps do
		table.insert(columns, level)
	end
	local folder = reset(#columns, #STATS)
	for row, stat in STATS do
		for column, level in columns do
			local d = design(m, archetype, tier, seed, raise(stat, level))
			local label = `{stat} {level}\nseed {seed} {d.name}`
			buildCar(m, folder, `{stat}{level}`, label, d, spot(m, column, row))
		end
	end
	finish(folder, #STATS * #columns)
end

function CarGallery.clear()
	local old = workspace:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
end

return CarGallery
