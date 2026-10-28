--!strict
-- Invites (ModuleScript) -> ReplicatedStorage.Invites
-- Invite rewards. Pure, see InputAxes.
--
-- A player who has never played joins from a friend's invite and remembers
-- who invited them (acceptInvite). Once they do their first launch, the
-- inviter is credited with them (credit): cash for each new friend, plus a
-- prize for every milestone the friend count crosses. Each friend counts once.
--
-- Separately, Roblox friends playing in the same server boost each other's
-- run payouts (squadBoost).

local Invites = {}

export type Milestone = {
	Friends: number, -- friend count that earns it
	Kind: string, -- "Cash" or "Car"
	Amount: number?, -- cash, for Kind "Cash"
	CarId: string?, -- the car given, for Kind "Car"
	Label: string,
}

-- Same fields as Tuning.Invites, declared here so this module needs no require.
export type Tuning = {
	PerFriend: number, -- cash for each new friend
	WelcomeCash: number, -- cash the invited friend gets on joining
	Milestones: { Milestone }, -- in rising Friends order
	SquadBoostPerFriend: number, -- payout bonus for each friend in the server
	SquadBoostMaxFriends: number, -- friends past this add nothing
}

export type State = {
	Friends: { number }, -- UserIds of new players this player brought in
	InvitedBy: number, -- UserId of who invited this player, 0 if nobody
	Reported: boolean, -- whether the inviter has been told of this player's first launch
}

export type Payout = {
	Added: number, -- friends newly credited
	Cash: number, -- per friend cash plus cash prizes
	Prizes: { Milestone }, -- every milestone crossed, cash ones included
}

local function isUserId(value: any): boolean
	return typeof(value) == "number" and value > 0 and value % 1 == 0
end

function Invites.newState(): State
	return { Friends = {}, InvitedBy = 0, Reported = false }
end

function Invites.reconcile(saved: any): State
	local state = Invites.newState()
	if typeof(saved) ~= "table" then
		return state
	end
	if typeof(saved.Friends) == "table" then
		for _, id in saved.Friends do
			if isUserId(id) and not table.find(state.Friends, id) then
				table.insert(state.Friends, id)
			end
		end
	end
	if isUserId(saved.InvitedBy) then
		state.InvitedBy = saved.InvitedBy
	end
	state.Reported = saved.Reported == true
	return state
end

-- `state` with its inviter set to `inviterId`, if this is a new player
-- (`isNew`) invited by someone else and no inviter is set yet.
function Invites.acceptInvite(state: State, inviterId: any, selfId: number, isNew: boolean): State
	if not isNew or state.InvitedBy ~= 0 or not isUserId(inviterId) or inviterId == selfId then
		return state
	end
	return { Friends = table.clone(state.Friends), InvitedBy = inviterId, Reported = state.Reported }
end

-- `state` with `friendIds` credited, and what that pays.
function Invites.credit(state: State, friendIds: { number }, tuning: Tuning): (State, Payout)
	local friends = table.clone(state.Friends)
	local before = #friends
	for _, id in friendIds do
		if isUserId(id) and not table.find(friends, id) then
			table.insert(friends, id)
		end
	end
	local after = #friends
	local payout: Payout = { Added = after - before, Cash = (after - before) * tuning.PerFriend, Prizes = {} }
	for _, milestone in tuning.Milestones do
		if milestone.Friends > before and milestone.Friends <= after then
			table.insert(payout.Prizes, milestone)
			if milestone.Kind == "Cash" then
				payout.Cash += milestone.Amount or 0
			end
		end
	end
	return { Friends = friends, InvitedBy = state.InvitedBy, Reported = state.Reported }, payout
end

-- The first milestone not yet reached with `count` friends, or nil past the last.
function Invites.nextMilestone(count: number, tuning: Tuning): Milestone?
	for _, milestone in tuning.Milestones do
		if milestone.Friends > count then
			return milestone
		end
	end
	return nil
end

-- The payout multiplier for having `friendsInServer` friends in the server.
function Invites.squadBoost(friendsInServer: number, tuning: Tuning): number
	return 1 + math.min(friendsInServer, tuning.SquadBoostMaxFriends) * tuning.SquadBoostPerFriend
end

return Invites
