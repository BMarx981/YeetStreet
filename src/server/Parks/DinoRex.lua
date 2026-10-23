--!strict
-- DinoRex (ModuleScript) -> ServerScriptService.Parks.DinoRex
-- Runs Dino Valley's T-Rex on the server, which owns where it is and every
-- catch. Each Heartbeat it steps the brain (Rex) with every car in
-- workspace.Cars as the server sees them, and moves the T-Rex there, with
-- its Mode attribute set to the brain's mode.
--
-- A car it catches is anchored and held by its back end in the head, nose
-- and driver out in the open, lifted up and shaken. ScoreService is told on
-- ServerStorage.CarEaten at each moment: "caught", then either "dropped" or
-- "chewed". For the first Grip seconds no harm is done, and the car slips
-- free (Rex.grip) if its jets burn long enough or a slip was rolled: it
-- drops level and untouched, back in its driver's hands. Otherwise the jaws
-- chomp while ScoreService chews it to a wreck and respawns it. The brain
-- never sees a held car, and rests once it is gone.
--
-- The driver's client says on ReplicatedStorage.HeldJets when its jets start
-- and stop burning while its car is held. Only the held car's driver counts,
-- and only the time it is held, so the most a false report does is free that
-- car.
--
-- The server moves only two invisible parts: Root, on the ground under its
-- hips facing its heading, and Head, which rears back over a wind-up,
-- snaps its mouth to the spot it bites, and shakes a held car. It also sets
-- the model's Chewing attribute and its HeldCar attribute (the held car's
-- name, or ""). Each client draws the T-Rex itself from those (TRexLook).
-- Numbers are in Tuning.Dino.Rex.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Rex = require(ReplicatedStorage.Rex)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)

local R = Tuning.Dino.Rex

local H = R.Head

-- How quickly the head settles back after a lunge, per second.
local HEAD_SETTLE = 8
-- Holding a car, the head shakes SHAKE degrees each way SHAKE_RATE times a
-- second; chewing, it also bobs CHOMP_DEPTH studs at the jaw's ChompRate.
local CHOMP_DEPTH = 4
local SHAKE = math.rad(15)
local SHAKE_RATE = 1.5
-- The held car's middle, in the head's frame (Tuning.Dino.Rex.Head).
local HELD_AT = CFrame.new(0, -H.CarDrop, -(H.Size.Z / 2 + Tuning.Chassis.HullSize.Z / 2 - H.CarIn))
-- A held car never dips lower than a car standing on the floor.
local HELD_LOWEST = Tuning.TestPark.SpawnHeight
-- Seconds past chewing and the wreck's beat before a car still held is let
-- go, in case nothing took it away.
local HOLD_SPARE = 2

local DinoRex = {}

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

local function tell(car: Model, moment: string)
	local carEaten = ServerStorage:FindFirstChild("CarEaten")
	if carEaten and carEaten:IsA("BindableEvent") then
		carEaten:Fire(car, moment)
	end
end

-- Lets the car fall from where it is, level, and gives it back to its
-- driver's game to drive, as CarService does when they sit in it.
local function drop(car: Model)
	local at = car:GetPivot()
	local look = at.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude > 1e-3 then
		car:PivotTo(CFrame.lookAt(at.Position, at.Position + look))
	end
	setAnchored(car, false)
	local driver = driverOf(car)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") and part:CanSetNetworkOwnership() then
			part:SetNetworkOwner(driver)
		end
	end
end

-- Where the head goes this step: rearing back over the wind-up, snapping
-- its mouth to the bite over Snap, shaking a held car, chomping too while it
-- chews, and easing back to rest otherwise.
local function headFrame(s: Rex.State, chewing: boolean, hips: CFrame, last: CFrame, dt: number): CFrame
	local rest = hips:PointToWorldSpace(H.Rest)
	local shoulders = hips:PointToWorldSpace(H.Shoulders)
	local settle = 1 - math.exp(-HEAD_SETTLE * dt)
	if s.mode == "hold" then
		local chomp = if chewing then CHOMP_DEPTH * math.abs(math.sin(math.pi * R.Look.ChompRate * s.timer)) else 0
		local shake = SHAKE * math.sin(2 * math.pi * SHAKE_RATE * s.timer)
		local hold = hips * CFrame.new(H.Hold - Vector3.new(0, chomp, 0)) * CFrame.Angles(math.rad(H.HoldTip), shake, 0)
		return last:Lerp(hold, settle)
	end
	if s.mode ~= "lunge" then
		return last:Lerp(CFrame.lookAt(rest, rest + (rest - shoulders)), settle)
	end
	local jaw = Vector3.new(s.jawX, s.jawY, s.jawZ)
	local back = hips:PointToWorldSpace(H.Back)
	local windUp = if s.air then R.AirWindUp else R.WindUp
	if s.timer < windUp then
		local at = rest:Lerp(back, s.timer / windUp)
		return CFrame.lookAt(at, at + (jaw - shoulders))
	end
	-- Snapping: the head's middle goes where its mouth lands on the bite.
	local aim = CFrame.lookAt(Vector3.zero, jaw - shoulders)
	local bitten = jaw - aim:PointToWorldSpace(HELD_AT.Position)
	local at = back:Lerp(bitten, math.min((s.timer - windUp) / R.Snap, 1))
	return CFrame.new(at) * aim
end

-- Starts the T-Rex in `model`, at x, z facing `heading` (radians), roaming
-- `territory`.
function DinoRex.start(model: Model, territory: Rex.Territory, x: number, z: number, heading: number)
	local root = marker(model, "Root", Vector3.one)
	local head = marker(model, "Head", H.Size)
	local s = Rex.new(x, z, heading)
	local rng = Rng.new(R.Seed)
	local slipRolls = Random.new()
	local carsFolder = workspace:WaitForChild("Cars")
	local hips = CFrame.new(x, territory.floor, z) * CFrame.Angles(0, heading, 0)
	root.CFrame = hips
	head.CFrame = CFrame.new(hips:PointToWorldSpace(H.Rest)) * hips.Rotation
	model:SetAttribute("Mode", s.mode)
	model:SetAttribute("Chewing", false)
	model:SetAttribute("HeldCar", "")

	-- The car in its jaws, how long it has been held and its jets burned
	-- there, whether it rolled a slip, and whether it is being chewed.
	local held: Model? = nil
	local heldFor, jetsFor = 0, 0
	local slips = false
	local chewing = false
	local letGoAt = 0
	local jetting: { [Player]: boolean } = {}

	local heldJets = Instance.new("RemoteEvent")
	heldJets.Name = "HeldJets"
	heldJets.OnServerEvent:Connect(function(player: Player, burning: any)
		if typeof(burning) == "boolean" then
			jetting[player] = burning or nil
		end
	end)
	heldJets.Parent = ReplicatedStorage
	Players.PlayerRemoving:Connect(function(player: Player)
		jetting[player] = nil
	end)

	local function letGo(seconds: number)
		held = nil
		Rex.letGo(s, seconds)
	end

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
		if caught then
			local driver = driverOf(caught)
			slips = Rex.slips(slipRolls:NextNumber(), R)
			print(`T-Rex caught {if driver then driver.Name else caught.Name}{if slips then ", will slip" else ""}`)
			held = caught
			heldFor, jetsFor = 0, 0
			chewing = false
			setAnchored(caught, true)
			tell(caught, "caught")
		end

		local car = held
		if car then
			local driver = driverOf(car)
			if car.Parent ~= carsFolder then
				letGo(if chewing then R.Rest else R.Stun)
			elseif chewing then
				if os.clock() >= letGoAt then
					drop(car)
					tell(car, "dropped")
					letGo(R.Rest)
				end
			else
				heldFor += dt
				if driver and jetting[driver] then
					jetsFor += dt
				end
				local grip = Rex.grip(heldFor, jetsFor, slips, R)
				if grip == "slip" then
					print(`T-Rex dropped {if driver then driver.Name else car.Name}`)
					drop(car)
					tell(car, "dropped")
					letGo(R.Stun)
				elseif grip == "chew" then
					chewing = true
					letGoAt = os.clock() + R.Chew + Tuning.Toughness.WreckBeat + HOLD_SPARE
					tell(car, "chewed")
				end
			end
		end
		if model:GetAttribute("Mode") ~= s.mode then
			model:SetAttribute("Mode", s.mode)
		end
		local heldName = if held then held.Name else ""
		if model:GetAttribute("HeldCar") ~= heldName then
			model:SetAttribute("HeldCar", heldName)
		end
		local chewingNow = held ~= nil and chewing
		if model:GetAttribute("Chewing") ~= chewingNow then
			model:SetAttribute("Chewing", chewingNow)
		end

		hips = CFrame.new(s.x, territory.floor, s.z) * CFrame.Angles(0, s.heading, 0)
		root.CFrame = hips
		head.CFrame = headFrame(s, chewing, hips, head.CFrame, dt)

		if held then
			local frame = head.CFrame * HELD_AT
			local lift = math.max(territory.floor + HELD_LOWEST - frame.Y, 0)
			held:PivotTo(frame + Vector3.new(0, lift, 0))
		end
	end)
end

return DinoRex
