--!strict
-- CarDamage (ModuleScript) -> ServerScriptService.CarDamage
-- Knocks breakable parts off a car. Breakable parts are the Body parts with a
-- Slot attribute (CarBuilder). Breaking one removes its weld to the hull and
-- moves it out of the car into the Props collision group, so it tumbles to the
-- ground without ever touching a car, then is removed after PartLifetime. A
-- respawned car is built fresh, with every part back.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Tuning = require(ReplicatedStorage.Tuning)
local CollisionGroups = require(ServerScriptService.CollisionGroups)

local T = Tuning.Toughness

local CarDamage = {}

-- Breaks up to `count` parts in `slot` and returns how many broke, which is
-- fewer once the slot runs out of parts.
function CarDamage.breakParts(car: Model, slot: string, count: number): number
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
		if part:IsA("BasePart") and part:GetAttribute("Slot") == slot then
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
			broken += 1
		end
	end
	return broken
end

return CarDamage
