--!strict
-- DinoBox (ModuleScript) -> ReplicatedStorage.DinoBox
-- The Dino Mystery Box: which car it holds, and how its wheel turns. Pure, see
-- InputAxes. The server picks the car; the client only shows the wheel landing
-- on it.
--
-- The wheel is a loop of cars. A position of k has car k + 1 (wrapping around)
-- in the middle, so whole numbers are the places it can stop.

local DinoBox = {}

export type Reward = {
	CarId: string,
	Weight: number, -- higher is more common
	Blurb: string, -- shown when the wheel lands on it
}

function DinoBox.allOwned(rewards: { Reward }, owned: { string }): boolean
	for _, reward in rewards do
		if not table.find(owned, reward.CarId) then
			return false
		end
	end
	return true
end

-- A weighted pick among the cars not owned yet, for a roll from 0 to 1. Nil if
-- they own them all.
function DinoBox.pick(rewards: { Reward }, owned: { string }, roll: number): Reward?
	local total = 0
	local last: Reward? = nil
	for _, reward in rewards do
		if not table.find(owned, reward.CarId) then
			total += reward.Weight
			last = reward
		end
	end
	local left = roll * total
	for _, reward in rewards do
		if not table.find(owned, reward.CarId) then
			left -= reward.Weight
			if left < 0 then
				return reward
			end
		end
	end
	return last
end

-- Where the wheel ends: on car `winner`, after `turns` full loops of `count` cars.
function DinoBox.stop(count: number, winner: number, turns: number): number
	return turns * count + winner - 1
end

-- The wheel's position `t` seconds in: fast at first, easing to rest on `stop`.
function DinoBox.position(t: number, duration: number, stop: number): number
	local left = 1 - math.clamp(t / duration, 0, 1)
	return stop * (1 - left * left * left)
end

-- How many places car `index` is from the middle, with the cars farthest away
-- wrapping to the other side.
function DinoBox.offset(index: number, position: number, count: number): number
	return (index - 1 - position + count / 2) % count - count / 2
end

return DinoBox
