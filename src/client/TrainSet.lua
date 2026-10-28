--!strict
-- TrainSet (ModuleScript) -> StarterPlayerScripts.TrainSet
-- Builds this client's own trains for the city's train line (Railway) and
-- moves them every frame from the server's clock (Trains), so every player
-- sees them in the same place. The server has no trains. They never touch
-- anything: CarController asks TrainSet.push how a train pushes its car
-- instead. During a replay they are drawn where they were at the moment
-- being watched (ReplayWorld), but still push from where they are now.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Trains = require(ReplicatedStorage.Trains)
local Tuning = require(ReplicatedStorage.Tuning)
local ReplayWorld = require(script.Parent.ReplayWorld)

local TrainSet = {}

local T = Tuning.City.Railway.Trains

local BODY_COLOR = Color3.fromRGB(200, 204, 210)
local STRIPE_COLOR = Color3.fromRGB(220, 60, 50)
local WINDOW_COLOR = Color3.fromRGB(30, 36, 44)
local LAMP_COLOR = Color3.fromRGB(255, 240, 200)

local area = MapLayout.find(Tuning.Map.Areas :: any, "City")

-- Each carriage's model, and where they all are now, which may not be
-- where they are drawn.
local carriages: { Model } = {}
local frames: { CFrame } = {}

local function part(parent: Instance, name: string, size: Vector3, offset: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- One carriage around the origin, facing -Z: a body with a stripe and a
-- band of windows down each side, and lamps on the front of a train's
-- first carriage.
local function build(parent: Instance, first: boolean): Model
	local model = Instance.new("Model")
	model.Name = "Carriage"
	local body = part(model, "Body", Vector3.new(T.Width, T.Height, T.Length), CFrame.identity, BODY_COLOR)
	model.PrimaryPart = body
	for _, side in { -1, 1 } do
		local x = side * (T.Width / 2 + 0.05)
		part(model, "Stripe", Vector3.new(0.2, 1.5, T.Length), CFrame.new(x, -T.Height / 4, 0), STRIPE_COLOR)
		part(
			model,
			"Windows",
			Vector3.new(0.2, T.Height / 3, T.Length - 6),
			CFrame.new(x, T.Height / 6, 0),
			WINDOW_COLOR
		)
	end
	if first then
		for _, side in { -1, 1 } do
			local lamp = part(
				model,
				"Lamp",
				Vector3.new(2, 2, 0.4),
				CFrame.new(side * (T.Width / 2 - 3), -T.Height / 4, -T.Length / 2 - 0.2),
				LAMP_COLOR
			)
			lamp.Material = Enum.Material.Neon
		end
	end
	model.Parent = parent
	return model
end

local function place()
	frames = Trains.frames(workspace:GetServerTimeNow())
	for i, frame in if ReplayWorld.isWatching() then Trains.frames(ReplayWorld.serverTime()) else frames do
		carriages[i]:PivotTo(frame)
	end
end

-- The velocity a train's nose gives a car whose hull is `hull`, or nil when
-- no train's nose is touching it (Trains.push).
function TrainSet.push(hull: BasePart): Vector3?
	return Trains.push(frames, hull.Position, hull.AssemblyLinearVelocity)
end

function TrainSet.start()
	if not area then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Trains"
	for i = 1, T.Count * T.Carriages do
		carriages[i] = build(folder, Trains.isNose(i))
	end
	folder.Parent = workspace
	place()
	RunService.RenderStepped:Connect(place)
end

return TrainSet
