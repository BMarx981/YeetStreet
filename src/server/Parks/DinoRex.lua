--!strict
-- DinoRex (ModuleScript) -> ServerScriptService.Parks.DinoRex
-- Runs Dino Valley's T-Rex on the server, which owns where it is and every
-- catch. Each Heartbeat it steps the brain (Rex) with every car in
-- workspace.Cars and every player on foot as the server sees them, and
-- moves the T-Rex there, with its Mode attribute set to the brain's mode.
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
-- A player on foot it catches is held the same way, sideways in its jaws,
-- by anchoring their root part. They are never hurt. Only a rolled slip
-- drops them free; otherwise it chews them for Chew seconds and swallows,
-- and ScoreService (told on ServerStorage.PlayerEaten) brings them back in a
-- fresh car at their last launcher.
--
-- The driver's client says on ReplicatedStorage.HeldJets when its jets start
-- and stop burning while its car is held. Only the held car's driver counts,
-- and only the time it is held, so the most a false report does is free that
-- car.
--
-- The server moves only two invisible parts: Root, on the ground under its
-- hips facing its heading, and Head, which rears back over a wind-up,
-- snaps its mouth to the spot it bites, and shakes a held car. It also sets
-- the model's Chewing attribute, its HeldCar attribute (the held car's name,
-- or "") and its HeldPlayer attribute (the held player's name, or ""). Each
-- client draws the T-Rex itself from those (TRexLook).
--
-- Downtown's kaiju (Parks.CityKaiju) is run here the same way, with its own
-- numbers and name.
-- Numbers are in Tuning.Dino.Rex.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Rex = require(ReplicatedStorage.Rex)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)

-- How quickly the head settles back after a lunge, per second.
local HEAD_SETTLE = 8
-- Holding a car, the head shakes SHAKE degrees each way SHAKE_RATE times a
-- second; chewing, it also bobs CHOMP_DEPTH studs at the jaw's ChompRate.
local CHOMP_DEPTH = 4
local SHAKE = math.rad(15)
local SHAKE_RATE = 1.5
-- A held car never dips lower than a car standing on the floor.
local HELD_LOWEST = Tuning.TestPark.SpawnHeight
-- Seconds past chewing and the wreck's beat before a car still held is let
-- go, in case nothing took it away.
local HOLD_SPARE = 2

local DinoRex = {}

-- A creature's numbers, shaped like Tuning.Dino.Rex, and its name, which
-- pays as the target when it snaps a car out of the air.
export type Options = {
	tuning: typeof(Tuning.Dino.Rex),
	name: string,
}

-- Its numbers and name, and where it holds a car's middle and a player's
-- root in its head's frame: a player turned across the jaws.
type Kind = {
	R: typeof(Tuning.Dino.Rex),
	name: string,
	heldAt: CFrame,
	heldPerson: CFrame,
}

local function kindOf(options: Options): Kind
	local H = options.tuning.Head
	local heldAt = CFrame.new(0, -H.CarDrop, -(H.Size.Z / 2 + Tuning.Chassis.HullSize.Z / 2 - H.CarIn))
	return {
		R = options.tuning,
		name = options.name,
		heldAt = heldAt,
		heldPerson = heldAt * CFrame.Angles(0, math.pi / 2, 0),
	}
end

-- Every creature's held driver says here when their jets burn (HeldJets).
local jetting: { [Player]: boolean } = {}
local heldJets: RemoteEvent? = nil

local function listenForJets()
	if heldJets then
		return
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = "HeldJets"
	remote.OnServerEvent:Connect(function(player: Player, burning: any)
		if typeof(burning) == "boolean" then
			jetting[player] = burning or nil
		end
	end)
	remote.Parent = ReplicatedStorage
	heldJets = remote
	Players.PlayerRemoving:Connect(function(player: Player)
		jetting[player] = nil
	end)
end

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

local function tell(car: Model, moment: string, kind: Kind)
	local carEaten = ServerStorage:FindFirstChild("CarEaten")
	if carEaten and carEaten:IsA("BindableEvent") then
		carEaten:Fire(car, moment, kind.name, kind.R.Chew)
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

local function rootOf(character: Model): BasePart?
	local part = character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

-- Lets a player it held fall from where they are, upright, and gives their
-- character back to their game.
local function dropPerson(character: Model, player: Player)
	local rootPart = rootOf(character)
	if not rootPart then
		return
	end
	local at = character:GetPivot()
	local look = at.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude > 1e-3 then
		character:PivotTo(CFrame.lookAt(at.Position, at.Position + look))
	end
	rootPart.Anchored = false
	if rootPart:CanSetNetworkOwnership() then
		rootPart:SetNetworkOwner(player)
	end
end

-- Where the head goes this step: rearing back over the wind-up, snapping
-- its mouth to the bite over Snap, shaking a held car, chomping too while it
-- chews, and easing back to rest otherwise.
local function headFrame(s: Rex.State, chewing: boolean, hips: CFrame, last: CFrame, dt: number, kind: Kind): CFrame
	local R, H = kind.R, kind.R.Head
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
	local bitten = jaw - aim:PointToWorldSpace(kind.heldAt.Position)
	local at = back:Lerp(bitten, math.min((s.timer - windUp) / R.Snap, 1))
	return CFrame.new(at) * aim
end

-- Starts the T-Rex in `model`, at x, z facing `heading` (radians), roaming
-- `territory`, or with `options` another creature that hunts the same way.
function DinoRex.start(model: Model, territory: Rex.Territory, x: number, z: number, heading: number, options: Options?)
	local kind = kindOf(options or { tuning = Tuning.Dino.Rex, name = "T-Rex" })
	local R, H = kind.R, kind.R.Head
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
	model:SetAttribute("HeldPlayer", "")

	-- The car or character in its jaws (and whose character, if one), how
	-- long it has been held and its jets burned there, whether it rolled a
	-- slip, and whether it is being chewed.
	local held: Model? = nil
	local heldPlayer: Player? = nil
	local heldFor, jetsFor = 0, 0
	local slips = false
	local chewing = false
	local letGoAt = 0
	listenForJets()

	local function letGo(seconds: number)
		held = nil
		heldPlayer = nil
		Rex.letGo(s, seconds)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		-- While the park is put away (the :dino admin command) the T-Rex
		-- rests: anything in its jaws is let go, and nothing else runs.
		if not model:IsDescendantOf(workspace) then
			local car = held
			if car then
				if heldPlayer then
					dropPerson(car, heldPlayer)
				else
					drop(car)
					tell(car, "dropped", kind)
				end
				letGo(R.Rest)
			end
			return
		end
		local cars: { Rex.Car } = {}
		for _, car in carsFolder:GetChildren() do
			local hull = if car:IsA("Model") and car ~= held then car.PrimaryPart else nil
			-- An anchored car is held by something else (the pterodactyl).
			if hull and not hull.Anchored then
				local p, v = hull.Position, hull.AssemblyLinearVelocity
				table.insert(cars, { id = car, x = p.X, y = p.Y, z = p.Z, vx = v.X, vy = v.Y, vz = v.Z })
			end
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rootPart = character and rootOf(character)
			if character ~= held and humanoid and humanoid.Health > 0 and humanoid.SeatPart == nil and rootPart then
				local p, v = rootPart.Position, rootPart.AssemblyLinearVelocity
				table.insert(cars, { id = character, x = p.X, y = p.Y, z = p.Z, vx = v.X, vy = v.Y, vz = v.Z })
			end
		end
		local caught = Rex.step(s, cars, territory, rng, dt, R)
		if caught then
			local person = Players:GetPlayerFromCharacter(caught)
			local driver = person or driverOf(caught)
			slips = Rex.slips(slipRolls:NextNumber(), R)
			print(
				`{kind.name} caught {if driver then driver.Name else caught.Name}{if person then " on foot" else ""}{if slips
					then ", will slip"
					else ""}`
			)
			held, heldPlayer = caught, person
			heldFor, jetsFor = 0, 0
			chewing = false
			if person then
				local rootPart = rootOf(caught)
				if rootPart then
					rootPart.Anchored = true
				end
			else
				setAnchored(caught, true)
				tell(caught, "caught", kind)
			end
		end

		local car = held
		if car then
			local person = heldPlayer
			local driver = person or driverOf(car)
			local gone = if person then person.Character ~= car or car.Parent == nil else car.Parent ~= carsFolder
			if gone then
				letGo(if chewing then R.Rest else R.Stun)
			elseif chewing then
				if os.clock() >= letGoAt then
					if person then
						local rootPart = rootOf(car)
						if rootPart then
							rootPart.Anchored = false
						end
						local playerEaten = ServerStorage:FindFirstChild("PlayerEaten")
						if playerEaten and playerEaten:IsA("BindableEvent") then
							playerEaten:Fire(person)
						end
					else
						drop(car)
						tell(car, "dropped", kind)
					end
					letGo(R.Rest)
				end
			else
				heldFor += dt
				if not person and driver and jetting[driver] then
					jetsFor += dt
				end
				local grip = Rex.grip(heldFor, jetsFor, slips, R)
				if grip == "slip" then
					print(`{kind.name} dropped {if driver then driver.Name else car.Name}`)
					if person then
						dropPerson(car, person)
					else
						drop(car)
						tell(car, "dropped", kind)
					end
					letGo(R.Stun)
				elseif grip == "chew" then
					chewing = true
					if person then
						letGoAt = os.clock() + R.Chew
					else
						letGoAt = os.clock() + R.Chew + Tuning.Toughness.WreckBeat + HOLD_SPARE
						tell(car, "chewed", kind)
					end
				end
			end
		end
		if model:GetAttribute("Mode") ~= s.mode then
			model:SetAttribute("Mode", s.mode)
		end
		local heldName = if held and not heldPlayer then held.Name else ""
		if model:GetAttribute("HeldCar") ~= heldName then
			model:SetAttribute("HeldCar", heldName)
		end
		local heldPlayerName = if heldPlayer then heldPlayer.Name else ""
		if model:GetAttribute("HeldPlayer") ~= heldPlayerName then
			model:SetAttribute("HeldPlayer", heldPlayerName)
		end
		local chewingNow = held ~= nil and chewing
		if model:GetAttribute("Chewing") ~= chewingNow then
			model:SetAttribute("Chewing", chewingNow)
		end

		hips = CFrame.new(s.x, territory.floor, s.z) * CFrame.Angles(0, s.heading, 0)
		root.CFrame = hips
		head.CFrame = headFrame(s, chewing, hips, head.CFrame, dt, kind)

		if held then
			local frame = head.CFrame * (if heldPlayer then kind.heldPerson else kind.heldAt)
			local lift = math.max(territory.floor + HELD_LOWEST - frame.Y, 0)
			held:PivotTo(frame + Vector3.new(0, lift, 0))
		end
	end)
end

return DinoRex
