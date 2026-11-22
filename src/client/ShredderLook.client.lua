--!strict
-- ShredderLook (LocalScript) -> StarterPlayerScripts.ShredderLook
-- Makes and spins the Scrapyard shredder's toothed rollers on this client
-- (ShredderWorld, Tuning.Scrapyard.Shredder), neighbors turning toward each
-- other. They never touch anything: cars fall past them onto the hopper's
-- floor until the server catches them (Parks.ScrapyardShredder).
--
-- While a car has the Shredding attribute, sparks fly off the rollers, bits
-- in the car's own colors spray up out of the top (Shredder.spray), the
-- rollers grind louder, and its driver is hidden until the car is gone, as
-- nobody is ever hurt. A crunch plays as each car is caught. The car's own
-- parts spray out as they break (CarVisuals).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Rng = require(ReplicatedStorage.Rng)
local Shredder = require(ReplicatedStorage.Shredder)
local ShredderWorld = require(ReplicatedStorage.ShredderWorld)
local Tuning = require(ReplicatedStorage.Tuning)
local OneShot = require(script.Parent.OneShot)

local S = Tuning.Scrapyard.Shredder
local SOUNDS = Tuning.Scrapyard.Sounds
local CONFIG: Shredder.Config = S :: any

if not MapLayout.find(Tuning.Map.Areas :: any, "Scrapyard") then
	return
end

local PROPS_GROUP = "Props" -- CollisionGroups.Props, a server module
local DRAW_RANGE = 700 -- studs from the camera past which the rollers stand still
local TOOTH = Vector3.new(1.6, 2.4, 1.6)

local frame = ShredderWorld.frame
local rng = Rng.new(os.time())

local folder = Instance.new("Folder")
folder.Name = "ShredderLook"
folder.Parent = workspace

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.Color = color
	p.Material = material
	p.Parent = folder
	return p
end

-- Each roller across the opening, its teeth in rows along it, and each
-- tooth's place on its roller.
type Roller = { part: BasePart, at: CFrame, spin: number }
type Tooth = { part: BasePart, roller: Roller, offset: CFrame }

local rollers: { Roller } = {}
local teeth: { Tooth } = {}
local spacing = S.Length / S.Rollers
local across = S.Width - 1
for i = 1, S.Rollers do
	local along = -S.Length / 2 + (i - 0.5) * spacing
	-- A cylinder's axis is its X, so lying across the opening it is along
	-- the frame's RightVector already.
	local at = frame * CFrame.new(0, S.RestHeight - S.RollerRadius, along)
	local cylinder =
		part("Roller", Vector3.new(across, 2 * S.RollerRadius, 2 * S.RollerRadius), S.RollerColor, Enum.Material.Metal)
	cylinder.Shape = Enum.PartType.Cylinder
	local roller = { part = cylinder, at = at, spin = if i % 2 == 1 then 1 else -1 }
	table.insert(rollers, roller)
	for row = 1, S.TeethRows do
		local x = -across / 2 + (row - 0.5) * across / S.TeethRows
		for k = 1, S.Teeth do
			local angle = (k + row / 2) * 2 * math.pi / S.Teeth
			local offset = CFrame.new(x, 0, 0) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, S.RollerRadius, 0)
			table.insert(teeth, {
				part = part("Tooth", TOOTH, S.TeethColor, Enum.Material.Metal),
				roller = roller,
				offset = offset,
			})
		end
	end
end

local moving: { BasePart } = {}
for _, roller in rollers do
	table.insert(moving, roller.part)
end
for _, tooth in teeth do
	table.insert(moving, tooth.part)
end
local places: { CFrame } = table.create(#moving)

local function turnRollers(time: number)
	local n = 0
	local turned: { [Roller]: CFrame } = {}
	for _, roller in rollers do
		local cf = roller.at * CFrame.Angles(roller.spin * time * S.RollerSpin * 2 * math.pi, 0, 0)
		turned[roller] = cf
		n += 1
		places[n] = cf
	end
	for _, tooth in teeth do
		n += 1
		places[n] = turned[tooth.roller] * tooth.offset
	end
	workspace:BulkMoveTo(moving, places, Enum.BulkMoveMode.FireCFrameChanged)
end
turnRollers(0)

-- Sparks off the rollers' tops while a car is chewed.
local sparkPlate = part("Sparks", Vector3.new(S.Width, 0.2, S.Length), S.RollerColor, Enum.Material.SmoothPlastic)
sparkPlate.Transparency = 1
sparkPlate.CFrame = frame * CFrame.new(0, S.RestHeight, 0)
local sparks = Instance.new("ParticleEmitter")
sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 110, 30))
sparks.LightEmission = 1
sparks.Size = NumberSequence.new(0.35, 0)
sparks.Lifetime = NumberRange.new(0.3, 0.7)
sparks.Speed = NumberRange.new(25, 50)
sparks.SpreadAngle = Vector2.new(35, 35)
sparks.Acceleration = Vector3.new(0, -Tuning.World.Gravity / 2, 0)
sparks.Rate = 120
sparks.Enabled = false
sparks.Parent = sparkPlate

local grind = OneShot.make(SOUNDS.ShredIdle, SOUNDS.Near, SOUNDS.Far, sparkPlate)
grind.Looped = true
grind:Play()

local function setHidden(things: { Instance }, hidden: boolean)
	for _, thing in things do
		if thing:IsA("BasePart") or thing:IsA("Decal") then
			thing.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

-- One chewed bit, in one of the car's colors, flying up out of the top.
local function spray(at: Vector3, colors: { Color3 })
	local bit = Instance.new("Part")
	bit.Name = "ShredBit"
	bit.Size = Vector3.new(
		rng.range(S.BitSize.Min, S.BitSize.Max),
		rng.range(S.BitSize.Min, S.BitSize.Max) / 2,
		rng.range(S.BitSize.Min, S.BitSize.Max)
	)
	bit.Color = if #colors > 0 then colors[rng.int(1, #colors)] else S.TeethColor
	bit.Material = Enum.Material.Metal
	bit.CanQuery = false
	bit.CanTouch = false
	bit.CollisionGroup = PROPS_GROUP
	bit.CFrame = CFrame.new(at) * CFrame.Angles(rng.range(0, 6.3), rng.range(0, 6.3), 0)
	bit.AssemblyLinearVelocity = Vector3.new(Shredder.spray(CONFIG, rng))
	bit.AssemblyAngularVelocity = Vector3.new(rng.range(-10, 10), rng.range(-10, 10), rng.range(-10, 10))
	bit.Parent = folder
	Debris:AddItem(bit, S.BitLife)
end

-- Each car being chewed: its colors, its hidden driver, and the bits owed.
type Chewing = { colors: { Color3 }, hidden: { Instance }, owed: number }
local chewing: { [Model]: Chewing } = {}

local function startChewing(car: Model): Chewing
	local seen: { [Color3]: boolean } = {}
	local colors: { Color3 } = {}
	for _, thing in car:GetDescendants() do
		if thing:IsA("BasePart") and thing.Transparency < 1 and not seen[thing.Color] then
			seen[thing.Color] = true
			table.insert(colors, thing.Color)
		end
	end
	local hidden: { Instance } = {}
	local owner = Players:GetPlayerByUserId(car:GetAttribute("OwnerUserId") :: any or 0)
	if owner and owner.Character then
		hidden = owner.Character:GetDescendants()
		setHidden(hidden, true)
	end
	local hull = car.PrimaryPart
	OneShot.at(SOUNDS.ShredCatch, if hull then hull.Position else frame.Position, SOUNDS.Near, SOUNDS.Far)
	return { colors = colors, hidden = hidden, owed = 0 }
end

RunService.RenderStepped:Connect(function(dt: number)
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - frame.Position).Magnitude < DRAW_RANGE then
		turnRollers(os.clock())
	end

	for car, state in chewing do
		if not car.Parent or car:GetAttribute("Shredding") ~= true then
			setHidden(state.hidden, false)
			chewing[car] = nil
		end
	end
	local cars = workspace:FindFirstChild("Cars")
	if cars then
		for _, car in cars:GetChildren() do
			if car:IsA("Model") and car:GetAttribute("Shredding") == true and not chewing[car] then
				chewing[car] = startChewing(car)
			end
		end
	end

	local busy = next(chewing) ~= nil
	sparks.Enabled = busy
	local sound = if busy then SOUNDS.ShredGrinding else SOUNDS.ShredIdle
	grind.PlaybackSpeed = sound.Pitch
	grind.Volume = sound.Volume
	for car, state in chewing do
		local hull = car.PrimaryPart
		if not hull then
			continue
		end
		state.owed += dt * S.BitsPerSecond
		while state.owed >= 1 do
			state.owed -= 1
			spray(hull.Position + Vector3.new(0, 2, 0), state.colors)
		end
	end
end)
