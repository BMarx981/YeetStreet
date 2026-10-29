--!strict
-- ObbyCourse (ModuleScript) -> ReplicatedStorage.ObbyCourse
-- Lays out the car obby's course from its stages. Pure, see InputAxes.
--
-- The course runs from a start point like a pen: each segment adds pieces
-- ahead of it and moves it on. A stage is a list of segments, and every
-- stage ends with a checkpoint pad (Obby) numbered by the stage. Checkpoint 0,
-- the start pad, comes before stage 1.
--
-- Headings are degrees, turning the way CFrame.Angles(0, angle, 0) turns:
-- facing -Z, left is -X. The course is always level across, so pieces only
-- turn about Y; a ramp is a wedge on a slab. A mover is a slab laid where a
-- road would be, that each client moves out of line and back (ObbyMover).
-- A ring is a wall standing across the way with a hole to fly through, made
-- of four slabs: a post each side and a bar above and below the hole. The
-- wall reaches RingBorder past the hole all round.

local ObbyCourse = {}

-- Same fields as ObbyMover.Mover, declared here so this module needs no require.
export type Mover = {
	Axis: string,
	Travel: number,
	Move: number,
	Hold: number,
	Phase: number,
}

export type Segment = {
	-- "Road" flat, "Ramp" sloped, "Gap" empty space, "Turn" a square corner,
	-- "Mover" a flat platform that moves, "Ring" a wall with a hole
	Kind: string,
	Length: number?, -- along the way, for Road, Ramp, Gap and Mover; a Ring's thickness
	Rise: number?, -- height gained, negative to go down, for Ramp and Gap
	Width: number?, -- in place of the stage's Width, for Road, Ramp and Mover; a Ring's hole
	Offset: number?, -- sideways, right is positive, for Gap; for Ring, of the hole
	Height: number?, -- of a Ring's hole
	Lift: number?, -- of a Ring's hole bottom, above the course
	Angle: number?, -- degrees, left is positive, for Turn
	Boost: number?, -- makes a Road or Ramp a booster, pushing cars up to this speed
	-- For Mover, see ObbyMover. Phase defaults to 0.
	Axis: string?,
	Travel: number?,
	Move: number?,
	Hold: number?,
	Phase: number?,
}

export type Stage = {
	Name: string,
	Width: number, -- of the stage's road, corners and pad
	Segments: { Segment },
}

-- Same fields as Tuning.Obby.World1, declared here so this module needs no require.
export type Tuning = {
	X: number, -- start point: the start pad's back edge, on its top
	Y: number,
	Z: number,
	Heading: number,
	Thickness: number, -- of every slab
	PadLength: number, -- of every checkpoint pad
	RingBorder: number, -- how far a ring's wall reaches past its hole
	Stages: { Stage },
}

export type Piece = {
	Kind: string, -- "Slab", "Wedge" or "Pad"
	X: number, -- center
	Y: number,
	Z: number,
	Heading: number,
	Width: number, -- across
	Height: number,
	Length: number, -- along the way
	Stage: number, -- 0 for the start pad
	Checkpoint: number?, -- for a Pad
	Rising: boolean?, -- for a Wedge: whether it rises along the way
	Corner: boolean?, -- for a Slab: whether it is a Turn's corner
	Boost: number?, -- for a booster Slab or Wedge: the speed it pushes cars up to
	Mover: Mover?, -- for a moving Slab: how it moves, from where it is here
	Ring: boolean?, -- for a Slab: whether it is part of a ring's wall
}

type Pen = { x: number, y: number, z: number, heading: number }

local function forward(heading: number): (number, number)
	local r = math.rad(heading)
	return -math.sin(r), -math.cos(r)
end

local function move(pen: Pen, along: number, right: number)
	local fx, fz = forward(pen.heading)
	pen.x += fx * along - fz * right
	pen.z += fz * along + fx * right
end

-- A box `length` long from the pen, its top `top` above the pen.
local function box(pen: Pen, kind: string, width: number, height: number, length: number, top: number, stage: number): Piece
	local fx, fz = forward(pen.heading)
	return {
		Kind = kind,
		X = pen.x + fx * length / 2,
		Y = pen.y + top - height / 2,
		Z = pen.z + fz * length / 2,
		Heading = pen.heading,
		Width = width,
		Height = height,
		Length = length,
		Stage = stage,
	}
end

-- A box like `box`, but `right` to the side of the pen.
local function aside(pen: Pen, right: number, kind: string, width: number, height: number, length: number, top: number, stage: number): Piece
	move(pen, 0, right)
	local piece = box(pen, kind, width, height, length, top, stage)
	move(pen, 0, -right)
	return piece
end

local function pad(pen: Pen, width: number, checkpoint: number, tuning: Tuning): Piece
	local piece = box(pen, "Pad", width, tuning.Thickness, tuning.PadLength, 0, checkpoint)
	piece.Checkpoint = checkpoint
	move(pen, tuning.PadLength, 0)
	return piece
end

local function segment(pen: Pen, seg: Segment, stage: Stage, n: number, tuning: Tuning, pieces: { Piece })
	local width = seg.Width or stage.Width
	local length = seg.Length or 0
	local rise = seg.Rise or 0
	if seg.Kind == "Road" then
		local road = box(pen, "Slab", width, tuning.Thickness, length, 0, n)
		road.Boost = seg.Boost
		table.insert(pieces, road)
		move(pen, length, 0)
	elseif seg.Kind == "Ramp" then
		local low = math.min(rise, 0)
		table.insert(pieces, box(pen, "Slab", width, tuning.Thickness, length, low, n))
		local wedge = box(pen, "Wedge", width, math.abs(rise), length, low + math.abs(rise), n)
		wedge.Rising = rise > 0
		wedge.Boost = seg.Boost
		table.insert(pieces, wedge)
		move(pen, length, 0)
		pen.y += rise
	elseif seg.Kind == "Gap" then
		move(pen, length, seg.Offset or 0)
		pen.y += rise
	elseif seg.Kind == "Mover" then
		local slab = box(pen, "Slab", width, tuning.Thickness, length, 0, n)
		slab.Mover = {
			Axis = seg.Axis or "Side",
			Travel = seg.Travel or 0,
			Move = seg.Move or 1,
			Hold = seg.Hold or 1,
			Phase = seg.Phase or 0,
		}
		table.insert(pieces, slab)
		move(pen, length, 0)
	elseif seg.Kind == "Ring" then
		local border = tuning.RingBorder
		local hole, high, lift, off = width, seg.Height or 0, seg.Lift or 0, seg.Offset or 0
		local top = lift + high + border
		local walls = {
			aside(pen, off - (hole + border) / 2, "Slab", border, high + 2 * border, length, top, n),
			aside(pen, off + (hole + border) / 2, "Slab", border, high + 2 * border, length, top, n),
			aside(pen, off, "Slab", hole, border, length, top, n),
			aside(pen, off, "Slab", hole, border, length, lift, n),
		}
		for _, wall in walls do
			wall.Ring = true
			table.insert(pieces, wall)
		end
		move(pen, length, 0)
	elseif seg.Kind == "Turn" then
		local corner = box(pen, "Slab", width, tuning.Thickness, width, 0, n)
		corner.Corner = true
		table.insert(pieces, corner)
		move(pen, width / 2, 0)
		pen.heading += seg.Angle or 0
		move(pen, width / 2, 0)
	end
end

-- Every piece of the course, in order from the start pad.
function ObbyCourse.layout(tuning: Tuning): { Piece }
	local pen: Pen = { x = tuning.X, y = tuning.Y, z = tuning.Z, heading = tuning.Heading }
	local first = tuning.Stages[1]
	local pieces = { pad(pen, if first then first.Width else 30, 0, tuning) }
	for n, stage in tuning.Stages do
		for _, seg in stage.Segments do
			segment(pen, seg, stage, n, tuning, pieces)
		end
		table.insert(pieces, pad(pen, stage.Width, n, tuning))
	end
	return pieces
end

return ObbyCourse
