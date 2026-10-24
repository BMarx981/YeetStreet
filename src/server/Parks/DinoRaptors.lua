--!strict
-- DinoRaptors (ModuleScript) -> ServerScriptService.Parks.DinoRaptors
-- Runs Dino Valley's velociraptor packs on the server, which owns where they
-- are and every bite. Each Heartbeat it steps the brain (Raptors) with every
-- car in workspace.Cars and every player on foot as the server sees them,
-- and moves each raptor there: on the ground or a mound under it, or on its
-- spot on the car or player it has latched onto (Tuning.Dino.Raptors.Slots).
--
-- ScoreService is told on ServerStorage.CarBitten of each bite (with the
-- slot the raptor is on), each car that shook a pack off ("shakeOff"), and
-- each that survived one ("survived"). A player on foot a raptor pins is
-- held still, unhurt, by anchoring their root part until it lets go.
--
-- Each raptor is a blocky stand-in, a Model named Raptor<pack>_<raptor>
-- with Mode and Slot attributes, that never touches a car.
-- Numbers are in Tuning.Dino.Raptors.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Raptors = require(ReplicatedStorage.Raptors)
local Tuning = require(ReplicatedStorage.Tuning)

local R = Tuning.Dino.Raptors

local BODY_COLOR = Color3.fromRGB(150, 112, 62)
local HEAD_COLOR = Color3.fromRGB(120, 86, 46)

local SLOTS: { [string]: Vector3 } = {
	roof = R.Slots.Roof,
	hood = R.Slots.Hood,
	trunk = R.Slots.Trunk,
	left = R.Slots.Left,
	right = R.Slots.Right,
	pin = R.Slots.Pin,
}

local DinoRaptors = {}

local function block(parent: Instance, name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- A raptor stand-in: a body with its head out front, pivoting at its
-- middle.
local function standIn(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local body = block(model, "Body", Vector3.new(3, 4, 9), BODY_COLOR)
	local head = block(model, "Head", Vector3.new(2.5, 2.5, 4), HEAD_COLOR)
	head.CFrame = body.CFrame * CFrame.new(0, 2, -6)
	model.PrimaryPart = body
	model.Parent = parent
	return model
end

local function rootOf(character: Model): BasePart?
	local part = character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

local function nameOf(thing: Instance): string
	local player = Players:GetPlayerFromCharacter(thing)
	if player then
		return `{player.Name} on foot`
	end
	local owner = thing:GetAttribute("OwnerUserId")
	local driver = if typeof(owner) == "number" then Players:GetPlayerByUserId(owner) else nil
	return if driver then driver.Name else thing.Name
end

-- Starts `packs` packs in `model`, each at a start spot, hiding among
-- `covers` and roaming `territory`. `ground` is what they stand on.
function DinoRaptors.start(
	model: Model,
	territory: Raptors.Territory,
	covers: { Raptors.Cover },
	starts: { Vector3 },
	ground: { Instance },
	floor: number
)
	local packs: { Raptors.Pack } = {}
	local looks: { { Model } } = {}
	for p, start in starts do
		local pack = Raptors.newPack(start.X, start.Z, 0)
		table.insert(packs, pack)
		local row = {}
		for i in pack.raptors do
			table.insert(row, standIn(model, `Raptor{p}_{i}`))
		end
		table.insert(looks, row)
	end
	local carsFolder = workspace:WaitForChild("Cars")

	local groundRays = RaycastParams.new()
	groundRays.FilterType = Enum.RaycastFilterType.Include
	groundRays.FilterDescendantsInstances = ground
	-- What a car can stand on, so the air test matches the car's own.
	local airRays = RaycastParams.new()
	airRays.FilterType = Enum.RaycastFilterType.Exclude
	airRays.CollisionGroup = "Cars"

	local function groundUnder(x: number, z: number): number
		local hit = workspace:Raycast(Vector3.new(x, floor + 200, z), Vector3.new(0, -400, 0), groundRays)
		return if hit then hit.Position.Y else floor
	end

	local function inAir(part: BasePart, skip: { Instance }): boolean
		airRays.FilterDescendantsInstances = skip
		return workspace:Raycast(part.Position, Vector3.new(0, -R.AirProbe, 0), airRays) == nil
	end

	-- How many raptors pin each player on foot.
	local pinned: { [Model]: number } = {}
	local function pin(character: Model, by: number)
		local count = (pinned[character] or 0) + by
		pinned[character] = if count > 0 then count else nil
		local rootPart = rootOf(character)
		if rootPart then
			rootPart.Anchored = count > 0
		end
	end

	local function tell(car: Instance, moment: string, slot: string?)
		local carBitten = ServerStorage:FindFirstChild("CarBitten")
		if carBitten and carBitten:IsA("BindableEvent") then
			carBitten:Fire(car, moment, slot)
		end
	end

	RunService.Heartbeat:Connect(function(dt: number)
		-- While the park is put away (the :dino admin command) they wait,
		-- letting go of anyone pinned.
		if not model:IsDescendantOf(workspace) then
			for character in pinned do
				pin(character, -math.huge)
			end
			return
		end
		local cars: { Raptors.Car } = {}
		local frames: { [any]: CFrame } = {}
		local skip: { Instance } = { carsFolder, model }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(skip, player.Character)
			end
		end
		for _, car in carsFolder:GetChildren() do
			local hull = if car:IsA("Model") then car.PrimaryPart else nil
			-- An anchored car is held by something else (the T-Rex or the
			-- pterodactyl).
			if hull and not hull.Anchored then
				local p, v = hull.Position, hull.AssemblyLinearVelocity
				table.insert(cars, {
					id = car,
					x = p.X,
					y = p.Y,
					z = p.Z,
					vx = v.X,
					vy = v.Y,
					vz = v.Z,
					air = inAir(hull, skip),
					foot = false,
				})
				frames[car] = hull.CFrame
			end
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rootPart = character and rootOf(character)
			-- Anchored is held by something (the T-Rex) unless it is a pin.
			local free = rootPart and (not rootPart.Anchored or pinned[character :: Model] ~= nil)
			if humanoid and humanoid.Health > 0 and humanoid.SeatPart == nil and rootPart and free then
				local p, v = rootPart.Position, rootPart.AssemblyLinearVelocity
				table.insert(cars, {
					id = character,
					x = p.X,
					y = p.Y,
					z = p.Z,
					vx = v.X,
					vy = v.Y,
					vz = v.Z,
					air = inAir(rootPart, skip),
					foot = true,
				})
				frames[character] = rootPart.CFrame
			end
		end

		for _, event in Raptors.step(packs, cars, covers, territory, dt, R) do
			local thing = if typeof(event.car) == "Instance" then event.car else nil
			if not thing then
				continue
			end
			local raptor = `Raptor {event.pack}.{event.raptor}`
			local pinning = event.slot == "pin" and thing:IsA("Model")
			if event.kind == "latch" then
				print(`{raptor} latched onto {nameOf(thing)} ({event.slot})`)
				if pinning then
					pin(thing :: Model, 1)
				end
			elseif event.kind == "shaken" or event.kind == "done" or event.kind == "lost" then
				print(`{raptor} {if event.kind == "shaken" then "shaken off" else "let go of"} {nameOf(thing)}`)
				if pinning and pinned[thing :: Model] then
					pin(thing :: Model, -1)
				end
			elseif event.kind == "bite" then
				tell(thing, "bite", event.slot)
			elseif event.kind == "shakeOff" or event.kind == "survived" then
				tell(thing, event.kind)
			end
		end

		local parts: { BasePart } = {}
		local cframes: { CFrame } = {}
		for p, pack in packs do
			for i, r in pack.raptors do
				local look = looks[p][i]
				local frame = if r.mode == "latch" and r.slot then frames[r.target] else nil
				local at = if frame and r.slot
					then frame * CFrame.new(SLOTS[r.slot])
					else CFrame.new(r.x, groundUnder(r.x, r.z) + R.Stand, r.z) * CFrame.Angles(0, r.heading, 0)
				local body = look.PrimaryPart :: BasePart
				for _, part in look:GetChildren() do
					if part:IsA("BasePart") then
						table.insert(parts, part)
						table.insert(cframes, at * body.CFrame:ToObjectSpace(part.CFrame))
					end
				end
				if look:GetAttribute("Mode") ~= r.mode then
					look:SetAttribute("Mode", r.mode)
				end
				local slot = if r.mode == "latch" then r.slot or "" else ""
				if look:GetAttribute("Slot") ~= slot then
					look:SetAttribute("Slot", slot)
				end
			end
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

return DinoRaptors
