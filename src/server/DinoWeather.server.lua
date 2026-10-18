--!strict
-- DinoWeather (Script) -> ServerScriptService.DinoWeather
-- Periodically rains dino bones from the sky. Players pick them up by touching
-- them to earn BoneCoins, shown in the leaderstats. The weather runs in
-- cycles: it rains bones for a while, then goes calm, then repeats.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Leaderstats = require(game.ServerScriptService.Leaderstats)

-- ── Config ──────────────────────────────────────────────────────────────

local RAIN_DURATION = 30      -- seconds of bone rain per cycle
local CALM_DURATION = 60      -- seconds of calm between cycles
local SPAWN_INTERVAL = 0.4     -- seconds between each bone spawn
local BONE_LIFETIME = 20       -- seconds before an uncollected bone disappears
local BONES_PER_PLAYER = 1    -- bones spawned per interval per player
local BONE_VALUE = 5          -- BoneCoins per bone
local FALL_HEIGHT = 120       -- studs above the ground to spawn
local SPAWN_RADIUS = 80       -- studs around the player to scatter bones
local DESPAWN_Y = -50         -- bones below this Y are removed

local BONE_COLOR = Color3.fromRGB(220, 210, 180)

-- ── State ───────────────────────────────────────────────────────────────

local raining = false
local cycleTime = 0
local spawnTimer = 0

-- ── Bone spawning ──────────────────────────────────────────────────────

local function spawnBone(center: Vector3)
	local angle = math.random() * math.pi * 2
	local dist = math.random() * SPAWN_RADIUS
	local x = center.X + math.cos(angle) * dist
	local z = center.Z + math.sin(angle) * dist
	local y = center.Y + FALL_HEIGHT

	local bone = Instance.new("Part")
	bone.Name = "DinoBone"
	bone.Size = Vector3.new(2, 1, 4)
	bone.Color = BONE_COLOR
	bone.Material = Enum.Material.SmoothPlastic
	bone.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	bone.Anchored = false
	bone.CanCollide = true
	bone.TopSurface = Enum.SurfaceType.Smooth
	bone.BottomSurface = Enum.SurfaceType.Smooth

	-- Small glow so bones are easy to spot
	local highlight = Instance.new("SelectionBox")
	highlight.Adornee = bone
	highlight.Color3 = Color3.fromRGB(255, 200, 80)
	highlight.LineThickness = 0.05
	highlight.Transparency = 0.5
	highlight.Parent = bone

	bone.Parent = workspace

	-- Track lifetime and cleanup
	local spawnedAt = os.clock()
	local collected = false

	bone.Touched:Connect(function(other: BasePart)
		if collected then return end
		local character = other.Parent
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		collected = true
		local coins = Leaderstats.value(player, "BoneCoins")
		coins.Value += BONE_VALUE
		bone:Destroy()
	end)

	-- Cleanup timer for uncollected bones
	task.spawn(function()
		while bone.Parent and not collected do
			task.wait(0.5)
			if os.clock() - spawnedAt > BONE_LIFETIME or bone.Position.Y < DESPAWN_Y then
				bone:Destroy()
				break
			end
		end
	end)
end

-- ── Main loop ───────────────────────────────────────────────────────────

RunService.Heartbeat:Connect(function(dt: number)
	cycleTime += dt

	if raining then
		if cycleTime >= RAIN_DURATION then
			raining = false
			cycleTime = 0
		end
		spawnTimer += dt
		if spawnTimer >= SPAWN_INTERVAL then
			spawnTimer = 0
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") then
					for _ = 1, BONES_PER_PLAYER do
						spawnBone(hrp.Position)
					end
				end
			end
		end
	else
		if cycleTime >= CALM_DURATION then
			raining = true
			cycleTime = 0
			spawnTimer = 0
		end
	end
end)