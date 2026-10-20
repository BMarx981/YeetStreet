--!strict
-- SwingRide (ModuleScript) -> StarterPlayerScripts.SwingRide
-- Rides the driven car on a giant swing's seat (Swings). CarController calls
-- step each physics step; it puts a car that comes down on a seat, or drives
-- onto one, on that seat. While step returns true the car sticks to the seat,
-- even upside down: this places it there every step and moves it with the
-- seat, and CarController leaves driving, jets, and air control alone. The
-- car turns to face along the seat.
--
-- This client steps the swing it rides (Swing), pumped by gas and brake along
-- the car's nose: pumping in time with the swing takes it higher, all the way
-- over the top, and the car rolls a little toward the way it pumps. The swing
-- goes to the server (SwingService) SendRate times a second, so everyone sees
-- the seat move the way it is pumped.
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

-- How far from the seat's edges the hull's center stays.
local EDGE_X = 4
local EDGE_Z = 6

type Ride = {
	entry: Swings.Entry,
	x: number, -- across the seat
	slide: number, -- along it, forward positive
	yaw: number, -- the car's heading on the seat, 0 nose forward
	facing: number, -- 1 riding nose forward, -1 nose back
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
		local yaw = math.atan2(-look.X, -look.Z)
		local edgeX, edgeZ = S.SeatWidth / 2 - EDGE_X, S.SeatDepth / 2 - EDGE_Z
		entry.driven = true
		entry.riderId = player.UserId
		sinceSend = math.huge
		return {
			entry = entry,
			x = math.clamp(onSeat.X, -edgeX, edgeX),
			slide = math.clamp(-onSeat.Z, -edgeZ, edgeZ),
			yaw = yaw,
			facing = if math.cos(yaw) >= 0 then 1 else -1,
		}
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

-- Puts the hull on the seat, its wheels on the seat's top face.
local function place(model: Model, hull: BasePart, current: Ride)
	local seat = Swings.seatCFrame(current.entry)
	local target = seat
		* CFrame.new(current.x, Tuning.TestPark.SpawnHeight, -current.slide)
		* CFrame.Angles(0, current.yaw, 0)
	model:PivotTo(target * hull.CFrame:ToObjectSpace(model:GetPivot()))
end

-- Advances the ride, or starts one. Returns true while the car is on a seat.
function SwingRide.step(
	model: Model,
	hull: BasePart,
	roots: { BasePart },
	throttle: number,
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
	local entry = current.entry
	local spin = entry.pivot.RightVector * entry.state.speed

	if jetPressed then
		local up = Swings.seatCFrame(entry).UpVector
		letGo(current)
		setMotion(roots, Swings.velocityAt(entry, hull.Position) + up * S.Hop, spin)
		return false
	end

	local pump = math.clamp(throttle, -1, 1) * current.facing
	Swing.step(entry.state, pump, dt, S)
	SwingSet.place(entry)

	current.slide += (pump * S.Slide - current.slide) * math.min(S.SlideRate * dt, 1)
	local ahead = if current.facing > 0 then 0 elseif current.yaw >= 0 then math.pi else -math.pi
	local turn = S.TurnRate * dt
	current.yaw += math.clamp(ahead - current.yaw, -turn, turn)

	place(model, hull, current)
	setMotion(roots, Swings.velocityAt(entry, hull.Position), entry.pivot.RightVector * entry.state.speed)

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
