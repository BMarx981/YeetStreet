--!strict
-- TornadoService (Script) -> ServerScriptService.TornadoService
-- Runs the tornados on the server, which owns where they are and every catch
-- and throw (Tornado, Tuning.Tornado). It keeps Count of them on the map:
-- each touches down at a random spot in one of the map's areas (Tuning.Map,
-- so the hub, every park and the long jump field; the obby floats far above
-- any tornado's top), and Respawn seconds after one goes a new one touches
-- down somewhere else.
--
-- Each Heartbeat it steps every tornado with every car in workspace.Cars and
-- every player on foot as the server sees them. A car or player something
-- else holds (anchored, as the T-Rex, pterodactyl, crane and missile hold
-- one) is never caught; a moving one is judged by where it will be a moment
-- on (Tornado.catch). A caught car is anchored where it was, and its Tornado
-- (the tornado's name), RideAt (the server's time then), RideAngle and
-- RideUp attributes say where its ride started. The server does not move it
-- while it rides: every client places it round the funnel each frame from
-- those (TornadoRiders, Tornado.rideAfter), so it whirls smoothly on every
-- screen, tumbling, driver seated in the open with arms flailing. A player
-- on foot is held the same way by their root part, attributes on their
-- character, and thrown out upright to land on foot, with no run and no pay;
-- no tornado catches them again for WalkerRest, since they can't outrun one.
-- For a car, ScoreService is told on ServerStorage.CarCarried: "grabbed",
-- then "dropped" with the ground's height and PayScale when it is thrown
-- out, which starts a run from there.
-- A thrown car is turned level facing the way it flies, then falls at the
-- throw's speed, back in its driver's hands.
--
-- The driver's client says on ReplicatedStorage.HeldJets (made by DinoRex)
-- when its jets start and stop burning while its car is anchored. Only a
-- rider's driver counts, so the most a false report does is throw that car
-- out sooner.
--
-- Each tornado is a Model in workspace.Tornados, named Tornado1, Tornado2 and
-- on, with an invisible Base part on the ground at its middle and attributes
-- Height, Phase and PhaseAt (when the phase began, on
-- workspace:GetServerTimeNow()'s clock). Each throw adds one to its Throws
-- attribute and sets ThrowAt to where the car left. Each client draws it and
-- plays its sounds from those (TornadoLook).
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
local PAY_SCALE: number = Tuning.Tornado.PayScale
local WALKER_REST: number = Tuning.Tornado.WalkerRest
local FLOOR: number = Tuning.Map.FloorTop
local AREAS: { MapLayout.Area } = Tuning.Map.Areas :: any
local RETRY = 3 -- seconds before trying again when no spot was free
-- The attributes that say where a riding car's ride started.
local RIDE_ATTRIBUTES = { "Tornado", "RideAt", "RideAngle", "RideUp" }

type Live = {
	state: Tornado.State,
	model: Model,
	base: Part,
	extra: boolean, -- an admin's, not replaced when it goes
}

local folder = Instance.new("Folder")
folder.Name = "Tornados"
folder.Parent = workspace

local carsFolder = workspace:WaitForChild("Cars")
local rng = Rng.new(os.time())
local rolls = Random.new()
local live: { Live } = {}
local made = 0
local jetting: { [Player]: boolean } = {}
-- When each player last thrown out on foot may be caught again: on foot
-- they can't outrun a tornado, so none takes them for WalkerRest.
local restUntil: { [Player]: number } = {}

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

-- `groundY` is the height of the ground under a thrown car, and `payScale`
-- what its run pays.
local function tell(car: Model, moment: string, groundY: number?, payScale: number?)
	local carCarried = ServerStorage:FindFirstChild("CarCarried")
	if carCarried and carCarried:IsA("BindableEvent") then
		carCarried:Fire(car, moment, groundY, payScale)
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

local function publish(t: Live)
	local s = t.state
	t.base.CFrame = CFrame.new(s.x, FLOOR, s.z)
	if t.model:GetAttribute("Phase") ~= s.phase then
		t.model:SetAttribute("Phase", s.phase)
		t.model:SetAttribute("PhaseAt", workspace:GetServerTimeNow())
	end
end

local function touchDown(x: number, z: number, area: Tornado.Area, extra: boolean)
	local s = Tornado.new(x, z, Tornado.height(rolls:NextNumber(), T), rolls:NextNumber(T.LifeMin, T.LifeMax), area)
	local model = Instance.new("Model")
	made += 1
	model.Name = `Tornado{made}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local base = hidden(model, "Base")
	model.PrimaryPart = base
	model:SetAttribute("Height", s.height)
	local t: Live = { state = s, model = model, base = base, extra = extra }
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

local function rootOf(character: Model): BasePart?
	local part = character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

-- Whether `rider`, a car or a player's character, is still in the game.
local function stillThere(rider: Model): boolean
	local walker = Players:GetPlayerFromCharacter(rider)
	if walker then
		return walker.Character == rider and rider:IsDescendantOf(workspace)
	end
	return rider.Parent == carsFolder
end

-- Lets `rider` go at `throw`, facing the way it flies, falling at the
-- throw's speed, back in its player's game: a car level, to drive, as
-- CarService does when they sit in it, its run starting there; a player on
-- foot upright, to land on foot, with no run.
local function throwOut(model: Model, rider: Model, throw: Tornado.Throw)
	local at = Vector3.new(throw.x, FLOOR + throw.up, throw.z)
	local velocity = Vector3.new(throw.vx, throw.vy, throw.vz)
	rider:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.atan2(-throw.vx, -throw.vz), 0))
	for _, attribute in RIDE_ATTRIBUTES do
		rider:SetAttribute(attribute, nil)
	end
	model:SetAttribute("ThrowAt", at)
	model:SetAttribute("Throws", (model:GetAttribute("Throws") or 0) + 1)

	local walker = Players:GetPlayerFromCharacter(rider)
	if walker then
		local root = rootOf(rider)
		if root then
			root.Anchored = false
			root.AssemblyLinearVelocity = velocity
			root.AssemblyAngularVelocity = Vector3.zero
			if root:CanSetNetworkOwnership() then
				root:SetNetworkOwner(walker)
			end
		end
		restUntil[walker] = os.clock() + WALKER_REST
		print(`Tornado threw {walker.Name} on foot out at {math.floor(throw.up)} up`)
		return
	end

	setAnchored(rider, false)
	local hull = rider.PrimaryPart
	if hull then
		hull.AssemblyLinearVelocity = velocity
		hull.AssemblyAngularVelocity = Vector3.zero
	end
	local driver = driverOf(rider)
	for _, part in rider:GetDescendants() do
		if part:IsA("BasePart") and part:CanSetNetworkOwnership() then
			part:SetNetworkOwner(driver)
		end
	end
	tell(rider, "dropped", FLOOR, PAY_SCALE)
	print(`Tornado threw {rider.Name} out at {math.floor(throw.up)} up ({throw.why})`)
end

-- Every car and player on foot free to catch, as the server sees them.
local function freeRiders(): { Tornado.Car }
	local riders: { Tornado.Car } = {}
	for _, car in carsFolder:GetChildren() do
		local hull = if car:IsA("Model") then car.PrimaryPart else nil
		if hull and not hull.Anchored and not car:GetAttribute("Crushing") then
			local p, v = hull.Position, hull.AssemblyLinearVelocity
			table.insert(riders, { id = car, x = p.X, up = p.Y - FLOOR, z = p.Z, vx = v.X, vz = v.Z })
		end
	end
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		if now < (restUntil[player] or 0) then
			continue
		end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then rootOf(character) else nil
		if
			character
			and humanoid
			and humanoid.Health > 0
			and humanoid.SeatPart == nil
			and root
			and not root.Anchored
		then
			local p, v = root.Position, root.AssemblyLinearVelocity
			table.insert(riders, { id = character, x = p.X, up = p.Y - FLOOR, z = p.Z, vx = v.X, vz = v.Z })
		end
	end
	return riders
end

local function step(t: Live, dt: number)
	local s = t.state
	local jets: { [any]: boolean } = {}
	for i = #s.riders, 1, -1 do
		local car = s.riders[i].id
		if not stillThere(car) then
			Tornado.drop(s, car)
			continue
		end
		local driver = driverOf(car)
		if driver and jetting[driver] then
			jets[car] = true
		end
	end

	for _, throw in Tornado.step(s, dt, rng, jets, T) do
		throwOut(t.model, throw.id, throw)
	end

	local caught = Tornado.catch(s, freeRiders(), T)
	for _, r in s.riders do
		if table.find(caught, r.id) then
			local rider: Model = r.id
			local walker = Players:GetPlayerFromCharacter(rider)
			local root = if walker then rootOf(rider) else nil
			if root then
				root.Anchored = true
			else
				setAnchored(rider, true)
			end
			rider:SetAttribute("RideAt", workspace:GetServerTimeNow())
			rider:SetAttribute("RideAngle", r.angle0)
			rider:SetAttribute("RideUp", r.up0)
			rider:SetAttribute("Tornado", t.model.Name)
			if walker then
				print(`Tornado caught {walker.Name} on foot`)
			else
				tell(rider, "grabbed")
				print(`Tornado caught {rider.Name}`)
			end
		end
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
	restUntil[player] = nil
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
