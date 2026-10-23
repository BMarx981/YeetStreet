--!strict
-- DinoRex (ModuleScript) -> ServerScriptService.Parks.DinoRex
-- Runs Dino Valley's T-Rex on the server, which owns where it is and every
-- catch. Each Heartbeat it steps the brain (Rex) with every car in
-- workspace.Cars as the server sees them, and moves the T-Rex there, with
-- its Mode attribute set to the brain's mode.
--
-- A car it catches is anchored and held by its back end in the head, nose
-- and driver out in the open, lifted up and shaken while the jaws chomp,
-- until it is gone (ScoreService, told on ServerStorage.CarEaten, chews it
-- to a wreck and respawns it). The brain never sees a held car.
--
-- For now the T-Rex is a stand-in of plain blocks moved by the server: a
-- body on two legs with a tail, and a head that rears back and snaps at
-- the spot it bites. Numbers are in Tuning.Dino.Rex.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

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
-- Chewing, the head holds lower and tipped down, bobbing CHOMP_DEPTH studs
-- CHOMP_RATE times a second and shaking SHAKE degrees each way SHAKE_RATE
-- times a second.
local HEAD_CHEW = Vector3.new(0, 74, -74)
local CHEW_TIP = math.rad(-20)
local CHOMP_DEPTH = 4
local CHOMP_RATE = 3
local SHAKE = math.rad(15)
local SHAKE_RATE = 1.5
-- The held car's middle, in the head's frame: just out of its front, so
-- the back HELD_IN studs of a car HELD_LENGTH long are in its mouth.
local HELD_LENGTH = Tuning.Chassis.HullSize.Z
local HELD_IN = 2
local HELD_AT = CFrame.new(0, -4, -(HEAD_SIZE.Z / 2 + HELD_LENGTH / 2 - HELD_IN))
-- A held car never dips lower than a car standing on the floor.
local HELD_LOWEST = Tuning.TestPark.SpawnHeight
-- Seconds past chewing and the wreck's beat before a car still held is let
-- go, in case nothing took it away.
local HOLD_SPARE = 2

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

local function setAnchored(car: Model, anchored: boolean)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end
end

-- Where the head goes this step: rearing back over the wind-up, snapping to
-- the bite over Snap, chomping and shaking while it chews, and easing back
-- to rest otherwise.
local function headFrame(s: Rex.State, hips: CFrame, last: CFrame, dt: number): CFrame
	local rest = hips:PointToWorldSpace(HEAD_REST)
	local shoulders = hips:PointToWorldSpace(SHOULDERS)
	local settle = 1 - math.exp(-HEAD_SETTLE * dt)
	if s.mode == "rest" and s.timer < R.Chew then
		local chomp = CHOMP_DEPTH * math.abs(math.sin(math.pi * CHOMP_RATE * s.timer))
		local shake = SHAKE * math.sin(2 * math.pi * SHAKE_RATE * s.timer)
		local chew = hips * CFrame.new(HEAD_CHEW - Vector3.new(0, chomp, 0)) * CFrame.Angles(CHEW_TIP, shake, 0)
		return last:Lerp(chew, settle)
	end
	if s.mode ~= "lunge" then
		return last:Lerp(CFrame.lookAt(rest, rest + (rest - shoulders)), settle)
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
	local held: Model? = nil
	local letGoAt = 0

	RunService.Heartbeat:Connect(function(dt: number)
		local cars: { Rex.Car } = {}
		for _, car in carsFolder:GetChildren() do
			local hull = if car:IsA("Model") and car ~= held then car.PrimaryPart else nil
			if hull then
				local p, v = hull.Position, hull.AssemblyLinearVelocity
				table.insert(cars, { id = car, x = p.X, y = p.Y, z = p.Z, vx = v.X, vy = v.Y, vz = v.Z })
			end
		end
		local caught = Rex.step(s, cars, territory, rng, dt, R)
		if caught and held == nil then
			print(`T-Rex caught {driverName(caught)}`)
			held = caught
			letGoAt = os.clock() + R.Chew + Tuning.Toughness.WreckBeat + HOLD_SPARE
			setAnchored(caught, true)
			local carEaten = ServerStorage:FindFirstChild("CarEaten")
			if carEaten and carEaten:IsA("BindableEvent") then
				carEaten:Fire(caught)
			end
		end
		if model:GetAttribute("Mode") ~= s.mode then
			model:SetAttribute("Mode", s.mode)
		end

		hips = CFrame.new(s.x, territory.floor, s.z) * CFrame.Angles(0, s.heading, 0)
		for part, offset in blocks do
			part.CFrame = hips * offset
		end
		head.CFrame = headFrame(s, hips, head.CFrame, dt)

		if held then
			if held.Parent ~= carsFolder then
				held = nil
			elseif os.clock() >= letGoAt then
				setAnchored(held, false)
				held = nil
			else
				local frame = head.CFrame * HELD_AT
				local lift = math.max(territory.floor + HELD_LOWEST - frame.Y, 0)
				held:PivotTo(frame + Vector3.new(0, lift, 0))
			end
		end
	end)
end

return DinoRex
