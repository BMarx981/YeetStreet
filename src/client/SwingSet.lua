--!strict
-- SwingSet (ModuleScript) -> StarterPlayerScripts.SwingSet
-- Builds this client's own seat for every giant swing (Swings) and moves it
-- every physics step. The server has no seats, only each swing's state
-- (SwingService).
--
-- A swing this client's car doesn't ride follows the server: it steps on
-- here, and is pulled toward the State the server last sent (stepped on too,
-- since it arrived) at Tuning.Swing.Follow, so it moves smoothly between
-- sends. The swing the car rides is `driven`: SwingRide steps it and calls
-- place.
--
-- A seat is a plank with a rod up to the pivot at each side. Only the plank
-- collides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Swing = require(ReplicatedStorage.Swing)
local Swings = require(ReplicatedStorage.Swings)
local Tuning = require(ReplicatedStorage.Tuning)

local SwingSet = {}

local PLANK_COLOR = Color3.fromRGB(230, 170, 40)
local ROD_COLOR = Color3.fromRGB(60, 60, 66)
local TAU = 2 * math.pi

type Look = {
	seat: Model,
	server: Swing.State, -- the server's last State, stepped on since
}

local looks: { [Model]: Look } = {}

-- The seat hanging still, with its pivot on the swing's.
local function build(entry: Swings.Entry): Model
	local S = Tuning.Swing
	local seat = Instance.new("Model")
	seat.Name = "Seat"

	local plank = Instance.new("Part")
	plank.Name = "Plank"
	plank.Anchored = true
	plank.Size = Vector3.new(S.SeatWidth, S.SeatThickness, S.SeatDepth)
	plank.CFrame = entry.pivot * CFrame.new(0, -S.Length - S.SeatThickness / 2, 0)
	plank.Color = PLANK_COLOR
	plank.Material = Enum.Material.WoodPlanks
	plank.TopSurface = Enum.SurfaceType.Smooth
	plank.BottomSurface = Enum.SurfaceType.Smooth
	plank.Parent = seat

	for _, side in { -1, 1 } do
		local rod = Instance.new("Part")
		rod.Name = "Rod"
		rod.Anchored = true
		rod.CanCollide = false
		rod.CanQuery = false
		rod.CanTouch = false
		rod.Size = Vector3.new(0.8, S.Length, 0.8)
		rod.CFrame = entry.pivot * CFrame.new(side * (S.SeatWidth / 2 - 0.4), -S.Length / 2, 0)
		rod.Color = ROD_COLOR
		rod.Material = Enum.Material.Metal
		rod.Parent = seat
	end

	seat.WorldPivot = entry.pivot
	seat.Parent = entry.model
	return seat
end

local function serverState(model: Model): Swing.State?
	local value = model:GetAttribute("State")
	return if typeof(value) == "Vector2" then { angle = value.X, speed = value.Y } else nil
end

local function lookFor(entry: Swings.Entry): Look
	local existing = looks[entry.model]
	if existing then
		return existing
	end
	local look: Look = {
		seat = build(entry),
		server = serverState(entry.model) or table.clone(entry.state),
	}
	entry.model:GetAttributeChangedSignal("State"):Connect(function()
		local state = serverState(entry.model)
		if state then
			look.server = state
		end
	end)
	entry.model:GetAttributeChangedSignal("RiderId"):Connect(function()
		local rider = entry.model:GetAttribute("RiderId")
		if not entry.driven then
			entry.riderId = if typeof(rider) == "number" then rider else 0
		end
	end)
	looks[entry.model] = look
	return look
end

-- Moves the swing's seat to the swing's angle.
function SwingSet.place(entry: Swings.Entry)
	local look = looks[entry.model]
	if look then
		look.seat:PivotTo(entry.pivot * CFrame.Angles(entry.state.angle, 0, 0))
	end
end

function SwingSet.start()
	RunService.PreSimulation:Connect(function(dt: number)
		local S = Tuning.Swing
		local all = Swings.all()
		for model in looks do
			if not all[model] then
				looks[model] = nil
			end
		end
		for _, entry in all do
			local look = lookFor(entry)
			if not entry.driven then
				Swing.step(look.server, 0, dt, S)
				Swing.step(entry.state, 0, dt, S)
				local pull = math.min(S.Follow * dt, 1)
				local behind = (look.server.angle - entry.state.angle + math.pi) % TAU - math.pi
				entry.state.angle += behind * pull
				entry.state.speed += (look.server.speed - entry.state.speed) * pull
				SwingSet.place(entry)
			end
		end
	end)
end

return SwingSet
