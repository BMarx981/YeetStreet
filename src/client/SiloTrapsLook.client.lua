--!strict
-- SiloTrapsLook (LocalScript) -> StarterPlayerScripts.SiloTrapsLook
-- Draws the silo ramp's booby traps (SiloTraps) and moves them every frame
-- from the server's clock, so every player sees them in the same place. They
-- never touch anything: CarController asks SiloTraps.push how one knocks its
-- car. Each popper has a light on the column that glows red before it fires.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local SiloTraps = require(ReplicatedStorage.SiloTraps)
local Tuning = require(ReplicatedStorage.Tuning)

local S = Tuning.Silo
local T = S.Traps
local CONFIG: SiloTraps.Config = T :: any
local RAMP: SiloTraps.Ramp = S.Ramp :: any

local POPPER_COLOR = Color3.fromRGB(120, 60, 35)
local SWEEPER_COLOR = Color3.fromRGB(165, 130, 40)
local LIGHT_OFF = Color3.fromRGB(50, 15, 15)
local LIGHT_ON = Color3.fromRGB(255, 30, 20)

local area = MapLayout.find(Tuning.Map.Areas :: any, "Silo")
if not area then
	return
end

local center = Vector3.new(area.X, Tuning.Map.FloorTop, area.Z)

type Look = {
	trap: SiloTraps.Trap,
	part: Part,
	light: Part?,
	pop: Sound?,
	was: number,
}

local folder = Instance.new("Folder")
folder.Name = "SiloTraps"
folder.Parent = workspace

local function part(name: string, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Metal
	p.Parent = folder
	return p
end

-- Which way is out from the middle at `along`, and a point on the ramp there.
local function out(along: number): Vector3
	return Vector3.new(math.cos(along), 0, -math.sin(along))
end

local function at(radius: number, along: number, above: number): Vector3
	return center + out(along) * radius + Vector3.new(0, -RAMP.Pitch * along / (2 * math.pi) + above, 0)
end

local looks: { Look } = {}
for _, trap in SiloTraps.layout(CONFIG) do
	if trap.kind == "popper" then
		local P = T.Poppers
		local look: Look = {
			trap = trap,
			part = part("Popper", Vector3.new(P.Width, P.Height, P.Reach), POPPER_COLOR),
			was = 0,
		}
		local spot = at(S.ColumnRadius + 0.3, trap.along, P.Height / 2 + 2)
		local light = part("Warning", Vector3.new(P.Width * 0.6, 3, 0.5), LIGHT_OFF)
		light.CFrame = CFrame.lookAt(spot, spot + out(trap.along))
		look.light = light
		local pop = Instance.new("Sound")
		pop.SoundId = T.PopSoundId
		pop.Volume = T.PopVolume
		pop.RollOffMaxDistance = T.PopReach
		pop.Parent = look.part
		look.pop = pop
		table.insert(looks, look)
	else
		local W = T.Sweepers
		table.insert(looks, {
			trap = trap,
			part = part("Sweeper", Vector3.new(W.Across, W.Height, W.Length), SWEEPER_COLOR),
			was = 0,
		})
	end
end

local lane = SiloTraps.lane(RAMP)

local function place(look: Look, time: number)
	local trap = look.trap
	if trap.kind == "popper" then
		local P = T.Poppers
		local extent = SiloTraps.popperExtent(P, trap.id, time)
		if extent > 0 then
			-- Its inner end runs from inside the column's middle out.
			local spot = at(RAMP.InnerRadius + P.Reach * (extent - 0.5), trap.along, P.Height / 2 + 1)
			look.part.CFrame = CFrame.lookAt(spot, spot + out(trap.along))
		end
		look.part.Transparency = if extent > 0 then 0 else 1
		if extent > 0 and look.was == 0 and look.pop then
			look.pop:Play()
		end
		look.was = extent
		local light = look.light
		if light then
			local warning = SiloTraps.popperWarning(P, trap.id, time)
			light.Color = if warning then LIGHT_ON else LIGHT_OFF
			light.Material = if warning then Enum.Material.Neon else Enum.Material.Metal
		end
	else
		local W = T.Sweepers
		local along = trap.along + SiloTraps.sweeperOffset(W, trap.id, time) / lane
		local spot = at(lane, along, W.Height / 2 + 1)
		local ahead = at(lane, along + 0.01, W.Height / 2 + 1)
		look.part.CFrame = CFrame.lookAt(spot, ahead)
	end
end

local function near(): boolean
	return (workspace.CurrentCamera.CFrame.Position - center).Magnitude < T.DrawWithin
end

for _, look in looks do
	place(look, workspace:GetServerTimeNow())
end

RunService.Heartbeat:Connect(function()
	if not near() then
		return
	end
	local time = workspace:GetServerTimeNow()
	for _, look in looks do
		place(look, time)
	end
end)
