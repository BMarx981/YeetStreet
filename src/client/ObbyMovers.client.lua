--!strict
-- ObbyMovers (LocalScript) -> StarterPlayerScripts.ObbyMovers
-- Builds this client's own copy of the car obby's moving platforms (the
-- Mover pieces of ObbyCourse's layout, which ObbyBuilder leaves out) and
-- moves them every step from the server's clock (ObbyMover), so every
-- player sees them in the same place. The driver's client simulates its own
-- car, so its car rides on its own copy. Each step a platform also gets the
-- velocity it is moving at, so a car on it moves with it instead of sliding.
--
-- Like the obby's other parts, each has an invisible Shoulder copy,
-- ShoulderWidth wider on each side, that only wheels touch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ObbyCourse = require(ReplicatedStorage.ObbyCourse)
local ObbyMover = require(ReplicatedStorage.ObbyMover)
local Tuning = require(ReplicatedStorage.Tuning)

local COLORS = Tuning.Obby.StageColors
local SHOULDERS = "Shoulders" -- CollisionGroups.Shoulders, registered by the server

type Platform = {
	mover: ObbyMover.Mover,
	rest: CFrame,
	parts: { BasePart },
}

local folder = Instance.new("Folder")
folder.Name = "ObbyMovers"
folder.Parent = workspace

local function slab(piece: ObbyCourse.Piece, rest: CFrame): Part
	local p = Instance.new("Part")
	p.Name = "Mover"
	p.Anchored = true
	p.Size = Vector3.new(piece.Width, piece.Height, piece.Length)
	p.CFrame = rest
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = COLORS[(piece.Stage - 1) % #COLORS + 1]
	p.Parent = folder
	return p
end

local function shoulder(road: Part): Part
	local s = road:Clone()
	s.Name = "Shoulder"
	s.Size = road.Size + Vector3.new(2 * Tuning.Obby.ShoulderWidth, 0, 0)
	s.Transparency = 1
	s.CanTouch = false
	s.CanQuery = false
	s.CollisionGroup = SHOULDERS
	s.Parent = folder
	return s
end

local platforms: { Platform } = {}
for _, piece in ObbyCourse.layout(Tuning.Obby.World1) do
	local mover = piece.Mover
	if mover then
		local rest = CFrame.new(piece.X, piece.Y, piece.Z) * CFrame.Angles(0, math.rad(piece.Heading), 0)
		local road = slab(piece, rest)
		table.insert(platforms, { mover = mover, rest = rest, parts = { road, shoulder(road) } })
	end
end

RunService.PreSimulation:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, platform in platforms do
		local out, speed = ObbyMover.offset(platform.mover, now)
		local axis = if platform.mover.Axis == "Up" then Vector3.yAxis else platform.rest.RightVector
		local cframe = platform.rest + axis * out
		for _, part in platform.parts do
			part.CFrame = cframe
			part.AssemblyLinearVelocity = axis * speed
		end
	end
end)
