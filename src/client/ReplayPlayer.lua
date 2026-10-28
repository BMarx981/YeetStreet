--!strict
-- ReplayPlayer (ModuleScript) -> StarterPlayerScripts.ReplayPlayer
-- Plays a replay from ReplayRecorder: a ghost of the car moves along the
-- clip. The ghost is built from the replay's look attributes the way
-- CarPreview builds a car, with stand-in wheels, and leaves off the parts
-- broken before the clip. It is only on this client and out of physics: its
-- parts are welded to one anchored root, with no collisions, touches, or
-- queries, so moving the root moves the whole ghost.
--
-- While it plays, the real car and its driver are hidden on this screen,
-- Controls gives the car no input, and CarController leaves the camera and
-- HUD alone. The camera starts on the ghost from the side, a little behind
-- the way the run went (Tuning.Replay), and the player can circle it from
-- there (ReplayCamera). The last frame holds for EndHold, then the replay
-- closes.
--
-- With streaming on, this client only has the map near the real car, so as
-- a replay starts it asks for the map along the ghost's path, every
-- StreamSpacing studs.
--
-- HeliCar and PlaneCar replay with their generated look.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarDesign = require(ReplicatedStorage.CarDesign)
local CarParts = require(ReplicatedStorage.CarParts)
local ReplayOrbit = require(ReplicatedStorage.ReplayOrbit)
local ReplayTape = require(ReplicatedStorage.ReplayTape)
local Tuning = require(ReplicatedStorage.Tuning)
local CarPreview = require(script.Parent.CarPreview)
local ReplayCamera = require(script.Parent.ReplayCamera)
local ReplayRecorder = require(script.Parent.ReplayRecorder)

local R = Tuning.Replay

local RENDER_NAME = "YeetStreetReplay"

local ReplayPlayer = {}

type Playing = {
	replay: ReplayRecorder.Replay,
	ghost: Model,
	root: BasePart,
	hidden: { BasePart },
	time: number,
}

local playing: Playing? = nil

local function noPhysics(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
end

-- The ghost car for `look`, at the origin, or nil if the look is incomplete.
local function buildGhost(look: { [string]: any }): (Model?, BasePart?)
	local ghost = Instance.new("Model")
	ghost.Name = "ReplayGhost"
	for key, value in look do
		ghost:SetAttribute(key, value)
	end
	local design = CarParts.designFor(ghost)
	if not design then
		ghost:Destroy()
		return nil, nil
	end
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one
	root.Transparency = 1
	root.Anchored = true
	noPhysics(root)
	root.Parent = ghost
	ghost.PrimaryPart = root

	local parts = CarParts.build(design, CFrame.new(), ghost)
	for _, slot in CarParts.Slots do
		local value = look[CarParts.brokenAttribute(slot)]
		local order = CarDesign.breakable(design, slot)
		for k = 1, math.min(if typeof(value) == "number" then value else 0, #order) do
			parts[order[k]]:Destroy()
		end
	end
	CarPreview.wheels(design, ghost)
	for _, part in ghost:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			noPhysics(part)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
			part.Anchored = false
		end
	end
	return ghost, root
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
	local player = Players.LocalPlayer
	for _, at in points do
		task.spawn(function()
			local ok, err = pcall(player.RequestStreamAroundAsync, player, at)
			if not ok then
				warn(`ReplayPlayer: could not stream the map around {at}: {err}`)
			end
		end)
	end
end

local function show(now: Playing, dt: number)
	local a, b, alpha = ReplayTape.sample(now.replay.clip, now.time)
	now.root.CFrame = a:Lerp(b, alpha)
	ReplayCamera.update(now.root.Position, dt)
end

-- Whether a replay is playing.
function ReplayPlayer.isPlaying(): boolean
	return playing ~= nil
end

-- Stops the replay, if one is playing, and shows the real car again.
function ReplayPlayer.stop()
	local now = playing
	if not now then
		return
	end
	playing = nil
	RunService:UnbindFromRenderStep(RENDER_NAME)
	ReplayCamera.stop()
	now.ghost:Destroy()
	for _, part in now.hidden do
		part.LocalTransparencyModifier = 0
	end
end

-- Plays `replay`, hiding `car` and `character` while it does.
function ReplayPlayer.play(replay: ReplayRecorder.Replay, car: Model?, character: Model?)
	ReplayPlayer.stop()
	local ghost, root = buildGhost(replay.look)
	if not (ghost and root) then
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
	local now: Playing = {
		replay = replay,
		ghost = ghost,
		root = root,
		hidden = hidden,
		time = 0,
	}
	playing = now
	streamAlong(replay.clip)
	ReplayCamera.start(startOrbit(replay.clip))
	-- In the workspace before it moves: welds keep the offsets their parts
	-- have when they get there.
	ghost.Parent = workspace
	show(now, 0)
	workspace.CurrentCamera.FieldOfView = Tuning.Camera.Fov
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		now.time += dt
		if now.time > replay.clip.duration + R.EndHold then
			ReplayPlayer.stop()
			return
		end
		show(now, dt)
	end)
end

return ReplayPlayer
