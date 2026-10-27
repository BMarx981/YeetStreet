--!strict
-- CityPedestrians (ModuleScript) -> ServerScriptService.Parks.CityPedestrians
-- Downtown's walkers, started by City.start whenever a server starts, even
-- when the city's parts were saved with the place. Each goes round its
-- loop on the curbs (Pedestrians) from the server's clock, and the server
-- steps each one (Pedestrian) Rate times a second against the cars near
-- it, looking past the buildings to say which it can see, and where the
-- kaiju (CityKaiju) is, so they run from it. A near miss
-- fires ServerStorage.PedestrianNearMiss with the car, and ScoreService
-- pays its driver. Nothing here ever touches a car.
--
-- For each client to draw them (PedestrianLook), workspace.Parks.City.
-- Pedestrians holds one Configuration per walker, named by its number,
-- with its Pedestrian.State as attributes: Mode, Since, StartX, StartZ,
-- AnchorX, AnchorZ, DirX, DirZ, Delay and Rate, set whenever it flees,
-- dives, flops or walks on. Points are in park coordinates; the model's AreaX and AreaZ
-- attributes are the park's middle.
--
-- People also sit on a Share of the roof gardens' seats (CityRoofs tags
-- them GardenSeat). Each is a walker whose loop is its seat, its feet up on
-- the roof: it dives, is knocked flat and walks back to its seat the same
-- way, and pays near misses the same. Its Configuration is named "Sitter"
-- and its number, with the seat as attributes too: SeatX, SeatZ, FaceX,
-- FaceZ, Y (its feet above the floor), SeatHeight and Kind.

local CollectionService = game:GetService("CollectionService")
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

type Sitter = {
	spot: Pedestrian.Spot,
	y: number,
	state: Pedestrian.State,
	config: Configuration,
}

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
	config:SetAttribute("Rate", s.rate)
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

	-- The seats in a set order, so the same ones are taken every time.
	local seats: { BasePart } = {}
	for _, seat in CollectionService:GetTagged("GardenSeat") do
		if seat:IsA("BasePart") and seat:IsDescendantOf(parent) and typeof(seat:GetAttribute("Foot")) == "Vector3" then
			table.insert(seats, seat)
		end
	end
	table.sort(seats, function(a, b)
		local fa, fb = a:GetAttribute("Foot") :: Vector3, b:GetAttribute("Foot") :: Vector3
		if fa.X ~= fb.X then
			return fa.X < fb.X
		end
		return fa.Z < fb.Z
	end)
	local sitters: { Sitter } = {}
	local pick = Rng.new(P.Sitters.Seed)
	for _, seat in seats do
		if pick.next() < P.Sitters.Share then
			local foot = seat:GetAttribute("Foot") :: Vector3
			local face = seat:GetAttribute("Face")
			local faceX, faceZ = 0, -1
			if typeof(face) == "Vector3" then
				faceX, faceZ = face.X, face.Z
			end
			local spot = {
				x = foot.X - area.X,
				z = foot.Z - area.Z,
				headingX = faceX,
				headingZ = faceZ,
				road = false,
				toCurb = 0,
			}
			local config = Instance.new("Configuration")
			config.Name = `Sitter{#sitters + 1}`
			config:SetAttribute("SeatX", spot.x)
			config:SetAttribute("SeatZ", spot.z)
			config:SetAttribute("FaceX", faceX)
			config:SetAttribute("FaceZ", faceZ)
			config:SetAttribute("Y", foot.Y - FLOOR)
			config:SetAttribute("SeatHeight", seat:GetAttribute("SeatHeight"))
			config:SetAttribute("Kind", seat:GetAttribute("Kind"))
			local state = Pedestrian.new()
			state.anchorX, state.anchorZ = spot.x, spot.z
			publish(config, state)
			config.Parent = model
			table.insert(sitters, { spot = spot, y = foot.Y - FLOOR, state = state, config = config })
		end
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

		-- The kaiju's feet, in park coordinates.
		local kaiju: Pedestrian.Point? = nil
		local kaijuModel = parent:FindFirstChild("Kaiju")
		local root = kaijuModel and kaijuModel:FindFirstChild("Root")
		if root and root:IsA("BasePart") then
			kaiju = { x = root.Position.X - area.X, z = root.Position.Z - area.Z }
		end

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

		-- The cars near someone at (x, z) with its feet `y` above the floor,
		-- as it sees them.
		local function near(x: number, z: number, y: number): { Pedestrian.Car }
			local eyes = Vector3.new(area.X + x, FLOOR + y + P.EyeHeight, area.Z + z)
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
						air = hull.p.Y - FLOOR - y > P.AirHeight,
					})
				end
			end
			return cars
		end

		for i, walker in walkers do
			local s = states[i]
			local route = routes[walker.route]
			local spot = Pedestrians.at(walker, route, Pedestrian.clock(s, now, D))
			local x, z = spot.x, spot.z
			if not Pedestrian.onLoop(s) then
				local where = Pedestrian.where(s, now, D)
				x, z = where.x, where.z
			end
			local mode, since = s.mode, s.since
			local event = Pedestrian.step(s, spot, 0, near(x, z, 0), now, D, kaiju)
			if event and event.kind == "nearMiss" then
				tellNearMiss(event.car)
			end
			if s.mode ~= mode or s.since ~= since then
				publish(configs[i], s)
			end
		end

		for _, sitter in sitters do
			local s = sitter.state
			local x, z = sitter.spot.x, sitter.spot.z
			if not Pedestrian.onLoop(s) then
				local where = Pedestrian.where(s, now, D)
				x, z = where.x, where.z
			end
			local mode, since = s.mode, s.since
			local event = Pedestrian.step(s, sitter.spot, sitter.y, near(x, z, sitter.y), now, D)
			if event and event.kind == "nearMiss" then
				tellNearMiss(event.car)
			end
			if s.mode ~= mode or s.since ~= since then
				publish(sitter.config, s)
			end
		end
	end)
end

return CityPedestrians
