--!strict
-- CraneLook (LocalScript) -> StarterPlayerScripts.CraneLook
-- Draws the Scrapyard magnet crane's moving parts on this client (the
-- tower and pad are the server's, Parks.ScrapyardCrane): the boom turning on
-- top of the tower with its counterweight, the trolley out along it, the
-- cable, and the magnet. They move from the server's clock and the crane's
-- CycleAt attribute (MagnetCrane, MagnetCraneWorld), so every player sees
-- the same swing. While it holds a car (the Holding attribute) the magnet
-- sits right on that car, so the two never drift apart, and its rim glows.
-- It clunks as it clamps on and clangs as it lets go. During a replay it is
-- as it was at the moment being watched (ReplayWorld), on the ghost car.
-- None of it touches anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MagnetCrane = require(ReplicatedStorage.MagnetCrane)
local MagnetCraneWorld = require(ReplicatedStorage.MagnetCraneWorld)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local OneShot = require(script.Parent.OneShot)
local ReplayWorld = require(script.Parent.ReplayWorld)

local K = Tuning.Scrapyard.Crane
local S = Tuning.Scrapyard.Sounds
local CONFIG: MagnetCrane.Config = K :: any

if not MapLayout.find(Tuning.Map.Areas :: any, "Scrapyard") then
	return
end

local BOOM_WIDTH = 6
local CABLE = 0.6 -- how thick the cable is
-- Seconds; a longer jump in time between frames (a replay starting or
-- scrubbing) plays no sounds.
local CUE_GAP = 0.5

local folder = Instance.new("Folder")
folder.Name = "CraneLook"
folder.Parent = workspace

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.Color = color
	p.Material = material
	p.Parent = folder
	return p
end

local reach = K.Radius + 20 -- the boom runs a little past the magnet
local boom = part("Boom", Vector3.new(BOOM_WIDTH, K.BoomDepth, reach + K.BackLength), K.CraneColor, Enum.Material.Metal)
local cab = part("Cab", Vector3.new(K.TowerWidth + 2, 10, K.TowerWidth + 2), K.CraneColor, Enum.Material.Metal)
local weight = part("Weight", Vector3.new(12, 12, 14), K.SteelColor, Enum.Material.Concrete)
local trolley = part("Trolley", Vector3.new(8, 4, 8), K.SteelColor, Enum.Material.Metal)
local cable = part("Cable", Vector3.new(1, CABLE, CABLE), Color3.fromRGB(25, 25, 25), Enum.Material.Metal)
cable.Shape = Enum.PartType.Cylinder
local magnet =
	part("Magnet", Vector3.new(K.MagnetThickness, K.MagnetSize, K.MagnetSize), K.MagnetColor, Enum.Material.Metal)
magnet.Shape = Enum.PartType.Cylinder
local rim = part(
	"Rim",
	Vector3.new(K.MagnetThickness / 2, K.MagnetSize + 1.5, K.MagnetSize + 1.5),
	K.SteelColor,
	Enum.Material.Metal
)
rim.Shape = Enum.PartType.Cylinder

local clamp = OneShot.make(S.MagnetClamp, S.Near, S.Far, magnet)
local release = OneShot.make(S.MagnetRelease, S.Near, S.Far, magnet)

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis, its X, stood up

local function craneModel(): Instance?
	local parks = workspace:FindFirstChild("Parks")
	local yard = parks and parks:FindFirstChild("Scrapyard")
	return yard and yard:FindFirstChild("MagnetCrane")
end

-- Where the held car named `name` is drawn, if it can be found.
local function heldCar(name: string): CFrame?
	if name == "" then
		return nil
	end
	if ReplayWorld.isWatching() then
		return ReplayWorld.car(name)
	end
	local cars = workspace:FindFirstChild("Cars")
	local car = cars and cars:FindFirstChild(name)
	return if car and car:IsA("Model") then car:GetPivot() else nil
end

local followed: Instance? = nil
local lastTime = 0
local lastCycleAt: number? = nil

RunService.RenderStepped:Connect(function()
	local model = craneModel()
	if model and model ~= followed then
		followed = model
		ReplayWorld.follow(model)
	end
	local cycleAt = model and ReplayWorld.attribute(model, "CycleAt")
	local holding = model and ReplayWorld.attribute(model, "Holding")
	local now = ReplayWorld.serverTime()
	local step = now - lastTime
	lastTime = now
	local elapsed = if typeof(cycleAt) == "number" then now - cycleAt else -1

	if typeof(cycleAt) == "number" and step > 0 and step <= CUE_GAP then
		-- A cycle seen for the first time sounds only if it just started.
		local from = if cycleAt == lastCycleAt then elapsed - step elseif elapsed < CUE_GAP then -1e-3 else elapsed
		for _, cue in MagnetCrane.cues(CONFIG, from, elapsed) do
			if cue == "clamp" then
				OneShot.play(clamp, S.MagnetClamp)
			else
				OneShot.play(release, S.MagnetRelease)
			end
		end
	end
	lastCycleAt = if typeof(cycleAt) == "number" then cycleAt else nil

	local angle, height = MagnetCrane.pose(CONFIG, elapsed)
	local top = MagnetCraneWorld.tower + Vector3.new(0, K.TowerHeight, 0)
	local a = math.rad(angle)
	local turned = CFrame.lookAt(top, top + Vector3.new(math.sin(a), 0, math.cos(a)))
	boom.CFrame = turned * CFrame.new(0, K.BoomDepth / 2, -(reach - K.BackLength) / 2)
	cab.CFrame = turned * CFrame.new(0, K.BoomDepth + 5, 0)
	weight.CFrame = turned * CFrame.new(0, -4, K.BackLength - 8)
	local trolleyAt = turned * CFrame.new(0, -2, -K.Radius)
	trolley.CFrame = trolleyAt

	local car = heldCar(if typeof(holding) == "string" then holding else "")
	local under = if car
		then turned.Rotation + (car.Position + Vector3.new(0, K.HoldBelow, 0))
		else MagnetCraneWorld.at(angle, height)
	magnet.CFrame = under * CFrame.new(0, K.MagnetThickness / 2, 0) * UPRIGHT
	rim.CFrame = magnet.CFrame
	local lit = car ~= nil
	rim.Color = if lit then K.LitColor else K.SteelColor
	rim.Material = if lit then Enum.Material.Neon else Enum.Material.Metal

	local from = (trolleyAt * CFrame.new(0, -2, 0)).Position
	local to = under.Position + Vector3.new(0, K.MagnetThickness, 0)
	local length = (to - from).Magnitude
	cable.Size = Vector3.new(math.max(length, 0.1), CABLE, CABLE)
	-- The cable hangs about straight down, so its "up" is along the boom.
	cable.CFrame = CFrame.lookAt((from + to) / 2, to, turned.LookVector) * CFrame.Angles(0, math.pi / 2, 0)
end)
