--!strict
-- Swings (ModuleScript) -> ReplicatedStorage.Swings
-- Every model tagged Swing, with the swing's state on this machine. A swing
-- model holds no seat: each client builds and moves its own (SwingSet), and
-- the server keeps only the state (SwingService). Its attributes are Pivot
-- (the CFrame it swings about, see Swing), State (a Vector2 of angle and
-- speed, sent by the server), and RiderId (the UserId of whoever rides it, 0
-- for nobody).
--
-- The server steps every swing and takes the rider's word for theirs. Each
-- client follows the server's State, except for the swing its own car rides,
-- which it steps itself (`driven`). CarSensor asks here whether a car rides a
-- seat.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Swing = require(ReplicatedStorage.Swing)
local Tuning = require(ReplicatedStorage.Tuning)

local Swings = {}

Swings.TAG = "Swing"

export type Entry = {
	model: Model,
	id: string, -- names the swing in RunTracker samples
	pivot: CFrame,
	state: Swing.State,
	riderId: number,
	driven: boolean, -- stepped from this machine's own rider, not followed
}

local entries: { [Model]: Entry } = {}

local function add(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local pivot = instance:GetAttribute("Pivot")
	if typeof(pivot) ~= "CFrame" then
		warn(`Swings: {instance:GetFullName()} has no Pivot`)
		return
	end
	local state = instance:GetAttribute("State")
	local rider = instance:GetAttribute("RiderId")
	local start = if typeof(state) == "Vector2" then state else Vector2.zero
	entries[instance] = {
		model = instance,
		id = instance:GetFullName(),
		pivot = pivot,
		state = { angle = start.X, speed = start.Y },
		riderId = if typeof(rider) == "number" then rider else 0,
		driven = false,
	}
end

local function remove(instance: Instance)
	if instance:IsA("Model") then
		entries[instance] = nil
	end
end

for _, instance in CollectionService:GetTagged(Swings.TAG) do
	add(instance)
end
CollectionService:GetInstanceAddedSignal(Swings.TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(Swings.TAG):Connect(remove)

function Swings.all(): { [Model]: Entry }
	return entries
end

-- Where the seat's top face is, its up vector pointing at the pivot and its
-- LookVector the way a positive speed moves it.
function Swings.seatCFrame(entry: Entry): CFrame
	return entry.pivot * CFrame.Angles(entry.state.angle, 0, 0) * CFrame.new(0, -Tuning.Swing.Length, 0)
end

-- How fast the seat moves at `position`.
function Swings.velocityAt(entry: Entry, position: Vector3): Vector3
	return entry.pivot.RightVector:Cross(position - entry.pivot.Position) * entry.state.speed
end

-- The id of the swing that the player with this UserId rides, if their hull
-- is on its seat, within HoldSlack.
function Swings.ridden(userId: number, position: Vector3): string?
	local S = Tuning.Swing
	for _, entry in entries do
		if entry.riderId == userId and userId ~= 0 then
			local p = entry.pivot:PointToObjectSpace(position)
			if Swing.onSeat(entry.state, p.X, p.Y, p.Z, S.HoldSlack, S) then
				return entry.id
			end
		end
	end
	return nil
end

return Swings
