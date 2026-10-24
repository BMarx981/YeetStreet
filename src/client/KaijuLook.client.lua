--!strict
-- KaijuLook (LocalScript) -> StarterPlayerScripts.KaijuLook
-- Draws Downtown's kaiju on this client from the two invisible parts the
-- server moves in workspace.Parks.City.Kaiju (Parks.CityKaiju): Root, on
-- the ground under its feet, and Head. For now a plain stand-in of blocks:
-- legs, body, tail, a neck stretched up to the head, and glowing eyes. None
-- of it touches anything.
--
-- While the server says its eyes charge a laser (LaserCharge), they glow
-- brighter and brighter, light up round the head, and a faint line runs
-- from them to where they aim (LaserAim). Each shot (LaserShots) flashes a
-- beam from each eye to where it stopped (LaserEnd), fading over BeamTime.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tuning = require(ReplicatedStorage.Tuning)

local BODY_COLOR = Color3.fromRGB(55, 70, 60)
local EYE_COLOR = Color3.fromRGB(120, 220, 255)
local HOT_COLOR = Color3.fromRGB(235, 250, 255)
-- The eyes pulse this many times a second while charging, and the light
-- round the head grows to GLOW_BRIGHTNESS.
local PULSE_RATE = 6
local GLOW_BRIGHTNESS = 6
local GLOW_RANGE = 40
local BEAM_WIDTH = 3

local H = Tuning.City.Kaiju.Head
local L = Tuning.City.Kaiju.Laser

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
local eyes: { { part: Part, offset: CFrame } } = {}
for _, side in { -1, 1 } do
	local eye = block("Eye", Vector3.new(4, 3, 1), EYE_COLOR)
	eye.Material = Enum.Material.Neon
	local piece = { part = eye, offset = CFrame.new(side * 6, 4, -H.Size.Z / 2 - 0.5) }
	table.insert(onHead, piece)
	table.insert(eyes, piece)
end
local neck = block("Neck", Vector3.new(14, 14, 1), BODY_COLOR)
local NECK_BASE = CFrame.new(0, 105, -5)

local glow = Instance.new("PointLight")
glow.Color = EYE_COLOR
glow.Range = GLOW_RANGE
glow.Brightness = 0
glow.Parent = onHead[1].part

local function beam(name: string, width: number): Part
	local p = block(name, Vector3.new(width, width, 1), EYE_COLOR)
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Transparency = 1
	return p
end
local aimLine = beam("AimLine", 0.6)
local beams = { beam("Beam", BEAM_WIDTH), beam("Beam", BEAM_WIDTH) }
local shotAt = -math.huge
kaiju:GetAttributeChangedSignal("LaserShots"):Connect(function()
	shotAt = os.clock()
end)

-- A cylinder's frame from `from` to `to`: its length runs along its X.
local function span(part: Part, from: Vector3, to: Vector3): CFrame
	local length = math.max((to - from).Magnitude, 0.1)
	part.Size = Vector3.new(length, part.Size.Y, part.Size.Z)
	return CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0)
end

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

	-- Charging, the eyes pulse hotter and the line shows where they aim.
	local charging = kaiju:GetAttribute("LaserCharge") == true
	local aim = kaiju:GetAttribute("LaserAim")
	local middle = top:PointToWorldSpace(L.Eyes)
	local heat = if charging then 0.5 + 0.5 * math.sin(os.clock() * PULSE_RATE * 2 * math.pi) else 0
	for _, piece in eyes do
		piece.part.Color = EYE_COLOR:Lerp(HOT_COLOR, heat)
	end
	glow.Brightness = heat * GLOW_BRIGHTNESS
	aimLine.Transparency = if charging and typeof(aim) == "Vector3" then 0.75 else 1
	if typeof(aim) == "Vector3" then
		table.insert(parts, aimLine)
		table.insert(frames, span(aimLine, middle, aim))
	end

	-- A shot: a beam from each eye to where it stopped, fading out.
	local since = os.clock() - shotAt
	local finish = kaiju:GetAttribute("LaserEnd")
	local shown = since < L.BeamTime and typeof(finish) == "Vector3"
	for i, piece in eyes do
		local part = beams[i]
		part.Transparency = if shown then since / L.BeamTime else 1
		if shown and typeof(finish) == "Vector3" then
			table.insert(parts, part)
			table.insert(frames, span(part, top:PointToWorldSpace(piece.offset.Position), finish))
		end
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end)
