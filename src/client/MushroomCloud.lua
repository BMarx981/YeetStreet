--!strict
-- MushroomCloud (ModuleScript) -> StarterPlayerScripts.MushroomCloud
-- Draws a nuke-style blast on the ground at `at`: a flash, a shock ring, a
-- shake for anyone near, and a mushroom cloud (MissileCloud) that climbs out
-- of the fireball, cools to smoke, stands, and fades. It is all this client's
-- own parts, and none of them touch anything. The silo missile's is full
-- size (SiloBlast, Tuning.Silo.Blast) and a TNT barrel's is small (TntBoom,
-- Tuning.Scrapyard.Tnt.Cloud); each plays its own boom.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MissileCloud = require(ReplicatedStorage.MissileCloud)
local Rng = require(ReplicatedStorage.Rng)

local MushroomCloud = {}

export type Config = MissileCloud.Config & {
	Radius: number, -- how far the flash swells
	Fire: Color3,
	Smoke: Color3,
	Cool: number, -- seconds from fire to smoke
	Hold: number, -- seconds it stands before it starts to fade
	Fade: number,
	FlashTime: number,
	Ring: number, -- seconds for the shock ring to spread to Radius times RingReach
	RingReach: number,
	ShakeReach: number, -- studs away that the camera stops shaking
	ShakeMax: number, -- studs, at the blast itself
	ShakeTime: number,
}

local WHITE = Color3.fromRGB(255, 245, 210)

local shakes = 0 -- for a name each shake can be unbound by

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

local function flash(c: Config, parent: Instance, at: Vector3)
	local ball = ghost(parent, Enum.PartType.Ball, Vector3.one * 10, CFrame.new(at), WHITE)
	tween(ball, c.FlashTime, Enum.EasingStyle.Quad, {
		Size = Vector3.one * c.Radius * 2,
		Transparency = 1,
	})
	-- A cylinder lying flat, its axis up.
	local ring = ghost(
		parent,
		Enum.PartType.Cylinder,
		Vector3.new(1, 10, 10),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		c.Fire
	)
	tween(ring, c.Ring, Enum.EasingStyle.Quad, {
		Size = Vector3.new(1, 2 * c.Radius * c.RingReach, 2 * c.Radius * c.RingReach),
		Transparency = 1,
	})
end

local function puff(c: Config, parent: Instance, at: Vector3, spec: MissileCloud.Puff)
	local start = at + Vector3.new(0, spec.radius * 0.5, 0)
	local part = ghost(parent, Enum.PartType.Ball, Vector3.one * 2, CFrame.new(start), c.Fire)
	task.delay(spec.delay, function()
		tween(part, c.Rise - spec.delay * 0.5, Enum.EasingStyle.Quad, {
			CFrame = CFrame.new(at + Vector3.new(spec.x, spec.y, spec.z)),
			Size = Vector3.one * 2 * spec.radius,
		})
		tween(part, c.Cool, Enum.EasingStyle.Sine, { Color = c.Smoke })
		task.delay(c.Hold, function()
			tween(part, c.Fade, Enum.EasingStyle.Sine, { Transparency = 1 })
		end)
	end)
end

local function shake(c: Config, at: Vector3)
	local camera = workspace.CurrentCamera
	local strength = c.ShakeMax * (1 - (camera.CFrame.Position - at).Magnitude / c.ShakeReach)
	if strength <= 0 then
		return
	end
	local started = os.clock()
	shakes += 1
	local name = `BlastShake{shakes}`
	-- After every camera script has set the camera for this frame.
	RunService:BindToRenderStep(name, Enum.RenderPriority.Last.Value + 10, function()
		local left = 1 - (os.clock() - started) / c.ShakeTime
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

function MushroomCloud.play(c: Config, at: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "MushroomCloud"
	folder.Parent = workspace
	flash(c, folder, at)
	shake(c, at)
	-- From the spot, so every client draws the same cloud.
	local rng = Rng.new(math.floor(at.X * 7 + at.Z * 13))
	for _, spec in MissileCloud.puffs(c, rng) do
		puff(c, folder, at, spec)
	end
	Debris:AddItem(folder, c.Rise + c.Hold + c.Fade + 2)
end

return MushroomCloud
