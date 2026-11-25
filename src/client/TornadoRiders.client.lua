--!strict
-- TornadoRiders (LocalScript) -> StarterPlayerScripts.TornadoRiders
-- Every car and player on foot riding a tornado, on this client. The server
-- anchors a caught car (or a player's root part) and leaves it there,
-- setting its Tornado (which tornado), RideAt (the server's time it was
-- caught), RideAngle and RideUp attributes on the car or character
-- (TornadoService). Each frame, before the camera, this places it round that
-- tornado's funnel from those (Tornado.rideAfter, Tornado.riderAt), so it
-- whirls smoothly on every screen rather than jumping as server updates
-- arrive. The change is this client's own; the server moves it again only
-- when it throws it out. A player riding on foot sees their ride through
-- TornadoCamera, as a driver does, and gets the normal camera back after.
--
-- The rider's arms (a car's driver's) flail over their head: each physics
-- step, after their animations, the shoulders and elbows are turned (Flail).
-- Works on R15 characters, whose arm joints are named RightShoulder,
-- LeftShoulder, RightElbow and LeftElbow.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tornado = require(ReplicatedStorage.Tornado)
local Tuning = require(ReplicatedStorage.Tuning)
local Flail = require(script.Parent.Flail)
local TornadoCamera = require(script.Parent.TornadoCamera)

local T: Tornado.Tuning = Tuning.Tornado :: any
local FLOOR: number = Tuning.Map.FloorTop
local NO_AREA: Tornado.Area = { X = 0, Z = 0, Width = 0, Depth = 0 }

-- Rojo has synced some LocalScripts twice; one is enough.
local player = Players.LocalPlayer
if player:GetAttribute("TornadoRiders") then
	return
end
player:SetAttribute("TornadoRiders", true)

local carsFolder = workspace:WaitForChild("Cars")
local tornados = workspace:WaitForChild("Tornados")

-- Where `car` is in its ride now, and its tornado's Base and height, or nil
-- if it rides nothing.
local function placeOf(car: Instance, now: number): (CFrame?, BasePart?, number?)
	local name = car:GetAttribute("Tornado")
	local rideAt = car:GetAttribute("RideAt")
	local angle0 = car:GetAttribute("RideAngle")
	local up0 = car:GetAttribute("RideUp")
	if
		typeof(name) ~= "string"
		or typeof(rideAt) ~= "number"
		or typeof(angle0) ~= "number"
		or typeof(up0) ~= "number"
	then
		return nil
	end
	local model = tornados:FindFirstChild(name)
	local base = if model then model:FindFirstChild("Base") else nil
	local height = if model then model:GetAttribute("Height") else nil
	if not (base and base:IsA("BasePart") and typeof(height) == "number") then
		return nil
	end
	local age = math.max(now - rideAt, 0)
	local angle, up, tumble = Tornado.rideAfter(angle0, up0, height, age, T)
	local s = Tornado.new(base.Position.X, base.Position.Z, height, 0, NO_AREA)
	local place = Tornado.riderAt(s, {
		id = car,
		angle0 = angle0,
		up0 = up0,
		age = age,
		angle = angle,
		up = up,
		tumble = tumble,
		jetsFor = 0,
	}, T)
	return CFrame.new(place.x, FLOOR + place.up, place.z) * CFrame.Angles(0, place.yaw, 0) * CFrame.Angles(
		0,
		0,
		place.tumble
	),
		base,
		height
end

-- The driver sitting in `car`, if any.
local function driverOf(car: Instance): Model?
	local seat = car:FindFirstChild("DriverSeat", true)
	local occupant = if seat and (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then (seat :: any).Occupant else nil
	local character = if occupant then occupant.Parent else nil
	return if character and character:IsA("Model") then character else nil
end

-- Everything riding a tornado now: each car or character with the part
-- the server anchored, and whose arms flail (a car's driver, if any).
local function riders(): { { model: Model, held: BasePart, flailer: Model? } }
	local found = {}
	for _, car in carsFolder:GetChildren() do
		local hull = if car:IsA("Model") then car.PrimaryPart else nil
		if hull and car:GetAttribute("Tornado") ~= nil then
			table.insert(found, { model = car :: Model, held = hull, flailer = driverOf(car) })
		end
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if character and root and root:IsA("BasePart") and character:GetAttribute("Tornado") ~= nil then
			table.insert(found, { model = character, held = root, flailer = character })
		end
	end
	return found
end

-- Whether this player's own camera is following their ride on foot.
local watchingOwn = false

RunService:BindToRenderStep("TornadoRiders", Enum.RenderPriority.Camera.Value - 1, function(dt: number)
	local now = workspace:GetServerTimeNow()
	local ownRide = false
	for _, rider in riders() do
		if rider.held.Anchored then
			local frame, base, height = placeOf(rider.model, now)
			if frame then
				rider.model:PivotTo(frame)
				-- On foot, CarController leaves the camera alone, so the
				-- player's own ride is followed here as a car's is.
				if rider.model == player.Character and base and height then
					ownRide = true
					TornadoCamera.update(rider.held, base.Position, height, dt)
				end
			end
		end
	end
	if watchingOwn and not ownRide then
		TornadoCamera.release()
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
	watchingOwn = ownRide
end)

-- Each character's own flail timing, so two riders never flail in step.
local offsets: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local rolls = Random.new()

local function turn(character: Model, name: string, angles: CFrame)
	local joint = character:FindFirstChild(name, true)
	if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
		(joint :: any).Transform = angles
	end
end

-- Animations set the joints before the physics step, so the flail goes on
-- after them, here.
RunService.PreSimulation:Connect(function()
	local clock = os.clock()
	for _, rider in riders() do
		local character = rider.flailer
		if character then
			local offset = offsets[character]
			if not offset then
				offset = rolls:NextNumber(0, 100)
				offsets[character] = offset
			end
			for name, angles in Flail.joints(clock + offset) do
				turn(character, name, angles)
			end
		end
	end
end)
