--!strict
-- KaijuLook (LocalScript) -> StarterPlayerScripts.KaijuLook
-- Draws Downtown's kaiju on this client from the two invisible parts the
-- server moves in workspace.Parks.City.Kaiju (Parks.CityKaiju): Root, on
-- the ground under its feet, and Head. For now a plain stand-in of blocks:
-- legs, body, tail, a neck stretched up to the head, and glowing eyes. None
-- of it touches anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tuning = require(ReplicatedStorage.Tuning)

local BODY_COLOR = Color3.fromRGB(55, 70, 60)
local EYE_COLOR = Color3.fromRGB(120, 220, 255)

local H = Tuning.City.Kaiju.Head

local kaiju = workspace:WaitForChild("Parks"):WaitForChild("City"):WaitForChild("Kaiju")
local root = kaiju:WaitForChild("Root") :: BasePart
local head = kaiju:WaitForChild("Head") :: BasePart

local model = Instance.new("Model")
model.Name = "KaijuLook"

local function block(name: string, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end

-- Each block and where it sits on the feet (Root), or on the head.
local onFeet: { { part: Part, offset: CFrame } } = {
	{ part = block("Leg", Vector3.new(12, 40, 14), BODY_COLOR), offset = CFrame.new(-11, 20, 0) },
	{ part = block("Leg", Vector3.new(12, 40, 14), BODY_COLOR), offset = CFrame.new(11, 20, 0) },
	{ part = block("Body", Vector3.new(36, 75, 28), BODY_COLOR), offset = CFrame.new(0, 75, 0) },
	{ part = block("Tail", Vector3.new(14, 14, 70), BODY_COLOR), offset = CFrame.new(0, 30, 45) },
}
local onHead: { { part: Part, offset: CFrame } } = {
	{ part = block("Head", H.Size, BODY_COLOR), offset = CFrame.identity },
}
for _, side in { -1, 1 } do
	local eye = block("Eye", Vector3.new(4, 3, 1), EYE_COLOR)
	eye.Material = Enum.Material.Neon
	table.insert(onHead, { part = eye, offset = CFrame.new(side * 6, 4, -H.Size.Z / 2 - 0.5) })
end
local neck = block("Neck", Vector3.new(14, 14, 1), BODY_COLOR)
local NECK_BASE = CFrame.new(0, 105, -5)

model.Parent = workspace

local parts: { BasePart } = {}
local frames: { CFrame } = {}

RunService.RenderStepped:Connect(function()
	local feet, top = root.CFrame, head.CFrame
	table.clear(parts)
	table.clear(frames)
	for _, piece in onFeet do
		table.insert(parts, piece.part)
		table.insert(frames, feet * piece.offset)
	end
	for _, piece in onHead do
		table.insert(parts, piece.part)
		table.insert(frames, top * piece.offset)
	end
	-- The neck runs from the top of the body to the back of the head.
	local from = feet:PointToWorldSpace(NECK_BASE.Position)
	local to = top:PointToWorldSpace(Vector3.new(0, 0, H.Size.Z / 2))
	local length = math.max((to - from).Magnitude, 1)
	neck.Size = Vector3.new(14, 14, length)
	table.insert(parts, neck)
	table.insert(frames, CFrame.lookAt((from + to) / 2, to))
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end)
