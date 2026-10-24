--!strict
-- WreckingBallLook (LocalScript) -> StarterPlayerScripts.WreckingBallLook
-- Draws a ball and its cable under every Downtown crane's jib
-- (WreckingBalls) and swings them every frame from the server's clock, so
-- every player sees them in the same place. They never touch anything:
-- CarController asks WreckingBalls.push how a ball smacks its car.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tuning = require(ReplicatedStorage.Tuning)
local WreckingBalls = require(ReplicatedStorage.WreckingBalls)

local BALL_COLOR = Color3.fromRGB(45, 45, 50)
local CABLE_COLOR = Color3.fromRGB(25, 25, 25)
local CABLE_WIDTH = 0.6

type Look = {
	ball: Part,
	cable: Part,
}

local folder = Instance.new("Folder")
folder.Name = "WreckingBalls"
folder.Parent = workspace

local looks: { [BasePart]: Look } = {}

local function part(name: string, shape: Enum.PartType, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Metal
	p.Parent = folder
	return p
end

local function build(entry: WreckingBalls.Entry): Look
	local radius = Tuning.City.Cranes.Ball.Radius
	return {
		ball = part("Ball", Enum.PartType.Ball, Vector3.one * radius * 2, BALL_COLOR),
		cable = part(
			"Cable",
			Enum.PartType.Cylinder,
			Vector3.new(entry.ball.length - radius, CABLE_WIDTH, CABLE_WIDTH),
			CABLE_COLOR
		),
	}
end

local parts: { BasePart } = {}
local frames: { CFrame } = {}

RunService.RenderStepped:Connect(function()
	local all = WreckingBalls.all()
	for pivot, look in looks do
		if not all[pivot] then
			look.ball:Destroy()
			look.cable:Destroy()
			looks[pivot] = nil
		end
	end
	local radius = Tuning.City.Cranes.Ball.Radius
	local time = workspace:GetServerTimeNow()
	table.clear(parts)
	table.clear(frames)
	for pivot, entry in all do
		local look = looks[pivot]
		if not look then
			look = build(entry)
			looks[pivot] = look
		end
		local center = WreckingBalls.center(entry, time)
		-- The cable runs up the ball's own up axis from its top to the pivot;
		-- a cylinder's length is along its X.
		local cable = (entry.ball.length - radius) / 2
		table.insert(parts, look.ball)
		table.insert(frames, center)
		table.insert(parts, look.cable)
		table.insert(frames, center * CFrame.new(0, radius + cable, 0) * CFrame.Angles(0, 0, math.pi / 2))
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end)
