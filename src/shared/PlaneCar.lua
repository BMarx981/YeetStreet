--!strict
-- PlaneCar (ModuleScript) -> ReplicatedStorage.PlaneCar
-- A fixed look copied from photos of a small brick plane that turns into a
-- car: swept white wings on grey click hinges, a short white tail fin with a
-- clear blue piece at its foot, a hinged white nose with a dark clear tile on
-- the end, and a grey gun under each wing. Working name until the real one
-- is known.
--
-- The driver rides on the body in front of the fin, legs along the nose. To
-- become a car (PlaneMorph), the wings fold down, the whole plane tips
-- nose-up onto them, so they lie along the sides with their tips forward,
-- and the nose folds forward over the driver as a roof. The guns swing to
-- point forward again, and wheels pop out of the wings' back edges, which
-- are now along the bottom.
--
-- Parts are in plane space: where they sit on the hull as a plane, in studs
-- from the hull's center, x to the right, y up, the nose toward -z.
-- PlaneCar.pose moves each group of parts from there to where it is part of
-- the way through the transform. Parts come out like HeliCar's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarDesign = require(ReplicatedStorage.CarDesign)
local HeliCar = require(ReplicatedStorage.HeliCar)
local PlaneMorph = require(ReplicatedStorage.PlaneMorph)

local PlaneCar = {}

export type Group = "body" | "nose" | "wingL" | "wingR" | "gunL" | "gunR"

local WHITE = Color3.fromRGB(242, 243, 242)
local LIGHT_GREY = Color3.fromRGB(160, 165, 169)
local DARK_GREY = Color3.fromRGB(99, 95, 98)
local BLACK = Color3.fromRGB(27, 27, 30)
local GLASS_BLUE = Color3.fromRGB(85, 165, 175)
local GLASS_SMOKE = Color3.fromRGB(60, 52, 46)

local U = 1.7 -- one stud of the real plane, in studs
local STUD_HEIGHT = 0.17 * U
local STUD_WIDTH = 0.6 * U

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis up
local LENGTHWAYS = CFrame.Angles(0, math.rad(90), 0) -- a cylinder's axis along z

local groups: { [Group]: { HeliCar.Spec } } = {
	body = {},
	nose = {},
	wingL = {},
	wingR = {},
	gunL = {},
	gunR = {},
}

local function add(
	group: Group,
	name: string,
	shape: HeliCar.Shape,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	slot: CarDesign.Slot?,
	transparency: number?
)
	table.insert(groups[group], {
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
local function box(
	group: Group,
	name: string,
	low: Vector3,
	high: Vector3,
	color: Color3,
	slot: CarDesign.Slot?,
	transparency: number?
)
	add(group, name, "block", high - low, CFrame.new((low + high) / 2), color, slot, transparency)
end

-- A stud standing on a top surface at height y.
local function stud(group: Group, x: number, y: number, z: number, color: Color3, slot: CarDesign.Slot?)
	add(
		group,
		"Stud",
		"cylinder",
		Vector3.new(STUD_HEIGHT, STUD_WIDTH, STUD_WIDTH),
		CFrame.new(x, y + STUD_HEIGHT / 2, z) * UPRIGHT,
		color,
		slot
	)
end

-- The body: a white bottom plate the driver sits on, a grey plate under
-- them, the click hinges either side of a grey core, and the fin on top.
local BOTTOM = 0.3
local PLATE_TOP = BOTTOM + 0.4 * U
local HINGE_TOP = 2.0 -- the wings' underside
local BODY_FRONT = -0.03
local BODY_BACK = 5.26
local FIN_FRONT = 1.6
local FIN_HALF = 0.5 * U
local HINGE_X = 2.35 -- the wings fold about this edge

box(
	"body",
	"BottomPlate",
	Vector3.new(-1.0, BOTTOM, BODY_FRONT),
	Vector3.new(1.0, PLATE_TOP, BODY_BACK),
	WHITE,
	"underside"
)
box(
	"body",
	"SeatPlate",
	Vector3.new(-FIN_HALF, PLATE_TOP, BODY_FRONT),
	Vector3.new(FIN_HALF, PLATE_TOP + 0.3, FIN_FRONT),
	LIGHT_GREY
)
stud("body", 0, PLATE_TOP + 0.3, 0.7, LIGHT_GREY)
box(
	"body",
	"Glass",
	Vector3.new(-0.45 * U, PLATE_TOP, FIN_FRONT),
	Vector3.new(0.45 * U, HINGE_TOP, FIN_FRONT + 0.4),
	GLASS_BLUE,
	nil,
	0.3
)
box(
	"body",
	"Core",
	Vector3.new(-FIN_HALF, PLATE_TOP, FIN_FRONT + 0.4),
	Vector3.new(FIN_HALF, HINGE_TOP, BODY_BACK),
	LIGHT_GREY
)

local KNUCKLES = 5
local KNUCKLE_FRONT = 1.4
local KNUCKLE_BACK = 4.6
local knuckleLength = (KNUCKLE_BACK - KNUCKLE_FRONT) / KNUCKLES
for _, side in { -1, 1 } do
	box(
		"body",
		"HingePlate",
		Vector3.new(math.min(side * FIN_HALF, side * HINGE_X), PLATE_TOP, KNUCKLE_FRONT),
		Vector3.new(math.max(side * FIN_HALF, side * HINGE_X), PLATE_TOP + 0.25, KNUCKLE_BACK),
		LIGHT_GREY
	)
	local diameter = HINGE_TOP - (PLATE_TOP + 0.25)
	local y = HINGE_TOP - diameter / 2
	for column, x in { 1.3, 1.95 } do
		for k = 0, KNUCKLES - 1 do
			local dark = (k + column) % 2 == 0
			add(
				"body",
				"Knuckle",
				"cylinder",
				Vector3.new(knuckleLength, diameter, diameter),
				CFrame.new(side * x, y, KNUCKLE_FRONT + (k + 0.5) * knuckleLength) * LENGTHWAYS,
				if dark then DARK_GREY else LIGHT_GREY
			)
		end
	end
end

-- The fin: a brick with a sloped front and a stud on top.
local FIN_TOP = HINGE_TOP + 2.9
local SLOPE_FRONT = FIN_FRONT
local SLOPE_BACK = FIN_FRONT + 1.3
local SLOPE_BOTTOM = HINGE_TOP + 1.3
box(
	"body",
	"Fin",
	Vector3.new(-FIN_HALF, HINGE_TOP, SLOPE_BACK),
	Vector3.new(FIN_HALF, FIN_TOP, BODY_BACK),
	WHITE,
	"tail"
)
box(
	"body",
	"FinFoot",
	Vector3.new(-FIN_HALF, HINGE_TOP, SLOPE_FRONT),
	Vector3.new(FIN_HALF, SLOPE_BOTTOM, SLOPE_BACK),
	WHITE,
	"tail"
)
add(
	"body",
	"FinSlope",
	"wedge",
	Vector3.new(2 * FIN_HALF, FIN_TOP - SLOPE_BOTTOM, SLOPE_BACK - SLOPE_FRONT),
	CFrame.new(0, (SLOPE_BOTTOM + FIN_TOP) / 2, (SLOPE_FRONT + SLOPE_BACK) / 2),
	WHITE,
	"tail"
)
stud("body", 0, FIN_TOP, 4.6, WHITE, "tail")

-- Where the jet flame blows out: the back of the body, under the fin.
add(
	"body",
	"Exhaust",
	"block",
	Vector3.new(0.4, 1.0, 1.0),
	CFrame.new(0, 1.5, BODY_BACK + 0.2) * LENGTHWAYS,
	WHITE,
	nil,
	1
)

-- The nose, on a hinge at its root: a grey clip, a white plate, a white tile,
-- and a dark clear tile on the end with a stud showing through.
local NOSE_HINGE = CFrame.new(0, (BOTTOM + PLATE_TOP + 0.4) / 2, -0.5)
local NOSE_TIP = -5.27
local GLASS_FROM = -3.6
box(
	"nose",
	"Clip",
	Vector3.new(-0.35, BOTTOM + 0.1, -1.3),
	Vector3.new(0.35, PLATE_TOP + 0.1, BODY_FRONT),
	LIGHT_GREY,
	"nose"
)
add("nose", "NoseHinge", "cylinder", Vector3.new(1.6, 0.9, 0.9), NOSE_HINGE, WHITE, "nose")
box(
	"nose",
	"NosePlate",
	Vector3.new(-0.48 * U, BOTTOM, NOSE_TIP),
	Vector3.new(0.48 * U, PLATE_TOP, -0.9),
	WHITE,
	"nose"
)
box(
	"nose",
	"NoseTile",
	Vector3.new(-0.48 * U, PLATE_TOP, GLASS_FROM),
	Vector3.new(0.48 * U, PLATE_TOP + 0.25, -1.9),
	WHITE,
	"nose"
)
stud("nose", 0, PLATE_TOP, (GLASS_FROM + NOSE_TIP) / 2, WHITE, "nose")
box(
	"nose",
	"NoseGlass",
	Vector3.new(-0.48 * U, PLATE_TOP, NOSE_TIP),
	Vector3.new(0.48 * U, PLATE_TOP + 0.3, GLASS_FROM),
	GLASS_SMOKE,
	"nose",
	0.35
)

-- The wings: a smooth white plate swept back from the root, a grey block
-- under the root, and a round grey mount the gun clips onto.
local WING_TOP = HINGE_TOP + 0.4 * U
local WING_TIP = 9.0
local TRAILING = 4.48 -- the straight back edge
local ROOT_LEADING = 1.47
local TIP_LEADING = 2.9
local GUN_X = 5.5
local GUN_MOUNT_Z = 2.6
local GUN_Y = 1.45
local MUZZLE_Z = 0.38
for _, side in { -1, 1 } do
	local wing: Group = if side < 0 then "wingL" else "wingR"
	box(
		wing,
		"Wing",
		Vector3.new(math.min(side * HINGE_X, side * WING_TIP), HINGE_TOP, TIP_LEADING),
		Vector3.new(math.max(side * HINGE_X, side * WING_TIP), WING_TOP, TRAILING),
		WHITE,
		"sides"
	)
	-- A wedge's triangle is in its own y-z plane; turned so its y runs out
	-- along the wing and its x is the wing's thickness.
	local span = WING_TIP - HINGE_X
	local sweep = TIP_LEADING - ROOT_LEADING
	add(
		wing,
		"WingSweep",
		"wedge",
		Vector3.new(WING_TOP - HINGE_TOP, span, sweep),
		CFrame.fromMatrix(
			Vector3.new(side * (HINGE_X + span / 2), (HINGE_TOP + WING_TOP) / 2, ROOT_LEADING + sweep / 2),
			Vector3.new(0, -side, 0),
			Vector3.new(side, 0, 0)
		),
		WHITE,
		"sides"
	)
	box(
		wing,
		"WingRoot",
		Vector3.new(math.min(side * HINGE_X, side * 3.6), HINGE_TOP - 0.55, 1.9),
		Vector3.new(math.max(side * HINGE_X, side * 3.6), HINGE_TOP, 4.4),
		LIGHT_GREY,
		"sides"
	)
	add(
		wing,
		"GunMount",
		"cylinder",
		Vector3.new(STUD_HEIGHT, STUD_WIDTH, STUD_WIDTH),
		CFrame.new(side * GUN_X, HINGE_TOP - STUD_HEIGHT / 2, GUN_MOUNT_Z) * UPRIGHT,
		DARK_GREY,
		"underside"
	)

	-- The gun: a clip under the mount and a barrel out the front.
	local gun: Group = if side < 0 then "gunL" else "gunR"
	box(
		gun,
		"GunClip",
		Vector3.new(side * GUN_X - 0.35, GUN_Y - 0.25, GUN_MOUNT_Z - 0.4),
		Vector3.new(side * GUN_X + 0.35, HINGE_TOP - STUD_HEIGHT, GUN_MOUNT_Z + 0.4),
		DARK_GREY,
		"underside"
	)
	add(
		gun,
		"GunBarrel",
		"cylinder",
		Vector3.new(GUN_MOUNT_Z - 0.4, 0.75, 0.75),
		CFrame.new(side * GUN_X, GUN_Y, (GUN_MOUNT_Z + 0.4) / 2) * LENGTHWAYS,
		DARK_GREY,
		"underside"
	)
	add(
		gun,
		"Muzzle",
		"cylinder",
		Vector3.new(0.05, 0.35, 0.35),
		CFrame.new(side * GUN_X, GUN_Y, MUZZLE_Z) * LENGTHWAYS,
		BLACK,
		"underside"
	)
end

PlaneCar.groups = groups

-- As a car, the plane stands nose-up with its tail at the back of the hull:
-- plane space turned a quarter turn about x, then moved by TIP_TO. It tips
-- about TIP_ABOUT, near the tail.
local TIP_TO = Vector3.new(0, 5.25, 1.2)
local TIP_ABOUT = Vector3.new(0, HINGE_TOP, 4.5)
local QUARTER = math.rad(90)

local function tipped(amount: number): CFrame
	local turn = CFrame.Angles(QUARTER, 0, 0)
	local shift = TIP_TO - TIP_ABOUT + turn * TIP_ABOUT
	return CFrame.new(TIP_ABOUT + shift * amount) * CFrame.Angles(QUARTER * amount, 0, 0) * CFrame.new(-TIP_ABOUT)
end

-- A turn about a hinge at `at`.
local function about(at: CFrame, turn: CFrame): CFrame
	return at * turn * at:Inverse()
end

local WING_HINGES = {
	wingL = CFrame.new(-HINGE_X, HINGE_TOP, 0),
	wingR = CFrame.new(HINGE_X, HINGE_TOP, 0),
}
local GUN_PIVOTS = {
	gunL = CFrame.new(-GUN_X, GUN_Y, GUN_MOUNT_Z),
	gunR = CFrame.new(GUN_X, GUN_Y, GUN_MOUNT_Z),
}

local function wingPose(wing: "wingL" | "wingR", stages: PlaneMorph.Stages): CFrame
	local side = if wing == "wingL" then 1 else -1
	return tipped(stages.tip) * about(WING_HINGES[wing], CFrame.Angles(0, 0, side * QUARTER * stages.fold))
end

-- Where a group's parts go, from plane space to the hull's space, partway
-- through the transform. The nose folds down as the plane tips up, so it
-- stays pointing forward the whole way. Each gun swings in its wing's plane
-- toward the tip, which ends up pointing forward.
function PlaneCar.pose(group: Group, stages: PlaneMorph.Stages): CFrame
	if group == "body" then
		return tipped(stages.tip)
	elseif group == "nose" then
		return tipped(stages.tip) * about(NOSE_HINGE, CFrame.Angles(-QUARTER * stages.tip, 0, 0))
	elseif group == "wingL" or group == "wingR" then
		return wingPose(group, stages)
	end
	local side = if group == "gunL" then 1 else -1
	local wing = if group == "gunL" then "wingL" else "wingR"
	return wingPose(wing, stages) * about(GUN_PIVOTS[group], CFrame.Angles(0, side * QUARTER * stages.guns, 0))
end

-- Where the shots come out of the left gun (1) and the right gun (2), in
-- the hull's space, looking along the barrel.
function PlaneCar.muzzles(stages: PlaneMorph.Stages): { CFrame }
	return {
		PlaneCar.pose("gunL", stages) * CFrame.new(-GUN_X, GUN_Y, MUZZLE_Z),
		PlaneCar.pose("gunR", stages) * CFrame.new(GUN_X, GUN_Y, MUZZLE_Z),
	}
end

-- A tyre and hub welded to each physics wheel, in the wheel's own space,
-- where its axle is x. The physics wheels themselves are hidden.
PlaneCar.wheel = {
	{
		name = "Tyre",
		shape = "cylinder",
		size = Vector3.new(1.1, 2.8, 2.8),
		cframe = CFrame.new(),
		color = BLACK,
		transparency = 0,
	},
	{
		name = "Hub",
		shape = "cylinder",
		size = Vector3.new(1.16, 1.3, 1.3),
		cframe = CFrame.new(),
		color = LIGHT_GREY,
		transparency = 0,
	},
} :: { HeliCar.Spec }

-- Where a left wheel hides as a plane, from where it is as a car, in the
-- hull's space: up into the wing and in toward the middle. A right wheel's
-- is mirrored.
PlaneCar.WheelTuck = Vector3.new(0.7, 1.4, 0)

return PlaneCar
