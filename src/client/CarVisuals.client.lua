--!strict
-- CarVisuals (LocalScript) -> StarterPlayerScripts.CarVisuals
-- Builds the looks of every car in workspace.Cars on this client. The server
-- sends only the car's look attributes (CarParts), so every client makes the
-- same parts from CarDesign and welds them to the hull in a Looks folder.
-- They are massless and out of physics, so handling comes only from stats.
--
-- Also, on each car:
--   Hover cars hide their wheels. The physics wheels are still there.
--   Each thruster gets a flame, a smoke trail, and a glow that grow with the
--   car's Jets level (Tuning.JetFlames), lit while the car's JetsBurning
--   attribute is true. CarController sets it on the local player's car.
--   Broken<Slot> counts from the server (CarDamage) knock parts off, in
--   CarDesign.breakable order. They fly off in the Props collision group,
--   which never touches cars, and are removed after PartLifetime.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarDesign = require(ReplicatedStorage.CarDesign)
local CarParts = require(ReplicatedStorage.CarParts)
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

-- What a thruster lights up while the jets burn.
type Jet = {
	emitters: { ParticleEmitter },
	glow: PointLight?,
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

	local folder = Instance.new("Folder")
	folder.Name = "Looks"
	local parts = CarParts.build(design, hull.CFrame, folder)
	local jets: { Jet } = {}
	local jetStep = CarDesign.step(car:GetAttribute("LevelJets") :: number, Tuning.CarLooks.StatSteps)
	for i, part in parts do
		part.CanQuery = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hull
		weld.Part1 = part
		weld.Parent = part
		part.Anchored = false
		if design.parts[i].role == "thruster" then
			table.insert(jets, addJet(part, rgb(design.flameColor), jetStep))
		end
	end
	folder.Parent = car

	if design.hideWheels then
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

	for _, slot in CarParts.Slots do
		local order = CarDesign.breakable(design, slot)
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
