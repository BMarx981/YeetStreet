--!strict
-- GravitronLook (LocalScript) -> StarterPlayerScripts.GravitronLook
-- Draws the Corkscrew park's gravitron spinning on this client
-- (GravitronRide): stripes up its curve and wall, and lights round its rim
-- that run from blue at the slowest stop to red at the fastest, and flash
-- there. The bowl itself never moves; this one model of stripes and lights
-- turns round its axis, on the server's clock like everyone else's. Nothing
-- in it can be hit, touched or found by a ray.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurveProfile = require(ReplicatedStorage.CurveProfile)
local Gravitron = require(ReplicatedStorage.Gravitron)
local GravitronRide = require(ReplicatedStorage.GravitronRide)
local Tuning = require(ReplicatedStorage.Tuning)

local G = Tuning.Corkscrew.Gravitron

local STRIPES = 16
local STRIPE_WIDTH = 8
local STRIPE_COLORS = { Color3.fromRGB(235, 60, 60), Color3.fromRGB(245, 245, 245) }
local LIGHTS = 48
local SLOW_COLOR = Color3.fromRGB(60, 140, 255)
local MIDDLE_COLOR = Color3.fromRGB(255, 220, 40)
local FAST_COLOR = Color3.fromRGB(255, 40, 30)
local FLASH_LEVEL = 0.95 -- at this level and over, the lights flash
local FLASH_RATE = 6 -- flashes a second
local LIFT = 0.08 -- off the surface, so the stripes never flicker with it
local DRAW_RANGE = 2500 -- studs from the camera past which the spin is not drawn

local bowl = GravitronRide.bowl
if not bowl then
	return
end

local model = Instance.new("Model")
model.Name = "GravitronLook"

local function strip(size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Parent = model
	return part
end

-- Laid like CurvedWall's planks, in the bowl's space: `out` from the
-- floor's edge along the slice's -Z, `up` the axis, tilted `tilt` up from
-- flat, its top LIFT off the surface.
local function onSurface(slice: CFrame, out: number, up: number, tilt: number): CFrame
	return slice * CFrame.new(0, up, -out) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, LIFT, 0)
end

local footR, footY = Gravitron.foot(GravitronRide.shape)
local rimR = Gravitron.rimRadius(GravitronRide.shape)
local lean = math.rad(G.Lean)
local wallLength = (G.Height - footY) / math.cos(lean)
local curve = CurveProfile.planks(G.CurveRadius, 90 - G.Lean, G.CurveSteps)

for i = 1, STRIPES do
	local slice = CFrame.Angles(0, 2 * math.pi * i / STRIPES, 0) * CFrame.new(0, 0, -G.FloorRadius)
	local color = STRIPE_COLORS[i % #STRIPE_COLORS + 1]
	for _, plank in curve do
		strip(
			Vector3.new(STRIPE_WIDTH, 0.1, plank.length),
			onSurface(slice, plank.out, plank.up, plank.tilt),
			color,
			Enum.Material.SmoothPlastic
		)
	end
	strip(
		Vector3.new(STRIPE_WIDTH, 0.1, wallLength),
		onSurface(slice, (footR + rimR) / 2 - G.FloorRadius, (footY + G.Height) / 2, math.pi / 2 - lean),
		color,
		Enum.Material.SmoothPlastic
	)
end

-- The lights, just under the rim.
local lights: { Part } = {}
local lightOut = rimR - 4 * math.tan(lean) - G.FloorRadius
for i = 1, LIGHTS do
	local slice = CFrame.Angles(0, 2 * math.pi * (i + 0.5) / LIGHTS, 0) * CFrame.new(0, 0, -G.FloorRadius)
	table.insert(
		lights,
		strip(
			Vector3.new(CurveProfile.sliceLength(rimR, 360 / LIGHTS) * 0.6, 0.3, 4),
			onSurface(slice, lightOut, G.Height - 4, math.pi / 2 - lean),
			SLOW_COLOR,
			Enum.Material.Neon
		)
	)
end

model.WorldPivot = bowl
model.Parent = workspace

local function colorAt(level: number): Color3
	if level < 0.5 then
		return SLOW_COLOR:Lerp(MIDDLE_COLOR, level * 2)
	end
	return MIDDLE_COLOR:Lerp(FAST_COLOR, (level - 0.5) * 2)
end

local shownColor: Color3? = nil
RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - bowl.Position).Magnitude > DRAW_RANGE then
		return
	end
	local time = workspace:GetServerTimeNow()
	model:PivotTo(bowl * CFrame.Angles(0, GravitronRide.angle(time), 0))

	local level = Gravitron.level(GravitronRide.spin, GravitronRide.speed(time))
	local color = colorAt(level)
	if level >= FLASH_LEVEL and math.floor(time * FLASH_RATE * 2) % 2 == 1 then
		color = Color3.new(0, 0, 0):Lerp(color, 0.3)
	end
	if color ~= shownColor then
		shownColor = color
		for _, light in lights do
			light.Color = color
		end
	end
end)
