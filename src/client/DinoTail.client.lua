--!strict
-- DinoTail (LocalScript) -> StarterPlayerScripts.DinoTail
-- The tip of the brontosaurus's tail in Dino Valley (Parks.Dino), past where
-- the ride's path starts: a row of blocks lying on the ground behind it,
-- narrowing to a point and swishing side to side. This client builds and
-- moves its own, timed from the server's clock so every player sees the same
-- swish. Only for looks: cars drive straight through it. Numbers are in
-- Tuning.Dino.Bronto.Tail.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)

local B = Tuning.Dino.Bronto
local T = B.Tail
local FLOOR = Tuning.Map.FloorTop

local COLOR = Color3.fromRGB(104, 150, 86)

local area = MapLayout.find(Tuning.Map.Areas :: any, "Dino")
if not area then
	return
end

-- On the ground at the path's start, facing up the path, so the tail runs
-- back along +Z.
local root = CFrame.new(area.X + B.X, FLOOR, area.Z + B.StartZ) * CFrame.Angles(0, math.rad(B.Heading), 0)
local length = T.Length / T.Segments

local folder = Instance.new("Folder")
folder.Name = "DinoTail"
folder.Parent = workspace

local blocks: { Part } = {}
for i = 1, T.Segments do
	local t = (i - 0.5) / T.Segments
	local part = Instance.new("Part")
	part.Name = "Tail"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.new(B.Start.Width + (T.TipWidth - B.Start.Width) * t, T.Height, length + 0.4)
	part.Color = COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	table.insert(blocks, part)
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
end)
