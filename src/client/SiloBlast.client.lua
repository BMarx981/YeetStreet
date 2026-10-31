--!strict
-- SiloBlast (LocalScript) -> StarterPlayerScripts.SiloBlast
-- Draws a silo missile's blast where the server says it hit, on
-- ReplicatedStorage.MissileBlast: a flash, a shock ring, a boom, a shake for
-- anyone near, and a mushroom cloud (MissileCloud) that climbs out of the
-- fireball, cools to smoke, stands, and fades. It is all this client's own
-- parts, and none of them touch anything.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MissileCloud = require(ReplicatedStorage.MissileCloud)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)

local B = Tuning.Silo.Blast
local CONFIG: MissileCloud.Config = B :: any

local WHITE = Color3.fromRGB(255, 245, 210)

local function ghost(parent: Instance, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = "Blast"
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Parent = parent
	return part
end

local function tween(part: Instance, seconds: number, style: Enum.EasingStyle, goal: { [string]: any }): Tween
	local made = TweenService:Create(part, TweenInfo.new(seconds, style, Enum.EasingDirection.Out), goal)
	made:Play()
	return made
end

local function flash(parent: Instance, at: Vector3)
	local ball = ghost(parent, Enum.PartType.Ball, Vector3.one * 10, CFrame.new(at), WHITE)
	tween(ball, B.FlashTime, Enum.EasingStyle.Quad, {
		Size = Vector3.one * B.Radius * 2,
		Transparency = 1,
	})
	-- A cylinder lying flat, its axis up.
	local ring = ghost(
		parent,
		Enum.PartType.Cylinder,
		Vector3.new(1, 10, 10),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		B.Fire
	)
	tween(ring, B.Ring, Enum.EasingStyle.Quad, {
		Size = Vector3.new(1, 2 * B.Radius * B.RingReach, 2 * B.Radius * B.RingReach),
		Transparency = 1,
	})
end

local function puff(parent: Instance, at: Vector3, spec: MissileCloud.Puff)
	local start = at + Vector3.new(0, spec.radius * 0.5, 0)
	local part = ghost(parent, Enum.PartType.Ball, Vector3.one * 2, CFrame.new(start), B.Fire)
	task.delay(spec.delay, function()
		tween(part, B.Rise - spec.delay * 0.5, Enum.EasingStyle.Quad, {
			CFrame = CFrame.new(at + Vector3.new(spec.x, spec.y, spec.z)),
			Size = Vector3.one * 2 * spec.radius,
		})
		tween(part, B.Cool, Enum.EasingStyle.Sine, { Color = B.Smoke })
		task.delay(B.Cool, function()
			part.Material = Enum.Material.SmoothPlastic
		end)
		task.delay(B.Hold, function()
			tween(part, B.Fade, Enum.EasingStyle.Sine, { Transparency = 1 })
		end)
	end)
end

local function boom(parent: Instance, at: Vector3)
	local speaker = ghost(parent, Enum.PartType.Block, Vector3.one, CFrame.new(at), WHITE)
	speaker.Transparency = 1
	local sound = Instance.new("Sound")
	sound.SoundId = B.BoomId
	sound.Volume = B.BoomVolume
	sound.RollOffMaxDistance = B.BoomReach
	sound.Parent = speaker
	sound:Play()
end

local function shake(at: Vector3)
	local camera = workspace.CurrentCamera
	local strength = B.ShakeMax * (1 - (camera.CFrame.Position - at).Magnitude / B.ShakeReach)
	if strength <= 0 then
		return
	end
	local started = os.clock()
	local name = `SiloShake{started}`
	-- After every camera script has set the camera for this frame.
	RunService:BindToRenderStep(name, Enum.RenderPriority.Last.Value + 10, function()
		local left = 1 - (os.clock() - started) / B.ShakeTime
		if left <= 0 then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local size = strength * left
		camera.CFrame *= CFrame.new(
			(math.random() - 0.5) * size,
			(math.random() - 0.5) * size,
			(math.random() - 0.5) * size
		)
	end)
end

local remote = ReplicatedStorage:WaitForChild("MissileBlast") :: RemoteEvent
remote.OnClientEvent:Connect(function(at: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "MissileBlast"
	folder.Parent = workspace
	flash(folder, at)
	boom(folder, at)
	shake(at)
	-- From the spot, so every client draws the same cloud.
	local rng = Rng.new(math.floor(at.X * 7 + at.Z * 13))
	for _, spec in MissileCloud.puffs(CONFIG, rng) do
		puff(folder, at, spec)
	end
	Debris:AddItem(folder, B.Rise + B.Hold + B.Fade + 2)
end)
