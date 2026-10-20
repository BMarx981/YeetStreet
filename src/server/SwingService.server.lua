--!strict
-- SwingService (Script) -> ServerScriptService.SwingService
-- Keeps every giant swing (Swings) swinging on the server and tells the
-- clients where it is: each Heartbeat it steps every swing with no pump, and
-- SendRate times a second it writes the swing's State and RiderId attributes,
-- which each client's SwingSet follows.
--
-- A client whose car rides a seat steps that swing itself, pumped by its
-- driver, and sends it here on ReplicatedStorage.SwingState as (swing model,
-- angle, speed, riding). The server takes it, so the seat moves for everyone
-- the way the rider pumps it, when nobody else rides that swing and the
-- player's car is on the seat it describes (within HoldSlack). Between sends
-- the server steps it on as usual. A send with riding false, or none for
-- RiderTimeout seconds, lets the swing go.
--
-- RiderId is also how CarSensor knows a car rides a seat (Swings.ridden), so
-- scoring never takes a client's word for a run: only for where the seat is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Swing = require(ReplicatedStorage.Swing)
local Swings = require(ReplicatedStorage.Swings)
local Tuning = require(ReplicatedStorage.Tuning)

local S = Tuning.Swing

local swingState = Instance.new("RemoteEvent")
swingState.Name = "SwingState"
swingState.Parent = ReplicatedStorage

local riderUntil: { [Model]: number } = {}
local carsFolder = workspace:WaitForChild("Cars")

local function carOf(player: Player): Model?
	for _, car in carsFolder:GetChildren() do
		if car:IsA("Model") and car:GetAttribute("OwnerUserId") == player.UserId then
			return car
		end
	end
	return nil
end

local function isNumber(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

swingState.OnServerEvent:Connect(function(player: Player, model: any, angle: any, speed: any, riding: any)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end
	local entry = Swings.all()[model]
	if not (entry and isNumber(angle) and isNumber(speed) and typeof(riding) == "boolean") then
		return
	end
	local someoneElse = entry.riderId ~= 0 and entry.riderId ~= player.UserId
	if someoneElse then
		return
	end
	if not riding then
		if entry.riderId == player.UserId then
			entry.riderId = 0
			riderUntil[model] = nil
		end
		return
	end

	local state: Swing.State = { angle = angle, speed = speed }
	local car = carOf(player)
	local hull = car and car:FindFirstChild("Hull")
	if not (hull and hull:IsA("BasePart")) then
		return
	end
	local p = entry.pivot:PointToObjectSpace(hull.Position)
	if not Swing.onSeat(state, p.X, p.Y, p.Z, S.HoldSlack, S) then
		return
	end
	Swing.limit(state, S)
	entry.state = state
	entry.riderId = player.UserId
	riderUntil[model] = os.clock() + S.RiderTimeout
end)

Players.PlayerRemoving:Connect(function(player: Player)
	for model, entry in Swings.all() do
		if entry.riderId == player.UserId then
			entry.riderId = 0
			riderUntil[model] = nil
		end
	end
end)

local sinceSend = 0

RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()
	for model, entry in Swings.all() do
		if entry.riderId ~= 0 and (riderUntil[model] or 0) < now then
			entry.riderId = 0
			riderUntil[model] = nil
		end
		Swing.step(entry.state, 0, dt, S)
	end

	sinceSend += dt
	if sinceSend < 1 / S.SendRate then
		return
	end
	sinceSend = 0
	for model, entry in Swings.all() do
		model:SetAttribute("State", Vector2.new(entry.state.angle, entry.state.speed))
		model:SetAttribute("RiderId", entry.riderId)
	end
end)
