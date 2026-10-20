--!strict
-- DinoWeather (Script) -> ServerScriptService.DinoWeather
-- Rains dino bones from the sky when triggered by an admin via the
-- `:weather bonerain` command. Players pick them up by touching them
-- to earn BoneCoins, shown in the leaderstats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Leaderstats = require(ServerScriptService.Leaderstats)

local boneRainEvent = ReplicatedStorage:FindFirstChild("BoneRainEvent")
local toggleEvent = ServerScriptService:FindFirstChild("BoneRainToggle")

-- ── Config ──────────────────────────────────────────────────────────────

local SPAWN_INTERVAL = 0.4     -- seconds between each bone spawn
local BONE_LIFETIME = 20       -- seconds before an uncollected bone disappears
local BONES_PER_PLAYER = 1    -- bones spawned per interval per player
local BONE_VALUE = 5          -- BoneCoins per bone
local FALL_HEIGHT = 120       -- studs above the ground to spawn
local SPAWN_RADIUS = 80       -- studs around the player to scatter bones
local DESPAWN_Y = -50         -- bones below this Y are removed

local BONE_COLOR = Color3.fromRGB(220, 210, 180)

-- ── State (declared early so functions below can reference) ──────────────

local raining = false
local boneFolder = nil

-- ── Trader NPC ──────────────────────────────────────────────────────────

local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local traderTemplate = ServerStorage:FindFirstChild("BoneTrader")
local traderNPC = nil
local traderWanderTask = nil

-- Wander config
local WANDER_RADIUS = 250      -- studs from map center to pick wander targets
local WANDER_TIMEOUT = 12      -- seconds before giving up on a walk target and picking a new one
local TRADER_SPAWN_HEIGHT = 5  -- studs above ground to spawn

-- Find a valid ground position by raycasting downward from the sky
local function findGroundPos(x: number, z: number): Vector3?
	local origin = Vector3.new(x, 500, z)
	local direction = Vector3.new(0, -1000, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excludeList = {}
	if boneFolder then table.insert(excludeList, boneFolder) end
	if traderNPC then table.insert(excludeList, traderNPC) end
	params.FilterDescendantsInstances = excludeList

	local result = workspace:Raycast(origin, direction, params)
	if result and result.Position.Y > -10 then
		return result.Position
	end
	return nil
end

local function spawnTrader()
	if traderNPC then return end
	if not traderTemplate then return end

	traderNPC = traderTemplate:Clone()

	-- Find a spawn position near the map center
	local spawnPos = nil
	for _ = 1, 20 do
		local angle = math.random() * math.pi * 2
		local dist = math.random(20, 100)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		local ground = findGroundPos(x, z)
		if ground then
			spawnPos = ground + Vector3.new(0, 3, 0)
			break
		end
	end

	if not spawnPos then
		spawnPos = Vector3.new(0, 5, 0)
	end

	traderNPC:PivotTo(CFrame.new(spawnPos))
	traderNPC.Parent = workspace

	-- Tag as Garage (so the shop key opens) and BoneTrader (so the shop shows
	-- bone items instead of the regular garage)
	CollectionService:AddTag(traderNPC, "Garage")
	CollectionService:AddTag(traderNPC, "BoneTrader")

	-- Add a glow so players can spot the trader easily
	local humanoid = traderNPC:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local root = traderNPC:FindFirstChild("HumanoidRootPart")
		if root then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 200, 100)
			light.Range = 25
			light.Brightness = 2
			light.Parent = root
		end
	end

	-- Start wandering loop
	traderWanderTask = task.spawn(function()
		while traderNPC and traderNPC.Parent do
			local humanoid = traderNPC:FindFirstChildOfClass("Humanoid")
			local root = traderNPC:FindFirstChild("HumanoidRootPart")
			if not humanoid or not root then break end

			-- Pick a random wander target
			local targetPos = nil
			for _ = 1, 10 do
				local angle = math.random() * math.pi * 2
				local dist = math.random(30, WANDER_RADIUS)
				local x = math.cos(angle) * dist
				local z = math.sin(angle) * dist
				local ground = findGroundPos(x, z)
				if ground then
					targetPos = ground + Vector3.new(0, 3, 0)
					break
				end
			end

			if targetPos then
				humanoid:MoveTo(targetPos)
				-- Wait until the trader reaches the target or times out
				local reached = false
				local conn = humanoid.MoveToFinished:Connect(function()
					reached = true
				end)
				local waited = 0
				while not reached and waited < WANDER_TIMEOUT and traderNPC and traderNPC.Parent do
					task.wait(0.5)
					waited += 0.5
				end
				conn:Disconnect()
			else
				task.wait(1)
			end

			-- Brief pause between walks
			if traderNPC and traderNPC.Parent then
				task.wait(math.random(1, 3))
			end
		end
	end)
end

local function removeTrader()
	if traderWanderTask then
		task.cancel(traderWanderTask)
		traderWanderTask = nil
	end
	if traderNPC then
		traderNPC:Destroy()
		traderNPC = nil
	end
end

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

	bone.Parent = boneFolder

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
		local bones = Leaderstats.value(player, "Bones")
		bones.Value += 1
		-- Also publish as an attribute so the GarageMenu client can refresh
		player:SetAttribute("BoneCoins", coins.Value)
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

-- ── Start / Stop ────────────────────────────────────────────────────────

local function fireBoneRain(isRaining: boolean)
	if not boneRainEvent then return end
	for _, p in Players:GetPlayers() do
		boneRainEvent:FireClient(p, isRaining)
	end
end

local function startBoneRain()
	if raining then return end
	raining = true

	boneFolder = Instance.new("Folder")
	boneFolder.Name = "BoneRain"
	boneFolder.Parent = workspace

	fireBoneRain(true)

	-- Spawn the wandering Bone Trader NPC
	spawnTrader()

	task.spawn(function()
		while raining do
			task.wait(SPAWN_INTERVAL)
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
	end)
end

local function stopBoneRain()
	raining = false
	if boneFolder then
		boneFolder:Destroy()
		boneFolder = nil
	end
	removeTrader()
	fireBoneRain(false)
end

-- Listen for admin toggle commands from AdminCommands
if toggleEvent then
	toggleEvent.Event:Connect(function(shouldRain: boolean)
		if shouldRain then
			startBoneRain()
		else
			stopBoneRain()
		end
	end)
end

-- Fire for players who join mid-rain
Players.PlayerAdded:Connect(function(player)
	if boneRainEvent and raining then
		boneRainEvent:FireClient(player, true)
	end
end)