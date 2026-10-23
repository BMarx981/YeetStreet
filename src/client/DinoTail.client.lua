--!strict
-- DinoTail (LocalScript) -> StarterPlayerScripts.DinoTail
-- The tip of the brontosaurus's tail in Dino Valley (Parks.Dino), past where
-- the ride's path starts: a row of blocks lying on the ground behind it,
-- narrowing from the width of the skin's flat middle where the path starts
-- to a point, and swishing side to side. Dark spots and booster stripes
-- carry on along it from the back. This client builds and moves its own,
-- timed from the server's clock so every player sees the same swish. Only
-- for looks: cars drive straight through it. Numbers are in
-- Tuning.Dino.Bronto.Tail.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

-- On the ground at the path's start, facing up the path, so the tail runs
-- back along +Z.
local root = CFrame.new(area.X + B.X, FLOOR, area.Z + B.StartZ) * CFrame.Angles(0, math.rad(B.Heading), 0)
local length = T.Length / T.Segments
local rootWidth = B.Start.Width * B.Crown.Flat

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
for i = 1, T.Segments do
	local t = (i - 0.5) / T.Segments
	table.insert(
		blocks,
		block("Tail", Vector3.new(rootWidth + (T.TipWidth - rootWidth) * t, T.Height, length + 0.4), COLOR)
	)
end

-- Parts riding on a block, placed from that block's middle.
type Rider = { part: Part, on: number, offset: CFrame }
local riders: { Rider } = {}

-- Where `back` studs behind the path's start falls: the block it is on and
-- how far along that block from its middle.
local function blockAt(back: number): (number, number)
	local on = math.clamp(math.floor(back / length) + 1, 1, T.Segments)
	return on, back - (on - 0.5) * length
end

-- The back's boosters come every BoostEvery planks of Step, the last one
-- just before the path's start, so the stripes carry on back from there.
local every = B.BoostEvery * B.Step
local back = 0
while back + B.Step <= T.Length do
	local on, z = blockAt(back + B.Step / 2)
	local size = blocks[on].Size
	local stripe = block("Stripe", Vector3.new(size.X + 0.1, size.Y + 0.1, B.Step), STRIPE_COLOR)
	stripe.Material = Enum.Material.Neon
	table.insert(riders, { part = stripe, on = on, offset = CFrame.new(0, 0, z) })
	back += every
end

local S = B.Spots
local random = Random.new(S.Seed)
for _ = 1, T.Spots do
	local on, z = blockAt(random:NextNumber(0, T.Length * 0.8))
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

-- Each joint bends the same share of the swing, a little later than the one
-- before it, so a wave runs out to the tip.
RunService.RenderStepped:Connect(function()
	local phase = workspace:GetServerTimeNow() * 2 * math.pi / T.Period
	local bend = math.rad(T.Swing) / T.Segments
	local joint = root
	for i, part in blocks do
		joint *= CFrame.Angles(0, bend * math.sin(phase - i * 0.5), 0)
		part.CFrame = joint * CFrame.new(0, T.Height / 2, length / 2)
		joint *= CFrame.new(0, 0, length)
	end
	for _, rider in riders do
		rider.part.CFrame = blocks[rider.on].CFrame * rider.offset
	end
end)
