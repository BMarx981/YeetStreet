--!strict
-- ArchSign (ModuleScript) -> ServerScriptService.Pieces.ArchSign
-- A sign over a way in: a dark board with big text, held up between two
-- steel posts, that cars drive under. `at` is on the ground in the middle of
-- the way, facing the way cars go; the text faces them as they drive in.
-- The posts stand `across` studs either side of the middle, and the board's
-- underside is `bottom` studs up.

local ArchSign = {}

local POST = 4 -- how thick the posts are
local BOARD = 10 -- how tall the board is
local BOARD_COLOR = Color3.fromRGB(22, 22, 26)

export type Options = {
	across: number,
	bottom: number,
	text: string,
	textColor: Color3,
	postColor: Color3,
}

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

function ArchSign.make(parent: Instance, at: CFrame, o: Options)
	local top = o.bottom + BOARD
	for _, side in { -1, 1 } do
		block(
			parent,
			"SignPost",
			Vector3.new(POST, top, POST),
			at * CFrame.new(side * o.across, top / 2, 0),
			o.postColor,
			Enum.Material.Metal
		)
	end
	local board = block(
		parent,
		"Sign",
		Vector3.new(2 * o.across + POST, BOARD, 1),
		at * CFrame.new(0, o.bottom + BOARD / 2, 0),
		BOARD_COLOR,
		Enum.Material.SmoothPlastic
	)
	-- Its Back face looks back the way cars come.
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = o.textColor
	label.Text = o.text
	label.Parent = gui
end

return ArchSign
