--!strict
-- DinoRex (ModuleScript) -> ServerScriptService.Parks.DinoRex
-- Runs Dino Valley's T-Rex on the server, which owns where it is and every
-- catch. Each Heartbeat it steps the brain (Rex) with every car in
-- workspace.Cars as the server sees them, and moves the T-Rex there, with
-- its Mode attribute set to the brain's mode.
--
-- For now the T-Rex is a stand-in of plain blocks moved by the server: a
-- body on two legs with a tail, and a head that rears back and snaps at
-- the spot it bites. A catch only prints to Output, and the T-Rex rests.
-- Numbers are in Tuning.Dino.Rex.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rex = require(ReplicatedStorage.Rex)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)

local R = Tuning.Dino.Rex

local SKIN_COLOR = Color3.fromRGB(110, 120, 72)
local HEAD_COLOR = Color3.fromRGB(92, 100, 60)

-- The stand-in's blocks, in the frame of its hips on the ground facing -Z.
local BLOCKS = {
	{ Name = "Body", Size = Vector3.new(34, 36, 80), At = CFrame.new(0, 70, 0) },
	{ Name = "LeftLeg", Size = Vector3.new(12, 52, 18), At = CFrame.new(-16, 26, 4) },
	{ Name = "RightLeg", Size = Vector3.new(12, 52, 18), At = CFrame.new(16, 26, 4) },
	{ Name = "Tail", Size = Vector3.new(16, 16, 80), At = CFrame.new(0, 66, 78) * CFrame.Angles(math.rad(8), 0, 0) },
}
local HEAD_SIZE = Vector3.new(22, 22, 40)
local HEAD_REST = Vector3.new(0, 88, -70)
-- Where the head pulls back to over the wind-up.
local HEAD_BACK = Vector3.new(0, 100, -50)
-- The head points away from here, so it looks along the neck.
local SHOULDERS = Vector3.new(0, 76, -30)
-- How quickly the head settles back after a lunge, per second.
local HEAD_SETTLE = 8

local DinoRex = {}

local function decoration(parent: Instance, name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function driverName(car: Model): string
	local userId = car:GetAttribute("OwnerUserId")
	local player = typeof(userId) == "number" and Players:GetPlayerByUserId(userId)
	return if player then player.Name else car.Name
end

-- Where the head goes this step: rearing back over the wind-up, snapping to
-- the bite over Snap, and easing back to rest otherwise.
local function headFrame(s: Rex.State, hips: CFrame, last: CFrame, dt: number): CFrame
	local rest = hips:PointToWorldSpace(HEAD_REST)
	local shoulders = hips:PointToWorldSpace(SHOULDERS)
	if s.mode ~= "lunge" then
		return last:Lerp(CFrame.lookAt(rest, rest + (rest - shoulders)), 1 - math.exp(-HEAD_SETTLE * dt))
	end
	local jaw = Vector3.new(s.jawX, s.jawY, s.jawZ)
	local back = hips:PointToWorldSpace(HEAD_BACK)
	local windUp = if s.air then R.AirWindUp else R.WindUp
	local at = if s.timer < windUp
		then rest:Lerp(back, s.timer / windUp)
		else back:Lerp(jaw, math.min((s.timer - windUp) / R.Snap, 1))
	return CFrame.lookAt(at, at + (jaw - shoulders))
end

-- Starts the T-Rex in `model`, at x, z facing `heading` (radians), roaming
-- `territory`.
function DinoRex.start(model: Model, territory: Rex.Territory, x: number, z: number, heading: number)
	local blocks: { [Part]: CFrame } = {}
	for _, b in BLOCKS do
		blocks[decoration(model, b.Name, b.Size, SKIN_COLOR)] = b.At
	end
	local head = decoration(model, "Head", HEAD_SIZE, HEAD_COLOR)
	local s = Rex.new(x, z, heading)
	local rng = Rng.new(R.Seed)
	local carsFolder = workspace:WaitForChild("Cars")
	local hips = CFrame.new(x, territory.floor, z) * CFrame.Angles(0, heading, 0)
	head.CFrame = CFrame.new(hips:PointToWorldSpace(HEAD_REST)) * hips.Rotation
	model:SetAttribute("Mode", s.mode)

	RunService.Heartbeat:Connect(function(dt: number)
		local cars: { Rex.Car } = {}
		for _, car in carsFolder:GetChildren() do
			local hull = if car:IsA("Model") then car.PrimaryPart else nil
			if hull then
				local p, v = hull.Position, hull.AssemblyLinearVelocity
				table.insert(cars, { id = car, x = p.X, y = p.Y, z = p.Z, vx = v.X, vy = v.Y, vz = v.Z })
			end
		end
		local caught = Rex.step(s, cars, territory, rng, dt, R)
		if caught then
			print(`T-Rex caught {driverName(caught)}`)
		end
		if model:GetAttribute("Mode") ~= s.mode then
			model:SetAttribute("Mode", s.mode)
		end

		hips = CFrame.new(s.x, territory.floor, s.z) * CFrame.Angles(0, s.heading, 0)
		for part, offset in blocks do
			part.CFrame = hips * offset
		end
		head.CFrame = headFrame(s, hips, head.CFrame, dt)
	end)
end

return DinoRex
