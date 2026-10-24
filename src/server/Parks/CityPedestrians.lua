--!strict
-- CityPedestrians (ModuleScript) -> ServerScriptService.Parks.CityPedestrians
-- Downtown's walkers, started by City.start whenever a server starts, even
-- when the city's parts were saved with the place. Each goes round its
-- loop on the curbs (Pedestrians) from the server's clock, and the server
-- steps each one (Pedestrian) Rate times a second against the cars near
-- it, looking past the buildings to say which it can see. A near miss
-- fires ServerStorage.PedestrianNearMiss with the car, and ScoreService
-- pays its driver. Nothing here ever touches a car.
--
-- For each client to draw them (PedestrianLook), workspace.Parks.City.
-- Pedestrians holds one Configuration per walker, named by its number,
-- with its Pedestrian.State as attributes: Mode, Since, StartX, StartZ,
-- AnchorX, AnchorZ, DirX, DirZ and Delay, set whenever it dives, flops or
-- walks on. Points are in park coordinates; the model's AreaX and AreaZ
-- attributes are the park's middle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Pedestrian = require(ReplicatedStorage.Pedestrian)
local Pedestrians = require(ReplicatedStorage.Pedestrians)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)

local C = Tuning.City
local P = C.Pedestrians
local FLOOR = Tuning.Map.FloorTop

local CityPedestrians = {}

local function tellNearMiss(car: Model)
	local event = ServerStorage:FindFirstChild("PedestrianNearMiss")
	if event and event:IsA("BindableEvent") then
		event:Fire(car)
	end
end

local function publish(config: Configuration, s: Pedestrian.State)
	config:SetAttribute("Mode", s.mode)
	config:SetAttribute("Since", s.since)
	config:SetAttribute("StartX", s.startX)
	config:SetAttribute("StartZ", s.startZ)
	config:SetAttribute("AnchorX", s.anchorX)
	config:SetAttribute("AnchorZ", s.anchorZ)
	config:SetAttribute("DirX", s.dirX)
	config:SetAttribute("DirZ", s.dirZ)
	config:SetAttribute("Delay", s.delay)
end

function CityPedestrians.start(parent: Instance, area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "Pedestrians"
	-- Persistent, so streaming never takes it from a client.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:SetAttribute("AreaX", area.X)
	model:SetAttribute("AreaZ", area.Z)

	local routes = Pedestrians.routes(Pedestrians.layout(C :: any), P)
	local walkers = Pedestrians.walkers(routes, P, Rng.new(P.Seed))
	local states: { Pedestrian.State } = {}
	local configs: { Configuration } = {}
	for i in walkers do
		local config = Instance.new("Configuration")
		config.Name = tostring(i)
		states[i] = Pedestrian.new()
		configs[i] = config
		publish(config, states[i])
		config.Parent = model
	end
	model.Parent = parent

	local D = P.Dodge
	local carsFolder = workspace:WaitForChild("Cars")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local reach = D.SeeDistance + D.HitRadius
	local untilStep = 0

	RunService.Heartbeat:Connect(function(dt: number)
		untilStep -= dt
		if untilStep > 0 or not model:IsDescendantOf(workspace) then
			return
		end
		untilStep = 1 / P.Rate
		local now = workspace:GetServerTimeNow()

		-- Every unheld car in park coordinates, once.
		local hulls: { { model: Model, p: Vector3, v: Vector3 } } = {}
		for _, car in carsFolder:GetChildren() do
			local hull = if car:IsA("Model") then car.PrimaryPart else nil
			if hull and not hull.Anchored then
				local p = hull.Position
				if MapLayout.contains(area, p.X, p.Z) then
					table.insert(hulls, { model = car, p = p, v = hull.AssemblyLinearVelocity })
				end
			end
		end

		-- Only buildings and the like block a walker's view.
		local ignore: { Instance } = { carsFolder }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		params.FilterDescendantsInstances = ignore

		for i, walker in walkers do
			local s = states[i]
			local route = routes[walker.route]
			local spot = Pedestrians.at(walker, route, Pedestrian.clock(s, now, D))
			local x, z = spot.x, spot.z
			if s.mode ~= "walk" then
				local where = Pedestrian.where(s, now, D)
				x, z = where.x, where.z
			end
			local eyes = Vector3.new(area.X + x, FLOOR + P.EyeHeight, area.Z + z)
			local cars: { Pedestrian.Car } = {}
			for _, hull in hulls do
				local offset = hull.p - eyes
				if offset.X * offset.X + offset.Z * offset.Z <= reach * reach then
					table.insert(cars, {
						id = hull.model,
						x = hull.p.X - area.X,
						y = hull.p.Y - FLOOR,
						z = hull.p.Z - area.Z,
						vx = hull.v.X,
						vy = hull.v.Y,
						vz = hull.v.Z,
						visible = workspace:Raycast(eyes, offset, params) == nil,
						air = hull.p.Y - FLOOR > P.AirHeight,
					})
				end
			end
			if #cars > 0 or s.mode ~= "walk" then
				local mode = s.mode
				local event = Pedestrian.step(s, spot, 0, cars, now, D)
				if event and event.kind == "nearMiss" then
					tellNearMiss(event.car)
				end
				if s.mode ~= mode then
					publish(configs[i], s)
				end
			end
		end
	end)
end

return CityPedestrians
