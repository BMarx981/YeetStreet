--!strict
-- ScrapyardTnt (ModuleScript) -> ServerScriptService.Parks.ScrapyardTnt
-- The Scrapyard's TNT barrel field (Tnt, Tuning.Scrapyard.Tnt). build stands
-- a red barrel on each of Tnt.layout's spots, in a TntField model. Barrels
-- never collide, so a car drives right into one.
--
-- start watches every car. A hull touching a standing barrel blows it up:
-- the barrel's BlownAt attribute gets the server time, from which every
-- client shows an explosion there and hides the barrel until it stands
-- back up Respawn seconds later (TntBoom), every car in reach is thrown
-- (ServerStorage.TntBlast, ScoreService), and the barrels near it go off
-- ChainDelay later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Rng = require(ReplicatedStorage.Rng)
local Tnt = require(ReplicatedStorage.Tnt)
local Tuning = require(ReplicatedStorage.Tuning)

local B = Tuning.Scrapyard.Tnt
local CONFIG: Tnt.Config = B :: any
local FLOOR = Tuning.Map.FloorTop

local ScrapyardTnt = {}

-- The field's middle on the floor.
local function middle(area: MapLayout.Area): Vector3
	return Vector3.new(area.X + B.X, FLOOR, area.Z + B.Z)
end

local function buildBarrel(parent: Instance, at: Vector3, index: number)
	local model = Instance.new("Model")
	model.Name = "Barrel"
	model:SetAttribute("Index", index)
	-- A cylinder's axis is its X, so each piece is stood on end.
	local function piece(name: string, length: number, radius: number, up: number, color: Color3)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = Vector3.new(length, 2 * radius, 2 * radius)
		part.CFrame = CFrame.new(at + Vector3.new(0, up, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = model
	end
	piece("Body", B.Height, B.Radius, B.Height / 2, B.BarrelColor)
	for _, share in { 0.25, 0.75 } do
		piece("Band", 0.8, B.Radius + 0.1, B.Height * share, B.BandColor)
	end
	model.Parent = parent
end

function ScrapyardTnt.build(folder: Folder, area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "TntField"
	local center = middle(area)
	for index, spot in Tnt.layout(CONFIG, Rng.new(B.Seed)) do
		buildBarrel(model, center + Vector3.new(spot.x, 0, spot.z), index)
	end
	model.Parent = folder
end

function ScrapyardTnt.start(folder: Folder, area: MapLayout.Area)
	local tntBlast = ServerStorage:WaitForChild("TntBlast") :: BindableEvent
	local field = folder:FindFirstChild("TntField")
	if not field then
		warn("Scrapyard: no TntField to start")
		return
	end

	local center = middle(area)
	local spots = Tnt.layout(CONFIG, Rng.new(B.Seed))
	local barrels: { [number]: Model } = {}
	local standing: { [number]: boolean } = {}
	for _, barrel in field:GetChildren() do
		local index = barrel:GetAttribute("Index")
		if barrel:IsA("Model") and typeof(index) == "number" then
			barrels[index] = barrel
			standing[index] = true
		end
	end

	local function blowUp(index: number)
		local barrel = barrels[index]
		if not (barrel and standing[index]) then
			return
		end
		standing[index] = false
		barrel:SetAttribute("BlownAt", workspace:GetServerTimeNow())
		local spot = spots[index]
		local at = center + Vector3.new(spot.x, 0, spot.z)
		local cars = workspace:FindFirstChild("Cars")
		for _, car in if cars then cars:GetChildren() else {} do
			local hull = car:IsA("Model") and car.PrimaryPart
			if hull then
				local away = hull.Position - at
				local vx, vy, vz = Tnt.blast(CONFIG, away.X, away.Z)
				if vx and vy and vz and math.abs(away.Y) <= B.BlastRadius then
					tntBlast:Fire(car, Vector3.new(vx, vy, vz))
				end
			end
		end
		for _, near in Tnt.chained(CONFIG, spots, index) do
			task.delay(B.ChainDelay, blowUp, near)
		end
		task.delay(B.Respawn, function()
			standing[index] = true
		end)
	end

	RunService.Heartbeat:Connect(function()
		local cars = workspace:FindFirstChild("Cars")
		if not cars then
			return
		end
		for _, car in cars:GetChildren() do
			local hull = car:IsA("Model") and car.PrimaryPart
			if not hull or hull.Anchored then
				continue
			end
			local p = hull.Position - center
			if math.abs(p.X) > B.Width / 2 + B.Spacing or math.abs(p.Z) > B.Depth / 2 + B.Spacing then
				continue
			end
			for index, spot in spots do
				if standing[index] and Tnt.touches(CONFIG, p.X - spot.x, p.Y, p.Z - spot.z) then
					blowUp(index)
				end
			end
		end
	end)
end

return ScrapyardTnt
