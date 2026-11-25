--!strict
-- TornadoService (Script) -> ServerScriptService.TornadoService
-- Runs the tornados on the server, which owns where they are and every catch
-- and throw (Tornado, Tuning.Tornado). It keeps Count of them on the map:
-- each touches down at a random spot in one of the map's areas (Tuning.Map,
-- so the hub, every park and the long jump field; the obby floats far above
-- any tornado's top), and Respawn seconds after one goes a new one touches
-- down somewhere else.
--
-- Each Heartbeat it steps every tornado with every car in workspace.Cars as
-- the server sees it. A car something else holds (anchored, as the T-Rex,
-- pterodactyl, crane and missile hold one) is never caught. A caught car is
-- anchored and moved round the funnel each Heartbeat, tumbling, driver
-- seated in the open. ScoreService is told on ServerStorage.CarCarried:
-- "grabbed", then "dropped" with the ground's height when it is thrown out.
-- A thrown car is turned level facing the way it flies, then falls at the
-- throw's speed, back in its driver's hands.
--
-- The driver's client says on ReplicatedStorage.HeldJets (made by DinoRex)
-- when its jets start and stop burning while its car is anchored. Only a
-- rider's driver counts, so the most a false report does is throw that car
-- out sooner.
--
-- Each tornado is a Model in workspace.Tornados with an invisible Base part
-- on the ground at its middle and attributes Height, Phase and PhaseAt (when
-- the phase began, on workspace:GetServerTimeNow()'s clock). Until clients
-- draw it, a grey stand-in funnel of StandInSlices pieces shows where it is.
--
-- ServerStorage.TornadoHere (a BindableEvent, fired by the `:tornado` admin
-- command) with a player drops an extra tornado at their car, or where they
-- stand. Nothing replaces it when it goes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Rng = require(ReplicatedStorage.Rng)
local Tornado = require(ReplicatedStorage.Tornado)
local Tuning = require(ReplicatedStorage.Tuning)

local T: Tornado.Tuning = Tuning.Tornado :: any
local COUNT: number = Tuning.Tornado.Count
local RESPAWN: number = Tuning.Tornado.Respawn
local ADMIN_AREA: number = Tuning.Tornado.AdminArea
local SLICES: number = Tuning.Tornado.StandInSlices
local FLOOR: number = Tuning.Map.FloorTop
local AREAS: { MapLayout.Area } = Tuning.Map.Areas :: any
local RETRY = 3 -- seconds before trying again when no spot was free

type Live = {
	state: Tornado.State,
	model: Model,
	base: Part,
	slices: { Part },
	extra: boolean, -- an admin's, not replaced when it goes
}

local folder = Instance.new("Folder")
folder.Name = "Tornados"
folder.Parent = workspace

local carsFolder = workspace:WaitForChild("Cars")
local rng = Rng.new(os.time())
local rolls = Random.new()
local live: { Live } = {}
local jetting: { [Player]: boolean } = {}

local function driverOf(car: Model): Player?
	local userId = car:GetAttribute("OwnerUserId")
	return if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function setAnchored(car: Model, anchored: boolean)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end
end

-- `groundY` is the height of the ground under a thrown car.
local function tell(car: Model, moment: string, groundY: number?)
	local carCarried = ServerStorage:FindFirstChild("CarCarried")
	if carCarried and carCarried:IsA("BindableEvent") then
		carCarried:Fire(car, moment, groundY)
	end
end

local function hidden(parent: Instance, name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Parent = parent
	return part
end

-- Moves the stand-in funnel's pieces to the tornado, showing only the part
-- of it that is down: growing down from the top while it touches down, and
-- shrinking up into the sky while it lifts.
local function drawStandIn(t: Live)
	local s = t.state
	local downFrom = 0
	if s.phase == "touchdown" then
		downFrom = s.height * (1 - math.clamp(s.phaseAge / T.TouchTime, 0, 1))
	elseif s.phase == "lift" then
		downFrom = s.height * math.clamp(s.phaseAge / T.LiftTime, 0, 1)
	end
	local tall = s.height / SLICES
	for i, slice in t.slices do
		local mid = (i - 0.5) * tall
		local width = 2 * Tornado.radiusAt(s, mid, T)
		-- A cylinder's length runs along its X, so it is turned to stand up.
		slice.Size = Vector3.new(tall, width, width)
		slice.CFrame = CFrame.new(s.x, FLOOR + mid, s.z) * CFrame.Angles(0, 0, math.pi / 2)
		slice.Transparency = if mid >= downFrom then 0.6 else 1
	end
end

local function publish(t: Live)
	local s = t.state
	t.base.CFrame = CFrame.new(s.x, FLOOR, s.z)
	if t.model:GetAttribute("Phase") ~= s.phase then
		t.model:SetAttribute("Phase", s.phase)
		t.model:SetAttribute("PhaseAt", workspace:GetServerTimeNow())
	end
	drawStandIn(t)
end

local function touchDown(x: number, z: number, area: Tornado.Area, extra: boolean)
	local s = Tornado.new(x, z, Tornado.height(rolls:NextNumber(), T), rolls:NextNumber(T.LifeMin, T.LifeMax), area)
	local model = Instance.new("Model")
	model.Name = "Tornado"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local base = hidden(model, "Base")
	model.PrimaryPart = base
	local slices = {}
	for i = 1, SLICES do
		local slice = hidden(model, `StandIn{i}`)
		slice.Shape = Enum.PartType.Cylinder
		slice.Material = Enum.Material.SmoothPlastic
		slice.Color = Color3.fromRGB(120, 120, 125)
		table.insert(slices, slice)
	end
	model:SetAttribute("Height", s.height)
	local t: Live = { state = s, model = model, base = base, slices = slices, extra = extra }
	publish(t)
	model.Parent = folder
	table.insert(live, t)
	print(`Tornado touching down at {math.floor(x)}, {math.floor(z)}, {math.floor(s.height)} tall`)
end

-- Drops a replacement tornado at a free spot, or tries again shortly.
local function touchDownSomewhere()
	local others = {}
	for _, t in live do
		table.insert(others, { x = t.state.x, z = t.state.z })
	end
	local spot = Tornado.pickSpot(AREAS, others, rng, T)
	if spot then
		touchDown(spot.x, spot.z, spot.area, false)
	else
		task.delay(RETRY, touchDownSomewhere)
	end
end

-- Lets `car` go at `throw`: level, facing the way it flies, falling at the
-- throw's speed, and back in its driver's game to drive, as CarService does
-- when they sit in it.
local function throwOut(car: Model, throw: Tornado.Throw)
	local at = Vector3.new(throw.x, FLOOR + throw.up, throw.z)
	car:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.atan2(-throw.vx, -throw.vz), 0))
	setAnchored(car, false)
	local hull = car.PrimaryPart
	if hull then
		hull.AssemblyLinearVelocity = Vector3.new(throw.vx, throw.vy, throw.vz)
		hull.AssemblyAngularVelocity = Vector3.zero
	end
	local driver = driverOf(car)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") and part:CanSetNetworkOwnership() then
			part:SetNetworkOwner(driver)
		end
	end
	tell(car, "dropped", FLOOR)
	print(`Tornado threw {car.Name} out at {math.floor(throw.up)} up ({throw.why})`)
end

-- Every car free to catch, as the server sees it.
local function freeCars(): { Tornado.Car }
	local cars: { Tornado.Car } = {}
	for _, car in carsFolder:GetChildren() do
		local hull = if car:IsA("Model") then car.PrimaryPart else nil
		if hull and not hull.Anchored and not car:GetAttribute("Crushing") then
			local p = hull.Position
			table.insert(cars, { id = car, x = p.X, up = p.Y - FLOOR, z = p.Z })
		end
	end
	return cars
end

local function step(t: Live, dt: number)
	local s = t.state
	local jets: { [any]: boolean } = {}
	for i = #s.riders, 1, -1 do
		local car = s.riders[i].id
		if car.Parent ~= carsFolder then
			Tornado.drop(s, car)
			continue
		end
		local driver = driverOf(car)
		if driver and jetting[driver] then
			jets[car] = true
		end
	end

	for _, throw in Tornado.step(s, dt, rng, jets, T) do
		throwOut(throw.id, throw)
	end

	for _, car in Tornado.catch(s, freeCars(), T) do
		setAnchored(car, true)
		tell(car, "grabbed")
		print(`Tornado caught {car.Name}`)
	end

	for _, r in s.riders do
		local place = Tornado.riderAt(s, r, T)
		local frame = CFrame.new(place.x, FLOOR + place.up, place.z)
			* CFrame.Angles(0, place.yaw, 0)
			* CFrame.Angles(0, 0, place.tumble)
		r.id:PivotTo(frame)
	end

	publish(t)
end

task.spawn(function()
	local heldJets = ReplicatedStorage:WaitForChild("HeldJets", 60)
	if heldJets and heldJets:IsA("RemoteEvent") then
		heldJets.OnServerEvent:Connect(function(player: Player, burning: any)
			if typeof(burning) == "boolean" then
				jetting[player] = burning or nil
			end
		end)
	else
		warn("TornadoService: no ReplicatedStorage.HeldJets, so jets can't break a car free")
	end
end)
Players.PlayerRemoving:Connect(function(player: Player)
	jetting[player] = nil
end)

local tornadoHere = Instance.new("BindableEvent")
tornadoHere.Name = "TornadoHere"
tornadoHere.Event:Connect(function(player: Player)
	local at: Vector3? = nil
	for _, car in carsFolder:GetChildren() do
		if car:IsA("Model") and car:GetAttribute("OwnerUserId") == player.UserId then
			at = car:GetPivot().Position
		end
	end
	local character = player.Character
	if not at and character then
		at = character:GetPivot().Position
	end
	if not at then
		return
	end
	local area: Tornado.Area = { X = at.X, Z = at.Z, Width = ADMIN_AREA, Depth = ADMIN_AREA }
	for _, a in AREAS do
		if MapLayout.contains(a, at.X, at.Z) then
			area = a
			break
		end
	end
	touchDown(at.X, at.Z, area, true)
end)
tornadoHere.Parent = ServerStorage

RunService.Heartbeat:Connect(function(dt: number)
	for i = #live, 1, -1 do
		local t = live[i]
		step(t, dt)
		if t.state.phase == "gone" then
			t.model:Destroy()
			table.remove(live, i)
			if not t.extra then
				task.delay(RESPAWN, touchDownSomewhere)
			end
		end
	end
end)

for _ = 1, COUNT do
	touchDownSomewhere()
end
