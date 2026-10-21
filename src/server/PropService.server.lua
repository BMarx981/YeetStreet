--!strict
-- PropService (Script) -> ServerScriptService.PropService
-- Parts tagged Knockable (the distance boards) get knocked flying when a car
-- passes through them, then snap back after Tuning.Props.ResetTime. A part's
-- own ResetTime and CarSpeedShare attributes override Tuning.Props. A prop
-- can have other parts welded to it, which fly with it.
--
-- Props never touch cars: they are in the Props collision group, which does
-- not collide with cars or drivers, and car raycasts skip them (CarSensor). So
-- a prop never changes where a car goes or when it lands. Hits come from each
-- car's hull path between Heartbeats (Sweep), so a fast car cannot skip past a
-- thin board.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Sweep = require(ReplicatedStorage.Sweep)
local Tuning = require(ReplicatedStorage.Tuning)
local CollisionGroups = require(ServerScriptService.CollisionGroups)

local P = Tuning.Props

local TAG = "Knockable"

type Prop = {
	part: BasePart,
	home: CFrame,
	down: boolean,
}

local props: { [BasePart]: Prop } = {}
-- Each car hull's position at the last Heartbeat.
local lastPositions: { [BasePart]: Vector3 } = {}

local function adopt(instance: Instance)
	if not instance:IsA("BasePart") or props[instance] then
		return
	end
	instance.CollisionGroup = CollisionGroups.Props
	props[instance] = { part = instance, home = instance.CFrame, down = false }
end

local function forget(instance: Instance)
	if instance:IsA("BasePart") then
		props[instance] = nil
	end
end

for _, instance in CollectionService:GetTagged(TAG) do
	adopt(instance)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(adopt)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(forget)

local function knock(prop: Prop, carVelocity: Vector3)
	local part = prop.part
	prop.down = true
	part.Anchored = false
	local share = part:GetAttribute("CarSpeedShare")
	part.AssemblyLinearVelocity = carVelocity * (if typeof(share) == "number" then share else P.CarSpeedShare)
		+ Vector3.new(0, P.Pop, 0)
	local flat = Vector3.new(carVelocity.X, 0, carVelocity.Z)
	if flat.Magnitude > 1e-3 then
		-- About the level axis across the car's path (up cross travel), so the
		-- top tips away from the car.
		part.AssemblyAngularVelocity = Vector3.new(flat.Z, 0, -flat.X).Unit * P.Spin
	end

	local resetTime = part:GetAttribute("ResetTime")
	task.delay(if typeof(resetTime) == "number" then resetTime else P.ResetTime, function()
		if props[part] ~= prop then
			return
		end
		part.Anchored = true
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
		part.CFrame = prop.home
		prop.down = false
	end)
end

-- Knocks every standing prop the hull passed through since the last step.
local function sweep(from: Vector3, to: Vector3, carVelocity: Vector3)
	local r = P.HitRadius
	for _, prop in props do
		if not prop.down then
			local a = prop.home:PointToObjectSpace(from)
			local b = prop.home:PointToObjectSpace(to)
			local half = prop.part.Size / 2
			if Sweep.hitsBox(a.X, a.Y, a.Z, b.X, b.Y, b.Z, half.X + r, half.Y + r, half.Z + r) then
				knock(prop, carVelocity)
			end
		end
	end
end

local carsFolder = workspace:WaitForChild("Cars")

RunService.Heartbeat:Connect(function()
	for hull in lastPositions do
		if not hull:IsDescendantOf(carsFolder) then
			lastPositions[hull] = nil
		end
	end
	for _, car in carsFolder:GetChildren() do
		local hull = car:FindFirstChild("Hull")
		if hull and hull:IsA("BasePart") then
			local to = hull.Position
			local from = lastPositions[hull] or to
			lastPositions[hull] = to
			-- A reset teleports the car; it did not fly through what lies between.
			if (to - from).Magnitude <= Tuning.Run.TeleportDistance then
				sweep(from, to, hull.AssemblyLinearVelocity)
			end
		end
	end
end)
