--!strict
local Check = require("./Check")
local Invites = require("../src/shared/Invites")

local T: Invites.Tuning = {
	PerFriend = 100,
	WelcomeCash = 50,
	Milestones = {
		{ Friends = 1, Kind = "Cash", Amount = 10, Label = "first" },
		{ Friends = 3, Kind = "Cash", Amount = 30, Label = "third" },
		{ Friends = 5, Kind = "Car", CarId = "Prize", Label = "car" },
	},
	SquadBoostPerFriend = 0.1,
	SquadBoostMaxFriends = 3,
}

local function withFriends(ids: { number }): Invites.State
	local state = Invites.newState()
	state.Friends = ids
	return state
end

Check.test("a new state has no friends and no inviter", function()
	local state = Invites.newState()
	Check.eq(#state.Friends, 0)
	Check.eq(state.InvitedBy, 0)
	Check.eq(state.Reported, false)
end)

Check.test("reconcile keeps valid saved fields", function()
	local state = Invites.reconcile({ Friends = { 11, 22 }, InvitedBy = 7, Reported = true })
	Check.eq(#state.Friends, 2)
	Check.eq(state.Friends[2], 22)
	Check.eq(state.InvitedBy, 7)
	Check.eq(state.Reported, true)
end)

Check.test("reconcile drops junk and duplicate friends", function()
	local state = Invites.reconcile({ Friends = { 11, "x", -3, 1.5, 11, 22 }, InvitedBy = -1, Reported = "yes" })
	Check.eq(#state.Friends, 2)
	Check.eq(state.Friends[1], 11)
	Check.eq(state.Friends[2], 22)
	Check.eq(state.InvitedBy, 0)
	Check.eq(state.Reported, false)
end)

Check.test("reconcile of nothing is a new state", function()
	local state = Invites.reconcile(nil)
	Check.eq(#state.Friends, 0)
	Check.eq(state.InvitedBy, 0)
end)

Check.test("a new player accepts an invite", function()
	local state = Invites.acceptInvite(Invites.newState(), 7, 99, true)
	Check.eq(state.InvitedBy, 7)
end)

Check.test("a returning player can't accept an invite", function()
	local state = Invites.acceptInvite(Invites.newState(), 7, 99, false)
	Check.eq(state.InvitedBy, 0)
end)

Check.test("an invite from yourself or a bad id is ignored", function()
	Check.eq(Invites.acceptInvite(Invites.newState(), 99, 99, true).InvitedBy, 0)
	Check.eq(Invites.acceptInvite(Invites.newState(), 0, 99, true).InvitedBy, 0)
	Check.eq(Invites.acceptInvite(Invites.newState(), "7", 99, true).InvitedBy, 0)
	Check.eq(Invites.acceptInvite(Invites.newState(), nil, 99, true).InvitedBy, 0)
end)

Check.test("an accepted inviter is not replaced", function()
	local state = Invites.acceptInvite(Invites.newState(), 7, 99, true)
	state = Invites.acceptInvite(state, 8, 99, true)
	Check.eq(state.InvitedBy, 7)
end)

Check.test("the first friend pays per friend plus the first milestone", function()
	local state, payout = Invites.credit(Invites.newState(), { 11 }, T)
	Check.eq(#state.Friends, 1)
	Check.eq(payout.Added, 1)
	Check.eq(payout.Cash, 110)
	Check.eq(#payout.Prizes, 1)
	Check.eq(payout.Prizes[1].Label, "first")
end)

Check.test("a friend already credited pays nothing", function()
	local state, payout = Invites.credit(withFriends({ 11 }), { 11 }, T)
	Check.eq(#state.Friends, 1)
	Check.eq(payout.Added, 0)
	Check.eq(payout.Cash, 0)
	Check.eq(#payout.Prizes, 0)
end)

Check.test("duplicates and junk in one credit count once", function()
	local _, payout = Invites.credit(Invites.newState(), { 11, 11, "x" :: any, 0, -4 }, T)
	Check.eq(payout.Added, 1)
end)

Check.test("crossing several milestones at once pays each", function()
	local state, payout = Invites.credit(withFriends({ 1, 2 }), { 3, 4, 5 }, T)
	Check.eq(#state.Friends, 5)
	Check.eq(payout.Added, 3)
	Check.eq(payout.Cash, 330)
	Check.eq(#payout.Prizes, 2)
	Check.eq(payout.Prizes[1].Label, "third")
	Check.eq(payout.Prizes[2].Kind, "Car")
end)

Check.test("milestones already passed are not paid again", function()
	local _, payout = Invites.credit(withFriends({ 1, 2, 3, 4, 5 }), { 6 }, T)
	Check.eq(payout.Cash, 100)
	Check.eq(#payout.Prizes, 0)
end)

Check.test("credit leaves the old state alone", function()
	local before = withFriends({ 1 })
	Invites.credit(before, { 2 }, T)
	Check.eq(#before.Friends, 1)
end)

Check.test("next milestone is the first one not reached", function()
	Check.eq((Invites.nextMilestone(0, T) :: Invites.Milestone).Friends, 1)
	Check.eq((Invites.nextMilestone(1, T) :: Invites.Milestone).Friends, 3)
	Check.eq((Invites.nextMilestone(4, T) :: Invites.Milestone).Friends, 5)
	Check.eq(Invites.nextMilestone(5, T), nil)
end)

Check.test("squad boost grows per friend up to the cap", function()
	Check.near(Invites.squadBoost(0, T), 1)
	Check.near(Invites.squadBoost(1, T), 1.1)
	Check.near(Invites.squadBoost(3, T), 1.3)
	Check.near(Invites.squadBoost(8, T), 1.3)
end)

Check.finish("Invites")
