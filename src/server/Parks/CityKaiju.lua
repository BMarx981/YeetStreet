--!strict
-- CityKaiju (ModuleScript) -> ServerScriptService.Parks.CityKaiju
-- Downtown's kaiju, built into the city's folder by City.build. It hunts
-- cars and players on foot the way Dino Valley's T-Rex does, and Parks.DinoRex
-- runs it, but it keeps to Downtown's streets (Tuning.City.Kaiju.Streets),
-- walking round the blocks to reach a car on another street. Each client
-- draws it from the two parts DinoRex moves (KaijuLook).
--
-- Its eyes fire lasers (Laser) at cars too far to bite that they can see
-- past the buildings, whenever it is not biting or holding something. A
-- struck car is blasted up and away: ServerStorage.CarZapped tells
-- ScoreService, which has the driver's game blast it. For each client to
-- draw them, the model's LaserCharge attribute is true while the eyes
-- charge, LaserAim is where they aim, and each shot adds one to LaserShots
-- and sets LaserEnd, where the beam stopped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Laser = require(ReplicatedStorage.Laser)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Rex = require(ReplicatedStorage.Rex)
local Tuning = require(ReplicatedStorage.Tuning)
local DinoRex = require(script.Parent.DinoRex)

local K = Tuning.City.Kaiju
local FLOOR = Tuning.Map.FloorTop

local CityKaiju = {}

-- Modes of the brain (Rex) it may fire in: not while lunging, holding a
-- catch, or resting after one.
local FIRES_IN: { [string]: boolean } = { roam = true, chase = true, recover = true }

local function tellZapped(car: Model, velocity: Vector3)
	local carZapped = ServerStorage:FindFirstChild("CarZapped")
	if carZapped and carZapped:IsA("BindableEvent") then
		carZapped:Fire(car, velocity)
	end
end

-- Runs the eyes' lasers each Heartbeat from the head DinoRex moves.
local function startLasers(model: Model, head: BasePart)
	local L = K.Laser
	local s = Laser.new()
	local shots = 0
	local carsFolder = workspace:WaitForChild("Cars")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	model:SetAttribute("LaserCharge", false)
	model:SetAttribute("LaserAim", Vector3.zero)
	model:SetAttribute("LaserEnd", Vector3.zero)
	model:SetAttribute("LaserShots", shots)

	RunService.Heartbeat:Connect(function(dt: number)
		if not model:IsDescendantOf(workspace) then
			return
		end
		local eyes = head.CFrame:PointToWorldSpace(L.Eyes)
		-- Only buildings and the like stand in the way: never a car, a
		-- player or the kaiju itself.
		local ignore: { Instance } = { carsFolder, model }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		params.FilterDescendantsInstances = ignore

		local cars: { Laser.Car } = {}
		for _, car in carsFolder:GetChildren() do
			local hull = if car:IsA("Model") then car.PrimaryPart else nil
			-- An anchored car is held by something else.
			if hull and not hull.Anchored then
				local p, v = hull.Position, hull.AssemblyLinearVelocity
				local offset = p - eyes
				local near = Vector2.new(offset.X, offset.Z).Magnitude <= L.MaxRange
				table.insert(cars, {
					id = car,
					x = p.X,
					y = p.Y,
					z = p.Z,
					vx = v.X,
					vy = v.Y,
					vz = v.Z,
					visible = near and workspace:Raycast(eyes, offset, params) == nil,
					air = p.Y - FLOOR > K.AirHeight,
				})
			end
		end

		local mode = model:GetAttribute("Mode")
		local canFire = typeof(mode) == "string" and FIRES_IN[mode] == true
		local fired = Laser.step(s, eyes.X, eyes.Y, eyes.Z, cars, canFire, dt, L)
		local charging = s.mode == "charge"
		if model:GetAttribute("LaserCharge") ~= charging then
			model:SetAttribute("LaserCharge", charging)
		end
		if charging then
			model:SetAttribute("LaserAim", Vector3.new(s.aimX, s.aimY, s.aimZ))
		end
		if not fired then
			return
		end

		-- The beam runs on a little past the aim, and stops at whatever is
		-- in the way.
		local aim = Vector3.new(s.aimX, s.aimY, s.aimZ)
		local along = aim - eyes
		local reach = along.Unit * (along.Magnitude + L.BeamRadius)
		local hit = workspace:Raycast(eyes, reach, params)
		local finish = if hit then hit.Position else eyes + reach
		shots += 1
		model:SetAttribute("LaserEnd", finish)
		model:SetAttribute("LaserShots", shots)
		local struck = Laser.struck(eyes.X, eyes.Y, eyes.Z, finish.X, finish.Y, finish.Z, cars, L)
		if not struck then
			return
		end
		local hull = (struck :: Model).PrimaryPart
		if not hull then
			return
		end
		local flat = Vector3.new(along.X, 0, along.Z)
		local heading = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
		local v = hull.AssemblyLinearVelocity
		local vx, vy, vz = Laser.blast(heading.X, heading.Z, v.X, v.Y, v.Z, L)
		tellZapped(struck, Vector3.new(vx, vy, vz))
	end)
end

function CityKaiju.build(parent: Instance, area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "Kaiju"
	-- Persistent, so streaming never takes it from a client.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent

	local streets: { Rex.Rect } = {}
	for _, street in K.Streets do
		table.insert(streets, {
			MinX = area.X + street.MinX,
			MaxX = area.X + street.MaxX,
			MinZ = area.Z + street.MinZ,
			MaxZ = area.Z + street.MaxZ,
		})
	end
	local territory: Rex.Territory = {
		rect = {
			MinX = area.X - area.Width / 2,
			MaxX = area.X + area.Width / 2,
			MinZ = area.Z - area.Depth / 2,
			MaxZ = area.Z + area.Depth / 2,
		},
		keepOut = {},
		floor = FLOOR,
		streets = streets,
	}
	DinoRex.start(
		model,
		territory,
		area.X + K.X,
		area.Z + K.Z,
		math.rad(K.Heading),
		{ tuning = K :: any, name = "Kaiju" }
	)
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		startLasers(model, head)
	else
		warn("CityKaiju: DinoRex made no Head; no lasers")
	end
end

return CityKaiju
