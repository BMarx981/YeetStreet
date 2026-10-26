--!strict
-- Guns (ModuleScript) -> ReplicatedStorage.Guns
-- When a PlaneCar's guns shoot. Pure, see InputAxes.
--
-- Holding fire shoots Rate times a second, the two guns taking turns. The
-- driver's game times the shots; the server takes one only if it comes no
-- sooner than Slack of a shot's time after the last, so network jitter
-- doesn't drop shots but a hacked game can't shoot faster.

local Guns = {}

-- The cooldown after dt seconds, and whether to shoot now.
function Guns.step(cooldown: number, held: boolean, dt: number, rate: number): (number, boolean)
	if held and cooldown <= 0 then
		return cooldown + 1 / rate, true
	end
	return math.max(cooldown - dt, 0), false
end

function Guns.allowed(lastAt: number, now: number, rate: number, slack: number): boolean
	return now - lastAt >= slack / rate
end

function Guns.nextGun(gun: number): number
	return if gun == 1 then 2 else 1
end

return Guns
