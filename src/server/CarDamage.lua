--!strict
-- CarDamage (ModuleScript) -> ServerScriptService.CarDamage
-- Knocks breakable parts off a car. Breakable parts are the Body parts with a
-- Slot attribute (CarBuilder). Breaking one removes its weld to the hull and
-- moves it out of the car into the Props collision group, so it tumbles to the
-- ground without ever touching a car, then is removed after PartLifetime. A
-- wreck breaks every part left and bursts into sparks. A respawned car is
-- built fresh, with every part back.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Tuning = require(ReplicatedStorage.Tuning)
local CollisionGroups = require(ServerScriptService.CollisionGroups)

local T = Tuning.Toughness

local CarDamage = {}

local SPARK_COLOR = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 120, 30))
-- The burst emits for this long. A property change replicates to every
-- client, where particles are drawn, which a server Emit call may not.
local SPARK_TIME = 0.15

local function breakOff(part: BasePart, hull: BasePart)
	for _, child in part:GetChildren() do
		if child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
	part.Massless = false
	part.CanCollide = true
	part.CollisionGroup = CollisionGroups.Props
	part.Parent = workspace
	local away = part.Position - hull.Position
	local pop = if away.Magnitude > 1e-3 then away.Unit * T.BreakPop else Vector3.zero
	part.AssemblyLinearVelocity = hull.AssemblyLinearVelocity + pop
	Debris:AddItem(part, T.PartLifetime)
end

-- Breaks up to `count` parts in `slot`, or in any slot when `slot` is nil.
-- Returns how many broke, which is fewer once there are none left to break.
function CarDamage.breakParts(car: Model, slot: string?, count: number): number
	local body = car:FindFirstChild("Body")
	local hull = car:FindFirstChild("Hull")
	if not (body and hull and hull:IsA("BasePart")) then
		return 0
	end

	local broken = 0
	for _, part in body:GetChildren() do
		if broken >= count then
			break
		end
		local partSlot = part:GetAttribute("Slot")
		if part:IsA("BasePart") and partSlot ~= nil and (slot == nil or partSlot == slot) then
			breakOff(part, hull)
			broken += 1
		end
	end
	return broken
end

-- Breaks every part left and bursts into sparks where the car is. Returns how
-- many parts broke. The car itself is replaced by the respawn.
function CarDamage.wreck(car: Model): number
	local hull = car:FindFirstChild("Hull")
	if not (hull and hull:IsA("BasePart")) then
		return 0
	end
	local broken = CarDamage.breakParts(car, nil, math.huge)

	local burst = Instance.new("Part")
	burst.Name = "WreckSparks"
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.Transparency = 1
	burst.Size = Vector3.one
	burst.CFrame = CFrame.new(hull.Position)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = T.WreckSparks / SPARK_TIME
	sparks.Speed = NumberRange.new(30, 70)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(0.4, 0.9)
	sparks.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
	sparks.LightEmission = 1
	sparks.Color = SPARK_COLOR
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Parent = burst
	burst.Parent = workspace
	task.delay(SPARK_TIME, function()
		sparks.Enabled = false
	end)
	Debris:AddItem(burst, 2)
	return broken
end

return CarDamage
