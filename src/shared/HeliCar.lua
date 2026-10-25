--!strict
-- HeliCar (ModuleScript) -> ReplicatedStorage.HeliCar
-- A fixed car look copied from photos of a real brick-built car: a tall blue
-- tub on a stud plate, an arch over the driver, a yellow fan ring with a horn
-- on the roof, and a jet tail with a flag fin. It doesn't come from a seed,
-- so every client builds the same parts.
--
-- Parts are in car space like CarDesign: studs from the hull's center, x to
-- the right, y up, the nose toward -z. The driver's seat (Chassis.SeatOffset)
-- sits under the arch, behind the dash. Wheel trims are in each wheel's own
-- space, where the wheel's axis is its x and the left wheels' outside is -x.
-- Parts come out anchored, with no collisions, touches, or mass, like
-- CarParts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarDesign = require(ReplicatedStorage.CarDesign)

local HeliCar = {}

export type Shape = "block" | "wedge" | "cylinder"

export type Spec = {
	name: string,
	shape: Shape,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	transparency: number,
	slot: CarDesign.Slot?, -- the slot it breaks off with
	label: string?, -- text shown on both sides
	swivel: boolean?, -- turns with the fan
}

local BLUE = Color3.fromRGB(0, 85, 191)
local SIDE_STUD_BLUE = Color3.fromRGB(0, 70, 160) -- a shade darker, so studs facing the camera still show
local WHITE = Color3.fromRGB(242, 243, 242)
local GREY = Color3.fromRGB(160, 165, 169)
local TAN = Color3.fromRGB(228, 205, 158)
local BLACK = Color3.fromRGB(27, 27, 30)
local YELLOW = Color3.fromRGB(242, 205, 55)
local RED = Color3.fromRGB(201, 26, 9)
local NAVY = Color3.fromRGB(10, 52, 99)
local GLASS_BLUE = Color3.fromRGB(80, 160, 230)
local GLASS_RED = Color3.fromRGB(220, 40, 30)

local PITCH = 0.8 -- one stud of the real car, in studs
local STUD_HEIGHT = 0.14
local STUD_WIDTH = 0.48

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis up
local LENGTHWAYS = CFrame.Angles(0, math.rad(90), 0) -- a cylinder's axis along z
local FLIPPED = CFrame.Angles(math.rad(180), 0, 0) -- a wedge's slope underneath, rising to the back
local REVERSED = CFrame.Angles(0, math.rad(180), 0) -- a wedge rising toward the front

local body: { Spec } = {}

local function add(
	name: string,
	shape: Shape,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	slot: CarDesign.Slot?,
	transparency: number?
)
	table.insert(body, {
		name = name,
		shape = shape,
		size = size,
		cframe = cframe,
		color = color,
		transparency = transparency or 0,
		slot = slot,
	})
end

-- A block from its low corner to its high corner.
local function box(name: string, low: Vector3, high: Vector3, color: Color3, slot: CarDesign.Slot?)
	add(name, "block", high - low, CFrame.new((low + high) / 2), color, slot)
end

-- A stud standing on a top surface at height y.
local function stud(x: number, y: number, z: number, color: Color3, slot: CarDesign.Slot?)
	add(
		"Stud",
		"cylinder",
		Vector3.new(STUD_HEIGHT, STUD_WIDTH, STUD_WIDTH),
		CFrame.new(x, y + STUD_HEIGHT / 2, z) * UPRIGHT,
		color,
		slot
	)
end

-- A stud sticking out of a side face at x, pointing away from the middle.
local function sideStud(x: number, y: number, z: number, color: Color3)
	local out = math.sign(x) * STUD_HEIGHT / 2
	add(
		"SideStud",
		"cylinder",
		Vector3.new(STUD_HEIGHT, STUD_WIDTH, STUD_WIDTH),
		CFrame.new(x + out, y, z),
		color,
		"sides"
	)
end

-- Under the plate: axles, and a leg of stacked bricks at each end.
local PLATE_BOTTOM = 1.1
local PLATE_TOP = PLATE_BOTTOM + 0.32
local WHEEL_Y = -0.5
local WHEEL_Z = 3.8
for _, z in { -WHEEL_Z, WHEEL_Z } do
	add("Axle", "block", Vector3.new(6.1, 0.4, 0.4), CFrame.new(0, WHEEL_Y, z), GREY, "underside")
	box("LegBase", Vector3.new(-0.8, -0.9, z - 0.8), Vector3.new(0.8, -0.4, z + 0.8), GREY, "underside")
	box(
		"Leg",
		Vector3.new(-0.8, -0.4, z - 0.8),
		Vector3.new(0.8, 0.3, z + 0.8),
		if z < 0 then TAN else GREY,
		"underside"
	)
	box("LegTop", Vector3.new(-0.8, 0.3, z - 0.8), Vector3.new(0.8, PLATE_BOTTOM, z + 0.8), WHITE, "underside")
end

-- The plate, 8 by 13 studs, with studs showing around the tub.
box("Plate", Vector3.new(-3.2, PLATE_BOTTOM, -5.2), Vector3.new(3.2, PLATE_TOP, 5.2), BLUE)
for i = 0, 12 do
	local z = -4.8 + i * PITCH
	stud(-2.8, PLATE_TOP, z, BLUE, "sides")
	stud(2.8, PLATE_TOP, z, BLUE, "sides")
end
for _, z in { 4.0, 4.8 } do
	for _, x in { -2.0, -1.2, -0.4, 0.4, 1.2, 2.0 } do
		stud(x, PLATE_TOP, z, BLUE, "tail")
	end
end

-- The tub the driver sits in, open on top, with a sloped chin under the nose.
local TUB_TOP = PLATE_TOP + 0.98
box("TubLeft", Vector3.new(-2.4, PLATE_TOP, -3.4), Vector3.new(-1.9, TUB_TOP, 3.0), BLUE, "sides")
box("TubRight", Vector3.new(1.9, PLATE_TOP, -3.4), Vector3.new(2.4, TUB_TOP, 3.0), BLUE, "sides")
box("TubFront", Vector3.new(-2.4, PLATE_TOP, -5.2), Vector3.new(2.4, TUB_TOP, -3.4), BLUE, "nose")
box("TubBack", Vector3.new(-1.9, PLATE_TOP, 2.6), Vector3.new(1.9, TUB_TOP, 3.0), BLUE)
add(
	"Chin",
	"wedge",
	Vector3.new(4.8, 0.98, 0.6),
	CFrame.new(0, (PLATE_TOP + TUB_TOP) / 2, -5.5) * FLIPPED * REVERSED,
	BLUE,
	"nose"
)

-- The dash: white blocks at the corners, a red lever, a clear light, and the
-- steering wheel on a grey column, tilted toward the driver.
for _, side in { -1, 1 } do
	box(
		"DashBlock",
		Vector3.new(side * 1.2, TUB_TOP, -4.8),
		Vector3.new(side * 2.4, TUB_TOP + 0.96, -3.6),
		WHITE,
		"nose"
	)
	for _, z in { -4.4, -4.0 } do
		if not (side < 0 and z == -4.0) then
			stud(side * 1.6, TUB_TOP + 0.96, z, WHITE, "nose")
		end
		stud(side * 2.0, TUB_TOP + 0.96, z, WHITE, "nose")
	end
end
add("Lever", "cylinder", Vector3.new(1.2, 0.6, 0.6), CFrame.new(0.75, TUB_TOP + 0.6, -3.9) * UPRIGHT, RED, "nose")
add(
	"Light",
	"cylinder",
	Vector3.new(0.32, 0.6, 0.6),
	CFrame.new(-1.6, TUB_TOP + 0.96 + 0.16, -4.0) * UPRIGHT,
	WHITE,
	"nose",
	0.4
)
box("Column", Vector3.new(-0.3, TUB_TOP, -3.4), Vector3.new(0.3, TUB_TOP + 0.9, -2.8), GREY, "nose")
local wheelTilt = CFrame.Angles(0, math.rad(-90), math.rad(37))
add(
	"SteeringWheel",
	"cylinder",
	Vector3.new(0.15, 1.0, 1.0),
	CFrame.new(0, TUB_TOP + 1.05, -2.75) * wheelTilt,
	BLACK,
	"nose"
)

-- The arch over the driver: solid sides with studs, a glass front edge.
local ARCH_FRONT = -1.6
local ARCH_BACK = 3.0
local ROOF_BOTTOM = 4.7
local ROOF_TOP = 5.2
for _, side in { -1, 1 } do
	local inner, outer = side * 1.9, side * 2.4
	box(
		"Pillar",
		Vector3.new(math.min(inner, outer), TUB_TOP, ARCH_FRONT),
		Vector3.new(math.max(inner, outer), ROOF_BOTTOM, ARCH_BACK),
		BLUE,
		"sides"
	)
	for _, z in { -0.2, 0.8, 1.8, 2.7 } do
		sideStud(outer, 4.3, z, SIDE_STUD_BLUE)
	end
	for _, y in { 3.0, 3.6 } do
		for _, z in { -1.2, -0.5 } do
			sideStud(outer, y, z, SIDE_STUD_BLUE)
		end
	end
end
box("Roof", Vector3.new(-2.4, ROOF_BOTTOM, -0.4), Vector3.new(2.4, ROOF_TOP, ARCH_BACK), BLUE, "roof")
add(
	"Windshield",
	"wedge",
	Vector3.new(4.8, 0.5, 1.2),
	CFrame.new(0, (ROOF_BOTTOM + ROOF_TOP) / 2, -1.0),
	GLASS_BLUE,
	"roof",
	0.35
)

-- The fan on the roof: a yellow ring around black blades, facing forward on
-- a stand. The ring and the horn on it swivel on top of the stand, about
-- HeliCar.fanPivot, to follow the steering (CarVisuals).
local FAN_RADIUS = 1.0
local FAN_SEGMENTS = 16
local FAN_BLADES = 10
local FAN_PIVOT = CFrame.new(0, ROOF_TOP + 0.3, 0.9)
local fanCenter = FAN_PIVOT * CFrame.new(0, FAN_RADIUS + 0.1, 0)
add("FanStand", "cylinder", Vector3.new(0.3, 0.8, 0.8), CFrame.new(0, ROOF_TOP + 0.15, 0.9) * UPRIGHT, BLUE, "roof")
local firstSwivel = #body + 1
local chord = 2 * (FAN_RADIUS + 0.1) * math.tan(math.pi / FAN_SEGMENTS)
for k = 0, FAN_SEGMENTS - 1 do
	local angle = k * 2 * math.pi / FAN_SEGMENTS
	add(
		"FanRing",
		"block",
		Vector3.new(chord, 0.2, 0.7),
		fanCenter * CFrame.Angles(0, 0, angle) * CFrame.new(0, FAN_RADIUS, 0),
		YELLOW,
		"roof"
	)
end
for k = 0, FAN_BLADES - 1 do
	local angle = k * 2 * math.pi / FAN_BLADES
	add(
		"FanBlade",
		"block",
		Vector3.new(0.8, 0.3, 0.05),
		fanCenter * CFrame.Angles(0, 0, angle) * CFrame.new(0.5, 0, 0) * CFrame.Angles(math.rad(25), 0, 0),
		BLACK,
		"roof"
	)
end
add("FanHub", "cylinder", Vector3.new(0.9, 0.4, 0.4), fanCenter * LENGTHWAYS, BLACK, "roof")

-- The horn on top of the ring, flared the way the fan faces.
local hornBase = fanCenter * CFrame.new(0, FAN_RADIUS + 0.1, 0)
add("HornMount", "block", Vector3.new(0.3, 0.25, 0.3), hornBase * CFrame.new(0, 0.125, 0.1), BLACK, "roof")
add("HornTube", "cylinder", Vector3.new(1.0, 0.4, 0.4), hornBase * CFrame.new(0, 0.45, 0.1) * LENGTHWAYS, BLACK, "roof")
add(
	"HornFlare",
	"cylinder",
	Vector3.new(0.25, 0.6, 0.6),
	hornBase * CFrame.new(0, 0.45, -0.5) * LENGTHWAYS,
	BLACK,
	"roof"
)
add(
	"HornMouth",
	"cylinder",
	Vector3.new(0.2, 0.8, 0.8),
	hornBase * CFrame.new(0, 0.45, -0.7) * LENGTHWAYS,
	BLACK,
	"roof"
)
for i = firstSwivel, #body do
	body[i].swivel = true
end

-- The jet tail: a boom out the back of the arch, white bricks and a grey
-- slope on top, a red tail light, and a swept white fin with a flag.
local BOOM_BOTTOM = 4.2
local BOOM_TOP = 4.9
box("Boom", Vector3.new(-1.2, BOOM_BOTTOM, ARCH_BACK), Vector3.new(1.2, BOOM_TOP, 5.6), BLUE, "tail")
add(
	"BoomTip",
	"wedge",
	Vector3.new(2.4, BOOM_TOP - BOOM_BOTTOM, 1.2),
	CFrame.new(0, (BOOM_BOTTOM + BOOM_TOP) / 2, 6.2) * FLIPPED,
	BLUE,
	"tail"
)
box("TailBrick", Vector3.new(-0.8, BOOM_TOP, ARCH_BACK), Vector3.new(0.8, BOOM_TOP + 0.6, 4.6), WHITE, "tail")
for _, x in { -0.4, 0.4 } do
	stud(x, BOOM_TOP + 0.6, 3.4, WHITE, "tail")
	stud(x, BOOM_TOP + 0.6, 4.2, WHITE, "tail")
end
add("TailSlope", "wedge", Vector3.new(1.6, 0.6, 1.2), CFrame.new(0, BOOM_TOP + 0.3, 5.2), GREY, "tail")
add(
	"TailLight",
	"wedge",
	Vector3.new(1.0, 0.45, 1.1),
	CFrame.new(0, BOOM_TOP + 0.225, 6.35) * REVERSED,
	GLASS_RED,
	"tail",
	0.25
)

local FIN_BOTTOM = BOOM_TOP + 0.6
local FIN_TOP = FIN_BOTTOM + 2.5
local finMiddle = (FIN_BOTTOM + FIN_TOP) / 2
local finHeight = FIN_TOP - FIN_BOTTOM
add("FinFront", "wedge", Vector3.new(0.24, finHeight, 1.2), CFrame.new(0, finMiddle, 5.2), WHITE, "tail")
box("Fin", Vector3.new(-0.12, FIN_BOTTOM, 5.8), Vector3.new(0.12, FIN_TOP, 6.6), WHITE, "tail")
add("FinBack", "wedge", Vector3.new(0.24, finHeight, 0.8), CFrame.new(0, finMiddle, 7.0) * FLIPPED, WHITE, "tail")
local sweep = math.atan(1.2 / finHeight)
for _, side in { -1, 1 } do
	local face = side * 0.13
	add(
		"FinStripe",
		"block",
		Vector3.new(0.02, finHeight * 0.7, 0.2),
		CFrame.new(face, finMiddle - 0.35, 5.55) * CFrame.Angles(sweep, 0, 0),
		NAVY,
		"tail"
	)
	local flag = CFrame.new(side * 0.14, FIN_TOP - 0.55, 6.5)
	add("Flag", "block", Vector3.new(0.02, 0.42, 0.7), flag, WHITE, "tail")
	for k = 0, 3 do
		add(
			"FlagStripe",
			"block",
			Vector3.new(0.02, 0.06, 0.7),
			flag * CFrame.new(side * 0.01, -0.18 + k * 0.12, 0),
			RED,
			"tail"
		)
	end
	add("FlagStars", "block", Vector3.new(0.02, 0.22, 0.3), flag * CFrame.new(side * 0.02, 0.1, -0.2), NAVY, "tail")
end
table.insert(body, {
	name = "FinNumber",
	shape = "block",
	size = Vector3.new(0.3, 0.4, 1.2),
	cframe = CFrame.new(0, FIN_BOTTOM + 0.9, 6.3),
	color = WHITE,
	transparency = 1,
	slot = "tail",
	label = "28000",
})

HeliCar.body = body

-- Where the fan swivels, in car space; it turns about this frame's y axis.
HeliCar.fanPivot = FAN_PIVOT
HeliCar.FanSteerGain = 1.5 -- fan turn per degree the front wheels steer
HeliCar.FanTurnRate = 10 -- how quickly the fan catches up to the wheels, per second

-- Trims welded to each physics wheel so they spin and steer with it. The
-- front left has a yellow rim, the back left is a flat black disc, and the
-- right side has grey rims.
local function rim(color: Color3, outside: number, diameter: number): { Spec }
	return {
		{
			name = "Rim",
			shape = "cylinder",
			size = Vector3.new(0.1, diameter, diameter),
			cframe = CFrame.new(outside * 0.58, 0, 0),
			color = color,
			transparency = 0,
		},
		{
			name = "RimHub",
			shape = "cylinder",
			size = Vector3.new(0.12, 0.5, 0.5),
			cframe = CFrame.new(outside * 0.66, 0, 0),
			color = if color == BLACK then GREY else color,
			transparency = 0,
		},
	}
end

HeliCar.wheels = {
	WheelFL = rim(YELLOW, -1, 1.7),
	WheelFR = rim(GREY, 1, 1.6),
	WheelRL = rim(BLACK, -1, 2.7),
	WheelRR = rim(GREY, 1, 1.6),
} :: { [string]: { Spec } }

-- Builds specs under parent at origin * each spec's cframe and returns the
-- parts in spec order.
function HeliCar.build(specs: { Spec }, origin: CFrame, parent: Instance): { BasePart }
	local built = {}
	for index, spec in specs do
		local part: BasePart
		if spec.shape == "wedge" then
			part = Instance.new("WedgePart")
		else
			local block = Instance.new("Part")
			if spec.shape == "cylinder" then
				block.Shape = Enum.PartType.Cylinder
			end
			part = block
		end
		part.Name = spec.name
		part.Size = spec.size
		part.CFrame = origin * spec.cframe
		part.Color = spec.color
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = spec.transparency
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		if spec.label then
			for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
				local gui = Instance.new("SurfaceGui")
				gui.Face = face
				gui.CanvasSize = Vector2.new(120, 40)
				local text = Instance.new("TextLabel")
				text.Size = UDim2.fromScale(1, 1)
				text.BackgroundTransparency = 1
				text.Text = spec.label
				text.TextScaled = true
				text.Font = Enum.Font.GothamBold
				text.TextColor3 = BLACK
				text.Parent = gui
				gui.Parent = part
			end
		end
		part.Parent = parent
		built[index] = part
	end
	return built
end

return HeliCar
