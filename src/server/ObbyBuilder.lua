--!strict
-- ObbyBuilder (ModuleScript) -> ServerScriptService.ObbyBuilder
-- Builds the car obby's world 1 from its layout (ObbyCourse, Tuning.Obby.World1)
-- into workspace.Obby.World1, one folder per stage. ObbyService builds it
-- when a server starts, unless a World1 folder was saved with the place.
--
-- Checkpoint pads are tagged ObbyCheckpoint with a Checkpoint attribute
-- (ObbyService) and show their number on top. Each part has an invisible
-- Shoulder copy, ShoulderWidth wider on each side (corners lengthways too),
-- that only wheels touch (CollisionGroups.Shoulders).
--
-- Boosters are launch pads (Pieces.LaunchPad) pushing the way the course
-- runs, up a ramp's slope, that pay BoostPayScale of a run's cash. They have
-- no RespawnCFrame: in the obby the checkpoint wins, and after it a reset
-- should not come back to the sky.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ObbyCourse = require(ReplicatedStorage.ObbyCourse)
local Tuning = require(ReplicatedStorage.Tuning)
local CollisionGroups = require(ServerScriptService.CollisionGroups)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)

local W = Tuning.Obby.World1

local ObbyBuilder = {}

-- A stage's road color, by stage number, round and round.
local COLORS = {
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(255, 120, 60),
	Color3.fromRGB(170, 90, 230),
	Color3.fromRGB(255, 80, 140),
	Color3.fromRGB(60, 200, 210),
}
local PAD_COLOR = Color3.fromRGB(40, 200, 110)

local function number(part: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 10
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = gui
end

local function part(piece: ObbyCourse.Piece, parent: Instance): BasePart
	local p: BasePart = if piece.Kind == "Wedge" then Instance.new("WedgePart") else Instance.new("Part")
	p.Name = if piece.Kind == "Pad" then `Checkpoint{piece.Checkpoint}` elseif piece.Boost then "Booster" else piece.Kind
	p.Anchored = true
	p.Size = Vector3.new(piece.Width, piece.Height, piece.Length)
	local cframe = CFrame.new(piece.X, piece.Y, piece.Z) * CFrame.Angles(0, math.rad(piece.Heading), 0)
	if piece.Kind == "Wedge" and piece.Rising then
		-- A wedge rises toward its back (+Z), and the way on is its front.
		cframe *= CFrame.Angles(0, math.pi, 0)
	end
	p.CFrame = cframe
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if piece.Kind == "Pad" then
		p.Color = PAD_COLOR
		p:SetAttribute("Checkpoint", piece.Checkpoint)
		CollectionService:AddTag(p, "ObbyCheckpoint")
		number(p, if piece.Checkpoint == 0 then "START" else tostring(piece.Checkpoint))
	elseif piece.Boost then
		LaunchPad.paint(p)
		local turn = CFrame.Angles(0, math.rad(piece.Heading), 0)
		local up = if piece.Kind ~= "Wedge" then 0 elseif piece.Rising then piece.Height else -piece.Height
		p:SetAttribute("LaunchSpeed", piece.Boost)
		p:SetAttribute("LaunchDirection", turn:VectorToWorldSpace(Vector3.new(0, up, -piece.Length).Unit))
		p:SetAttribute("PayScale", Tuning.Obby.BoostPayScale)
	else
		p.Color = COLORS[(piece.Stage - 1) % #COLORS + 1]
	end
	p.Parent = parent
	return p
end

local function shoulder(piece: ObbyCourse.Piece, road: BasePart)
	local s = road:Clone()
	s:ClearAllChildren()
	CollectionService:RemoveTag(s, "ObbyCheckpoint")
	s:SetAttribute("Checkpoint", nil)
	s:SetAttribute("LaunchSpeed", nil)
	s:SetAttribute("LaunchDirection", nil)
	s:SetAttribute("PayScale", nil)
	s.Name = "Shoulder"
	local extra = 2 * Tuning.Obby.ShoulderWidth
	s.Size = road.Size + Vector3.new(extra, 0, if piece.Corner then extra else 0)
	s.CFrame = road.CFrame
	s.Transparency = 1
	s.CanTouch = false
	s.CanQuery = false
	s.CollisionGroup = CollisionGroups.Shoulders
	s.Parent = road.Parent
end

-- Builds world 1's folder, not yet parented.
function ObbyBuilder.build(): Folder
	local world = Instance.new("Folder")
	world.Name = "World1"
	local stages: { [number]: Folder } = {}
	for _, piece in ObbyCourse.layout(W) do
		local folder = stages[piece.Stage]
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = if piece.Stage == 0 then "Start" else string.format("Stage%02d", piece.Stage)
			folder.Parent = world
			stages[piece.Stage] = folder
		end
		shoulder(piece, part(piece, folder))
	end
	return world
end

return ObbyBuilder
