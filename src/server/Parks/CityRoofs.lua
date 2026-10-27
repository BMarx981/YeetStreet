--!strict
-- CityRoofs (ModuleScript) -> ServerScriptService.Parks.CityRoofs
-- What goes on the dense city's roofs (Roofs), built by Parks.City into a
-- Roofs model in the park's folder, one Roof model a building with its Kind
-- attribute. It reads the roofs from the buildings already in the folder
-- (every Tower part; the spiral towers have none and are left out) and the
-- cranes standing on them, so it builds the same on a city just built from
-- code and on one saved with the place, without the rest being rebuilt.
-- Rebuilding replaces the folder's Roofs model.
--
-- A lip runs along each roof edge: a wedge in the building's own color and
-- material, rising toward the edge. On its roof's spot:
--   WaterTower: a wooden tank on legs, every part a knockable prop in one
--   Shatter model with Target "Water tower" (PropService pays it on a run).
--   An invisible Splash part tagged WaterTowerSplash marks where each
--   client draws the water bursting out (WaterTowerSplash).
--   Solar: rows of panels on frames a car drives up (Roofs.solarRows). The
--   panels are only looks: cars ride the frame, and start cracks the panels
--   where a car comes down hard.
--   Helipad: a pad with a ring round a big H, tagged Helipad, so a run
--   that lands on it pays the Helipad target (ScoreService). The paint and
--   lights on it are only looks.
--   Pool: a raised deck with ramps all round (Roofs.poolLayout) and a basin
--   down to the roof, every wall sloped to drive out. The water is only
--   looks, tagged Pool: a car falling into it splashes, and a run that
--   does pays the Pool target (ScoreService).
-- Numbers are in Tuning.City.Roofs.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Rng = require(ReplicatedStorage.Rng)
local Roofs = require(ReplicatedStorage.Roofs)
local Tuning = require(ReplicatedStorage.Tuning)

local T = Tuning.City.Roofs
local FLOOR = Tuning.Map.FloorTop

local STAVE_COLORS = { Color3.fromRGB(150, 105, 65), Color3.fromRGB(135, 92, 56) }
local IRON_COLOR = Color3.fromRGB(55, 55, 60)
local FRAME_COLOR = Color3.fromRGB(190, 192, 196)
local PANEL_COLOR = Color3.fromRGB(30, 45, 95)
local CRACKED_COLOR = Color3.fromRGB(200, 215, 230)
local PANEL_THICKNESS = 0.2
local SPLASH_TAG = "WaterTowerSplash"
local PAD_COLOR = Color3.fromRGB(70, 72, 78)
local RING_COLOR = Color3.fromRGB(255, 200, 40)
local LETTER_COLOR = Color3.fromRGB(240, 240, 240)
local PAD_LIGHT_COLOR = Color3.fromRGB(120, 255, 140)
local PAD_THICKNESS = 0.2
local PAINT = 0.05 -- each layer of paint above the last
local HELIPAD_TAG = "Helipad"
local DECK_COLOR = Color3.fromRGB(232, 226, 210)
local TILE_COLOR = Color3.fromRGB(120, 200, 235)
local WATER_COLOR = Color3.fromRGB(60, 165, 230)
local TILE_THICKNESS = 0.2
local POOL_TAG = "Pool"

local CityRoofs = {}

-- The footprint of an upright box part in park coordinates.
local function footprint(part: BasePart, area: MapLayout.Area): Roofs.Rect
	local p, s = part.Position, part.Size
	return {
		x1 = p.X - s.X / 2 - area.X,
		x2 = p.X + s.X / 2 - area.X,
		z1 = p.Z - s.Z / 2 - area.Z,
		z2 = p.Z + s.Z / 2 - area.Z,
	}
end

-- Every roof in the folder, west to east and then north to south, so the
-- kinds come out the same whichever order the buildings were made in. Each
-- tower's part is kept beside its roof for its look.
local function roofsIn(folder: Instance, area: MapLayout.Area): ({ Roofs.Roof }, { [Roofs.Roof]: BasePart })
	local masts: { BasePart } = {}
	local cranes = folder:FindFirstChild("Cranes")
	if cranes then
		for _, part in cranes:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Mast" then
				table.insert(masts, part)
			end
		end
	end
	local roofs: { Roofs.Roof } = {}
	local towers: { [Roofs.Roof]: BasePart } = {}
	local buildings = folder:FindFirstChild("Buildings")
	for _, part in if buildings then buildings:GetDescendants() else {} do
		if part:IsA("BasePart") and part.Name == "Tower" then
			local rect = footprint(part, area)
			local top = part.Position.Y + part.Size.Y / 2
			local roof: Roofs.Roof = {
				x1 = rect.x1,
				x2 = rect.x2,
				z1 = rect.z1,
				z2 = rect.z2,
				height = top - FLOOR,
				busy = {},
			}
			for _, mast in masts do
				local at = mast.Position
				local foot = at.Y - mast.Size.Y / 2
				if
					at.X - area.X > roof.x1
					and at.X - area.X < roof.x2
					and at.Z - area.Z > roof.z1
					and at.Z - area.Z < roof.z2
					and math.abs(foot - top) < 1
				then
					table.insert(roof.busy, footprint(mast, area))
				end
			end
			table.insert(roofs, roof)
			towers[roof] = part
		end
	end
	table.sort(roofs, function(a, b)
		if a.x1 ~= b.x1 then
			return a.x1 < b.x1
		end
		return a.z1 < b.z1
	end)
	return roofs, towers
end

-- A lip along one edge, its back face flush with the building's side.
local function lip(parent: Instance, area: MapLayout.Area, roof: Roofs.Roof, edge: Roofs.Lip, tower: BasePart)
	local out = Vector3.new(edge.outX, 0, edge.outZ)
	local length = math.abs(edge.x2 - edge.x1) + math.abs(edge.z2 - edge.z1)
	local middle = Vector3.new(area.X + (edge.x1 + edge.x2) / 2, FLOOR + roof.height, area.Z + (edge.z1 + edge.z2) / 2)
	local center = middle - out * (T.LipLength / 2) + Vector3.new(0, T.LipHeight / 2, 0)
	-- A wedge rises toward its +Z end, so look inward to rise toward the edge.
	local part = Instance.new("WedgePart")
	part.Name = "Lip"
	part.Anchored = true
	part.Size = Vector3.new(length, T.LipHeight, T.LipLength)
	part.CFrame = CFrame.lookAt(center, center - out)
	part.Color = tower.Color
	part.Material = tower.Material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

local function part(
	parent: Instance,
	name: string,
	class: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): BasePart
	local made = Instance.new(class) :: BasePart
	made.Name = name
	made.Anchored = true
	made.Size = size
	made.CFrame = cframe
	made.Color = color
	made.Material = material
	made.TopSurface = Enum.SurfaceType.Smooth
	made.BottomSurface = Enum.SurfaceType.Smooth
	made.Parent = parent
	return made
end

-- A flat disk lying level, centered on `at`.
local function disk(
	parent: Instance,
	name: string,
	at: Vector3,
	radius: number,
	thickness: number,
	color: Color3,
	material: Enum.Material
): BasePart
	local made = part(
		parent,
		name,
		"Part",
		Vector3.new(thickness, radius * 2, radius * 2),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material
	);
	(made :: Part).Shape = Enum.PartType.Cylinder
	return made
end

-- A water tower standing on the roof at `base`.
local function waterTower(parent: Instance, base: Vector3)
	local W = T.WaterTower
	local model = Instance.new("Model")
	model.Name = "WaterTower"
	model:SetAttribute("Shatter", true)
	local up = Vector3.yAxis
	local bottom = base + up * W.LegHeight

	local leg = W.Radius * 0.6
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1) } do
		part(
			model,
			"Leg",
			"Part",
			Vector3.new(W.LegSize, W.LegHeight, W.LegSize),
			CFrame.new(base + corner * leg + up * W.LegHeight / 2),
			IRON_COLOR,
			Enum.Material.Metal
		)
	end
	disk(model, "Floor", bottom - up * 0.5, W.Radius + 0.5, 1, IRON_COLOR, Enum.Material.Metal)

	local middle = bottom + up * W.TankHeight / 2
	local width = 2 * math.pi * W.Radius / W.Staves + 0.1
	for i = 1, W.Staves do
		local turn = CFrame.new(middle) * CFrame.Angles(0, (i - 0.5) / W.Staves * 2 * math.pi, 0)
		part(
			model,
			"Stave",
			"Part",
			Vector3.new(width, W.TankHeight, W.StaveThickness),
			turn * CFrame.new(0, 0, -(W.Radius - W.StaveThickness / 2)),
			STAVE_COLORS[i % 2 + 1],
			Enum.Material.WoodPlanks
		)
	end
	for _, share in { 0.25, 0.75 } do
		disk(model, "Hoop", bottom + up * W.TankHeight * share, W.Radius + 0.2, 0.6, IRON_COLOR, Enum.Material.Metal)
	end

	local step = W.RoofRise / 3
	for i, share in { 1.05, 0.65, 0.3 } do
		local at = bottom + up * (W.TankHeight + (i - 0.5) * step)
		disk(model, "Roof", at, W.Radius * share, step, STAVE_COLORS[2], Enum.Material.WoodPlanks)
	end

	for _, made in model:GetChildren() do
		made:SetAttribute("Target", "Water tower")
		made:SetAttribute("ResetTime", W.ResetTime)
		made:SetAttribute("CarSpeedShare", W.CarSpeedShare)
		CollectionService:AddTag(made, "Knockable")
	end

	local splash =
		part(model, "Splash", "Part", Vector3.one, CFrame.new(middle), IRON_COLOR, Enum.Material.SmoothPlastic)
	splash.Transparency = 1
	splash.CanCollide = false
	splash.CanQuery = false
	splash.CanTouch = false
	CollectionService:AddTag(splash, SPLASH_TAG)
	model.Parent = parent
end

-- A solar farm's rows on the roof `height` up: each a frame up the Run and
-- down the Back, with panels laid on its Run.
local function solarFarm(parent: Instance, area: MapLayout.Area, height: number, spot: Roofs.Rect)
	local S = T.Solar
	local model = Instance.new("Model")
	model.Name = "Solar"
	local up = Vector3.yAxis
	for _, row in Roofs.solarRows(spot, S :: any) do
		local rise = Vector3.new(row.riseX, 0, row.riseZ)
		local along = Vector3.new(math.abs(row.riseZ), 0, math.abs(row.riseX))
		local length = if row.riseZ ~= 0 then row.x2 - row.x1 else row.z2 - row.z1
		-- The middle of the row's low edge, behind the way it rises.
		local low = Vector3.new(
			area.X + (if row.riseX < 0 then row.x2 else (row.x1 + row.x2) / 2),
			FLOOR + height,
			area.Z + (if row.riseZ < 0 then row.z2 else (row.z1 + row.z2) / 2)
		)
		-- A wedge rises toward its +Z end.
		local front = low + rise * S.Run / 2 + up * S.Height / 2
		part(
			model,
			"Frame",
			"WedgePart",
			Vector3.new(length, S.Height, S.Run),
			CFrame.lookAt(front, front - rise),
			FRAME_COLOR,
			Enum.Material.Metal
		)
		local back = low + rise * (S.Run + S.Back / 2) + up * S.Height / 2
		part(
			model,
			"Frame",
			"WedgePart",
			Vector3.new(length, S.Height, S.Back),
			CFrame.lookAt(back, back + rise),
			FRAME_COLOR,
			Enum.Material.Metal
		)

		local slope = (rise * S.Run + up * S.Height).Magnitude
		local normal = (up * S.Run - rise * S.Height).Unit
		local count = math.floor((length + S.Seam) / (S.Panel + S.Seam))
		local first = -(count * (S.Panel + S.Seam) - S.Seam) / 2 + S.Panel / 2
		for i = 0, count - 1 do
			local center = front + normal * (PANEL_THICKNESS / 2) + along * (first + i * (S.Panel + S.Seam))
			local panel = part(
				model,
				"Panel",
				"Part",
				Vector3.new(S.Panel, PANEL_THICKNESS, slope - 0.6),
				CFrame.fromMatrix(center, along, normal),
				PANEL_COLOR,
				Enum.Material.Glass
			)
			panel.CanCollide = false
			panel.CanQuery = false
			panel.CanTouch = false
		end
	end
	model.Parent = parent
end

-- Paint and lights: seen, never touched or hit.
local function paint(made: BasePart)
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
end

-- A helipad filling the spot on the roof `height` up.
local function helipad(parent: Instance, area: MapLayout.Area, height: number, spot: Roofs.Rect)
	local H = T.Helipad
	local model = Instance.new("Model")
	model.Name = "Helipad"
	local up = Vector3.yAxis
	local middle = Vector3.new(area.X + (spot.x1 + spot.x2) / 2, FLOOR + height, area.Z + (spot.z1 + spot.z2) / 2)
	local pad = part(
		model,
		"Pad",
		"Part",
		Vector3.new(spot.x2 - spot.x1, PAD_THICKNESS, spot.z2 - spot.z1),
		CFrame.new(middle + up * PAD_THICKNESS / 2),
		PAD_COLOR,
		Enum.Material.Concrete
	)
	CollectionService:AddTag(pad, HELIPAD_TAG)

	local top = middle + up * PAD_THICKNESS
	paint(disk(model, "Ring", top + up * PAINT / 2, H.Ring, PAINT, RING_COLOR, Enum.Material.SmoothPlastic))
	paint(disk(model, "Inside", top + up * PAINT * 1.5, H.Ring - H.RingWidth, PAINT, PAD_COLOR, Enum.Material.Concrete))
	local width = H.Letter * 0.7
	local letter = top + up * PAINT * 2.5
	for _, side in { -1, 1 } do
		paint(
			part(
				model,
				"Letter",
				"Part",
				Vector3.new(H.Stroke, PAINT, H.Letter),
				CFrame.new(letter + Vector3.xAxis * side * (width - H.Stroke) / 2),
				LETTER_COLOR,
				Enum.Material.SmoothPlastic
			)
		)
	end
	paint(
		part(
			model,
			"Letter",
			"Part",
			Vector3.new(width, PAINT, H.Stroke),
			CFrame.new(letter),
			LETTER_COLOR,
			Enum.Material.SmoothPlastic
		)
	)
	for i = 1, H.Lights do
		local angle = (i - 0.5) / H.Lights * 2 * math.pi
		local at = top + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (H.Ring + 2) + up * 0.25
		paint(part(model, "Light", "Part", Vector3.new(1, 0.5, 1), CFrame.new(at), PAD_LIGHT_COLOR, Enum.Material.Neon))
	end
	model.Parent = parent
end

-- A pool deck on the roof `height` up.
local function pool(parent: Instance, area: MapLayout.Area, height: number, spot: Roofs.Rect)
	local P = T.Pool
	local layout = Roofs.poolLayout(spot, P :: any)
	local model = Instance.new("Model")
	model.Name = "Pool"
	local base = FLOOR + height
	local function box(rect: Roofs.Rect, bottom: number, top: number): (Vector3, Vector3)
		return Vector3.new(rect.x2 - rect.x1, top - bottom, rect.z2 - rect.z1),
			Vector3.new(area.X + (rect.x1 + rect.x2) / 2, base + (bottom + top) / 2, area.Z + (rect.z1 + rect.z2) / 2)
	end

	-- A ramp up each side of the deck, and a corner wedge between each two,
	-- so a car meets a slope coming from any way.
	local deck = layout.deck
	local sides = {
		{
			out = Vector3.new(0, 0, -1),
			at = Vector3.new((deck.x1 + deck.x2) / 2, 0, deck.z1),
			length = deck.x2 - deck.x1,
		},
		{
			out = Vector3.new(0, 0, 1),
			at = Vector3.new((deck.x1 + deck.x2) / 2, 0, deck.z2),
			length = deck.x2 - deck.x1,
		},
		{
			out = Vector3.new(-1, 0, 0),
			at = Vector3.new(deck.x1, 0, (deck.z1 + deck.z2) / 2),
			length = deck.z2 - deck.z1,
		},
		{
			out = Vector3.new(1, 0, 0),
			at = Vector3.new(deck.x2, 0, (deck.z1 + deck.z2) / 2),
			length = deck.z2 - deck.z1,
		},
	}
	for _, side in sides do
		local center = Vector3.new(area.X + side.at.X, base + P.Height / 2, area.Z + side.at.Z) + side.out * P.Ramp / 2
		-- A wedge rises toward its +Z end: look outward to rise inward.
		part(
			model,
			"Ramp",
			"WedgePart",
			Vector3.new(side.length, P.Height, P.Ramp),
			CFrame.lookAt(center, center + side.out),
			DECK_COLOR,
			Enum.Material.Concrete
		)
	end
	-- A corner wedge peaks at its +X, -Z corner, sloping down toward -X and
	-- +Z: turn its +X and +Z out from the deck's corner along the two sides.
	for _, corner in { { 1, 3 }, { 3, 2 }, { 2, 4 }, { 4, 1 } } do
		local a, b = sides[corner[1]].out, sides[corner[2]].out
		local right = -a
		if (right:Cross(Vector3.yAxis) - b).Magnitude > 0.01 then
			right = -b
		end
		local x = if a.X ~= 0 then (if a.X < 0 then deck.x1 else deck.x2) else (if b.X < 0 then deck.x1 else deck.x2)
		local z = if a.Z ~= 0 then (if a.Z < 0 then deck.z1 else deck.z2) else (if b.Z < 0 then deck.z1 else deck.z2)
		local center = Vector3.new(area.X + x, base + P.Height / 2, area.Z + z) + (a + b) * P.Ramp / 2
		part(
			model,
			"Corner",
			"CornerWedgePart",
			Vector3.new(P.Ramp, P.Height, P.Ramp),
			CFrame.fromMatrix(center, right, Vector3.yAxis),
			DECK_COLOR,
			Enum.Material.Concrete
		)
	end
	for _, slab in layout.rim do
		local size, center = box(slab, 0, P.Height)
		part(model, "Deck", "Part", size, CFrame.new(center), DECK_COLOR, Enum.Material.Concrete)
	end

	local size, center = box(layout.basin, 0, TILE_THICKNESS)
	part(model, "Tiles", "Part", size, CFrame.new(center), TILE_COLOR, Enum.Material.SmoothPlastic)
	-- A wedge rises toward its +Z end, across its X: look away from the wall.
	for _, slope in layout.slopes do
		local rise = Vector3.new(slope.riseX, 0, slope.riseZ)
		local slopeSize, slopeCenter = box(slope.rect, TILE_THICKNESS, P.Height)
		part(
			model,
			"Slope",
			"WedgePart",
			if slope.riseX ~= 0 then Vector3.new(slopeSize.Z, slopeSize.Y, slopeSize.X) else slopeSize,
			CFrame.lookAt(slopeCenter, slopeCenter - rise),
			TILE_COLOR,
			Enum.Material.SmoothPlastic
		)
	end

	local waterSize, waterCenter = box(layout.basin, TILE_THICKNESS, P.Height - P.WaterBelow)
	local water =
		part(model, "Water", "Part", waterSize, CFrame.new(waterCenter), WATER_COLOR, Enum.Material.SmoothPlastic)
	water.Transparency = 0.4
	water.Reflectance = 0.15
	paint(water)
	CollectionService:AddTag(water, POOL_TAG)
	model.Parent = parent
end

function CityRoofs.build(folder: Instance, area: MapLayout.Area)
	local old = folder:FindFirstChild("Roofs")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Roofs"
	local roofs, towers = roofsIn(folder, area)
	for _, plan in Roofs.plan(roofs, T :: any, Rng.new(T.Seed)) do
		local roof = Instance.new("Model")
		roof.Name = "Roof"
		roof:SetAttribute("Kind", plan.kind)
		for _, edge in plan.lips do
			lip(roof, area, plan.roof, edge, towers[plan.roof])
		end
		local spot = plan.spot
		if spot and plan.kind == "WaterTower" then
			local x, z = (spot.x1 + spot.x2) / 2, (spot.z1 + spot.z2) / 2
			waterTower(roof, Vector3.new(area.X + x, FLOOR + plan.roof.height, area.Z + z))
		elseif spot and plan.kind == "Solar" then
			solarFarm(roof, area, plan.roof.height, spot)
		elseif spot and plan.kind == "Helipad" then
			helipad(roof, area, plan.roof.height, spot)
		elseif spot and plan.kind == "Pool" then
			pool(roof, area, plan.roof.height, spot)
		end
		roof.Parent = model
	end
	model.Parent = folder
end

-- Cracks the solar panels near where a car comes down hard on a frame, and
-- mends them after a while.
function CityRoofs.start(folder: Instance, _area: MapLayout.Area)
	local K = T.Crack
	local roofs = folder:FindFirstChild("Roofs")
	if not roofs then
		return
	end
	local frames: { Instance } = {}
	local panels: { BasePart } = {}
	for _, made in roofs:GetDescendants() do
		if made:IsA("BasePart") and made.Name == "Frame" then
			table.insert(frames, made)
		elseif made:IsA("BasePart") and made.Name == "Panel" then
			table.insert(panels, made)
		end
	end
	if #frames == 0 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = frames
	local whole: { [BasePart]: { color: Color3, material: Enum.Material } } = {}
	local cars = workspace:WaitForChild("Cars")

	RunService.Heartbeat:Connect(function()
		for _, car in cars:GetChildren() do
			local hull = car:FindFirstChild("Hull")
			if not (hull and hull:IsA("BasePart") and hull.AssemblyLinearVelocity.Y < -K.Speed) then
				continue
			end
			local hit = workspace:Raycast(hull.Position, Vector3.new(0, -K.Reach, 0), params)
			if not hit then
				continue
			end
			for _, panel in panels do
				if not whole[panel] and (panel.Position - hit.Position).Magnitude < K.Radius then
					whole[panel] = { color = panel.Color, material = panel.Material }
					panel.Color = CRACKED_COLOR
					panel.Material = Enum.Material.Ice
					task.delay(K.Time, function()
						local was = whole[panel]
						whole[panel] = nil
						panel.Color = was.color
						panel.Material = was.material
					end)
				end
			end
		end
	end)
end

return CityRoofs
