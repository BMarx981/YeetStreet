--!strict
-- PedestrianLook (LocalScript) -> StarterPlayerScripts.PedestrianLook
-- Draws Downtown's walkers (Parks.CityPedestrians). Every walker's place
-- comes from the server's clock (Pedestrians) and its Configuration in
-- workspace.Parks.City.Pedestrians (Pedestrian.State as attributes), so
-- this client works out where each one is without anything sent each
-- frame. Only the nearest DrawCount within DrawRange of the camera are
-- drawn, by a fixed set of stand-ins handed to whichever walkers are
-- nearest. Nothing drawn here touches a car.
--
-- Stand-ins for now: a box per walker, lying down when it dives or is
-- knocked flat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Pedestrian = require(ReplicatedStorage.Pedestrian)
local Pedestrians = require(ReplicatedStorage.Pedestrians)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)

local C = Tuning.City
local P = C.Pedestrians
local D = P.Dodge
local FLOOR = Tuning.Map.FloorTop

local SIZE = Vector3.new(2, 5, 1)
local COLORS: { [Pedestrian.Phase]: Color3 } = {
	walk = Color3.fromRGB(230, 230, 230),
	dive = Color3.fromRGB(255, 220, 60),
	flop = Color3.fromRGB(230, 60, 50),
	down = Color3.fromRGB(230, 60, 50),
	up = Color3.fromRGB(255, 160, 60),
	fist = Color3.fromRGB(255, 120, 40),
	back = Color3.fromRGB(180, 200, 255),
}

local model = workspace:WaitForChild("Parks"):WaitForChild("City"):WaitForChild("Pedestrians")
local carsFolder = workspace:WaitForChild("Cars")
local areaX = model:GetAttribute("AreaX") :: number
local areaZ = model:GetAttribute("AreaZ") :: number

local routes = Pedestrians.routes(Pedestrians.layout(C :: any), P)
local walkers = Pedestrians.walkers(routes, P, Rng.new(P.Seed))

-- Each walker's state, kept up from its Configuration's attributes.
local states: { Pedestrian.State } = {}
local function read(config: Instance, s: Pedestrian.State)
	local function number(name: string, default: number): number
		local value = config:GetAttribute(name)
		return if typeof(value) == "number" then value else default
	end
	local mode = config:GetAttribute("Mode")
	s.mode = if mode == "dive" or mode == "flop" then mode else "walk"
	s.since = number("Since", 0)
	s.startX, s.startZ = number("StartX", 0), number("StartZ", 0)
	s.anchorX, s.anchorZ = number("AnchorX", 0), number("AnchorZ", 0)
	s.dirX, s.dirZ = number("DirX", 1), number("DirZ", 0)
	s.delay = number("Delay", 0)
end
for i in walkers do
	local s = Pedestrian.new()
	states[i] = s
	task.spawn(function()
		local config = model:WaitForChild(tostring(i))
		read(config, s)
		config.AttributeChanged:Connect(function()
			read(config, s)
		end)
	end)
end

local folder = Instance.new("Folder")
folder.Name = "PedestrianStandIns"
folder.Parent = workspace

local pool: { BasePart } = {}
for i = 1, P.DrawCount do
	local part = Instance.new("Part")
	part.Name = `Walker{i}`
	part.Size = SIZE
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = folder
	pool[i] = part
end

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Exclude

-- The floor or curve under (x, z), world coordinates.
local function groundAt(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, FLOOR + 30, z), Vector3.new(0, -40, 0), ground)
	return if hit then hit.Position.Y else FLOOR
end

-- How far over it leans, 0 standing to 1 flat on its back, in each phase.
local function lean(where: Pedestrian.Where): number
	local phase = where.phase
	if phase == "dive" or phase == "flop" then
		return where.progress
	elseif phase == "down" then
		return 1
	elseif phase == "up" then
		return 1 - where.progress
	end
	return 0
end

local HIDDEN = CFrame.new(0, -500, 0)

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = workspace:GetServerTimeNow()
	local eye = camera.CFrame.Position

	-- Every walker in range, nearest first.
	local near: { { gap: number, where: Pedestrian.Where } } = {}
	local range2 = P.DrawRange * P.DrawRange
	for i, walker in walkers do
		local s = states[i]
		local route = routes[walker.route]
		local where = Pedestrian.where(s, now, D)
		if where.phase == "walk" then
			local pose = Pedestrians.at(walker, route, Pedestrian.clock(s, now, D))
			local walking: Pedestrian.Where = {
				x = pose.x,
				z = pose.z,
				facingX = pose.headingX,
				facingZ = pose.headingZ,
				phase = "walk",
				progress = 0,
			}
			where = walking
		end
		local dx, dz = areaX + where.x - eye.X, areaZ + where.z - eye.Z
		local gap = dx * dx + dz * dz
		if gap <= range2 then
			table.insert(near, { gap = gap, where = where })
		end
	end
	table.sort(near, function(a, b)
		return a.gap < b.gap
	end)

	local ignore: { Instance } = { folder, carsFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	ground.FilterDescendantsInstances = ignore

	for i, part in pool do
		local entry = near[i]
		if not entry then
			part.CFrame = HIDDEN
			continue
		end
		local where = entry.where
		local x, z = areaX + where.x, areaZ + where.z
		local y = groundAt(x, z)
		local facing = Vector3.new(where.facingX, 0, where.facingZ)
		if facing.Magnitude < 1e-3 then
			facing = Vector3.new(0, 0, -1)
		end
		-- Falls backward, away from where it faces, pivoting at its feet.
		local feet = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z) + facing)
		local tipped = feet * CFrame.Angles(math.rad(90) * lean(where), 0, 0)
		part.CFrame = tipped * CFrame.new(0, SIZE.Y / 2, 0)
		part.Color = COLORS[where.phase]
	end
end)
