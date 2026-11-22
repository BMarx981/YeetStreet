--!strict
-- ScrapyardCrane (ModuleScript) -> ServerScriptService.Parks.ScrapyardCrane
-- The Scrapyard's magnet crane (MagnetCrane, MagnetCraneWorld,
-- Tuning.Scrapyard.Crane). build makes the fixed parts in a MagnetCrane
-- model: the tower, the pad under the waiting magnet with a MAGNET CRANE
-- sign over the way in. The boom and magnet turn, so every client draws
-- them (CraneLook).
--
-- start watches the pad. A car stopped on it starts a cycle: the model's
-- CycleAt attribute gets the server time, from which everyone moves the
-- magnet. As the magnet reaches its roof, if the car is still on the pad
-- it is anchored and held under the magnet (Holding names it), and
-- ScoreService is told on ServerStorage.CarCarried, as for the
-- pterodactyl: "grabbed", then "dropped" over the TNT field, which starts a
-- run there with its height counted from the floor, paying PayScale. The
-- car falls from rest, back in its driver's hands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local MagnetCrane = require(ReplicatedStorage.MagnetCrane)
local MagnetCraneWorld = require(ReplicatedStorage.MagnetCraneWorld)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local ArchSign = require(ServerScriptService.Pieces.ArchSign)

local K = Tuning.Scrapyard.Crane
local CONFIG: MagnetCrane.Config = K :: any
local FLOOR = Tuning.Map.FloorTop

local ScrapyardCrane = {}

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Metal
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function ScrapyardCrane.build(folder: Folder, _area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "MagnetCrane"
	local tower = MagnetCraneWorld.tower
	local base = K.TowerWidth + 10
	block(model, "Base", Vector3.new(base, 4, base), CFrame.new(tower + Vector3.new(0, 2, 0)), K.SteelColor)
	block(
		model,
		"Tower",
		Vector3.new(K.TowerWidth, K.TowerHeight, K.TowerWidth),
		CFrame.new(tower + Vector3.new(0, K.TowerHeight / 2, 0)),
		K.CraneColor
	)

	-- The pad: a dark disc with a yellow ring, a cylinder lying flat.
	local pad = MagnetCraneWorld.pad
	local flat = CFrame.Angles(0, 0, math.pi / 2)
	local ring = block(
		model,
		"PadRing",
		Vector3.new(0.2, 2 * K.PadRadius + 4, 2 * K.PadRadius + 4),
		pad * CFrame.new(0, 0.1, 0) * flat,
		K.PadColor
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	local disc = block(
		model,
		"Pad",
		Vector3.new(0.3, 2 * K.PadRadius, 2 * K.PadRadius),
		pad * CFrame.new(0, 0.15, 0) * flat,
		K.SteelColor
	)
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.DiamondPlate

	-- Over the way in from the yard's middle, on the pad's far side from the
	-- tower, facing cars driving toward the tower.
	ArchSign.make(model, pad * CFrame.new(0, 0, -(K.PadRadius + 6)) * CFrame.Angles(0, math.pi, 0), {
		across = K.PadRadius + 4,
		bottom = K.SignHeight,
		text = "MAGNET CRANE",
		textColor = K.PadColor,
		postColor = K.SteelColor,
	})

	model:SetAttribute("Holding", "")
	model.Parent = folder
end

local function setAnchored(car: Model, anchored: boolean)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end
end

local function tell(car: Model, moment: string, groundY: number?, payScale: number?)
	local carCarried = ServerStorage:FindFirstChild("CarCarried")
	if carCarried and carCarried:IsA("BindableEvent") then
		carCarried:Fire(car, moment, groundY, payScale)
	end
end

-- Whether `car` is stopped on the pad and held by nothing else.
local function waiting(car: Instance): boolean
	local hull = car:IsA("Model") and car.PrimaryPart
	if not hull or hull.Anchored or car:GetAttribute("Crushing") then
		return false
	end
	if hull.AssemblyLinearVelocity.Magnitude >= K.CatchSpeed then
		return false
	end
	local at = MagnetCraneWorld.pad:PointToObjectSpace(hull.Position)
	return MagnetCrane.onPad(CONFIG, at.X, at.Z, at.Y)
end

function ScrapyardCrane.start(folder: Folder, _area: MapLayout.Area)
	local model = folder:FindFirstChild("MagnetCrane")
	if not (model and model:IsA("Model")) then
		warn("Scrapyard: no MagnetCrane to start")
		return
	end
	local carsFolder = workspace:WaitForChild("Cars")

	local busy = false
	local cycleAt = 0
	-- The car the magnet holds, and where it hung from the magnet when caught.
	local held: Model? = nil
	local caughtAt = CFrame.identity

	local function letGo()
		local car = held
		held = nil
		model:SetAttribute("Holding", "")
		if not (car and car.Parent == carsFolder) then
			return
		end
		setAnchored(car, false)
		local hull = car.PrimaryPart
		if hull then
			hull.AssemblyLinearVelocity = Vector3.zero
			hull.AssemblyAngularVelocity = Vector3.zero
		end
		local userId = car:GetAttribute("OwnerUserId")
		local driver = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
		for _, part in car:GetDescendants() do
			if part:IsA("BasePart") and part:CanSetNetworkOwnership() then
				part:SetNetworkOwner(driver)
			end
		end
		tell(car, "dropped", FLOOR, K.PayScale)
		print(`Magnet crane dropped {car.Name}`)
	end

	local function cycle(car: Model)
		cycleAt = workspace:GetServerTimeNow()
		model:SetAttribute("CycleAt", cycleAt)
		task.wait(MagnetCrane.grabAt(CONFIG))
		if car.Parent == carsFolder and waiting(car) then
			local magnet = MagnetCraneWorld.magnet(workspace:GetServerTimeNow() - cycleAt)
			caughtAt = magnet:ToObjectSpace(car:GetPivot())
			setAnchored(car, true)
			held = car
			model:SetAttribute("Holding", car.Name)
			tell(car, "grabbed")
			print(`Magnet crane grabbed {car.Name}`)
		end
		task.wait(MagnetCrane.dropAt(CONFIG) - MagnetCrane.grabAt(CONFIG))
		letGo()
		task.wait(MagnetCrane.cycleLength(CONFIG) - MagnetCrane.dropAt(CONFIG))
		model:SetAttribute("CycleAt", nil)
		busy = false
	end

	RunService.Heartbeat:Connect(function()
		local car = held
		if car then
			if car.Parent ~= carsFolder then
				letGo()
				return
			end
			-- Hung where it was caught, drawn in under the middle as it lifts.
			local elapsed = workspace:GetServerTimeNow() - cycleAt
			local lifted = math.clamp((elapsed - MagnetCrane.grabAt(CONFIG)) / K.Lift, 0, 1)
			local under = CFrame.new(0, -K.HoldBelow, 0) * caughtAt.Rotation
			car:PivotTo(MagnetCraneWorld.magnet(elapsed) * caughtAt:Lerp(under, lifted * lifted * (3 - 2 * lifted)))
			return
		end
		if busy then
			return
		end
		for _, each in carsFolder:GetChildren() do
			if waiting(each) then
				busy = true
				task.spawn(cycle, each :: Model)
				return
			end
		end
	end)
end

return ScrapyardCrane
