--!strict
-- ScrapyardCrusher (ModuleScript) -> ServerScriptService.Parks.ScrapyardCrusher
-- The Scrapyard's car crusher (Crusher, Tuning.Scrapyard.Crusher). build
-- makes its fixed parts in a Crusher model: the steel bed, four columns, the
-- beam across their tops, and a back wall. The head and its piston move, so
-- every client makes and moves its own from the server's clock
-- (CrusherLook).
--
-- start watches the bed. A car that stops on it while the crusher is open
-- starts the countdown: the Crusher model gets FillAt (server time) for the
-- clients' gauge, and others have Fill seconds to drive on too. Then, if any
-- car is still stopped on the bed, a cycle starts: the model gets CycleAt
-- and CrushTime attributes, and every car on the bed is anchored, held
-- (ServerStorage.CarCrushed "grabbed") and given a Crushing attribute, so
-- every client flattens it under the head. Once the head reaches it, each is
-- crushed over its own crush time ("crush"), so it wrecks and comes back in
-- front of the bed. CycleAt clears when the head is back up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Crusher = require(ReplicatedStorage.Crusher)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)

local C = Tuning.Scrapyard.Crusher
local CONFIG: Crusher.Config = C :: any
local FLOOR = Tuning.Map.FloorTop

local ScrapyardCrusher = {}

-- The bed's middle on its top, facing the way cars drive in. The same as
-- CrusherLook's.
local function bedFrame(area: MapLayout.Area): CFrame
	return CFrame.new(area.X + C.X, FLOOR + C.BedHeight, area.Z + C.Z) * CFrame.Angles(0, math.rad(C.Turn), 0)
end

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, material: Enum.Material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = C.SteelColor
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

function ScrapyardCrusher.build(folder: Folder, area: MapLayout.Area)
	local frame = bedFrame(area)
	local model = Instance.new("Model")
	model.Name = "Crusher"
	-- Persistent, so every client can always read its cycle.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	block(
		model,
		"Bed",
		Vector3.new(C.BedWidth, C.BedHeight, C.BedLength),
		frame * CFrame.new(0, -C.BedHeight / 2, 0),
		Enum.Material.DiamondPlate
	)
	local columnHeight = C.BedHeight + C.FrameHeight + C.BeamDepth
	local across = C.BedWidth / 2 + C.ColumnWidth / 2
	local along = C.BedLength / 2 - C.ColumnWidth / 2
	for _, side in { -1, 1 } do
		for _, finish in { -1, 1 } do
			block(
				model,
				"Column",
				Vector3.new(C.ColumnWidth, columnHeight, C.ColumnWidth),
				frame * CFrame.new(side * across, columnHeight / 2 - C.BedHeight, finish * along),
				Enum.Material.Metal
			)
		end
	end
	local width = C.BedWidth + 2 * C.ColumnWidth
	block(
		model,
		"Beam",
		Vector3.new(width, C.BeamDepth, C.BedLength),
		frame * CFrame.new(0, C.FrameHeight + C.BeamDepth / 2, 0),
		Enum.Material.Metal
	)
	-- Across the far end, so a car rolling in stops on the bed.
	block(
		model,
		"BackWall",
		Vector3.new(width, C.FrameHeight + C.BedHeight, 2),
		frame * CFrame.new(0, (C.FrameHeight - C.BedHeight) / 2, -C.BedLength / 2 - 1),
		Enum.Material.Metal
	)
	model.Parent = folder
end

local function setAnchored(car: Model, anchored: boolean)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end
end

local function toughnessOf(car: Model): number
	local toughness = car:GetAttribute("Toughness")
	return if typeof(toughness) == "number" then toughness else 0
end

-- Every car stopped on the bed and not already held by something else.
local function carsOnBed(frame: CFrame): { Model }
	local found = {}
	local cars = workspace:FindFirstChild("Cars")
	if not cars then
		return found
	end
	for _, car in cars:GetChildren() do
		local hull = car:IsA("Model") and car.PrimaryPart
		if
			not hull
			or hull.Anchored
			or car:GetAttribute("Crushing")
			or hull.AssemblyLinearVelocity.Magnitude >= C.CatchSpeed
		then
			continue
		end
		local at = frame:PointToObjectSpace(hull.Position)
		if Crusher.onBed(CONFIG, at.X, at.Z, at.Y) then
			table.insert(found, car :: Model)
		end
	end
	return found
end

function ScrapyardCrusher.start(folder: Folder, area: MapLayout.Area)
	local model = folder:FindFirstChild("Crusher")
	local carCrushed = ServerStorage:WaitForChild("CarCrushed") :: BindableEvent
	if not (model and model:IsA("Model")) then
		warn("Scrapyard: no Crusher to start")
		return
	end
	local frame = bedFrame(area)
	local spot = frame * CFrame.new(0, 0, C.BedLength / 2 + C.RespawnBack)
	local respawnAt = spot.Rotation + Vector3.new(spot.Position.X, FLOOR + Tuning.TestPark.SpawnHeight, spot.Position.Z)

	local busy = false
	local function cycle()
		model:SetAttribute("FillAt", workspace:GetServerTimeNow())
		task.wait(C.Fill)
		model:SetAttribute("FillAt", nil)
		local caught = carsOnBed(frame)
		if #caught == 0 then
			busy = false
			return
		end
		local crushTime = 0
		for _, car in caught do
			crushTime = math.max(crushTime, Crusher.crushTime(CONFIG, toughnessOf(car)))
			setAnchored(car, true)
			car:SetAttribute("Crushing", true)
			carCrushed:Fire(car, "grabbed", respawnAt)
		end
		model:SetAttribute("CrushTime", crushTime)
		model:SetAttribute("CycleAt", workspace:GetServerTimeNow())
		task.wait(C.Close)
		for _, car in caught do
			if car.Parent then
				carCrushed:Fire(car, "crush", nil, Crusher.crushTime(CONFIG, toughnessOf(car)))
			end
		end
		task.wait(crushTime + C.Hold + C.Open)
		model:SetAttribute("CycleAt", nil)
		busy = false
	end

	RunService.Heartbeat:Connect(function()
		if busy then
			return
		end
		if #carsOnBed(frame) > 0 then
			busy = true
			task.spawn(cycle)
		end
	end)
end

return ScrapyardCrusher
