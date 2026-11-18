--!strict
-- TrailService (ModuleScript) -> ServerScriptService.TrailService
-- Car trails on the server: prize trails and the trail each player picked.
-- The rules are Trails'; this runs them.
--
-- Each player's trails show on them as the attributes TrailsOwned (prize
-- look ids, comma separated) and TrailChoice (Trails.current: "Rebirth",
-- a prize look id, or "Off"). The garage moves to the next choice with
-- ReplicatedStorage.NextTrail, a RemoteFunction answering (ok, reason) like
-- Garage's. The worn trail is the player's car's Trail attribute: set here
-- when the choice changes, and by CarService when a car spawns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService.PlayerData)
local Trails = require(ReplicatedStorage.Trails)
local Tuning = require(ReplicatedStorage.Tuning)

local T = Tuning.Trails

local TrailService = {}

local lastRequestAt: { [Player]: number } = {}

local function show(player: Player, state: Trails.State, rebirths: number)
	player:SetAttribute("TrailsOwned", table.concat(state.Owned, ","))
	player:SetAttribute("TrailChoice", Trails.current(state, rebirths))
	local cars = workspace:FindFirstChild("Cars")
	local car = cars and cars:FindFirstChild(`Car_{player.Name}`)
	if car then
		car:SetAttribute("Trail", Trails.worn(state, rebirths, T.Rebirth))
	end
end

local function set(player: Player, after: Trails.State, rebirths: number)
	PlayerData.update(player, function(data)
		data.Trails = after
	end)
	show(player, after, rebirths)
end

-- Gives the player the prize trail `id` (Tuning.Trails.Prizes) and puts it
-- on. Does nothing if they already have it.
function TrailService.give(player: Player, id: string)
	local data = PlayerData.get(player)
	local after = if data then Trails.give(data.Trails, id, T.Prizes) else nil
	if data and after then
		set(player, after, data.Rebirths)
	end
end

-- Puts the new rebirth trail on. Garage calls it when the player rebirths,
-- after their count has gone up.
function TrailService.reborn(player: Player)
	local data = PlayerData.get(player)
	if data then
		set(player, Trails.reborn(data.Trails), data.Rebirths)
	end
end

local nextTrail = Instance.new("RemoteFunction")
nextTrail.Name = "NextTrail"
nextTrail.OnServerInvoke = function(player: Player): (boolean, string?)
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < Tuning.Garage.RequestGap then
		return false, "TooSoon"
	end
	lastRequestAt[player] = now
	local data = PlayerData.get(player)
	if not data then
		return false, "NotLoaded"
	end
	set(player, Trails.nextChoice(data.Trails, data.Rebirths), data.Rebirths)
	return true, nil
end
nextTrail.Parent = ReplicatedStorage

local function onPlayerAdded(player: Player)
	local data = PlayerData.waitFor(player)
	if data then
		show(player, data.Trails, data.Rebirths)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player: Player)
	lastRequestAt[player] = nil
end)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

return TrailService
