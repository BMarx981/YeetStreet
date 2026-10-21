--!strict
-- TrainSet (ModuleScript) -> StarterPlayerScripts.TrainSet
-- Builds this client's own trains for the city's train line (Railway) and
-- moves them every frame from the server's clock, so every player sees them
-- in the same place. The server has no trains. They never touch anything:
-- CarController asks TrainSet.push how a train pushes its car instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Railway = require(ReplicatedStorage.Railway)
local Tuning = require(ReplicatedStorage.Tuning)
local Tunnel = require(ReplicatedStorage.Tunnel)

local TrainSet = {}

local R = Tuning.City.Railway
local T = R.Trains
local FLOOR = Tuning.Map.FloorTop

local BODY_COLOR = Color3.fromRGB(200, 204, 210)
local STRIPE_COLOR = Color3.fromRGB(220, 60, 50)
local WINDOW_COLOR = Color3.fromRGB(30, 36, 44)
local LAMP_COLOR = Color3.fromRGB(255, 240, 200)

local area = MapLayout.find(Tuning.Map.Areas :: any, "City")
local line: Railway.Line = R :: any
local start = Railway.start(line)
local pieces = Tunnel.path(start.x, start.z, start.headingX, start.headingZ, Railway.segments(line) :: any, start.y)
local lengths: { number } = {}
local total = 0
for _, piece in pieces do
	local length = Tunnel.length(piece)
	table.insert(lengths, length)
	total += length
end

-- Each carriage's model, and where it was put last.
local carriages: { Model } = {}
local frames: { CFrame } = {}

-- The middle of the deck's top `distance` round the loop.
local function pointOn(distance: number): Vector3
	local index, t = Railway.locate(lengths, distance)
	local x, y, z = Tunnel.pointAt(pieces[index], t)
	local a = area :: MapLayout.Area
	return Vector3.new(a.X + x, FLOOR + y, a.Z + z)
end

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

local function place(time: number)
	for i, span in Railway.carriages(total, time, T) do
		local front, back = pointOn(span.front), pointOn(span.back)
		local middle = (front + back) / 2
		local frame = CFrame.lookAt(middle, front, Vector3.yAxis) * CFrame.new(0, T.Height / 2 + 0.5, 0)
		frames[i] = frame
		carriages[i]:PivotTo(frame)
	end
end

-- The velocity a train gives a car whose hull is `hull`, or nil when no
-- train is touching it (Railway.push).
function TrainSet.push(hull: BasePart): Vector3?
	local velocity = hull.AssemblyLinearVelocity
	for _, frame in frames do
		local p = frame:PointToObjectSpace(hull.Position)
		local v = frame:VectorToObjectSpace(velocity)
		local va, vc, vu =
			Railway.push(-p.Z, p.X, p.Y, -v.Z, v.X, v.Y, T.Length / 2, T.Width / 2, T.Height / 2, T.Speed, R.Push)
		if va and vc and vu then
			return frame:VectorToWorldSpace(Vector3.new(vc, vu, -va))
		end
	end
	return nil
end

function TrainSet.start()
	if not area then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Trains"
	for i = 1, T.Count * T.Carriages do
		carriages[i] = build(folder, (i - 1) % T.Carriages == 0)
	end
	folder.Parent = workspace
	place(workspace:GetServerTimeNow())
	RunService.RenderStepped:Connect(function()
		place(workspace:GetServerTimeNow())
	end)
end

return TrainSet
