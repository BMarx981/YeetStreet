--!strict
-- ReplayWorld (ModuleScript) -> StarterPlayerScripts.ReplayWorld
-- The moment the world is drawn at: while a replay plays (ReplayPlayer), the
-- moment of the replay being watched, otherwise now.
--
-- Scripts that draw things moving on the server's clock ask it the time
-- (serverTime), so in a replay they are where they were then: the trains
-- (TrainSet), wrecking balls (WreckingBallLook), walkers (PedestrianLook),
-- the gravitron's stripes (GravitronLook), and the brontosaurus's tail
-- (DinoTail). Anything that pushes the real car, like TrainSet.push and
-- WreckingBalls.push in CarController, keeps to the real time.
--
-- Things the server moves, like the creatures, are recorded instead. A
-- script that draws one follows what it reads: the invisible parts the
-- server moves, the models whose attributes say what the creature is doing,
-- and ObjectValues like a raptor's Target. While driving, ReplayRecorder has
-- the parts' CFrames recorded each physics step alongside the car (record),
-- attribute and value changes are noted as they happen, and each replay
-- carries the stretch of all that its clip covers (cut). During a replay,
-- cframe, attribute and value read what was recorded at the moment being
-- watched, and what is live otherwise or when nothing was recorded. A look
-- also asks for the replay's time (time), so its own swaying and chomping
-- pause and slow with it; when something last changed (lastChange), to time
-- a jaw or a beam; the changes the replay went past since the frame before
-- (passed), to play sounds; and where the ghost car is (car), for a car the
-- server's creatures held by its name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplayLog = require(ReplicatedStorage.ReplayLog)
local ReplayTape = require(ReplicatedStorage.ReplayTape)
local Tuning = require(ReplicatedStorage.Tuning)

local R = Tuning.Replay

-- An ObjectValue's Value, noted like an attribute. Attribute names never
-- hold an @.
local VALUE_KEY = "@Value"
local TRIM_EVERY = 1 -- seconds between forgetting changes older than MaxLength

local ReplayWorld = {}

-- What a replay recorded of the world, with times counted like its clip's.
export type World = {
	zero: number, -- the recorder's time at the clip's start
	poses: { [BasePart]: ReplayTape.Clip<CFrame> },
	logs: { [Instance]: ReplayLog.Log },
}

local tapes: { [BasePart]: ReplayTape.Tape<CFrame> } = {}
local logs: { [Instance]: ReplayLog.Log } = {}
local trimmed = 0

-- The moment of a replay being watched.
export type Moment = {
	world: World,
	time: number, -- the replay's time, counted from the start of its clip
	serverTime: number, -- the server's time then
	car: string, -- the name the replayed car had
	carPose: CFrame, -- where the ghost car is
}

local moment: Moment? = nil
local previous = 0 -- the replay's time the frame before

local function note(log: ReplayLog.Log, key: string, value: any)
	local now = os.clock()
	ReplayLog.note(log, now, key, value)
	if now - trimmed >= TRIM_EVERY then
		trimmed = now
		for _, each in logs do
			ReplayLog.trim(each, now - R.MaxLength)
		end
	end
end

-- Records `instance` from now on: its attributes, its CFrame if it is a
-- part, and its Value if it is an ObjectValue.
function ReplayWorld.follow(instance: Instance)
	if logs[instance] then
		return
	end
	local log = ReplayLog.new()
	logs[instance] = log
	for key, value in instance:GetAttributes() do
		note(log, key, value)
	end
	instance.AttributeChanged:Connect(function(key: string)
		note(log, key, instance:GetAttribute(key))
	end)
	if instance:IsA("ObjectValue") then
		note(log, VALUE_KEY, instance.Value)
		instance:GetPropertyChangedSignal("Value"):Connect(function()
			note(log, VALUE_KEY, instance.Value)
		end)
	end
	if instance:IsA("BasePart") then
		tapes[instance] = ReplayTape.new()
	end
	instance.Destroying:Connect(function()
		logs[instance] = nil
		if instance:IsA("BasePart") then
			tapes[instance] = nil
		end
	end)
end

-- Records where the followed parts are at recorder time `t`.
function ReplayWorld.record(t: number)
	for part, tape in tapes do
		if part:IsDescendantOf(workspace) then
			ReplayTape.record(tape, t, part.CFrame, R)
		end
	end
end

-- What was recorded from `from` to `to`, with times counted from `zero`,
-- the recorder's time at the start of the car's clip.
function ReplayWorld.cut(from: number, to: number, zero: number): World
	local cut: World = { zero = zero, poses = {}, logs = {} }
	for part, tape in tapes do
		local clip = ReplayTape.cut(tape, from, to)
		if clip then
			cut.poses[part] = clip
		end
	end
	for instance, log in logs do
		cut.logs[instance] = ReplayLog.cut(log, from, to, zero)
	end
	return cut
end

-- Draws the world at `now`, a moment of a replay, each frame it plays
-- (ReplayPlayer); nil draws it as it is now again.
function ReplayWorld.watch(now: Moment?)
	local last = moment
	previous = if last and now and last.world == now.world then last.time else if now then now.time else 0
	moment = if now then table.clone(now) else nil
end

-- Whether the world is drawn at a replay's moment rather than now.
function ReplayWorld.isWatching(): boolean
	return moment ~= nil
end

-- The server time to draw the world at.
function ReplayWorld.serverTime(): number
	local now = moment
	return if now then now.serverTime else workspace:GetServerTimeNow()
end

-- The replay's time while one plays, counted from the start of its clip, so
-- things drawn in it pause and slow down with it; os.clock otherwise.
function ReplayWorld.time(): number
	local now = moment
	return if now then now.time else os.clock()
end

-- Where the ghost car is, if the replayed car was named `name`; nil when
-- no replay plays.
function ReplayWorld.car(name: string): CFrame?
	local now = moment
	return if now and now.car == name then now.carPose else nil
end

-- Where `part` is in the world being drawn.
function ReplayWorld.cframe(part: BasePart): CFrame
	local now = moment
	local clip = if now then now.world.poses[part] else nil
	if now and clip then
		local a, b, alpha = ReplayTape.sample(clip, now.time + now.world.zero - clip.start)
		return a:Lerp(b, alpha)
	end
	return part.CFrame
end

local function logOf(instance: Instance): ReplayLog.Log?
	local now = moment
	return if now then now.world.logs[instance] else nil
end

-- The attribute `key` of `instance` in the world being drawn.
function ReplayWorld.attribute(instance: Instance, key: string): any
	local log = logOf(instance)
	if log then
		return ReplayLog.at(log, key, ReplayWorld.time())
	end
	return instance:GetAttribute(key)
end

-- The Value of `object` in the world being drawn.
function ReplayWorld.value(object: ObjectValue): Instance?
	local log = logOf(object)
	if log then
		return ReplayLog.at(log, VALUE_KEY, ReplayWorld.time())
	end
	return object.Value
end

-- While a replay plays, the last recorded change to attribute `key` of
-- `instance` by the moment being watched (in the replay's time), and the
-- value before it, nil for the value the clip started with.
function ReplayWorld.lastChange(instance: Instance, key: string): (ReplayLog.Change?, any)
	local log = logOf(instance)
	if not log then
		return nil, nil
	end
	return ReplayLog.last(log, key, ReplayWorld.time())
end

-- While a replay plays, the recorded changes to attribute `key` of
-- `instance` the replay went past since the frame before, going forward.
function ReplayWorld.passed(instance: Instance, key: string): { ReplayLog.Change }
	local log = logOf(instance)
	if not log then
		return {}
	end
	return ReplayLog.passed(log, key, previous, ReplayWorld.time())
end

return ReplayWorld
