--!strict
-- DinoTail (LocalScript) -> StarterPlayerScripts.DinoTail
-- The tip of the brontosaurus's tail in Dino Valley (Parks.Dino): a row of
-- blocks lying on the ground, narrowing to a point and swishing side to
-- side. The ride's path starts flat on the ground and its rounded sides
-- sink into it, so the tail starts a little way up the path, where the path
-- has risen to the tail's height, as wide as the back is halfway down to the
-- ground there, and runs back over the path's start to Length past it. Dark
-- spots and booster stripes carry on along it from the back. This client
-- builds and moves its own, timed from the server's clock so every player
-- sees the same swish. Only for looks: cars drive straight through it.
-- Numbers are in Tuning.Dino.Bronto.Tail.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bronto = require(ReplicatedStorage.Bronto)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)

local B = Tuning.Dino.Bronto
local T = B.Tail
local FLOOR = Tuning.Map.FloorTop

local COLOR = Color3.fromRGB(104, 150, 86)
local SPOT_COLOR = Color3.fromRGB(66, 98, 56)
local STRIPE_COLOR = Color3.fromRGB(255, 200, 40)

local area = MapLayout.find(Tuning.Map.Areas :: any, "Dino")
if not area then
	return
end

local planks = Bronto.planks(B.Start, B.Segments, B.Step)
local rise = Bronto.alongAt(planks, T.Height)
local riseOut = Bronto.pointAt(planks, rise)
local riseWidth = Bronto.plankAt(planks, rise).width
local rootWidth = Bronto.crownWidth(riseWidth, B.Crown.Flat, B.Crown.Drop, T.Height / 2)
local total = rise + T.Length
local segments = math.ceil(total / (T.Length / T.Segments))
local length = total / segments

-- On the ground under where the path reaches the tail's height, facing up
-- the path, so the tail runs back along +Z.
local root = CFrame.new(area.X + B.X, FLOOR, area.Z + B.StartZ)
	* CFrame.Angles(0, math.rad(B.Heading), 0)
	* CFrame.new(0, 0, -riseOut)

local folder = Instance.new("Folder")
folder.Name = "DinoTail"
folder.Parent = workspace

local function block(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

local blocks: { Part } = {}
for i = 1, segments do
	local t = (i - 0.5) / segments
	table.insert(
		blocks,
		block("Tail", Vector3.new(rootWidth + (T.TipWidth - rootWidth) * t, T.Height, length + 0.4), COLOR)
	)
end

-- Parts riding on a block, placed from that block's middle.
type Rider = { part: Part, on: number, offset: CFrame }
local riders: { Rider } = {}

-- Where `back` studs behind the root falls: the block it is on and how far
-- along that block from its middle.
local function blockAt(back: number): (number, number)
	local on = math.clamp(math.floor(back / length) + 1, 1, segments)
	return on, back - (on - 0.5) * length
end

-- The back's boosters are every BoostEvery planks of Step up the tail, each
-- ending a multiple of BoostEvery times Step along the path, so the stripes
-- carry on back over the path's start from there.
local every = B.BoostEvery * B.Step
local stripeEnd = math.floor(rise / every) * every
while rise - stripeEnd + B.Step <= total do
	local on, z = blockAt(rise - stripeEnd + B.Step / 2)
	local size = blocks[on].Size
	local stripe = block("Stripe", Vector3.new(size.X + 0.1, size.Y + 0.1, B.Step), STRIPE_COLOR)
	stripe.Material = Enum.Material.Neon
	table.insert(riders, { part = stripe, on = on, offset = CFrame.new(0, 0, z) })
	stripeEnd -= every
end

local S = B.Spots
local random = Random.new(S.Seed)
for _ = 1, T.Spots do
	local on, z = blockAt(random:NextNumber(0, total * 0.8))
	local half = blocks[on].Size.X / 2
	local size = math.min(random:NextNumber(S.MinSize, S.MaxSize), half)
	local x = random:NextNumber(-(half - size / 2), half - size / 2)
	local spot = block("Spot", Vector3.new(size, 0.1, size * random:NextNumber(0.6, 1)), SPOT_COLOR)
	table.insert(riders, {
		part = spot,
		on = on,
		offset = CFrame.new(x, T.Height / 2 + 0.06, z) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0),
	})
end

-- The blocks over the path lie still on it. From the path's start, each
-- joint bends the same share of the swing, a little later than the one
-- before it, so a wave runs out to the tip.
local still = math.floor(rise / length + 0.5)
RunService.RenderStepped:Connect(function()
	local phase = workspace:GetServerTimeNow() * 2 * math.pi / T.Period
	local bend = math.rad(T.Swing) / (segments - still)
	local joint = root
	for i, part in blocks do
		if i > still then
			joint *= CFrame.Angles(0, bend * math.sin(phase - (i - still) * 0.5), 0)
		end
		part.CFrame = joint * CFrame.new(0, T.Height / 2, length / 2)
		joint *= CFrame.new(0, 0, length)
	end
	for _, rider in riders do
		rider.part.CFrame = blocks[rider.on].CFrame * rider.offset
	end
end)
