--!strict
-- GravitronLook (LocalScript) -> StarterPlayerScripts.GravitronLook
-- Draws the Corkscrew park's gravitron spinning on this client
-- (GravitronRide). The bowl never moves; instead this client paints its
-- planks (the Bowl model, Parks.CorkscrewGravitron) in stripes that turn
-- round its axis on the server's clock, like everyone else's (Gravitron
-- striped). The stripes run from blue at the slowest stop to red at the
-- fastest, and flash there. The paint is this client's only, so the
-- server's bowl stays plain. During a replay they turn as they were at the
-- moment being watched (ReplayWorld).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gravitron = require(ReplicatedStorage.Gravitron)
local GravitronRide = require(ReplicatedStorage.GravitronRide)
local ReplayWorld = require(script.Parent.ReplayWorld)

local STRIPES = 12
local SLOW_COLOR = Color3.fromRGB(60, 140, 255)
local MIDDLE_COLOR = Color3.fromRGB(255, 220, 40)
local FAST_COLOR = Color3.fromRGB(255, 40, 30)
local LEVELS = 20 -- the color steps through this many shades, so planks are not repainted every frame
local FLASH_LEVEL = 0.95 -- at this level and over, the stripes flash
local FLASH_RATE = 6 -- flashes a second
local DRAW_RANGE = 2500 -- studs from the camera past which the spin is not drawn

local bowl = GravitronRide.bowl
if not bowl then
	return
end

-- Each plank streamed in: how far round the axis it is, and its own color.
type Plank = { around: number, color: Color3 }
local planks: { [BasePart]: Plank } = {}

local function add(instance: Instance)
	if instance:IsA("BasePart") then
		local p = bowl:PointToObjectSpace(instance.Position)
		-- Built at CFrame.Angles(0, around, 0) * CFrame.new(0, 0, -FloorRadius).
		planks[instance] = { around = math.atan2(-p.X, -p.Z), color = instance.Color }
	end
end

local function colorAt(level: number): Color3
	if level < 0.5 then
		return SLOW_COLOR:Lerp(MIDDLE_COLOR, level * 2)
	end
	return MIDDLE_COLOR:Lerp(FAST_COLOR, (level - 0.5) * 2)
end

task.spawn(function()
	local model =
		workspace:WaitForChild("Parks"):WaitForChild("Corkscrew"):WaitForChild("Gravitron"):WaitForChild("Bowl")
	model.DescendantAdded:Connect(add)
	model.DescendantRemoving:Connect(function(instance: Instance)
		planks[instance :: BasePart] = nil
	end)
	for _, instance in model:GetDescendants() do
		add(instance)
	end

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera or (camera.CFrame.Position - bowl.Position).Magnitude > DRAW_RANGE then
			return
		end
		local time = ReplayWorld.serverTime()
		local turned = GravitronRide.angle(time)
		local level = Gravitron.level(GravitronRide.spin, GravitronRide.speed(time))
		local color = colorAt(math.floor(level * LEVELS + 0.5) / LEVELS)
		if level >= FLASH_LEVEL and math.floor(time * FLASH_RATE * 2) % 2 == 1 then
			color = Color3.new(0, 0, 0):Lerp(color, 0.3)
		end
		for part, plank in planks do
			local paint = if Gravitron.striped(plank.around, turned, STRIPES) then color else plank.color
			if part.Color ~= paint then
				part.Color = paint
			end
		end
	end)
end)
