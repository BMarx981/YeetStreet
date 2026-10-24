--!strict
-- DinoPtero (ModuleScript) -> ServerScriptService.Parks.DinoPtero
-- Runs Dino Valley's pterodactyl on the server, which owns where it is and
-- every grab and drop. Each Heartbeat it steps the brain (Ptero) with every
-- car in workspace.Cars as the server sees them, and moves the pterodactyl
-- there, with its Mode attribute set to the brain's mode. A car something
-- else holds (anchored, as the T-Rex holds one) is never hunted.
--
-- A car it grabs is anchored and carried level under its talons, roof up
-- and facing the way it flies, driver seated in the open, up its spiral.
-- ScoreService is told on ServerStorage.CarCarried: "grabbed", then
-- "dropped", which starts a run from there. It lets go (Ptero.releases) when the car's jets have burned
-- EscapeJets seconds, at a fumble's height if the grab rolled one
-- (Ptero.fumble), or at the top: the car falls from there at the speed it
-- was carried, level and untouched, back in its driver's hands.
--
-- The driver's client says on ReplicatedStorage.HeldJets (made by DinoRex)
-- when its jets start and stop burning while its car is anchored. Only the
-- carried car's driver counts, and only while carried, so the most a false
-- report does is drop that car sooner.
--
-- While the park is put away (the :dino admin command) it lets go of its
-- car and does nothing.
--
-- The server moves one invisible part, Talons, at the brain's position
-- facing its heading, and sets the model's CarriedCar attribute (the
-- carried car's name, or ""). Each client draws the pterodactyl itself from
-- those (PteroLook). Numbers are in Tuning.Dino.Ptero.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Ptero = require(ReplicatedStorage.Ptero)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)

local P = Tuning.Dino.Ptero

-- A carried car's middle, in the talons' frame: its roof at the talons.
local CARRIED_AT = CFrame.new(0, -P.CarTop, 0)

local DinoPtero = {}

local function marker(parent: Instance, name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size
	part.Parent = parent
	return part
end

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

-- `groundY` is the height of the ground under a dropped car.
local function tell(car: Model, moment: string, groundY: number?)
	local carCarried = ServerStorage:FindFirstChild("CarCarried")
	if carCarried and carCarried:IsA("BindableEvent") then
		carCarried:Fire(car, moment, groundY)
	end
end

-- Lets the car fall from where it is at `velocity`, and gives it back to
-- its driver's game to drive, as CarService does when they sit in it.
local function drop(car: Model, velocity: Vector3)
	setAnchored(car, false)
	local hull = car.PrimaryPart
	if hull then
		hull.AssemblyLinearVelocity = velocity
		hull.AssemblyAngularVelocity = Vector3.zero
	end
	local driver = driverOf(car)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") and part:CanSetNetworkOwnership() then
			part:SetNetworkOwner(driver)
		end
	end
end

-- Starts the pterodactyl in `model`, perched at `perch` (facing its look),
-- hunting over `territory`.
function DinoPtero.start(model: Model, territory: Ptero.Territory, perch: CFrame)
	local talons = marker(model, "Talons", Vector3.one)
	local _, heading, _ = perch:ToOrientation()
	local s = Ptero.new(perch.X, perch.Y, perch.Z, heading)
	local rng = Rng.new(P.Seed)
	local rolls = Random.new()
	local carsFolder = workspace:WaitForChild("Cars")
	model:SetAttribute("Mode", s.mode)
	model:SetAttribute("CarriedCar", "")

	-- The car in its talons, the height it fumbles at (if it does), and how
	-- long the car's jets have burned there.
	local carried: Model? = nil
	local fumbleAt: number? = nil
	local jetsFor = 0
	local jetting: { [Player]: boolean } = {}

	local heldJets = ReplicatedStorage:FindFirstChild("HeldJets")
	if heldJets and heldJets:IsA("RemoteEvent") then
		heldJets.OnServerEvent:Connect(function(player: Player, burning: any)
			if typeof(burning) == "boolean" then
				jetting[player] = burning or nil
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		jetting[player] = nil
	end)

	-- Lets go of its car, if it still has one, at the speed it flies, and
	-- flies home.
	local function letGo()
		local car = carried
		if car and car.Parent == carsFolder then
			local fx, fz = Ptero.forward(s.heading)
			drop(car, Vector3.new(fx * s.speed, s.vy, fz * s.speed))
			tell(car, "dropped", territory.floor)
		end
		carried, fumbleAt = nil, nil
		Ptero.letGo(s)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		if not model:IsDescendantOf(workspace) then
			if carried then
				letGo()
			end
			return
		end
		local cars: { Ptero.Car } = {}
		for _, car in carsFolder:GetChildren() do
			local hull = if car:IsA("Model") then car.PrimaryPart else nil
			if hull and not hull.Anchored then
				local p, v = hull.Position, hull.AssemblyLinearVelocity
				table.insert(cars, { id = car, x = p.X, y = p.Y, z = p.Z, vx = v.X, vy = v.Y, vz = v.Z })
			end
		end
		local grabbed = Ptero.step(s, cars, territory, rng, dt, P)
		if grabbed then
			carried = grabbed
			jetsFor = 0
			fumbleAt = Ptero.fumble(rolls:NextNumber(), rolls:NextNumber(), P)
			setAnchored(grabbed, true)
			tell(grabbed, "grabbed")
			print(
				`Pterodactyl grabbed {grabbed.Name}{if fumbleAt then `, will fumble at {math.floor(fumbleAt)}` else ""}`
			)
		end

		local car = carried
		if car then
			local driver = driverOf(car)
			if car.Parent ~= carsFolder then
				letGo()
			else
				if driver and jetting[driver] then
					jetsFor += dt
				end
				if Ptero.releases(s.y - territory.floor, jetsFor, fumbleAt, P) then
					print(`Pterodactyl let go of {car.Name} {math.floor(s.y - territory.floor)} up`)
					letGo()
				end
			end
		end
		if model:GetAttribute("Mode") ~= s.mode then
			model:SetAttribute("Mode", s.mode)
		end
		local carriedName = if carried then carried.Name else ""
		if model:GetAttribute("CarriedCar") ~= carriedName then
			model:SetAttribute("CarriedCar", carriedName)
		end

		local fx, fz = Ptero.forward(s.heading)
		local at = Vector3.new(s.x, s.y, s.z)
		local frame = CFrame.lookAt(at, at + Vector3.new(fx, 0, fz))
		talons.CFrame = frame
		if carried then
			carried:PivotTo(frame * CARRIED_AT)
		end
	end)
end

return DinoPtero
