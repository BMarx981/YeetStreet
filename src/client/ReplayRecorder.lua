--!strict
-- ReplayRecorder (ModuleScript) -> StarterPlayerScripts.ReplayRecorder
-- Records the local player's car onto a ReplayTape and keeps the clip of the
-- last run, for the replay to play. CarController tells it when the car
-- changes (start, stop), each physics step (step), and when a run ends
-- (finish).
--
-- The clip is cut Tail seconds after the run ends, or at once if the car
-- goes first (a wreck, reset, or exit), so it never shows the next car. A
-- run still in the air when the car goes, as in a wreck, ends there.
--
-- A replay carries the car's attributes (CarParts) as they were at the start
-- of its clip, so the replay can build the same car. Broken<Slot> counts are
-- those from before the clip; the clip's marks say when the rest broke off.
-- The attributes are copied as they change rather than read at the cut, since
-- by then a wrecked car is gone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarParts = require(ReplicatedStorage.CarParts)
local ReplayTape = require(ReplicatedStorage.ReplayTape)
local Tuning = require(ReplicatedStorage.Tuning)

local R = Tuning.Replay

export type Replay = {
	clip: ReplayTape.Clip<CFrame>,
	look: { [string]: any }, -- the car's attributes at the start of the clip
}

local ReplayRecorder = {}

local tape: ReplayTape.Tape<CFrame> = ReplayTape.new()
local look: { [string]: any } = {}
local connections: { RBXScriptConnection } = {}
local wasFlying = false
local liftoffAt = 0
-- The window of the run that ended, waiting for its tail to be recorded.
local pending: { from: number, to: number }? = nil
local last: Replay? = nil

local function cut()
	local window = pending
	if not window then
		return
	end
	pending = nil
	local clip = ReplayTape.cut(tape, window.from, window.to)
	if not clip then
		return
	end
	local before = table.clone(look)
	for slot, count in ReplayTape.broken(clip, clip.duration) do
		local attribute = CarParts.brokenAttribute(slot)
		local now = before[attribute]
		before[attribute] = math.max((if typeof(now) == "number" then now else 0) - count, 0)
	end
	last = { clip = clip, look = before }
end

-- Starts recording `model`, the car the local player just got into.
function ReplayRecorder.start(model: Model)
	ReplayRecorder.stop()
	tape = ReplayTape.new()
	look = model:GetAttributes()
	wasFlying = false
	table.insert(
		connections,
		model.AttributeChanged:Connect(function(attribute: string)
			local value = model:GetAttribute(attribute)
			for _, slot in CarParts.Slots do
				if attribute == CarParts.brokenAttribute(slot) then
					local was = look[attribute]
					local more = (if typeof(value) == "number" then value else 0)
						- (if typeof(was) == "number" then was else 0)
					for _ = 1, more do
						ReplayTape.mark(tape, os.clock(), slot)
					end
				end
			end
			look[attribute] = value
		end)
	)
end

-- Stops recording the car, cutting the last run's clip if it was waiting.
function ReplayRecorder.stop()
	if wasFlying then
		ReplayRecorder.finish()
		wasFlying = false
	end
	cut()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

-- Records this physics step. `flying` is whether a run is under way.
function ReplayRecorder.step(hull: BasePart, flying: boolean)
	local now = os.clock()
	if flying and not wasFlying then
		liftoffAt = now
	end
	wasFlying = flying
	ReplayTape.record(tape, now, hull.CFrame, R)
	local window = pending
	if window and now >= window.to then
		cut()
	end
end

-- Notes that a run just ended; its clip is cut once the tail is recorded.
-- A run shorter than MinAirtime keeps the last clip instead.
function ReplayRecorder.finish()
	local now = os.clock()
	local start = if wasFlying then liftoffAt else now
	if not ReplayTape.keeps(start, now, R) then
		return
	end
	local from, to = ReplayTape.window(start, now, R)
	pending = { from = from, to = to }
end

-- The last run's replay, nil until a run has ended and its clip was cut.
function ReplayRecorder.last(): Replay?
	return last
end

return ReplayRecorder
