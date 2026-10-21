--!strict
-- Railway (ModuleScript) -> ReplicatedStorage.Railway
-- The dense city's train line (Tuning.City.Railway): one loop, elevated
-- along the first of StreetZ, down a ramp along the strip at each side of
-- the city (StripX either side of the middle), and under the ground along
-- the second street. Its middle line is a Tunnel path; this module gives
-- the segments, where the trains are on it, how a train pushes a car, and
-- the holes cut in the ground for the line to go under it. Pure, see
-- InputAxes. Heights are the deck's top, from the floor.

local Railway = {}

-- The parts of Tuning.City.Railway the line's shape needs.
export type Line = {
	High: number,
	Low: number,
	Corner: number,
	StreetZ: { number },
	StripX: number,
}

export type Trains = {
	Count: number,
	Carriages: number,
	Length: number,
	Gap: number,
	Speed: number,
}

export type Push = {
	Margin: number,
	Ahead: number,
	Side: number,
}

-- A rectangle on the ground, seen from above.
export type Rect = { x1: number, x2: number, z1: number, z2: number }

-- Where the loop starts: on the elevated street, a corner in from the west
-- strip, heading +X.
function Railway.start(line: Line): { x: number, z: number, y: number, headingX: number, headingZ: number }
	return { x = -(line.StripX - line.Corner), z = line.StreetZ[1], y = line.High, headingX = 1, headingZ = 0 }
end

-- The loop from Railway.start, as Tunnel segments: along the elevated
-- street, round and down the east strip, back along under the other
-- street, and round and up the west strip. Every turn is to the left.
function Railway.segments(line: Line): { { Straight: number?, Turn: number?, Radius: number?, Rise: number? } }
	local across = 2 * (line.StripX - line.Corner)
	local ramp = (line.StreetZ[1] - line.StreetZ[2]) - 2 * line.Corner
	local turn = { Turn = 90, Radius = line.Corner }
	return {
		{ Straight = across },
		turn,
		{ Straight = ramp, Rise = line.Low - line.High },
		turn,
		{ Straight = across },
		turn,
		{ Straight = ramp, Rise = line.High - line.Low },
		turn,
	}
end

-- Which piece `distance` along a loop of pieces `lengths` long falls on,
-- and how far through it, wrapping round either way.
function Railway.locate(lengths: { number }, distance: number): (number, number)
	local total = 0
	for _, length in lengths do
		total += length
	end
	local left = distance % total
	for index, length in lengths do
		if left <= length then
			return index, left / length
		end
		left -= length
	end
	return #lengths, 1
end

export type Span = { train: number, carriage: number, front: number, back: number }

-- Where every carriage is at `time` seconds, as distances round a loop
-- `total` long: Count trains spread evenly, each Carriages long with a Gap
-- between, all going round at Speed.
function Railway.carriages(total: number, time: number, trains: Trains): { Span }
	local spans: { Span } = {}
	for train = 1, trains.Count do
		local head = time * trains.Speed + (train - 1) * total / trains.Count
		for carriage = 1, trains.Carriages do
			local front = head - (carriage - 1) * (trains.Length + trains.Gap)
			table.insert(spans, {
				train = train,
				carriage = carriage,
				front = front % total,
				back = (front - trains.Length) % total,
			})
		end
	end
	return spans
end

-- How a carriage `half` its size each way (length, width, height), going
-- at `speed`, pushes a car whose middle is at (along, across, up) from the
-- carriage's middle, going (va, vc, vu) the same ways: when the car is
-- within Margin of it, ahead at Ahead times the train's speed or more, and
-- nudged out to its side at Side or more. Nil when the car is clear.
function Railway.push(
	along: number,
	across: number,
	up: number,
	va: number,
	vc: number,
	vu: number,
	halfLength: number,
	halfWidth: number,
	halfHeight: number,
	speed: number,
	push: Push
): (number?, number?, number?)
	if
		math.abs(along) > halfLength + push.Margin
		or math.abs(across) > halfWidth + push.Margin
		or math.abs(up) > halfHeight + push.Margin
	then
		return nil, nil, nil
	end
	local side = if across >= 0 then math.max(vc, push.Side) else math.min(vc, -push.Side)
	return math.max(va, speed * push.Ahead), side, vu
end

-- What is left of `rect` after cutting `holes` out of it, as rectangles.
function Railway.cut(rect: Rect, holes: { Rect }): { Rect }
	local pieces = { rect }
	for _, hole in holes do
		local kept: { Rect } = {}
		for _, piece in pieces do
			if hole.x2 <= piece.x1 or hole.x1 >= piece.x2 or hole.z2 <= piece.z1 or hole.z1 >= piece.z2 then
				table.insert(kept, piece)
			else
				local x1, x2 = math.max(piece.x1, hole.x1), math.min(piece.x2, hole.x2)
				local z1, z2 = math.max(piece.z1, hole.z1), math.min(piece.z2, hole.z2)
				local around = {
					{ x1 = piece.x1, x2 = x1, z1 = piece.z1, z2 = piece.z2 },
					{ x1 = x2, x2 = piece.x2, z1 = piece.z1, z2 = piece.z2 },
					{ x1 = x1, x2 = x2, z1 = piece.z1, z2 = z1 },
					{ x1 = x1, x2 = x2, z1 = z2, z2 = piece.z2 },
				}
				for _, part in around do
					if part.x2 - part.x1 > 1e-6 and part.z2 - part.z1 > 1e-6 then
						table.insert(kept, part)
					end
				end
			end
		end
		pieces = kept
	end
	return pieces
end

return Railway
