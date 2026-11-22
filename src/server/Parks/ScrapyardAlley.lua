--!strict
-- ScrapyardAlley (ModuleScript) -> ServerScriptService.Parks.ScrapyardAlley
-- The Scrapyard's Hammer Alley (HammerAlley, Hammers,
-- Tuning.Scrapyard.Alley): the fixed parts, in a HammerAlley model. A
-- lane floor between two walls, open at both ends; over each swing hammer a
-- gantry it hangs from, and beside each slam hammer the post it turns on; a
-- sign over the start; and a kicker at the end, every plank a booster, whose
-- wrecks and resets come back to the start. The hammers move, so every client
-- makes and moves its own (HammerAlleyLook).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Hammers = require(ReplicatedStorage.Hammers)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local CurvedWall = require(ServerScriptService.Pieces.CurvedWall)
local LaunchPad = require(ServerScriptService.Pieces.LaunchPad)

local A = Tuning.Scrapyard.Alley

local POST = 4 -- how thick the gantry and pivot posts are
local SIGN_HEIGHT = 30 -- the start sign's underside above the floor

local ScrapyardAlley = {}

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
)
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

-- A place in the lane's studs (across, up, along) as a CFrame facing along it.
local function lane(x: number, y: number, a: number): CFrame
	return Hammers.frame * CFrame.new(x, y, -a)
end

local function buildSign(model: Model)
	local across = A.Width / 2 + A.WallThickness + POST / 2
	local top = SIGN_HEIGHT + 10
	for _, side in { -1, 1 } do
		block(
			model,
			"SignPost",
			Vector3.new(POST, top, POST),
			lane(side * across, top / 2, 0),
			A.SteelColor,
			Enum.Material.Metal
		)
	end
	local board = block(
		model,
		"Sign",
		Vector3.new(2 * across + POST, 10, 1),
		lane(0, SIGN_HEIGHT + 5, 0),
		Color3.fromRGB(22, 22, 26),
		Enum.Material.SmoothPlastic
	)
	-- Its Back face looks back up the lane, at cars driving in.
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 20
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = A.SignColor
	label.Text = "HAMMER ALLEY"
	label.Parent = gui
end

function ScrapyardAlley.build(folder: Folder, _area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "HammerAlley"

	block(
		model,
		"Lane",
		Vector3.new(A.Width, 0.2, A.Length),
		lane(0, 0, A.Length / 2),
		Color3.fromRGB(58, 58, 62),
		Enum.Material.Asphalt
	)
	local wallAcross = A.Width / 2 + A.WallThickness / 2
	for _, side in { -1, 1 } do
		block(
			model,
			"Wall",
			Vector3.new(A.WallThickness, A.WallHeight, A.Length),
			lane(side * wallAcross, A.WallHeight / 2, A.Length / 2),
			A.WallColor,
			Enum.Material.CorrodedMetal
		)
	end

	for _, hammer in A.Hammers do
		if hammer.Kind == "Swing" then
			local across = A.Width / 2 + A.WallThickness + POST / 2
			local height = A.Swing.Height + POST / 2
			for _, side in { -1, 1 } do
				block(
					model,
					"GantryPost",
					Vector3.new(POST, height, POST),
					lane(side * across, height / 2, hammer.At),
					A.SteelColor,
					Enum.Material.Metal
				)
			end
			block(
				model,
				"GantryBeam",
				Vector3.new(2 * across + POST, POST, POST),
				lane(0, A.Swing.Height + POST / 2, hammer.At),
				A.SteelColor,
				Enum.Material.Metal
			)
		else
			local across = hammer.Side * (A.Width / 2 + A.Slam.PivotOut)
			block(
				model,
				"PivotPost",
				Vector3.new(POST, A.Slam.Height, POST + 2),
				lane(across, A.Slam.Height / 2, hammer.At),
				A.SteelColor,
				Enum.Material.Metal
			)
		end
	end

	buildSign(model)

	local options: CurvedWall.Options = {
		radius = A.Kicker.Radius,
		endAngle = A.Kicker.Angle,
		steps = A.Kicker.Steps,
		thickness = 2,
		color = Color3.fromRGB(196, 196, 190),
	}
	local kicker = CurvedWall.straight(model, lane(0, 0, A.Length), A.Width, options)
	kicker.Name = "Kicker"
	CurvedWall.fill(kicker, Tuning.Map.FloorTop, options)
	LaunchPad.top(kicker, A.Kicker.Steps, A.Kicker.LaunchSpeed, Hammers.respawn, A.Kicker.PayScale)

	model.Parent = folder
end

return ScrapyardAlley
