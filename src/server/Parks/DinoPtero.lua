--!strict
-- DinoPtero (ModuleScript) -> ServerScriptService.Parks.DinoPtero
-- Runs Dino Valley's pterodactyl on the server, which owns where it is and
-- every grab and drop. Each Heartbeat it steps the brain (Ptero) with every
-- car in workspace.Cars as the server sees them, and moves the pterodactyl
-- there, with its Mode attribute set to the brain's mode.
--
-- For now a grab only prints: it carries nothing up its spiral, and lets go
-- at the top, or at a fumble's height if the grab rolled one (Ptero.fumble).
--
-- The server moves one invisible part, Talons, at the brain's position
-- facing its heading, and a block stand-in (body and wings) above it.
-- Numbers are in Tuning.Dino.Ptero.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ptero = require(ReplicatedStorage.Ptero)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)

local P = Tuning.Dino.Ptero

-- The stand-in's body and wings, above the talons.
local BODY_SIZE = Vector3.new(6, 6, 24)
local WING_SIZE = Vector3.new(40, 1, 10)
local BODY_UP = 6
local STAND_IN_COLOR = Color3.fromRGB(150, 96, 64)

local DinoPtero = {}

local function marker(parent: Instance, name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size
	part.Parent = parent
	return part
end

local function standIn(parent: Instance, name: string, size: Vector3): Part
	local part = marker(parent, name, size)
	part.Transparency = 0
	part.Color = STAND_IN_COLOR
	part.Material = Enum.Material.SmoothPlastic
	return part
end

-- Starts the pterodactyl in `model`, perched at `perch` (facing its look),
-- hunting over `territory`.
function DinoPtero.start(model: Model, territory: Ptero.Territory, perch: CFrame)
	local talons = marker(model, "Talons", Vector3.one)
	local body = standIn(model, "StandInBody", BODY_SIZE)
	local leftWing = standIn(model, "StandInLeftWing", WING_SIZE)
	local rightWing = standIn(model, "StandInRightWing", WING_SIZE)
	local _, heading, _ = perch:ToOrientation()
	local s = Ptero.new(perch.X, perch.Y, perch.Z, heading)
	local rng = Rng.new(P.Seed)
	local rolls = Random.new()
	local carsFolder = workspace:WaitForChild("Cars")
	local fumbleAt: number? = nil
	model:SetAttribute("Mode", s.mode)

	RunService.Heartbeat:Connect(function(dt: number)
		local cars: { Ptero.Car } = {}
		for _, car in carsFolder:GetChildren() do
			local hull = if car:IsA("Model") then car.PrimaryPart else nil
			if hull then
				local p, v = hull.Position, hull.AssemblyLinearVelocity
				table.insert(cars, { id = car, x = p.X, y = p.Y, z = p.Z, vx = v.X, vy = v.Y, vz = v.Z })
			end
		end
		local grabbed = Ptero.step(s, cars, territory, rng, dt, P)
		if grabbed then
			fumbleAt = Ptero.fumble(rolls:NextNumber(), rolls:NextNumber(), P)
			print(
				`Pterodactyl grabbed {grabbed.Name}{if fumbleAt then `, will fumble at {math.floor(fumbleAt)}` else ""}`
			)
		end
		if s.mode == "carry" and Ptero.releases(s.y - territory.floor, 0, fumbleAt, P) then
			print(`Pterodactyl let go {math.floor(s.y - territory.floor)} up`)
			fumbleAt = nil
			Ptero.letGo(s)
		end
		if model:GetAttribute("Mode") ~= s.mode then
			model:SetAttribute("Mode", s.mode)
		end

		local fx, fz = Ptero.forward(s.heading)
		local at = Vector3.new(s.x, s.y, s.z)
		local frame = CFrame.lookAt(at, at + Vector3.new(fx, 0, fz))
		talons.CFrame = frame
		body.CFrame = frame * CFrame.new(0, BODY_UP, 0)
		leftWing.CFrame = frame * CFrame.new(-(BODY_SIZE.X + WING_SIZE.X) / 2, BODY_UP, 0)
		rightWing.CFrame = frame * CFrame.new((BODY_SIZE.X + WING_SIZE.X) / 2, BODY_UP, 0)
	end)
end

return DinoPtero
