--!strict
-- ReplayPlayer (ModuleScript) -> StarterPlayerScripts.ReplayPlayer
-- Plays a replay from ReplayRecorder: a ghost of the car moves along the
-- clip. The ghost is built from the replay's look attributes the way
-- CarPreview builds a car, with stand-in wheels, and leaves off the parts
-- broken before the clip. It is only on this client and out of physics: its
-- parts are anchored, with no collisions, touches, or queries, and each frame
-- puts every part where the clip says.
--
-- Parts that broke off during the clip (its marks) come off the ghost at the
-- same time, in CarDesign.breakable order, and fly off along a path
-- (ReplayDebris) that follows the replay's clock, so they pause, slow down,
-- and scrub with the car. Scrubbing back to before a break puts the part
-- back on. Like real broken parts, they are gone after PartLifetime.
--
-- While it plays, the real car and its driver are hidden on this screen,
-- Controls gives the car no input, and CarController leaves the camera and
-- HUD alone. The camera starts on the ghost from the side, a little behind
-- the way the run went (Tuning.Replay), and the player can circle it from
-- there (ReplayCamera). The last frame holds for EndHold, then the replay
-- closes, unless it is paused. ReplayControls pauses, seeks, and changes the
-- speed on its clock (ReplayClock).
--
-- While it plays, the world is drawn at the replay's moment (ReplayWorld):
-- things on the server's clock, like the trains, and recorded creatures.
--
-- With streaming on, this client only has the map near the real car, so as
-- a replay starts it asks for the map along the ghost's path, every
-- StreamSpacing studs. That map streams out again while the real car is far
-- away, so every StreamRefresh seconds it asks again round the ghost and
-- where it will be StreamAhead seconds on.
--
-- HeliCar and PlaneCar replay with their generated look, so their ghosts
-- break apart though the real ones don't yet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarDesign = require(ReplicatedStorage.CarDesign)
local CarParts = require(ReplicatedStorage.CarParts)
local ReplayClock = require(ReplicatedStorage.ReplayClock)
local ReplayOrbit = require(ReplicatedStorage.ReplayOrbit)
local ReplayTape = require(ReplicatedStorage.ReplayTape)
local Tuning = require(ReplicatedStorage.Tuning)
local CarPreview = require(script.Parent.CarPreview)
local ReplayCamera = require(script.Parent.ReplayCamera)
local ReplayDebris = require(script.Parent.ReplayDebris)
local ReplayRecorder = require(script.Parent.ReplayRecorder)
local ReplayWorld = require(script.Parent.ReplayWorld)

local R = Tuning.Replay
local T = Tuning.Toughness

local RENDER_NAME = "YeetStreetReplay"

local ReplayPlayer = {}

-- One part of the ghost.
type Piece = {
	part: BasePart,
	offset: CFrame, -- from the car's pose
	breakAt: number?, -- clip time it breaks off, nil if it stays on
	path: { CFrame }?, -- where it flies once broken, worked out when first needed
}

type Playing = {
	replay: ReplayRecorder.Replay,
	ghost: Model,
	pieces: { Piece },
	parts: { BasePart }, -- the pieces' parts, for BulkMoveTo
	cframes: { CFrame }, -- reused each frame
	random: Random,
	streamed: number, -- os.clock when the map round the ghost was last asked for
	hidden: { BasePart },
	clock: ReplayClock.Clock,
}

local playing: Playing? = nil

local function noPhysics(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
end

-- The ghost car for `replay` and its pieces, built at the origin, or nil if
-- the look is incomplete.
local function buildGhost(replay: ReplayRecorder.Replay): (Model?, { Piece })
	local look = replay.look
	local ghost = Instance.new("Model")
	ghost.Name = "ReplayGhost"
	for key, value in look do
		ghost:SetAttribute(key, value)
	end
	local design = CarParts.designFor(ghost)
	if not design then
		ghost:Destroy()
		return nil, {}
	end

	local parts = CarParts.build(design, CFrame.new(), ghost)
	local breaks = ReplayTape.breaks(replay.clip)
	local breakAt: { [BasePart]: number } = {}
	for _, slot in CarParts.Slots do
		local value = look[CarParts.brokenAttribute(slot)]
		local before = if typeof(value) == "number" then value else 0
		local times = breaks[slot] or {}
		for k, index in CarDesign.breakable(design, slot) do
			if k <= before then
				parts[index]:Destroy()
			else
				breakAt[parts[index]] = times[k - before]
			end
		end
	end
	CarPreview.wheels(design, ghost)
	local pieces: { Piece } = {}
	for _, part in ghost:GetDescendants() do
		if part:IsA("BasePart") then
			noPhysics(part)
			part.Anchored = true
			table.insert(pieces, { part = part, offset = part.CFrame, breakAt = breakAt[part] })
		end
	end
	return ghost, pieces
end

local function poseAt(clip: ReplayTape.Clip<CFrame>, t: number): CFrame
	local a, b, alpha = ReplayTape.sample(clip, t)
	return a:Lerp(b, alpha)
end

-- Works out where `piece` flies after it breaks off: thrown with the car's
-- speed then, plus BreakPop away from the car's middle, like a real one.
local function flyOff(now: Playing, piece: Piece, at: number): { CFrame }
	local clip = now.replay.clip
	local pose = poseAt(clip, at)
	local start = pose * piece.offset
	local d = R.DebrisStep
	local velocity = (poseAt(clip, at + d).Position - poseAt(clip, at - d).Position) / (2 * d)
	local away = start.Position - pose.Position
	local pop = if away.Magnitude > 1e-3 then away.Unit * T.BreakPop else Vector3.zero
	local spin = now.random:NextUnitVector() * R.DebrisSpin
	local path = ReplayDebris.path(start, velocity + pop, piece.part.Size, spin, { now.ghost })
	piece.path = path
	return path
end

-- Where the camera starts: side on to the way the run went, turned
-- CameraAngle toward behind it.
local function startOrbit(clip: ReplayTape.Clip<CFrame>): ReplayOrbit.Orbit
	local first = clip.frames[1].pose
	local last = clip.frames[#clip.frames].pose
	local travel = (last.Position - first.Position) * Vector3.new(1, 0, 1)
	if travel.Magnitude < 1e-3 then
		travel = first.LookVector * Vector3.new(1, 0, 1)
	end
	if travel.Magnitude < 1e-3 then
		travel = -Vector3.zAxis
	end
	travel = travel.Unit
	local side = travel:Cross(Vector3.yAxis)
	local angle = math.rad(R.CameraAngle)
	local flat = side * math.cos(angle) - travel * math.sin(angle)
	return ReplayOrbit.new(ReplayOrbit.facing(flat.X, flat.Z), math.rad(R.CameraPitch), R.CameraDistance, R)
end

local function streamAround(at: Vector3)
	local player = Players.LocalPlayer
	task.spawn(function()
		local ok, err = pcall(player.RequestStreamAroundAsync, player, at)
		if not ok then
			warn(`ReplayPlayer: could not stream the map around {at}: {err}`)
		end
	end)
end

local function streamAlong(clip: ReplayTape.Clip<CFrame>)
	if not workspace.StreamingEnabled then
		return
	end
	local points: { Vector3 } = {}
	local last: Vector3? = nil
	for _, frame in clip.frames do
		local at = frame.pose.Position
		if not last or (at - last).Magnitude >= R.StreamSpacing then
			table.insert(points, at)
			last = at
		end
	end
	table.insert(points, clip.frames[#clip.frames].pose.Position)
	for _, at in points do
		streamAround(at)
	end
end

local function show(now: Playing, dt: number)
	local time = now.clock.time
	local pose = poseAt(now.replay.clip, time)
	ReplayWorld.watch({
		world = now.replay.world,
		time = time,
		serverTime = now.replay.serverStart + time,
		car = now.replay.car,
		carPose = pose,
	})
	for i, piece in now.pieces do
		local breakAt = piece.breakAt
		if breakAt and time >= breakAt then
			now.cframes[i] = ReplayDebris.at(piece.path or flyOff(now, piece, breakAt), time - breakAt)
			piece.part.LocalTransparencyModifier = if time - breakAt > T.PartLifetime then 1 else 0
		else
			now.cframes[i] = pose * piece.offset
			piece.part.LocalTransparencyModifier = 0
		end
	end
	workspace:BulkMoveTo(now.parts, now.cframes, Enum.BulkMoveMode.FireCFrameChanged)
	ReplayCamera.update(pose.Position, dt)
	if workspace.StreamingEnabled and os.clock() - now.streamed >= R.StreamRefresh then
		now.streamed = os.clock()
		streamAround(pose.Position)
		streamAround(poseAt(now.replay.clip, time + R.StreamAhead).Position)
	end
end

-- Whether a replay is playing.
function ReplayPlayer.isPlaying(): boolean
	return playing ~= nil
end

-- The playing replay's clock, to pause, seek, or change speed; nil if none.
function ReplayPlayer.clock(): ReplayClock.Clock?
	local now = playing
	return if now then now.clock else nil
end

-- Stops the replay, if one is playing, and shows the real car again.
function ReplayPlayer.stop()
	local now = playing
	if not now then
		return
	end
	playing = nil
	RunService:UnbindFromRenderStep(RENDER_NAME)
	ReplayWorld.watch(nil)
	ReplayCamera.stop()
	now.ghost:Destroy()
	for _, part in now.hidden do
		part.LocalTransparencyModifier = 0
	end
end

-- Plays `replay`, hiding `car` and `character` while it does.
function ReplayPlayer.play(replay: ReplayRecorder.Replay, car: Model?, character: Model?)
	ReplayPlayer.stop()
	local ghost, pieces = buildGhost(replay)
	if not ghost then
		warn("ReplayPlayer: the replay's car has no look attributes; nothing to play")
		return
	end
	local hidden: { BasePart } = {}
	for _, model in { car, character } do
		if model then
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 1
					table.insert(hidden, part)
				end
			end
		end
	end
	local parts: { BasePart } = {}
	for i, piece in pieces do
		parts[i] = piece.part
	end
	local now: Playing = {
		replay = replay,
		ghost = ghost,
		pieces = pieces,
		parts = parts,
		cframes = table.create(#pieces),
		random = Random.new(),
		streamed = os.clock(),
		hidden = hidden,
		clock = ReplayClock.new(replay.clip.duration),
	}
	playing = now
	streamAlong(replay.clip)
	ReplayCamera.start(startOrbit(replay.clip))
	ghost.Parent = workspace
	show(now, 0)
	workspace.CurrentCamera.FieldOfView = Tuning.Camera.Fov
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		ReplayClock.advance(now.clock, dt)
		if ReplayClock.done(now.clock, R.EndHold) then
			ReplayPlayer.stop()
			return
		end
		show(now, dt)
	end)
end

return ReplayPlayer
