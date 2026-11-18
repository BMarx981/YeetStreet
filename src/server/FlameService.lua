--!strict
-- FlameService (ModuleScript) -> ServerScriptService.FlameService
-- Prize jet flames on the server. The rules are Flames'; this runs them.
--
-- Each player's flames show on them as the attributes FlamesOwned (look ids,
-- comma separated) and FlameWorn (the look id that's on, or "" for none).
-- The garage turns one on with ReplicatedStorage.WearFlame and its look id,
-- or all off with "", a RemoteFunction answering (ok, reason) like
-- Garage's. The one that's on is the player's car's Flame attribute: set
-- here when it changes, and by CarService when a car spawns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Flames = require(ReplicatedStorage.Flames)
local PlayerData = require(ServerScriptService.PlayerData)
local Tuning = require(ReplicatedStorage.Tuning)

local LOOKS = Tuning.Flames.Looks

local FlameService = {}

local lastRequestAt: { [Player]: number } = {}

local function show(player: Player, state: Flames.State)
	player:SetAttribute("FlamesOwned", table.concat(state.Owned, ","))
	player:SetAttribute("FlameWorn", state.Worn or "")
	local cars = workspace:FindFirstChild("Cars")
	local car = cars and cars:FindFirstChild(`Car_{player.Name}`)
	if car then
		car:SetAttribute("Flame", state.Worn)
	end
end

local function set(player: Player, state: Flames.State)
	PlayerData.update(player, function(data)
		data.Flames = state
	end)
	show(player, state)
end

-- Gives the player the flame `id` (Tuning.Flames.Looks) and turns it on.
-- Does nothing if they already have it.
function FlameService.give(player: Player, id: string)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local after = Flames.give(data.Flames, id, LOOKS)
	if after then
		set(player, after)
	end
end

local wearFlame = Instance.new("RemoteFunction")
wearFlame.Name = "WearFlame"
wearFlame.OnServerInvoke = function(player: Player, id: any): (boolean, string?)
	if typeof(id) ~= "string" then
		return false, "UnknownFlame"
	end
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < Tuning.Garage.RequestGap then
		return false, "TooSoon"
	end
	lastRequestAt[player] = now
	local data = PlayerData.get(player)
	if not data then
		return false, "NotLoaded"
	end
	local after, reason = Flames.wear(data.Flames, if id == "" then nil else id)
	if not after then
		return false, reason
	end
	set(player, after)
	return true, nil
end
wearFlame.Parent = ReplicatedStorage

local function onPlayerAdded(player: Player)
	local data = PlayerData.waitFor(player)
	if data then
		show(player, data.Flames)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player: Player)
	lastRequestAt[player] = nil
end)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

return FlameService
