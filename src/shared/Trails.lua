--!strict
-- Trails (ModuleScript) -> ReplicatedStorage.Trails
-- Car trails: which one a car wears, and when it shows. Pure, see InputAxes.
-- Values live in Tuning.Trails.
--
-- A car wears the trail its player picked in the garage (State): the
-- rebirth trail, whose look steps through Tuning.Trails.Rebirth with each
-- rebirth and cycles after the last, a prize trail they were given (the
-- daily reward's rainbow), or none. Winning a prize trail or rebirthing puts
-- that trail on. The trail shows only in the air, once the car has been up
-- for a lift delay, so bumps and small hops don't light it.

local Trails = {}

-- How long a car has been in the air.
export type Air = {
	aloft: number, -- seconds since it last had ground under it
}

-- The trail look id for a player with `rebirths`, from `looks` in order; nil
-- before the first rebirth.
function Trails.forRebirths(rebirths: number, looks: { string }): string?
	if rebirths < 1 or #looks == 0 then
		return nil
	end
	return looks[(rebirths - 1) % #looks + 1]
end

function Trails.newAir(): Air
	return { aloft = 0 }
end

-- Prize trails a player has been given (the daily reward's week 3 prize),
-- and which trail they chose in the garage: "Rebirth" for the rebirth trail
-- (also what nil means), an owned prize trail's look id, or "Off".
export type State = {
	Owned: { string }, -- prize trail look ids, in the order given
	Choice: string?,
}

function Trails.newState(): State
	return { Owned = {}, Choice = nil }
end

-- A saved state with unknown prize trails dropped. A choice that's no
-- longer owned goes back to the rebirth trail.
function Trails.reconcile(saved: any, prizes: { [string]: any }): State
	local state = Trails.newState()
	if typeof(saved) ~= "table" then
		return state
	end
	if typeof(saved.Owned) == "table" then
		for _, id in saved.Owned do
			if typeof(id) == "string" and prizes[id] ~= nil and not table.find(state.Owned, id) then
				table.insert(state.Owned, id)
			end
		end
	end
	local choice = saved.Choice
	if choice == "Off" or (typeof(choice) == "string" and table.find(state.Owned, choice)) then
		state.Choice = choice
	end
	return state
end

-- Gives the prize trail `id` and puts it on. Fails with "UnknownTrail" or
-- "Owned".
function Trails.give(state: State, id: string, prizes: { [string]: any }): (State?, string?)
	if prizes[id] == nil then
		return nil, "UnknownTrail"
	end
	if table.find(state.Owned, id) then
		return nil, "Owned"
	end
	local owned = table.clone(state.Owned)
	table.insert(owned, id)
	return { Owned = owned, Choice = id }, nil
end

-- What the player can pick, in the garage's order: the rebirth trail once
-- they have one, each prize trail, then "Off".
function Trails.options(state: State, rebirths: number): { string }
	local options = {}
	if rebirths >= 1 then
		table.insert(options, "Rebirth")
	end
	for _, id in state.Owned do
		table.insert(options, id)
	end
	table.insert(options, "Off")
	return options
end

-- The choice in effect: the saved one if it can still be picked, or else
-- the rebirth trail, which is "Off" before the first rebirth.
function Trails.current(state: State, rebirths: number): string
	local choice = state.Choice or "Rebirth"
	if table.find(Trails.options(state, rebirths), choice) then
		return choice
	end
	return if rebirths >= 1 then "Rebirth" else "Off"
end

-- `state` with the choice after the current one, round to the first.
function Trails.nextChoice(state: State, rebirths: number): State
	local options = Trails.options(state, rebirths)
	local at = table.find(options, Trails.current(state, rebirths)) or 0
	return { Owned = table.clone(state.Owned), Choice = options[at % #options + 1] }
end

-- `state` after a rebirth, which puts the new rebirth trail on.
function Trails.reborn(state: State): State
	return { Owned = table.clone(state.Owned), Choice = "Rebirth" }
end

-- The trail look id the car wears (its Trail attribute), or nil for none.
function Trails.worn(state: State, rebirths: number, rebirthLooks: { string }): string?
	local choice = Trails.current(state, rebirths)
	if choice == "Off" then
		return nil
	elseif choice == "Rebirth" then
		return Trails.forRebirths(rebirths, rebirthLooks)
	end
	return choice
end

-- Moves `air` on by `dt`, `grounded` or not, and says whether the trail
-- shows: once the car has been up for `liftDelay` seconds, until it lands.
function Trails.step(air: Air, grounded: boolean, dt: number, liftDelay: number): boolean
	if grounded then
		air.aloft = 0
		return false
	end
	air.aloft += dt
	return air.aloft >= liftDelay - 1e-9
end

return Trails
