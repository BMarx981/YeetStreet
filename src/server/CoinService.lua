--!strict
-- CoinService (ModuleScript) -> ServerScriptService.CoinService
-- Places the coins and gems (Coins) and says who grabs them. ScoreService
-- calls start once, touch each step a car is flying, and runEnded when its
-- run ends; the cash goes on that run's pay.
--
-- Each launcher in Tuning.Coins.Launchers gets a line of coins on the path
-- off its top pad, cut short where a coin would come within GroundClear of
-- anything below it, and a gem above the top of the path. They are published
-- for every client as JSON in ReplicatedStorage.CoinLines: a list of
-- { Id, Coins = { {x, y, z} }, Gem = {x, y, z} }, which CoinLook draws.
--
-- Each player has their own coins and gems. A coin a player grabs is gone
-- for them until their run ends; a gem until GemRespawn seconds later. Each
-- grab goes to that player on ReplicatedStorage.CoinPickup ("coin", line,
-- index) or ("gem", line, seconds until it is back), and all their coins
-- coming back on ReplicatedStorage.CoinsBack.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Coins = require(ReplicatedStorage.Coins)
local Tuning = require(ReplicatedStorage.Tuning)

local C = Tuning.Coins
local FIND_WAIT = 30 -- seconds to wait for a launcher's park to be built

type Line = { id: string, coins: { Coins.Point }, gem: Coins.Point? }

local CoinService = {}

local lines: { Line } = {}
-- Per player: the coins they took this run, by "line:index", and when they
-- took each line's gem (os.clock()).
local taken: { [Player]: { [string]: boolean } } = {}
local gemsTaken: { [Player]: { [number]: number } } = {}

local published = Instance.new("StringValue")
published.Name = "CoinLines"
published.Value = "[]"
published.Parent = ReplicatedStorage

local pickup = Instance.new("RemoteEvent")
pickup.Name = "CoinPickup"
pickup.Parent = ReplicatedStorage

local coinsBack = Instance.new("RemoteEvent")
coinsBack.Name = "CoinsBack"
coinsBack.Parent = ReplicatedStorage

local function point(v: Vector3): Coins.Point
	return { x = v.X, y = v.Y, z = v.Z }
end

local function vector(p: Coins.Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function model(id: string): Instance?
	for _, launcher in Tuning.LaunchRecords.Launchers do
		if launcher.Id == id then
			local at: Instance = workspace
			for name in string.gmatch(launcher.Path, "[^%.]+") do
				local child = at:WaitForChild(name, FIND_WAIT)
				if not child then
					warn(`CoinService: no {launcher.Path} for {id}'s coins`)
					return nil
				end
				at = child
			end
			return at
		end
	end
	warn(`CoinService: {id} is not a record launcher`)
	return nil
end

-- The launcher's highest pad, the one cars leave from.
local function topPad(launcher: Instance): BasePart?
	local top: BasePart? = nil
	for _, part in launcher:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("LaunchSpeed") and part:GetAttribute("NoRun") ~= true then
			if not top or part.Position.Y > top.Position.Y then
				top = part
			end
		end
	end
	return top
end

local function lineFor(id: string, launcher: Instance): Line?
	local pad = topPad(launcher)
	local speed = if pad then pad:GetAttribute("LaunchSpeed") else nil
	if not pad or typeof(speed) ~= "number" then
		warn(`CoinService: no launch pad in {id}`)
		return nil
	end
	local lip = (pad.CFrame * CFrame.new(0, pad.Size.Y / 2 + C.HullLift, -pad.Size.Z / 2)).Position
	local velocity = pad.CFrame.LookVector * speed
	local gravity = workspace.Gravity

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local cars = workspace:FindFirstChild("Cars")
	params.FilterDescendantsInstances = if cars then { cars } else {}

	local coins: { Coins.Point } = {}
	for _, p in Coins.arc(point(lip), point(velocity), gravity, C) do
		if workspace:Raycast(vector(p), Vector3.new(0, -C.GroundClear, 0), params) then
			break
		end
		table.insert(coins, p)
	end
	local apex = Coins.apex(point(lip), point(velocity), gravity)
	return { id = id, coins = coins, gem = { x = apex.x, y = apex.y + C.GemAbove, z = apex.z } }
end

function CoinService.start()
	task.spawn(function()
		for _, id in C.Launchers do
			local launcher = model(id)
			local line = if launcher then lineFor(id, launcher) else nil
			if line then
				table.insert(lines, line)
			end
		end
		local out = {}
		for _, line in lines do
			local coins = {}
			for _, p in line.coins do
				table.insert(coins, { p.x, p.y, p.z })
			end
			local gem = line.gem
			table.insert(out, {
				Id = line.id,
				Coins = coins,
				Gem = if gem then { gem.x, gem.y, gem.z } else nil,
			})
		end
		published.Value = HttpService:JSONEncode(out)
	end)
end

-- The coins and gems a car at `position` grabs now, for `player`.
function CoinService.touch(player: Player, position: Vector3): (number, number)
	local at = point(position)
	local mine = taken[player]
	if not mine then
		mine = {}
		taken[player] = mine
	end
	local myGems = gemsTaken[player]
	if not myGems then
		myGems = {}
		gemsTaken[player] = myGems
	end
	local now = os.clock()
	local coins, gems = 0, 0
	for li, line in lines do
		for ci, p in line.coins do
			local key = `{li}:{ci}`
			if not mine[key] and Coins.near(at, p, C.Radius) then
				mine[key] = true
				coins += 1
				pickup:FireClient(player, "coin", li, ci)
			end
		end
		local gem = line.gem
		if gem and Coins.gemReady(myGems[li], now, C.GemRespawn) and Coins.near(at, gem, C.Radius) then
			myGems[li] = now
			gems += 1
			pickup:FireClient(player, "gem", li, C.GemRespawn)
		end
	end
	return coins, gems
end

-- Puts back every coin the player took this run.
function CoinService.runEnded(player: Player)
	local mine = taken[player]
	if mine and next(mine) then
		taken[player] = {}
		coinsBack:FireClient(player)
	end
end

Players.PlayerRemoving:Connect(function(player: Player)
	taken[player] = nil
	gemsTaken[player] = nil
end)

return CoinService
