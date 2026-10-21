--!strict
-- SwingRide (ModuleScript) -> StarterPlayerScripts.SwingRide
-- Rides the driven car on a giant swing's seat (Swings). CarController calls
-- step each physics step; it puts a car that comes down on a seat, or drives
-- onto one, on that seat. While step returns true the car sticks to the seat,
-- even upside down: this places it there every step and moves it with the
-- seat, and CarController leaves driving, jets, and air control alone.
--
-- On the seat the car drives around with gas, brake, and steering (Swing.drive),
-- and driving past an edge takes it off, with the seat's speed plus its own.
-- This client steps the swing it rides (Swing), pumped by gas the way the
-- car's nose points: driving back and forth in time with the swing takes it
-- higher, all the way over the top. The swing goes to the server
-- (SwingService) SendRate times a second, so everyone sees the seat move the
-- way it is pumped.
--
-- Jets launch the car off: it leaves with the seat's speed plus a hop off the
-- seat's face. A seat waits Cooldown seconds before it can catch the same car
-- again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Swing = require(ReplicatedStorage.Swing)
local Swings = require(ReplicatedStorage.Swings)
local Tuning = require(ReplicatedStorage.Tuning)
local SwingSet = require(script.Parent.SwingSet)

local SwingRide = {}

-- A car caught right at an edge starts this far in from it.
local EDGE = 1

type Ride = {
	entry: Swings.Entry,
	rider: Swing.Rider,
}

local player = Players.LocalPlayer :: Player
local ride: Ride? = nil
local cooldownUntil: { [Model]: number } = {}
local jetHeld = false
local sinceSend = 0
local remote: RemoteEvent? = nil

task.spawn(function()
	local found = ReplicatedStorage:WaitForChild("SwingState")
	if found:IsA("RemoteEvent") then
		remote = found
	else
		warn("SwingRide: ReplicatedStorage.SwingState is not a RemoteEvent; others won't see swings pumped")
	end
end)

local function send(entry: Swings.Entry, riding: boolean)
	local r = remote
	if r then
		r:FireServer(entry.model, entry.state.angle, entry.state.speed, riding)
	end
end

-- The way the rider's nose points, in world space.
local function nose(entry: Swings.Entry, rider: Swing.Rider): Vector3
	return Swings.seatCFrame(entry):VectorToWorldSpace(Vector3.new(-math.sin(rider.yaw), 0, -math.cos(rider.yaw)))
end

local function tryCapture(hull: BasePart): Ride?
	local S = Tuning.Swing
	local now = os.clock()
	for model, entry in Swings.all() do
		if (cooldownUntil[model] or 0) > now then
			continue
		end
		if entry.riderId ~= 0 and entry.riderId ~= player.UserId then
			continue
		end
		local p = entry.pivot:PointToObjectSpace(hull.Position)
		if not Swing.onSeat(entry.state, p.X, p.Y, p.Z, 0, S) then
			continue
		end
		local seat = Swings.seatCFrame(entry)
		if hull.CFrame.UpVector:Dot(seat.UpVector) < S.CaptureUp then
			continue
		end
		local onSeat = seat:PointToObjectSpace(hull.Position)
		local look = seat:VectorToObjectSpace(hull.CFrame.LookVector)
		local edgeX, edgeZ = S.SeatWidth / 2 - EDGE, S.SeatDepth / 2 - EDGE
		local rider: Swing.Rider = {
			x = math.clamp(onSeat.X, -edgeX, edgeX),
			z = math.clamp(onSeat.Z, -edgeZ, edgeZ),
			yaw = math.atan2(-look.X, -look.Z),
			speed = 0,
		}
		-- Keep the car's own speed across the seat, up to what it can drive there.
		local relative = hull.AssemblyLinearVelocity - Swings.velocityAt(entry, hull.Position)
		rider.speed = math.clamp(relative:Dot(nose(entry, rider)), -S.DriveSpeed, S.DriveSpeed)
		entry.driven = true
		entry.riderId = player.UserId
		sinceSend = math.huge
		return { entry = entry, rider = rider }
	end
	return nil
end

local function setMotion(roots: { BasePart }, velocity: Vector3, spin: Vector3)
	for _, part in roots do
		part.AssemblyLinearVelocity = velocity
		part.AssemblyAngularVelocity = spin
	end
end

local function letGo(current: Ride)
	ride = nil
	local entry = current.entry
	entry.driven = false
	entry.riderId = 0
	cooldownUntil[entry.model] = os.clock() + Tuning.Swing.Cooldown
	send(entry, false)
end

-- Puts the hull on the seat where the rider is, its wheels on the top face.
local function place(model: Model, hull: BasePart, current: Ride)
	local r = current.rider
	local target = Swings.seatCFrame(current.entry)
		* CFrame.new(r.x, Tuning.TestPark.SpawnHeight, r.z)
		* CFrame.Angles(0, r.yaw, 0)
	model:PivotTo(target * hull.CFrame:ToObjectSpace(model:GetPivot()))
end

-- Advances the ride, or starts one. Returns true while the car is on a seat.
function SwingRide.step(
	model: Model,
	hull: BasePart,
	roots: { BasePart },
	throttle: number,
	steer: number,
	jet: boolean,
	dt: number
): boolean
	local S = Tuning.Swing
	local jetPressed = jet and not jetHeld
	jetHeld = jet

	local current = ride or tryCapture(hull)
	if not current then
		return false
	end
	ride = current
	local entry, r = current.entry, current.rider
	local spin = entry.pivot.RightVector * entry.state.speed

	if jetPressed then
		local up = Swings.seatCFrame(entry).UpVector
		local velocity = Swings.velocityAt(entry, hull.Position) + nose(entry, r) * r.speed + up * S.Hop
		letGo(current)
		setMotion(roots, velocity, spin)
		return false
	end

	Swing.step(entry.state, Swing.pump(r, throttle), dt, S)
	SwingSet.place(entry)
	local stays = Swing.drive(r, math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1), dt, S)
	place(model, hull, current)
	local velocity = Swings.velocityAt(entry, hull.Position) + nose(entry, r) * r.speed
	spin = entry.pivot.RightVector * entry.state.speed
	if not stays then
		letGo(current)
		setMotion(roots, velocity, spin)
		return false
	end
	setMotion(roots, velocity, spin)

	sinceSend += dt
	if sinceSend >= 1 / S.SendRate then
		sinceSend = 0
		send(entry, true)
	end
	return true
end

-- Ends any ride at once, for resets and leaving the car.
function SwingRide.stop()
	local current = ride
	if current then
		letGo(current)
	end
	jetHeld = false
end

return SwingRide
