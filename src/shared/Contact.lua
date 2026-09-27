--!strict
-- Contact (ModuleScript) -> ReplicatedStorage.Contact
-- Decides when the car is flying, from how many wheels touch the ground each
-- frame, and when it is stuck on its roof. Pure, see InputAxes.

local Contact = {}

export type State = {
	airborne: boolean,
	-- Seconds since the last wheel left the ground. Zero while any wheel touches
	-- before lift off, and zero again on landing.
	airtime: number,
}

function Contact.new(): State
	return { airborne = false, airtime = 0 }
end

-- Lift off needs no wheels down for `airDelay` seconds, so bumps on the road do
-- not flip the controls into flight mode. Landing needs `landWheels` down, so
-- one wheel clipping a ledge mid flight does not end the flight.
function Contact.step(state: State, wheelsDown: number, dt: number, airDelay: number, landWheels: number): State
	if state.airborne then
		if wheelsDown >= landWheels then
			return Contact.new()
		end
		return { airborne = true, airtime = state.airtime + dt }
	end

	if wheelsDown > 0 then
		return Contact.new()
	end
	local airtime = state.airtime + dt
	return { airborne = airtime >= airDelay, airtime = airtime }
end

-- Seconds the car has been upside down (up vector Y below `maxUpY`) and slower
-- than `maxSpeed`. Any other frame resets it.
function Contact.stepStuck(
	timer: number,
	upY: number,
	speed: number,
	dt: number,
	maxUpY: number,
	maxSpeed: number
): number
	if upY < maxUpY and speed < maxSpeed then
		return timer + dt
	end
	return 0
end

return Contact
