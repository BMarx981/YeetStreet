--!strict
-- BushRustle (LocalScript) -> StarterPlayerScripts.BushRustle
-- Shakes Dino Valley's bushes (workspace.Parks.Dino.Bushes, built by
-- Parks.Dino) on this client while a car or a raptor moves through them
-- (so a bush bursts as raptors run out of it), each leafy ball swinging
-- about the bush's foot on its own beat, and lets them settle once it is
-- gone (Bush). Only for looks: the server never moves them.
-- Numbers are in Tuning.Dino.Bushes.Rustle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bush = require(ReplicatedStorage.Bush)
local Tuning = require(ReplicatedStorage.Tuning)

local B = Tuning.Dino.Bushes

type State = {
	foot: CFrame,
	top: number,
	radius: number,
	parts: { BasePart },
	rest: { CFrame }, -- each part in the foot's frame
	level: number,
	phase: number,
}

local dino = workspace:WaitForChild("Parks"):WaitForChild("Dino")
local bushes = dino:WaitForChild("Bushes")
-- Only one copy rustles, if Rojo has synced this script twice.
if bushes:GetAttribute("Rustled") then
	return
end
bushes:SetAttribute("Rustled", true)
local carsFolder = workspace:WaitForChild("Cars")

-- Forgotten when a bush streams away, so it is looked at afresh on return.
local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any
local count = 0

local function stateOf(model: Model): State
	local state = states[model]
	if state then
		return state
	end
	local foot = model.WorldPivot
	local parts, rest = {}, {}
	local top = 0
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
			table.insert(rest, foot:ToObjectSpace(part.CFrame))
			top = math.max(top, part.Position.Y + part.Size.Y / 2 - foot.Y)
		end
	end
	count += 1
	local made: State = {
		foot = foot,
		top = top,
		radius = model:GetAttribute("Radius") or 10,
		parts = parts,
		rest = rest,
		level = 0,
		phase = count * 1.7,
	}
	states[model] = made
	return made
end

-- Something that rustles a bush: where it is and how fast it moves.
type Mover = { position: Vector3, speed: number }

-- The fastest mover with its middle inside the bush, if any.
local function speedInside(state: State, movers: { Mover }): number?
	local fastest: number? = nil
	for _, mover in movers do
		local offset = mover.position - state.foot.Position
		local flat = Vector2.new(offset.X, offset.Z).Magnitude
		if flat < state.radius and offset.Y < state.top then
			fastest = math.max(fastest or 0, mover.speed)
		end
	end
	return fastest
end

-- Where each raptor was last step, for its speed: the server moves it
-- without a velocity.
local lastAt: { [BasePart]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any

local moved: { BasePart } = {}
local to: { CFrame } = {}

RunService.Heartbeat:Connect(function(dt: number)
	local movers: { Mover } = {}
	for _, car in carsFolder:GetChildren() do
		local hull = if car:IsA("Model") then car.PrimaryPart else nil
		if hull then
			table.insert(movers, { position = hull.Position, speed = hull.AssemblyLinearVelocity.Magnitude })
		end
	end
	local raptors = dino:FindFirstChild("Raptors")
	for _, raptor in if raptors then raptors:GetChildren() else {} do
		if raptor:IsA("BasePart") then
			local at = raptor.Position
			local last = lastAt[raptor]
			lastAt[raptor] = at
			if last then
				table.insert(movers, { position = at, speed = (at - last).Magnitude / dt })
			end
		end
	end
	local now = workspace:GetServerTimeNow()
	table.clear(moved)
	table.clear(to)
	for _, model in bushes:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local state = stateOf(model)
		local speed = speedInside(state, movers)
		local was = state.level
		state.level = Bush.rustle(was, speed ~= nil, speed or 0, dt, B.Rustle)
		if was == 0 and state.level == 0 then
			continue
		end
		for i, part in state.parts do
			local pitch = Bush.sway(state.level, now, state.phase + i * 0.7, B.Rustle)
			local roll = Bush.sway(state.level, now * 1.3, state.phase + i * 1.9, B.Rustle) * 0.6
			table.insert(moved, part)
			table.insert(to, state.foot * CFrame.Angles(pitch, 0, roll) * state.rest[i])
		end
	end
	if #moved > 0 then
		workspace:BulkMoveTo(moved, to, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
