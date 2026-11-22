--!strict
-- ScrapyardShredder (ModuleScript) -> ServerScriptService.Parks.ScrapyardShredder
-- The Scrapyard's shredder (Shredder, ShredderWorld, Tuning.Scrapyard.Shredder).
-- build makes its fixed parts in a Shredder model: the hopper's floor and
-- walls with a yellow rim, and the lane that aims at it: boosters on the
-- floor, a kicker whose every plank is a booster at the speed that lands a
-- car in the opening's middle (Shredder.launchSpeed), and a SHREDDER sign
-- over the lane's start, where wrecks and resets come back. The rollers
-- spin, so every client makes and turns its own (ShredderLook).
--
-- start catches cars: a hull coming down into the opening (Shredder.inside)
-- is anchored, given the Shredding attribute, and held (ServerStorage
-- .CarShredded, which ends its run and chews it over its chew time until it
-- wrecks). While held it settles onto the rollers, shaking, and sinks into
-- them (Shredder.pose).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Shredder = require(ReplicatedStorage.Shredder)
local ShredderWorld = require(ReplicatedStorage.ShredderWorld)
local Tuning = require(ReplicatedStorage.Tuning)
local ArchSign = require(ServerScriptService.Pieces.ArchSign)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)

local S = Tuning.Scrapyard.Shredder
local K = S.Kicker
local CONFIG: Shredder.Config = S :: any
local FLOOR = Tuning.Map.FloorTop

-- Studs from a held car's middle to the walls, so it rests between them.
local MARGIN_ACROSS = 6
local MARGIN_ALONG = 9
local TIP = math.rad(-15) -- a resting car's nose, down into the rollers

local ScrapyardShredder = {}

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Back along the kicker's line from the opening's middle: the kicker's top,
-- its foot, and the lane's start.
local function kickerFoot(): number
	return S.Distance + K.Radius * math.sin(math.rad(K.Angle))
end

local function laneStart(): number
	return kickerFoot() + S.LaneLength
end

function ScrapyardShredder.build(folder: Folder, _area: MapLayout.Area)
	local frame = ShredderWorld.frame
	local model = Instance.new("Model")
	model.Name = "Shredder"

	-- The hopper: a floor, and walls round the opening with a rim on top.
	local L, W, T, H = S.Length, S.Width, S.WallThickness, S.RimHeight
	block(model, "Floor", Vector3.new(W, 1, L), frame * CFrame.new(0, 0.5, 0), S.SteelColor, Enum.Material.DiamondPlate)
	local walls = {
		{ size = Vector3.new(T, H, L + 2 * T), at = Vector3.new(-(W + T) / 2, 0, 0) },
		{ size = Vector3.new(T, H, L + 2 * T), at = Vector3.new((W + T) / 2, 0, 0) },
		{ size = Vector3.new(W, H, T), at = Vector3.new(0, 0, -(L + T) / 2) },
		{ size = Vector3.new(W, H, T), at = Vector3.new(0, 0, (L + T) / 2) },
	}
	for _, wall in walls do
		block(
			model,
			"Wall",
			wall.size,
			frame * CFrame.new(wall.at + Vector3.new(0, H / 2, 0)),
			S.HopperColor,
			Enum.Material.CorrodedMetal
		)
		block(
			model,
			"Rim",
			Vector3.new(wall.size.X, 0.6, wall.size.Z),
			frame * CFrame.new(wall.at + Vector3.new(0, H + 0.3, 0)),
			S.RimColor,
			Enum.Material.Metal
		)
	end

	-- The lane, facing the hopper, its wrecks and resets back past its start.
	local start = laneStart()
	local respawn = ShredderWorld.line(start + S.RespawnBack) * CFrame.new(0, Tuning.TestPark.SpawnHeight, 0)
	local options: CurvedWall.Options = {
		radius = K.Radius,
		endAngle = K.Angle,
		steps = K.Steps,
		thickness = 2,
		color = S.SteelColor,
		material = Enum.Material.DiamondPlate,
	}
	local kicker = CurvedWall.straight(model, ShredderWorld.line(kickerFoot()), S.LaneWidth, options)
	kicker.Name = "Kicker"
	CurvedWall.fill(kicker, FLOOR, options)
	local top = K.Radius * (1 - math.cos(math.rad(K.Angle))) + S.HullAbove
	local speed = Shredder.launchSpeed(S.Distance, K.Angle, S.RimHeight - top, Tuning.World.Gravity)
	if not speed then
		warn("Scrapyard: the shredder's kicker can't reach its rim")
		speed = 150
	end
	LaunchPad.top(kicker, K.Steps, speed :: number, respawn, K.PayScale)

	-- Boosters 0.1 above the floor that cars pass through, as on Scrap
	-- Mountain, from the lane's start to the kicker.
	local d = start - S.BoostLength / 2
	while d > kickerFoot() + S.BoostLength / 2 do
		local pad = LaunchPad.flat(
			model,
			ShredderWorld.line(d) * CFrame.new(0, 0.1, 0),
			S.LaneWidth,
			S.BoostLength,
			S.BoostSpeed,
			respawn,
			K.PayScale
		)
		pad.CanCollide = false
		d -= S.BoostEvery
	end

	ArchSign.make(model, ShredderWorld.line(start), {
		across = S.LaneWidth / 2 + 2,
		bottom = S.SignHeight,
		text = "SHREDDER",
		textColor = S.SignColor,
		postColor = S.SteelColor,
	})

	model.Parent = folder
end

local function setAnchored(car: Model, anchored: boolean)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end
end

local function toughnessOf(car: Model): number
	local toughness = car:GetAttribute("Toughness")
	return if typeof(toughness) == "number" then toughness else 0
end

-- Where a car caught at `from` comes to rest: on the rollers under where it
-- came in, kept off the walls, facing the way it was going, nose down.
local function restFor(from: CFrame): CFrame
	local frame = ShredderWorld.frame
	local p = frame:PointToObjectSpace(from.Position)
	local x = math.clamp(p.X, -S.Width / 2 + MARGIN_ACROSS, S.Width / 2 - MARGIN_ACROSS)
	local z = math.clamp(p.Z, -S.Length / 2 + MARGIN_ALONG, S.Length / 2 - MARGIN_ALONG)
	local at = frame * Vector3.new(x, S.RestHeight, z)
	local look = Vector3.new(from.LookVector.X, 0, from.LookVector.Z)
	if look.Magnitude < 1e-3 then
		look = frame.LookVector
	end
	return CFrame.lookAt(at, at + look) * CFrame.Angles(TIP, 0, 0)
end

type Held = { from: CFrame, rest: CFrame, at: number, chew: number }

function ScrapyardShredder.start(_folder: Folder, _area: MapLayout.Area)
	local carShredded = ServerStorage:WaitForChild("CarShredded") :: BindableEvent
	local cars = workspace:WaitForChild("Cars")
	local held: { [Model]: Held } = {}

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for car, h in held do
			if car.Parent ~= cars then
				held[car] = nil
				continue
			end
			local pose = Shredder.pose(CONFIG, now - h.at, h.chew)
			local shake = ShredderWorld.frame:VectorToWorldSpace(Vector3.new(pose.shakeX, -pose.sink, pose.shakeZ))
			car:PivotTo(h.from:Lerp(h.rest, pose.blend) + shake)
		end
		for _, car in cars:GetChildren() do
			if not car:IsA("Model") or held[car] then
				continue
			end
			local hull = car.PrimaryPart
			if not hull or hull.Anchored or car:GetAttribute("Crushing") then
				continue
			end
			if Shredder.inside(CONFIG, ShredderWorld.toHopper(hull.Position)) then
				local from = car:GetPivot()
				local chew = Shredder.chewTime(CONFIG, toughnessOf(car))
				held[car] = { from = from, rest = restFor(from), at = now, chew = chew }
				setAnchored(car, true)
				car:SetAttribute("Shredding", true)
				carShredded:Fire(car, chew)
			end
		end
	end)
end

return ScrapyardShredder
