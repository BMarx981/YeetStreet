--!strict
-- Flames (ModuleScript) -> ReplicatedStorage.Flames
-- Prize jet flames: which a player owns, and which one is on. Pure, see
-- InputAxes. Looks live in Tuning.Flames.Looks.
--
-- A flame is given (the daily reward's week 2 prize), never bought, and is
-- on as soon as it's won. With none on, a car's flames take the color of its
-- Jets level (CarDesign). The server puts the one that's on onto the car as
-- its Flame attribute, and every client draws it (JetFlames.paint).

local Flames = {}

export type Look = {
	Name: string, -- shown to players
	Colors: { { number } }, -- from the nozzle out, each { r, g, b }
}

export type State = {
	Owned: { string }, -- look ids, in the order given
	Worn: string?, -- the look id that's on, or nil for the Jets level colors
}

function Flames.newState(): State
	return { Owned = {}, Worn = nil }
end

-- A saved state with unknown looks dropped, and nothing on unless it's owned.
function Flames.reconcile(saved: any, looks: { [string]: Look }): State
	local state = Flames.newState()
	if typeof(saved) ~= "table" then
		return state
	end
	if typeof(saved.Owned) == "table" then
		for _, id in saved.Owned do
			if typeof(id) == "string" and looks[id] and not table.find(state.Owned, id) then
				table.insert(state.Owned, id)
			end
		end
	end
	if typeof(saved.Worn) == "string" and table.find(state.Owned, saved.Worn) then
		state.Worn = saved.Worn
	end
	return state
end

-- Gives the flame `id` and turns it on. Fails with "UnknownFlame" or "Owned".
function Flames.give(state: State, id: string, looks: { [string]: Look }): (State?, string?)
	if not looks[id] then
		return nil, "UnknownFlame"
	end
	if table.find(state.Owned, id) then
		return nil, "Owned"
	end
	local owned = table.clone(state.Owned)
	table.insert(owned, id)
	return { Owned = owned, Worn = id }, nil
end

-- Turns the owned flame `id` on, or every flame off with nil. Fails with
-- "NotOwned".
function Flames.wear(state: State, id: string?): (State?, string?)
	if id ~= nil and not table.find(state.Owned, id) then
		return nil, "NotOwned"
	end
	return { Owned = table.clone(state.Owned), Worn = id }, nil
end

-- The flame given most recently, or nil if there are none.
function Flames.newest(state: State): string?
	return state.Owned[#state.Owned]
end

-- Where each of `count` colors sits along a flame, from the nozzle (0) to the
-- tip (1). One color still gets both ends.
function Flames.stops(count: number): { number }
	if count <= 1 then
		return { 0, 1 }
	end
	local stops = {}
	for i = 1, count do
		stops[i] = (i - 1) / (count - 1)
	end
	return stops
end

return Flames
