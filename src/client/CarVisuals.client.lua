--!strict
-- CarVisuals (LocalScript) -> StarterPlayerScripts.CarVisuals
-- Builds the looks of every car in workspace.Cars on this client. The server
-- sends only the car's look attributes (CarParts), so every client makes the
-- same parts from CarDesign and welds them to the hull in a Looks folder.
-- They are massless and out of physics, so handling comes only from stats.
--
-- Also, on each car:
--   A car with the HeliCar attribute (an admin toggle) gets the fixed
--   HeliCar look instead, with its roof fan turning to follow the steering.
--   It doesn't break apart on hits yet.
--   A car with the PlaneCar attribute (an admin toggle) gets the fixed
--   PlaneCar look, a plane while its WingsOut attribute is true and a car
--   otherwise, transforming between them. It doesn't break apart yet either.
--   Hover cars hide their wheels. The physics wheels are still there.
--   Each thruster gets a flame, a smoke trail, and a glow that grow with the
--   car's Jets level (Tuning.JetFlames), lit while the car's JetsBurning
--   attribute is true. CarController sets it on the local player's car.
--   Wheel brakes (CarDesign parts with a wheel) are welded to that wheel's
--   hub, so they steer and ride the suspension without spinning. They and
--   the brake lights glow while the car's Braking attribute is true, also set
--   by CarController on the local player's car.
--   Broken<Slot> counts from the server (CarDamage) knock parts off, in
--   CarDesign.breakable order. They fly off in the Props collision group,
--   which never touches cars, and are removed after PartLifetime.
--   Fire burns on the hull while the car's Burning attribute is true, set
--   by the server while lava burns it (ScoreService).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarDesign = require(ReplicatedStorage.CarDesign)
local CarParts = require(ReplicatedStorage.CarParts)
local HeliCar = require(ReplicatedStorage.HeliCar)
local PlaneCar = require(ReplicatedStorage.PlaneCar)
local PlaneMorph = require(ReplicatedStorage.PlaneMorph)
local Tuning = require(ReplicatedStorage.Tuning)

local T = Tuning.Toughness
local F = Tuning.JetFlames

local PROPS_GROUP = "Props" -- CollisionGroups.Props, a server module
local HULL_WAIT = 30 -- seconds to wait for a new car's hull to replicate
local WHEEL_NAMES = { "WheelFL", "WheelFR", "WheelRL", "WheelRR" }

-- Cars already given looks, so a car is never built twice.
local built: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function rgb(color: CarDesign.Color): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local BRAKE_GLOW = Color3.fromRGB(255, 70, 30)
local BRAKE_LIGHT_GLOW = Color3.fromRGB(255, 25, 25)

-- A brake part, how it looks unlit, and what it glows while braking.
type Brake = {
	part: BasePart,
	color: Color3,
	material: Enum.Material,
	glow: Color3,
}

-- What a thruster lights up while the jets burn.
type Jet = {
	emitters: { ParticleEmitter },
	glow: PointLight?,
}

-- A PlaneCar tyre on its physics wheel, and where it tucks to as a plane.
type Tyre = {
	wheel: BasePart,
	weld: Weld,
	parts: { BasePart },
	tuck: Vector3, -- in the hull's space
}

-- A flame, smoke, and glow out of the back of a thruster, sized for Jets look
-- step `step`. The thruster's axis is its X, which points toward the nose, so
-- its back end is at -X. The attachment is turned back to the car's own axes,
-- so the emitters' Back is out of the tail.
local function addJet(thruster: BasePart, color: Color3, step: number): Jet
	local k = step + 1
	local attachment = Instance.new("Attachment")
	attachment.Name = "Flame"
	attachment.CFrame = CFrame.new(-thruster.Size.X / 2, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)
	attachment.Parent = thruster

	-- Locked to the thruster, so it stays a flame at any speed instead of
	-- being left behind as a streak of dots.
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "JetFlame"
	flame.Enabled = false
	flame.LockedToPart = true
	flame.EmissionDirection = Enum.NormalId.Back
	flame.Rate = F.FlameRate[k]
	flame.Lifetime = NumberRange.new(F.FlameLife * 0.8, F.FlameLife)
	local speed = F.FlameLength[k] / F.FlameLife
	flame.Speed = NumberRange.new(speed * 0.85, speed)
	flame.SpreadAngle = Vector2.new(4, 4)
	flame.LightEmission = 1
	flame.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.6), color)
	local width = F.FlameWidth[k] * thruster.Size.Y
	flame.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, width), NumberSequenceKeypoint.new(1, width * 0.2) })
	flame.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.8) })
	flame.Parent = attachment

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "JetSmoke"
	smoke.Enabled = false
	smoke.EmissionDirection = Enum.NormalId.Back
	smoke.Rate = F.SmokeRate[k]
	smoke.Lifetime = NumberRange.new(F.SmokeLife * 0.7, F.SmokeLife)
	smoke.Speed = NumberRange.new(2, 5)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Drag = 1
	smoke.Color = ColorSequence.new(F.SmokeColor)
	local puff = F.SmokeSize[k]
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, puff * 0.4), NumberSequenceKeypoint.new(1, puff) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-60, 60)
	smoke.Parent = attachment

	local glow: PointLight? = nil
	if F.GlowRange[k] > 0 then
		local light = Instance.new("PointLight")
		light.Enabled = false
		light.Color = color
		light.Range = F.GlowRange[k]
		light.Brightness = F.GlowBrightness
		light.Parent = attachment
		glow = light
	end
	return { emitters = { flame, smoke }, glow = glow }
end

local function knockOff(part: BasePart, hull: BasePart)
	for _, child in part:GetChildren() do
		if child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
	part.Massless = false
	part.CanCollide = true
	part.CollisionGroup = PROPS_GROUP
	part.Parent = workspace
	local away = part.Position - hull.Position
	local pop = if away.Magnitude > 1e-3 then away.Unit * T.BreakPop else Vector3.zero
	part.AssemblyLinearVelocity = hull.AssemblyLinearVelocity + pop
	Debris:AddItem(part, T.PartLifetime)
end

-- A tiny blocky velociraptor that rides along one side of the Velociraptor
-- car, welded to the hull like the rest of its looks. `side` is -1 or 1 and
-- `zOffset` staggers the pair so they don't sit level with each other.
local function addRaptor(car: Model, hull: BasePart, side: number, zOffset: number)
	local GREEN = Color3.fromRGB(90, 140, 60)
	local BELLY = Color3.fromRGB(130, 160, 70)
	local AMBER = Color3.fromRGB(200, 120, 40)
	local base = hull.CFrame
		* CFrame.new(side * (hull.Size.X / 2 - 0.5), hull.Size.Y / 2, zOffset)

	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = base * offset
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hull
		weld.Part1 = part
		weld.Parent = part
		part.Parent = car
		return part
	end

	-- Body, leaning forward like a sprinting raptor.
	piece("RaptorBody", Vector3.new(0.9, 0.8, 1.7), CFrame.new(0, 1.05, 0) * CFrame.Angles(math.rad(12), 0, 0), GREEN)
	-- Head with a snout and an amber jaw.
	piece("RaptorHead", Vector3.new(0.7, 0.55, 1.1), CFrame.new(0, 1.85, -1.05) * CFrame.Angles(math.rad(18), 0, 0), GREEN)
	piece("RaptorJaw", Vector3.new(0.5, 0.18, 0.6), CFrame.new(0, 1.62, -1.45), AMBER)
	-- Tail, lifted behind.
	piece("RaptorTail", Vector3.new(0.45, 0.45, 1.6), CFrame.new(0, 1.25, 1.35) * CFrame.Angles(math.rad(-14), 0, 0), GREEN)
	-- Legs.
	piece("RaptorLegLeft", Vector3.new(0.25, 0.85, 0.4), CFrame.new(-0.28, 0.42, 0.1), BELLY)
	piece("RaptorLegRight", Vector3.new(0.25, 0.85, 0.4), CFrame.new(0.28, 0.42, 0.1), BELLY)
	-- Little arms, tucked forward.
	piece("RaptorArmLeft", Vector3.new(0.14, 0.4, 0.14), CFrame.new(-0.5, 1.15, -0.45) * CFrame.Angles(math.rad(30), 0, 0), GREEN)
	piece("RaptorArmRight", Vector3.new(0.14, 0.4, 0.14), CFrame.new(0.5, 1.15, -0.45) * CFrame.Angles(math.rad(30), 0, 0), GREEN)
	-- Eyes.
	local eyeLeft = piece("RaptorEyeLeft", Vector3.new(0.18, 0.18, 0.18), CFrame.new(-0.26, 1.98, -1.32), AMBER)
	eyeLeft.Shape = Enum.PartType.Ball
	local eyeRight = piece("RaptorEyeRight", Vector3.new(0.18, 0.18, 0.18), CFrame.new(0.26, 1.98, -1.32), AMBER)
	eyeRight.Shape = Enum.PartType.Ball
end

-- The HeliCar's fixed look in place of the generated one, with trims welded
-- to each wheel so they spin and steer with it. Its jet flame blows out of
-- the back of the roof fan.
--
-- The fan swivels on a Weld from the hull, turned each frame to follow the
-- front wheels. Their angle to the hull comes from physics, which replicates,
-- so every client sees the fan turn, not just the driver's.
local function buildHeliCar(car: Model, hull: BasePart, folder: Folder, flameColor: Color3, jetStep: number): { Jet }
	local function weldTo(base: BasePart, part: BasePart)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = part
		weld.Parent = part
		part.Anchored = false
	end

	local pivot = Instance.new("Part")
	pivot.Name = "FanPivot"
	pivot.Size = Vector3.one * 0.2
	pivot.CFrame = hull.CFrame * HeliCar.fanPivot
	pivot.Transparency = 1
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	pivot.Massless = true
	pivot.Parent = folder
	local swivel = Instance.new("Weld")
	swivel.Part0 = hull
	swivel.Part1 = pivot
	swivel.C0 = HeliCar.fanPivot
	swivel.Parent = pivot

	local jets: { Jet } = {}
	local parts = HeliCar.build(HeliCar.body, hull.CFrame, folder)
	for i, part in parts do
		weldTo(if HeliCar.body[i].swivel then pivot else hull, part)
		if part.Name == "FanHub" then
			table.insert(jets, addJet(part, flameColor, jetStep))
		end
	end
	local fronts: { BasePart } = {}
	for _, name in WHEEL_NAMES do
		local wheel = car:WaitForChild(name, HULL_WAIT)
		if wheel and wheel:IsA("BasePart") then
			for _, part in HeliCar.build(HeliCar.wheels[name], wheel.CFrame, folder) do
				weldTo(wheel, part)
			end
			if name == "WheelFL" or name == "WheelFR" then
				table.insert(fronts, wheel)
			end
		end
	end

	-- A wheel's axle is its x axis; turned left by a steer angle a about the
	-- hull's up axis, it points along (cos a, 0, -sin a) in hull space.
	local yaw = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		if car.Parent == nil then
			connection:Disconnect()
			return
		end
		if #fronts == 0 then
			return
		end
		local steer = 0
		for _, wheel in fronts do
			local axle = hull.CFrame:VectorToObjectSpace(wheel.CFrame.RightVector)
			steer += math.atan2(-axle.Z, axle.X)
		end
		local target = steer / #fronts * HeliCar.FanSteerGain
		yaw += (target - yaw) * (1 - math.exp(-HeliCar.FanTurnRate * dt))
		swivel.C0 = HeliCar.fanPivot * CFrame.Angles(0, yaw, 0)
	end)
	return jets
end

-- The PlaneCar's fixed look in place of the generated one. Each group of
-- parts (body, nose, wings, guns) is welded to a pivot of its own, on a Weld
-- from the hull that PlaneCar.pose moves through the transform: toward a
-- plane while the car's WingsOut attribute is true, toward a car otherwise.
-- A new car starts as whichever it is, without transforming. The jet flame
-- blows out of the back of the body.
--
-- The physics wheels are hidden. A tyre is welded to each through a pivot,
-- so it spins and steers with the wheel, and tucks up into the wing out of
-- sight as the car becomes a plane.
local function buildPlaneCar(car: Model, hull: BasePart, folder: Folder, flameColor: Color3, jetStep: number): { Jet }
	local function pivotOn(base: BasePart, name: string): (BasePart, Weld)
		local pivot = Instance.new("Part")
		pivot.Name = name
		pivot.Size = Vector3.one * 0.2
		pivot.CFrame = base.CFrame
		pivot.Transparency = 1
		pivot.CanCollide = false
		pivot.CanTouch = false
		pivot.CanQuery = false
		pivot.Massless = true
		pivot.Parent = folder
		local weld = Instance.new("Weld")
		weld.Part0 = base
		weld.Part1 = pivot
		weld.Parent = pivot
		return pivot, weld
	end
	-- A Weld, not a WeldConstraint: that keeps whatever offset its parts have
	-- when it reaches the workspace, by when show has moved the pivot.
	local function weldTo(pivot: BasePart, part: BasePart, offset: CFrame)
		local weld = Instance.new("Weld")
		weld.Part0 = pivot
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part
		part.Anchored = false
	end

	local jets: { Jet } = {}
	local poses: { [PlaneCar.Group]: Weld } = {}
	for group, specs in PlaneCar.groups do
		local pivot, weld = pivotOn(hull, "PlanePivot")
		poses[group] = weld
		for i, part in HeliCar.build(specs, hull.CFrame, folder) do
			weldTo(pivot, part, specs[i].cframe)
			if part.Name == "Exhaust" then
				table.insert(jets, addJet(part, flameColor, jetStep))
			end
		end
	end

	local tyres: { Tyre } = {}
	for _, name in WHEEL_NAMES do
		local wheel = car:WaitForChild(name, HULL_WAIT)
		if wheel and wheel:IsA("BasePart") then
			wheel.Transparency = 1
			local pivot, weld = pivotOn(wheel, "TyrePivot")
			local parts = HeliCar.build(PlaneCar.wheel, wheel.CFrame, folder)
			for i, part in parts do
				weldTo(pivot, part, PlaneCar.wheel[i].cframe)
			end
			local side = if string.sub(name, -1) == "L" then 1 else -1
			table.insert(tyres, {
				wheel = wheel,
				weld = weld,
				parts = parts,
				tuck = PlaneCar.WheelTuck * Vector3.new(side, 1, 1),
			})
		end
	end

	local function show(progress: number)
		local stages = PlaneMorph.stages(progress)
		for group, weld in poses do
			weld.C0 = PlaneCar.pose(group, stages)
		end
		local hidden = stages.wheels == 0
		for _, tyre in tyres do
			local tuck = hull.CFrame:VectorToWorldSpace(tyre.tuck * (1 - stages.wheels))
			tyre.weld.C0 = CFrame.new(tyre.wheel.CFrame:VectorToObjectSpace(tuck))
			for _, part in tyre.parts do
				part.Transparency = if hidden then 1 else 0
			end
		end
	end

	local function goal(): number
		return if car:GetAttribute("WingsOut") == true then 0 else 1
	end
	local progress = goal()
	show(progress)
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		if car.Parent == nil then
			connection:Disconnect()
			return
		end
		local target = goal()
		if progress ~= target then
			progress = PlaneMorph.approach(progress, target, dt)
			show(progress)
		end
	end)
	return jets
end

local function setUp(car: Model)
	local hull = car:WaitForChild("Hull", HULL_WAIT)
	if not (hull and hull:IsA("BasePart")) then
		warn(`CarVisuals: {car.Name} has no Hull after {HULL_WAIT}s`)
		return
	end
	if built[car] or car.Parent == nil then
		return
	end
	if car:GetAttribute("FrogCar") == true then
		built[car] = true
		hull.Transparency = 0
		hull.Color = Color3.fromRGB(80, 180, 60)
		hull.Material = Enum.Material.SmoothPlastic
		local function addEye(xOffset: number)
			local eye = Instance.new("Part")
			eye.Shape = Enum.PartType.Ball
			eye.Size = Vector3.new(2.5, 2.5, 2.5)
			eye.CFrame = hull.CFrame * CFrame.new(xOffset, hull.Size.Y / 2 + 1.8, -hull.Size.Z / 2 + 2.5)
			eye.Color = Color3.fromRGB(255, 255, 255)
			eye.Material = Enum.Material.SmoothPlastic
			eye.CanCollide = false
			eye.CanTouch = false
			eye.CanQuery = false
			eye.Massless = true
			eye.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hull
			weld.Part1 = eye
			weld.Parent = eye
			eye.Parent = car
			local pupil = Instance.new("Part")
			pupil.Shape = Enum.PartType.Ball
			pupil.Size = Vector3.new(1, 1, 1)
			pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -1.3)
			pupil.Color = Color3.fromRGB(20, 20, 20)
			pupil.Material = Enum.Material.SmoothPlastic
			pupil.CanCollide = false
			pupil.CanTouch = false
			pupil.CanQuery = false
			pupil.Massless = true
			pupil.Anchored = false
			local pweld = Instance.new("WeldConstraint")
			pweld.Part0 = eye
			pweld.Part1 = pupil
			pweld.Parent = pupil
			pupil.Parent = car
		end
		addEye(-1.8)
		addEye(1.8)
		return
	end
	local design = CarParts.designFor(car)
	if not design then
		warn(`CarVisuals: {car.Name} has no look attributes`)
		return
	end
	built[car] = true
	local heli = car:GetAttribute("HeliCar") == true
	local plane = car:GetAttribute("PlaneCar") == true

	local folder = Instance.new("Folder")
	folder.Name = "Looks"
	local parts = if heli or plane then {} else CarParts.build(design, hull.CFrame, folder)
	local jets: { Jet } = {}
	local jetStep = CarDesign.step(car:GetAttribute("LevelJets") :: number, Tuning.CarLooks.StatSteps)
	if plane then
		jets = buildPlaneCar(car, hull, folder, rgb(design.flameColor), jetStep)
	elseif heli then
		jets = buildHeliCar(car, hull, folder, rgb(design.flameColor), jetStep)
	end
	local brakes: { Brake } = {}
	for i, part in parts do
		local spec = design.parts[i]
		part.CanQuery = false
		local base = hull
		local wheel = spec.wheel
		local hub = if wheel then car:FindFirstChild(`Hub{wheel}`) else nil
		if wheel and hub and hub:IsA("BasePart") then
			-- Built for the hub at rest; moved to wherever the hub is now.
			local center = CarDesign.wheelCenter(wheel, Tuning.CarLooks)
			local fromHub = CFrame.new(-center.x, -center.y, -center.z) * hull.CFrame:ToObjectSpace(part.CFrame)
			part.CFrame = hub.CFrame * fromHub
			base = hub
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = part
		weld.Parent = part
		part.Anchored = false
		if spec.role == "thruster" then
			table.insert(jets, addJet(part, rgb(design.flameColor), jetStep))
		elseif spec.role == "brake" or spec.role == "brakeLight" then
			table.insert(brakes, {
				part = part,
				color = part.Color,
				material = part.Material,
				glow = if spec.role == "brake" then BRAKE_GLOW else BRAKE_LIGHT_GLOW,
			})
		end
	end
	folder.Parent = car

	-- The Velociraptor car carries two little raptors along its sides.
	if car:GetAttribute("CarId") == "Velociraptor" and not (heli or plane) then
		addRaptor(car, hull, -1, -2.5)
		addRaptor(car, hull, 1, 1.5)
	end

	if design.hideWheels and not (heli or plane) then
		for _, name in WHEEL_NAMES do
			local wheel = car:FindFirstChild(name)
			if wheel and wheel:IsA("BasePart") then
				wheel.Transparency = 1
			end
		end
	end

	local function lightFlames()
		local burning = car:GetAttribute("JetsBurning") == true
		for _, jet in jets do
			for _, emitter in jet.emitters do
				emitter.Enabled = burning
			end
			if jet.glow then
				jet.glow.Enabled = burning
			end
		end
	end
	car:GetAttributeChangedSignal("JetsBurning"):Connect(lightFlames)

	local function lightBrakes()
		local braking = car:GetAttribute("Braking") == true
		for _, brake in brakes do
			brake.part.Color = if braking then brake.glow else brake.color
			brake.part.Material = if braking then Enum.Material.Neon else brake.material
		end
	end
	car:GetAttributeChangedSignal("Braking"):Connect(lightBrakes)

	for _, slot in CarParts.Slots do
		local order = if heli or plane then {} else CarDesign.breakable(design, slot)
		local attribute = CarParts.brokenAttribute(slot)
		local shown = 0
		local function showBroken()
			local value = car:GetAttribute(attribute)
			local broken = math.min(if typeof(value) == "number" then value else 0, #order)
			for k = shown + 1, broken do
				knockOff(parts[order[k]], hull)
			end
			shown = math.max(shown, broken)
		end
		car:GetAttributeChangedSignal(attribute):Connect(showBroken)
		showBroken()
	end

	local fire = Instance.new("Fire")
	fire.Size = T.LavaFireSize
	fire.Heat = T.LavaFireSize * 1.5
	fire.Enabled = false
	fire.Parent = hull
	local function showBurning()
		fire.Enabled = car:GetAttribute("Burning") == true
	end
	car:GetAttributeChangedSignal("Burning"):Connect(showBurning)
	showBurning()
end

local carsFolder = workspace:WaitForChild("Cars")
carsFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		setUp(child)
	end
end)
for _, child in carsFolder:GetChildren() do
	if child:IsA("Model") then
		task.spawn(setUp, child)
	end
end
