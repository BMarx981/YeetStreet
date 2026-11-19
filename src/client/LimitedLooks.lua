--!strict
-- LimitedLooks (ModuleScript) -> StarterPlayerScripts.LimitedLooks
-- Draws worn limited looks on every car, on this client (CarVisuals). The
-- server sets one car attribute per worn Look (Garage.dressCar), and each
-- look comes and goes with it:
--   Underglow  a neon strip under the body and a light on the ground below,
--              fading through every color in step on every screen
--   GoldRims   a gold spoked rim on the outside of each wheel, turning with
--              it; none on hidden wheels (hover cars, the mesh cars)
--   Crown      a gold crown floating and turning above the car's top
-- Values live in Tuning.LimitedLooks. The parts are massless and out of
-- physics, like the rest of the car's looks.
--
-- A replay ghost wears the same looks (ghost), held on by ReplayPlayer
-- instead of welds and moved on the replay's clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LimitedPoses = require(ReplicatedStorage.LimitedPoses)
local Tuning = require(ReplicatedStorage.Tuning)

local L = Tuning.LimitedLooks

local WHEEL_NAMES = { "WheelFL", "WheelFR", "WheelRL", "WheelRR" }

-- How a look's parts are held on. `fix` holds `part` to `base` where it is
-- now. `float` holds it at `offset` from `base` and returns what moves it to
-- another offset. `wheels` are the wheels Gold Rims go on.
export type Rig = {
	wheels: { BasePart },
	fix: (base: BasePart, part: BasePart) -> (),
	float: (base: BasePart, part: BasePart, offset: CFrame) -> (CFrame) -> (),
}

-- Draws one look into `folder`, and returns what moves it each frame, if
-- anything, given the server time.
type Build = (car: Model, hull: BasePart, folder: Folder, rig: Rig) -> ((number) -> ())?

local LimitedLooks = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function piece(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- A real car's rig: welds, on its visible wheels.
local function weldRig(car: Model): Rig
	local wheels: { BasePart } = {}
	for _, name in WHEEL_NAMES do
		local wheel = car:FindFirstChild(name)
		if wheel and wheel:IsA("BasePart") and wheel.Transparency < 1 then
			table.insert(wheels, wheel)
		end
	end
	return {
		wheels = wheels,
		fix = function(base: BasePart, part: BasePart)
			local joint = Instance.new("WeldConstraint")
			joint.Part0 = base
			joint.Part1 = part
			joint.Parent = part
		end,
		-- A Weld, not a WeldConstraint, so it can move every frame.
		float = function(base: BasePart, part: BasePart, offset: CFrame): (CFrame) -> ()
			local joint = Instance.new("Weld")
			joint.Part0 = base
			joint.Part1 = part
			joint.C0 = offset
			joint.Parent = part
			return function(moved: CFrame)
				joint.C0 = moved
			end
		end,
	}
end

local function gold(part: BasePart, color: { number }, reflectance: number)
	part.Color = rgb(color)
	part.Material = Enum.Material.Metal
	part.Reflectance = reflectance
end

local function underglow(_car: Model, hull: BasePart, folder: Folder, rig: Rig): ((number) -> ())?
	local U = L.Underglow
	local size = Vector3.new(hull.Size.X - 2 * U.Inset, 0.1, hull.Size.Z - 2 * U.Inset)
	local strip = piece("Underglow", size, hull.CFrame * CFrame.new(0, Tuning.CarLooks.BodyBottom - 0.1, 0), folder)
	strip.Material = Enum.Material.Neon
	rig.fix(hull, strip)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 120
	light.Range = U.Range
	light.Brightness = U.Brightness
	light.Parent = strip
	return function(t: number)
		local color = Color3.fromHSV(LimitedPoses.hue(t, U.CycleTime), 1, 1)
		strip.Color = color
		light.Color = color
	end
end

local function goldRims(_car: Model, hull: BasePart, folder: Folder, rig: Rig): ((number) -> ())?
	local R = L.GoldRims
	for _, wheel in rig.wheels do
		-- A wheel's axle is its X axis, and the rim goes on the end away from
		-- the hull.
		local side = if wheel.CFrame:PointToObjectSpace(hull.Position).X > 0 then -1 else 1
		local x = side * (wheel.Size.X / 2 + 0.06)
		local radius = wheel.Size.Y / 2 * R.Size
		local function add(partName: string, size: Vector3, offset: CFrame)
			local part = piece(partName, size, wheel.CFrame * offset, folder)
			gold(part, R.Color, R.Reflectance)
			rig.fix(wheel, part)
		end
		for _, ring in LimitedPoses.ring(radius, R.RingPieces) do
			local at = CFrame.new(x, radius * math.cos(ring.angle), radius * math.sin(ring.angle))
			add("RimRing", Vector3.new(0.14, 0.2, ring.length), at * CFrame.Angles(ring.angle, 0, 0))
		end
		for k = 0, R.Spokes - 1 do
			local angle = 2 * math.pi * k / R.Spokes
			local at = CFrame.new(x, radius / 2 * math.cos(angle), radius / 2 * math.sin(angle))
			add("RimSpoke", Vector3.new(0.12, radius, 0.22), at * CFrame.Angles(angle, 0, 0))
		end
		local cap =
			piece("RimCap", Vector3.new(0.18, radius * 0.6, radius * 0.6), wheel.CFrame * CFrame.new(x, 0, 0), folder)
		cap.Shape = Enum.PartType.Cylinder
		gold(cap, R.Color, R.Reflectance)
		rig.fix(wheel, cap)
	end
	return nil
end

-- How high the car's visible parts reach above the hull's middle, leaving
-- out the limited looks themselves.
local function carTop(car: Model, hull: BasePart, skip: Instance): number
	local top = hull.Size.Y / 2
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and not part:IsDescendantOf(skip) then
			top = math.max(top, hull.CFrame:PointToObjectSpace(part.Position).Y + part.Size.Y / 2)
		end
	end
	return top
end

local function crown(car: Model, hull: BasePart, folder: Folder, rig: Rig): ((number) -> ())?
	local C = L.Crown
	local looks = folder.Parent :: Instance
	local rest = carTop(car, hull, looks) + C.Gap
	local root = piece("CrownRoot", Vector3.one * 0.2, hull.CFrame * CFrame.new(0, rest, 0), folder)
	root.Transparency = 1
	local float = rig.float(hull, root, CFrame.new(0, rest, 0))
	local function add(name: string, size: Vector3, offset: CFrame, shape: Enum.PartType?): Part
		local part = piece(name, size, root.CFrame * offset, folder)
		if shape then
			part.Shape = shape
		end
		gold(part, C.Color, 0.2)
		rig.fix(root, part)
		return part
	end
	local bandHeight = 0.7
	for _, ring in LimitedPoses.ring(C.Radius, 12) do
		add(
			"Band",
			Vector3.new(ring.length, bandHeight, 0.22),
			CFrame.Angles(0, ring.angle, 0) * CFrame.new(0, 0, -C.Radius)
		)
	end
	for k = 0, 4 do
		local around = CFrame.Angles(0, 2 * math.pi * k / 5, 0)
		add("Point", Vector3.new(0.32, 0.9, 0.22), around * CFrame.new(0, bandHeight / 2 + 0.45, -C.Radius))
		add(
			"PointTip",
			Vector3.one * 0.38,
			around * CFrame.new(0, bandHeight / 2 + 0.95, -C.Radius),
			Enum.PartType.Ball
		)
		local gem = add(
			"Gem",
			Vector3.one * 0.3,
			CFrame.Angles(0, 2 * math.pi * (k + 0.5) / 5, 0) * CFrame.new(0, 0, -C.Radius - 0.12),
			Enum.PartType.Ball
		)
		gem.Color = rgb(C.Gem)
		gem.Material = Enum.Material.Neon
		gem.Reflectance = 0
	end
	local cushion = add(
		"Cushion",
		Vector3.new(0.9, C.Radius * 1.9, C.Radius * 1.9),
		CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Enum.PartType.Cylinder
	)
	cushion.Color = rgb(C.Cushion)
	cushion.Material = Enum.Material.Fabric
	cushion.Reflectance = 0
	add("Top", Vector3.one * 0.45, CFrame.new(0, 0.7, 0), Enum.PartType.Ball)
	return function(t: number)
		local lift, turn = LimitedPoses.crownFloat(t, C)
		float(CFrame.new(0, rest + lift, 0) * CFrame.Angles(0, turn, 0))
	end
end

local BUILDS: { [string]: Build } = {
	Underglow = underglow,
	GoldRims = goldRims,
	Crown = crown,
}

-- Draws `car`'s worn limited looks on `hull`, following its Look
-- attributes, until the car is gone.
function LimitedLooks.add(car: Model, hull: BasePart)
	local looks = Instance.new("Folder")
	looks.Name = "LimitedLooks"
	looks.Parent = car
	local shown: { [string]: { folder: Folder, step: ((number) -> ())? } } = {}
	for look, build in BUILDS do
		local function show()
			local on = car:GetAttribute(look) == true
			local now = shown[look]
			if on and not now then
				local folder = Instance.new("Folder")
				folder.Name = look
				folder.Parent = looks
				shown[look] = { folder = folder, step = build(car, hull, folder, weldRig(car)) }
			elseif not on and now then
				now.folder:Destroy()
				shown[look] = nil
			end
		end
		car:GetAttributeChangedSignal(look):Connect(show)
		show()
	end

	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if car.Parent == nil or hull.Parent == nil then
			connection:Disconnect()
			return
		end
		local t = workspace:GetServerTimeNow()
		for _, look in shown do
			if look.step then
				look.step(t)
			end
		end
	end)
end

-- Draws replay ghost `ghost`'s worn limited looks, from the Look attributes
-- copied from its car, on `hull` (a stand-in for the car's hull), held on by
-- `rig`. Returns what moves them to a server time, nil if it wears none.
function LimitedLooks.ghost(ghost: Model, hull: BasePart, rig: Rig): ((number) -> ())?
	local looks = Instance.new("Folder")
	looks.Name = "LimitedLooks"
	looks.Parent = ghost
	local steps: { (number) -> () } = {}
	for look, build in BUILDS do
		if ghost:GetAttribute(look) == true then
			local folder = Instance.new("Folder")
			folder.Name = look
			folder.Parent = looks
			local step = build(ghost, hull, folder, rig)
			if step then
				table.insert(steps, step)
			end
		end
	end
	if #steps == 0 then
		return nil
	end
	return function(t: number)
		for _, step in steps do
			step(t)
		end
	end
end

return LimitedLooks
