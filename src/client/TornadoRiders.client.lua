--!strict
-- TornadoRiders (LocalScript) -> StarterPlayerScripts.TornadoRiders
-- Every car riding a tornado, on this client. The server anchors a caught
-- car and leaves it there, setting its Tornado (which tornado), RideAt (the
-- server's time it was caught), RideAngle and RideUp attributes
-- (TornadoService). Each frame, before the camera, this places the car round
-- that tornado's funnel from those (Tornado.rideAfter, Tornado.riderAt), so
-- it whirls smoothly on every screen rather than jumping as server updates
-- arrive. The change is this client's own; the server moves the car again
-- only when it throws it out.
--
-- The driver's arms flail over their head while they ride: each physics
-- step, after their animations, the shoulders and elbows are turned (Flail).
-- Works on R15 characters, whose arm joints are named RightShoulder,
-- LeftShoulder, RightElbow and LeftElbow.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tornado = require(ReplicatedStorage.Tornado)
local Tuning = require(ReplicatedStorage.Tuning)
local Flail = require(script.Parent.Flail)

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

-- Where `car` is in its ride now, or nil if it rides nothing.
local function placeOf(car: Instance, now: number): CFrame?
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
	return CFrame.new(place.x, FLOOR + place.up, place.z)
		* CFrame.Angles(0, place.yaw, 0)
		* CFrame.Angles(0, 0, place.tumble)
end

-- The driver sitting in `car`, if any.
local function driverOf(car: Instance): Model?
	local seat = car:FindFirstChild("DriverSeat", true)
	local occupant = if seat and (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then (seat :: any).Occupant else nil
	local character = if occupant then occupant.Parent else nil
	return if character and character:IsA("Model") then character else nil
end

RunService:BindToRenderStep("TornadoRiders", Enum.RenderPriority.Camera.Value - 1, function()
	local now = workspace:GetServerTimeNow()
	for _, car in carsFolder:GetChildren() do
		local hull = if car:IsA("Model") then car.PrimaryPart else nil
		if hull and hull.Anchored then
			local frame = placeOf(car, now)
			if frame then
				(car :: Model):PivotTo(frame)
			end
		end
	end
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
	for _, car in carsFolder:GetChildren() do
		if car:GetAttribute("Tornado") ~= nil then
			local character = driverOf(car)
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
	end
end)
