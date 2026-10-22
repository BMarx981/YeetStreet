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
--
-- A Model with a Shatter attribute is one target: hitting any of its props
-- knocks all of them, each also thrown out from the hit. A prop with a Target
-- attribute (such as a billboard tile) is something worth points to smash:
-- the car and the Target go out on ServerStorage.PropSmashed, once per hit
-- however many props fly, and ScoreService counts it on the car's run. A
-- prop with FallOnCar set (such as a coconut) is not thrown: it drops, with
-- just enough sideways speed to land where the car was when it hit (Fall),
-- moved over by its FallOffset (a Vector3) if it has one, so a few dropped
-- together land around the car instead of on one spot.
-- A prop with Trigger set (such as an invisible hit box round a tree) only
-- counts the hit: it stays where it is.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Fall = require(ReplicatedStorage.Fall)
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

local propSmashed = Instance.new("BindableEvent")
propSmashed.Name = "PropSmashed"
propSmashed.Parent = ServerStorage

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

local function knock(prop: Prop, carVelocity: Vector3, burst: Vector3, carAt: Vector3)
	local part = prop.part
	prop.down = true
	part.Anchored = part:GetAttribute("Trigger") == true
	local falls = part:GetAttribute("FallOnCar") == true
	if falls then
		local from = part.Position
		local offset = part:GetAttribute("FallOffset")
		local to = if typeof(offset) == "Vector3" then carAt + offset else carAt
		local vx, vz = Fall.toward(to.X - from.X, to.Z - from.Z, from.Y - to.Y, workspace.Gravity)
		-- The server keeps it, or Roblox hands it to the nearest player,
		-- whose copy can start off a little different and drift wide.
		part:SetNetworkOwner(nil)
		part.AssemblyLinearVelocity = Vector3.new(vx, 0, vz)
	else
		local share = part:GetAttribute("CarSpeedShare")
		part.AssemblyLinearVelocity = carVelocity * (if typeof(share) == "number" then share else P.CarSpeedShare)
			+ Vector3.new(0, P.Pop, 0)
			+ burst
	end
	local flat = Vector3.new(carVelocity.X, 0, carVelocity.Z)
	if flat.Magnitude > 1e-3 and not falls then
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

-- Knocks the prop the car hit, and the rest of its Model if that shatters.
local function hit(car: Model, prop: Prop, carVelocity: Vector3, at: Vector3)
	local group = prop.part.Parent
	if group and group:IsA("Model") and group:GetAttribute("Shatter") == true then
		for _, other in props do
			if other.part.Parent == group and not other.down then
				local out = other.part.Position - at
				knock(other, carVelocity, if out.Magnitude > 1e-3 then out.Unit * P.ShatterBurst else Vector3.zero, at)
			end
		end
	else
		knock(prop, carVelocity, Vector3.zero, at)
	end
	local target = prop.part:GetAttribute("Target")
	if typeof(target) == "string" then
		propSmashed:Fire(car, target)
	end
end

-- Knocks every standing prop the hull passed through since the last step.
local function sweep(car: Model, from: Vector3, to: Vector3, carVelocity: Vector3)
	local r = P.HitRadius
	for _, prop in props do
		if not prop.down then
			local a = prop.home:PointToObjectSpace(from)
			local b = prop.home:PointToObjectSpace(to)
			local half = prop.part.Size / 2
			if Sweep.hitsBox(a.X, a.Y, a.Z, b.X, b.Y, b.Z, half.X + r, half.Y + r, half.Z + r) then
				hit(car, prop, carVelocity, to)
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
		if car:IsA("Model") and hull and hull:IsA("BasePart") then
			local to = hull.Position
			local from = lastPositions[hull] or to
			lastPositions[hull] = to
			-- A reset teleports the car; it did not fly through what lies between.
			if (to - from).Magnitude <= Tuning.Run.TeleportDistance then
				sweep(car, from, to, hull.AssemblyLinearVelocity)
			end
		end
	end
end)
