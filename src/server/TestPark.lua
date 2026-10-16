--!strict
-- TestPark (ModuleScript) -> ServerScriptService.TestPark
-- The M0 test site: flat ground, a runway, one curved launch ramp, and distance
-- boards past the lip. Cars drive toward -Z. Built once by WorldBootstrap.
--
-- The ramp is a chain of planks whose pitch steps from RampStartAngle to
-- RampEndAngle. The last PadPlanks carry a LaunchSpeed attribute; the driving
-- client reads it from its wheel raycasts and tops its speed up to that value
-- while on them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local P = Tuning.TestPark

local TestPark = {}

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Hull center for spawn lane `index` (1-based, wraps). Faces -Z.
function TestPark.spawnCFrame(index: number): CFrame
	local lane = (index - 1) % P.SpawnLanes
	local x = (lane - (P.SpawnLanes - 1) / 2) * P.SpawnLaneSpacing
	return CFrame.new(x, P.SpawnHeight, P.SpawnZ)
end

local function buildRamp(parent: Instance): number
	local ramp = Instance.new("Folder")
	ramp.Name = "Ramp"
	ramp.Parent = parent

	local point = Vector3.new(0, 0, P.RampStartZ)
	for i = 1, P.RampPlanks do
		local t = (i - 1) / math.max(P.RampPlanks - 1, 1)
		local angle = math.rad(P.RampStartAngle + (P.RampEndAngle - P.RampStartAngle) * t)
		local dir = Vector3.new(0, math.sin(angle), -math.cos(angle))
		local mid = point + dir * (P.RampPlankLength / 2)
		local look = CFrame.lookAt(mid, mid + dir)
		local isPad = i > P.RampPlanks - P.PadPlanks

		-- Planks overlap a little so the seams between pitch steps stay closed.
		local plank = block(
			ramp,
			if isPad then "LaunchPad" else "Plank",
			Vector3.new(P.RampWidth, P.RampThickness, P.RampPlankLength + 0.4),
			look * CFrame.new(0, -P.RampThickness / 2, 0),
			if isPad then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(90, 96, 110),
			if isPad then Enum.Material.Neon else Enum.Material.DiamondPlate
		)
		if isPad then
			plank:SetAttribute("LaunchSpeed", P.LaunchSpeed)
		end

		-- Support block under the low end of the plank, kept below the plank's
		-- underside so it never pokes through the driving surface.
		local supportHeight = point.Y - P.RampThickness * 1.2
		if supportHeight > 0.5 then
			local depth = P.RampPlankLength * math.cos(angle)
			block(
				ramp,
				"Support",
				Vector3.new(P.RampWidth - 2, supportHeight, depth),
				CFrame.new(0, supportHeight / 2, mid.Z),
				Color3.fromRGB(60, 62, 70),
				Enum.Material.Concrete
			)
		end

		point += dir * P.RampPlankLength
	end

	return point.Z
end

local function buildBoard(parent: Instance, x: number, z: number, distance: number)
	local board = block(
		parent,
		`Board{distance}`,
		Vector3.new(14, 8, 1),
		CFrame.new(x, 4, z),
		Color3.fromRGB(245, 245, 240),
		Enum.Material.SmoothPlastic
	)
	-- The +Z face is the one a car flying toward -Z sees.
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 20
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(distance)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(30, 30, 40)
	label.Parent = gui
end

-- Covers the ground rectangle with tiles of at most GroundTile studs; the last
-- tile in each row and column is cut to fit.
local function buildGround(parent: Instance)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = parent

	local z = P.GroundBackZ
	while z > P.GroundFrontZ do
		local depth = math.min(P.GroundTile, z - P.GroundFrontZ)
		local x = -P.GroundHalfWidth
		while x < P.GroundHalfWidth do
			local width = math.min(P.GroundTile, P.GroundHalfWidth - x)
			block(
				ground,
				"Tile",
				Vector3.new(width, 4, depth),
				CFrame.new(x + width / 2, -2, z - depth / 2),
				Color3.fromRGB(96, 150, 72),
				Enum.Material.Grass
			)
			x += width
		end
		z -= depth
	end
end

-- One straight stretch of the edge wall, centered on `center` at the ground's
-- edge: a curve from flat, up through vertical at the edge, and on to
-- WallEndAngle, so the top leans back over the ground and sends a car off the
-- lip back inside. `out` points off the ground; each plank's X axis runs along
-- the edge.
local function buildWallStretch(parent: Instance, center: Vector3, out: Vector3, length: number)
	local R = P.WallRadius
	local arcCenter = center - out * R + Vector3.yAxis * R
	local function arcPoint(angle: number): Vector3
		return arcCenter + out * (R * math.sin(angle)) - Vector3.yAxis * (R * math.cos(angle))
	end

	-- Planks overlap a little so the seams between steps stay closed.
	local endAngle = math.rad(P.WallEndAngle)
	for i = 1, P.WallSteps do
		local a = arcPoint(endAngle * (i - 1) / P.WallSteps)
		local b = arcPoint(endAngle * i / P.WallSteps)
		local mid = (a + b) / 2
		local face = CFrame.lookAt(mid, b, (arcCenter - mid).Unit)
		block(
			parent,
			"Pipe",
			Vector3.new(length, P.WallThickness, (b - a).Magnitude + 0.4),
			face * CFrame.new(0, -P.WallThickness / 2, 0),
			Color3.fromRGB(150, 154, 162),
			Enum.Material.Concrete
		)
	end
end

-- Runs the wall from `from` to `to` along one edge, in stretches of at most
-- GroundTile studs.
local function buildWallEdge(parent: Instance, from: Vector3, to: Vector3, out: Vector3)
	local total = (to - from).Magnitude
	local along = (to - from).Unit
	local done = 0
	while done < total do
		local length = math.min(P.GroundTile, total - done)
		buildWallStretch(parent, from + along * (done + length / 2), out, length)
		done += length
	end
end

-- Curved walls all around the ground, so a car heading off the edge rides up
-- the wall and drops back inside. At the corners the two walls cross.
local function buildEdgeWall(parent: Instance)
	local wall = Instance.new("Folder")
	wall.Name = "EdgeWall"
	wall.Parent = parent

	local hw, back, front = P.GroundHalfWidth, P.GroundBackZ, P.GroundFrontZ
	buildWallEdge(wall, Vector3.new(-hw, 0, front), Vector3.new(hw, 0, front), -Vector3.zAxis)
	buildWallEdge(wall, Vector3.new(-hw, 0, back), Vector3.new(hw, 0, back), Vector3.zAxis)
	buildWallEdge(wall, Vector3.new(-hw, 0, back), Vector3.new(-hw, 0, front), -Vector3.xAxis)
	buildWallEdge(wall, Vector3.new(hw, 0, back), Vector3.new(hw, 0, front), Vector3.xAxis)
end

function TestPark.build(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "TestPark"

	buildGround(folder)
	buildEdgeWall(folder)

	local runwayStart = P.SpawnZ + 30
	local runwayLength = runwayStart - P.RampStartZ
	block(
		folder,
		"Runway",
		Vector3.new(P.RunwayWidth, 1, runwayLength),
		CFrame.new(0, -0.45, P.RampStartZ + runwayLength / 2),
		Color3.fromRGB(52, 52, 58),
		Enum.Material.Asphalt
	)

	local lipZ = buildRamp(folder)

	local boards = Instance.new("Folder")
	boards.Name = "DistanceBoards"
	boards.Parent = folder
	for i = 1, P.BoardCount do
		local distance = i * P.BoardSpacing
		buildBoard(boards, -P.BoardX, lipZ - distance, distance)
		buildBoard(boards, P.BoardX, lipZ - distance, distance)
	end

	folder.Parent = workspace
	return folder
end

return TestPark
