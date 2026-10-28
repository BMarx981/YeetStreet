--!strict
-- InviteRewards (ModuleScript) -> ServerScriptService.InviteRewards
-- Invite rewards on the server. The rules are Invites'; this runs them.
--
-- A player joining for the first time from a friend's invite remembers who
-- invited them and gets Tuning.Invites.WelcomeCash. The inviter comes from
-- the join data: ReferredByPlayerId, which Roblox sets for invites, or else
-- LaunchData holding the inviter's UserId.
--
-- After that player's first run ends (ScoreService calls ranRun), they are
-- added to their inviter's invite credits (PlayerData) and a message on
-- MessagingService tells the inviter's server, wherever it is. An inviter
-- has their credits checked when they join, on that message, and every
-- Tuning.Invites.CheckInterval, and is paid for friends not yet credited.
-- A car milestone adds that car to their garage (Garage.giveCar).
--
-- Roblox friends in the same server boost each other's run payouts
-- (squadBoost, used by ScoreService). Each player's count of friends here
-- shows as their SquadFriends attribute.
--
-- Each player's friend count shows as their InviteFriends attribute. Rewards
-- go to the player on ReplicatedStorage.InviteReward as a table: Welcome
-- (cash) for the invited player, or Added, Cash, Prizes (labels), and
-- Friends for the inviter.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Garage = require(ServerScriptService.Garage)
local Invites = require(ReplicatedStorage.Invites)
local PlayerData = require(ServerScriptService.PlayerData)
local Tuning = require(ReplicatedStorage.Tuning)

local T = Tuning.Invites
local TOPIC = "InviteCredit"

local InviteRewards = {}

local inviteReward = Instance.new("RemoteEvent")
inviteReward.Name = "InviteReward"
inviteReward.Parent = ReplicatedStorage

-- Players whose credit is being saved, so runs ending meanwhile don't repeat it.
local reporting: { [Player]: boolean } = {}

-- Each player's Roblox friends in this server, found when either joins.
local friendsHere: { [Player]: { [Player]: boolean } } = {}

local function squadSize(player: Player): number
	local count = 0
	local friends = friendsHere[player]
	if friends then
		for _ in friends do
			count += 1
		end
	end
	return count
end

local function findFriends(player: Player)
	friendsHere[player] = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and friendsHere[other] then
			local ok, friends = pcall(player.IsFriendsWithAsync, player, other.UserId)
			local mine, theirs = friendsHere[player], friendsHere[other]
			if ok and friends and mine and theirs then
				mine[other] = true
				theirs[player] = true
				other:SetAttribute("SquadFriends", squadSize(other))
			end
		end
	end
	player:SetAttribute("SquadFriends", squadSize(player))
end

-- The multiplier on the player's run payouts for friends in the server.
function InviteRewards.squadBoost(player: Player): number
	return Invites.squadBoost(squadSize(player), T)
end

local function inviterOf(player: Player): number?
	local ok, join: any = pcall(player.GetJoinData, player)
	if not ok or typeof(join) ~= "table" then
		return nil
	end
	-- Not in the type definitions yet; documented in Roblox's friend referral guide.
	local referrer = join.ReferredByPlayerId
	if typeof(referrer) == "number" and referrer > 0 then
		return referrer
	end
	local launch = join.LaunchData
	return if typeof(launch) == "string" then tonumber(launch) else nil
end

-- Pays the player for friends in their invite credits not yet credited.
function InviteRewards.check(player: Player)
	local credits = PlayerData.inviteCredits(player.UserId)
	local data = PlayerData.get(player)
	if not credits or not data or not player.Parent then
		return
	end
	local state, payout = Invites.credit(data.Invites, credits, T)
	if payout.Added == 0 then
		return
	end
	data.Invites = state
	Garage.pay(player, payout.Cash)
	player:SetAttribute("InviteFriends", #state.Friends)
	local prizes = {}
	for _, prize in payout.Prizes do
		if prize.Kind == "Car" and prize.CarId then
			Garage.giveCar(player, prize.CarId)
		end
		table.insert(prizes, prize.Label)
	end
	inviteReward:FireClient(player, {
		Added = payout.Added,
		Cash = payout.Cash,
		Prizes = prizes,
		Friends = #state.Friends,
	})
end

-- A run of the player's ended. The first one credits their inviter.
function InviteRewards.ranRun(player: Player)
	local data = PlayerData.get(player)
	if not data or data.Invites.InvitedBy == 0 or data.Invites.Reported or reporting[player] then
		return
	end
	local inviterId = data.Invites.InvitedBy
	reporting[player] = true
	task.spawn(function()
		if PlayerData.addInviteCredit(inviterId, player.UserId) then
			PlayerData.update(player, function(saved)
				saved.Invites.Reported = true
			end)
			local inviter = Players:GetPlayerByUserId(inviterId)
			if inviter then
				InviteRewards.check(inviter)
			else
				pcall(MessagingService.PublishAsync, MessagingService, TOPIC, inviterId)
			end
		end
		reporting[player] = nil
	end)
end

local function onPlayerAdded(player: Player)
	task.spawn(findFriends, player)
	local data = PlayerData.waitFor(player)
	if not data then
		return
	end
	if PlayerData.isNew(player) then
		local before = data.Invites.InvitedBy
		data.Invites = Invites.acceptInvite(data.Invites, inviterOf(player), player.UserId, true)
		if data.Invites.InvitedBy ~= before then
			Garage.pay(player, T.WelcomeCash)
			inviteReward:FireClient(player, { Welcome = T.WelcomeCash })
		end
	end
	player:SetAttribute("InviteFriends", #data.Invites.Friends)
	InviteRewards.check(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(function(player: Player)
	reporting[player] = nil
	local friends = friendsHere[player]
	friendsHere[player] = nil
	if friends then
		for other in friends do
			local theirs = friendsHere[other]
			if theirs then
				theirs[player] = nil
				other:SetAttribute("SquadFriends", squadSize(other))
			end
		end
	end
end)

local subscribed, problem = pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, function(message)
	local inviter = typeof(message.Data) == "number" and Players:GetPlayerByUserId(message.Data)
	if inviter then
		InviteRewards.check(inviter)
	end
end)
if not subscribed then
	warn(`InviteRewards: no MessagingService, invite credits wait for the next check ({problem})`)
end

task.spawn(function()
	while true do
		task.wait(T.CheckInterval)
		for _, player in Players:GetPlayers() do
			task.spawn(InviteRewards.check, player)
		end
	end
end)

return InviteRewards
