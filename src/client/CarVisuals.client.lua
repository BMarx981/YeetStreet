--!strict
-- CarVisuals (LocalScript) -> StarterPlayerScripts.CarVisuals
-- Builds the looks of every car in workspace.Cars on this client. The server
-- sends only the car's look attributes (CarParts), so every client makes the
-- same parts from CarDesign and welds them to the hull in a Looks folder.
-- They are massless and out of physics, so handling comes only from stats.
--
-- Also, on each car:
--   Hover cars hide their wheels. The physics wheels are still there.
--   Each thruster gets a JetFlame, lit while the car's JetsBurning attribute
--   is true. CarController sets it on the local player's car.
--   Broken<Slot> counts from the server (CarDamage) knock parts off, in
--   CarDesign.breakable order. They fly off in the Props collision group,
--   which never touches cars, and are removed after PartLifetime.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarDesign = require(ReplicatedStorage.CarDesign)
local CarParts = require(ReplicatedStorage.CarParts)
local Tuning = require(ReplicatedStorage.Tuning)

local T = Tuning.Toughness

local PROPS_GROUP = "Props" -- CollisionGroups.Props, a server module
local HULL_WAIT = 30 -- seconds to wait for a new car's hull to replicate
local WHEEL_NAMES = { "WheelFL", "WheelFR", "WheelRL", "WheelRR" }

-- Cars already given looks, so a car is never built twice.
local built: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function rgb(color: CarDesign.Color): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- A flame out of the back of a thruster. The thruster's axis is its X, which
-- points toward the nose, so its back end is at -X. The attachment is turned
-- back to the car's own axes, so the emitter's Back is out of the tail.
local function addFlame(thruster: BasePart, color: Color3): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = "Flame"
	attachment.CFrame = CFrame.new(-thruster.Size.X / 2, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)
	attachment.Parent = thruster
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "JetFlame"
	flame.Enabled = false
	flame.EmissionDirection = Enum.NormalId.Back
	flame.Rate = 120
	flame.Lifetime = NumberRange.new(0.15, 0.3)
	flame.Speed = NumberRange.new(30, 40)
	flame.SpreadAngle = Vector2.new(6, 6)
	flame.LightEmission = 1
	flame.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5), color)
	local size = 0.9 * thruster.Size.Y
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	flame.Parent = attachment
	return flame
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
	local design = CarParts.designFor(car)
	if not design then
		warn(`CarVisuals: {car.Name} has no look attributes`)
		return
	end
	built[car] = true

	local folder = Instance.new("Folder")
	folder.Name = "Looks"
	local parts = CarParts.build(design, hull.CFrame, folder)
	local flames: { ParticleEmitter } = {}
	for i, part in parts do
		part.CanQuery = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hull
		weld.Part1 = part
		weld.Parent = part
		part.Anchored = false
		if design.parts[i].role == "thruster" then
			table.insert(flames, addFlame(part, rgb(design.flameColor)))
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
		for _, flame in flames do
			flame.Enabled = burning
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
