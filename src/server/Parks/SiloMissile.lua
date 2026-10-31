--!strict
-- SiloMissile (ModuleScript) -> ServerScriptService.Parks.SiloMissile
-- Runs the silo's missiles on the server, which owns where each one is and
-- where it hits (Missile), since a hit wrecks cars. A launch
-- (ServerStorage.SiloLaunch) puts a new missile on the launch button with the
-- player's car anchored on top, the way the pterodactyl carries one, and
-- flies it on a random heading that lands on the map. The rider's client only
-- sends its steering, on ReplicatedStorage.MissileSteer (SiloRide), and the
-- most a false report does is steer that one missile.
--
-- The car's OnMissile attribute is set for the ride, so R and getting out do
-- nothing. A hit ends the ride and wrecks the car (ServerStorage.CarBlasted).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Missile = require(ReplicatedStorage.Missile)
local Rng = require(ReplicatedStorage.Rng)
local Silo = require(ReplicatedStorage.Silo)
local Tuning = require(ReplicatedStorage.Tuning)

local S = Tuning.Silo
local M = S.Missile
local CONFIG: Missile.Config = M :: any
local FLOOR = Tuning.Map.FloorTop

local BODY_COLOR = Color3.fromRGB(190, 190, 180)
local STRIPE_COLOR = Color3.fromRGB(30, 30, 34)
local NOSE_COLOR = Color3.fromRGB(170, 40, 30)

type Ride = {
	player: Player,
	car: Model,
	model: Model,
	state: Missile.State,
	steer: number,
	pitch: number,
}

local SiloMissile = {}

local function piece(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, solid: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = solid
	part.CanQuery = solid
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Metal
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A cylinder round the missile's length, centered `along` from its middle
-- toward the nose.
local function round(
	parent: Instance,
	name: string,
	frame: CFrame,
	along: number,
	length: number,
	radius: number,
	color: Color3,
	solid: boolean
): Part
	local part = piece(
		parent,
		name,
		Vector3.new(length, 2 * radius, 2 * radius),
		frame * CFrame.new(0, 0, -along) * CFrame.Angles(0, math.pi / 2, 0),
		color,
		solid
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A missile, its middle at `frame` with its nose along LookVector. Only a
-- standing one on the rack is solid.
function SiloMissile.model(parent: Instance, frame: CFrame, solid: boolean): Model
	local L, R = M.Length, M.Radius
	local model = Instance.new("Model")
	model.Name = "Missile"
	local body = round(model, "Body", frame, 0, L * 0.7, R, BODY_COLOR, solid)
	round(model, "Stripe", frame, L * 0.2, 2, R + 0.1, STRIPE_COLOR, solid)
	round(model, "Stripe", frame, -L * 0.2, 2, R + 0.1, STRIPE_COLOR, solid)
	-- The nose narrows in steps to a point.
	round(model, "Nose", frame, L * 0.4, L * 0.1, R * 0.75, NOSE_COLOR, solid)
	round(model, "Nose", frame, L * 0.46, L * 0.04, R * 0.45, NOSE_COLOR, solid)
	round(model, "Nose", frame, L * 0.49, L * 0.02, R * 0.2, NOSE_COLOR, solid)
	-- Four fins round the tail.
	for i = 0, 3 do
		local turn = frame * CFrame.Angles(0, 0, i * math.pi / 2)
		piece(
			model,
			"Fin",
			Vector3.new(0.6, R * 1.6, L * 0.2),
			turn * CFrame.new(0, R * 1.4, L * 0.28),
			NOSE_COLOR,
			solid
		)
	end
	model.PrimaryPart = body
	model.Parent = parent
	return model
end

-- Lights the tail of a flying missile.
local function ignite(model: Model, frame: CFrame)
	local tail = Instance.new("Part")
	tail.Name = "Tail"
	tail.Anchored = true
	tail.CanCollide = false
	tail.CanQuery = false
	tail.CanTouch = false
	tail.Transparency = 1
	tail.Size = Vector3.new(M.Radius * 2, M.Radius * 2, 1)
	tail.CFrame = frame * CFrame.new(0, 0, M.Length * 0.35)
	tail.Parent = model

	local fire = Instance.new("ParticleEmitter")
	fire.Name = "Flame"
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 20))
	fire.Size = NumberSequence.new(M.Radius * 1.5, M.Radius * 0.5)
	fire.Lifetime = NumberRange.new(0.25, 0.5)
	fire.Rate = 80
	fire.Speed = NumberRange.new(60, 90)
	fire.EmissionDirection = Enum.NormalId.Back
	fire.Parent = tail

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	smoke.Size = NumberSequence.new(M.Radius, M.Radius * 4)
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Rate = 40
	smoke.Speed = NumberRange.new(10, 20)
	smoke.EmissionDirection = Enum.NormalId.Back
	smoke.Parent = tail
end

local function setAnchored(car: Model, anchored: boolean)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end
end

-- Where a missile is, in the world, facing the way it flies.
local function frameOf(state: Missile.State): CFrame
	local look = Vector3.new(Missile.direction(state))
	local up = Vector3.new(Missile.up(state))
	local at = Vector3.new(state.x, state.y + FLOOR, state.z)
	return CFrame.lookAt(at, at + look, up)
end

-- Starts the missiles over the silo in `area`.
function SiloMissile.start(folder: Folder, area: MapLayout.Area)
	local shape: Silo.Shape = S :: any
	local padX, padY, padZ = Silo.launchPoint(shape)
	local startX, startY, startZ = area.X + padX, padY + M.Length / 2, area.Z + padZ
	local rng = Rng.new(os.time())
	local rides: { [Player]: Ride } = {}

	local flying = Instance.new("Folder")
	flying.Name = "Flying"
	flying.Parent = folder

	local steerRemote = Instance.new("RemoteEvent")
	steerRemote.Name = "MissileSteer"
	steerRemote.Parent = ReplicatedStorage
	steerRemote.OnServerEvent:Connect(function(player: Player, steer: any, pitch: any)
		local ride = rides[player]
		if ride and typeof(steer) == "number" and typeof(pitch) == "number" and steer == steer and pitch == pitch then
			ride.steer, ride.pitch = steer, pitch
		end
	end)

	local launch = ServerStorage:WaitForChild("SiloLaunch") :: BindableEvent
	launch.Event:Connect(function(player: Player)
		if rides[player] then
			return
		end
		local carsFolder = workspace:FindFirstChild("Cars")
		local car: Model? = nil
		if carsFolder then
			for _, candidate in carsFolder:GetChildren() do
				if candidate:IsA("Model") and candidate:GetAttribute("OwnerUserId") == player.UserId then
					car = candidate
				end
			end
		end
		if not car or not car.PrimaryPart then
			return
		end
		local azimuth = Missile.pickHeading(CONFIG, rng, startX, startY, startZ, Tuning.Map.Bounds)
		local state = Missile.new(startX, startY, startZ, azimuth, rng.next() * 2 * math.pi, M.Ignition)
		local frame = frameOf(state)
		local model = SiloMissile.model(flying, frame, false)
		ignite(model, frame)
		setAnchored(car, true)
		car:SetAttribute("OnMissile", true)
		car:PivotTo(frame * CFrame.new(0, M.Radius + M.RideHeight, 0))
		local carried = ServerStorage:FindFirstChild("CarCarried")
		if carried and carried:IsA("BindableEvent") then
			carried:Fire(car, "grabbed")
		end
		player:SetAttribute("OnMissile", true)
		rides[player] = { player = player, car = car, model = model, state = state, steer = 0, pitch = 0 }
	end)

	local function finish(ride: Ride)
		rides[ride.player] = nil
		ride.model:Destroy()
		ride.player:SetAttribute("OnMissile", nil)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true

	local function hit(ride: Ride, _position: Vector3)
		local car = ride.car
		finish(ride)
		setAnchored(car, false)
		local blasted = ServerStorage:FindFirstChild("CarBlasted")
		if blasted and blasted:IsA("BindableEvent") then
			blasted:Fire(car)
		end
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		local ride = rides[player]
		if ride then
			finish(ride)
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		for _, ride in rides do
			local carsFolder = workspace:FindFirstChild("Cars")
			if ride.car.Parent ~= carsFolder then
				finish(ride)
				continue
			end
			local state = ride.state
			local from = Vector3.new(state.x, state.y + FLOOR, state.z)
			Missile.step(state, CONFIG, ride.steer, ride.pitch, dt)
			local frame = frameOf(state)
			ride.model:PivotTo(frame)
			ride.car:PivotTo(frame * CFrame.new(0, M.Radius + M.RideHeight, 0))
			if not Missile.climbing(state, CONFIG) then
				params.FilterDescendantsInstances = { carsFolder :: Instance, flying }
				local nose = frame.Position + frame.LookVector * M.Length / 2
				local result = workspace:Raycast(from, nose - from, params)
				if result then
					hit(ride, result.Position)
				elseif state.y <= 0 then
					hit(ride, frame.Position)
				end
			end
		end
	end)
end

return SiloMissile
