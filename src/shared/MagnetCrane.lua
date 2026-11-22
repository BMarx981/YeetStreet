--!strict
-- MagnetCrane (ModuleScript) -> ReplicatedStorage.MagnetCrane
-- The Scrapyard's magnet crane (Tuning.Scrapyard.Crane): a tower with a boom
-- on top that turns, and a magnet hanging Radius out along it. One cycle
-- starts when a car stops on the pad under the waiting magnet: the magnet
-- comes down onto its roof over Lower seconds and clamps on, lifts it to
-- LiftHeight, swings round from PadAngle to DropAngle, holds, lets go, swings
-- back, and settles to wait again. Angles are degrees round the tower, 0
-- toward +Z and 90 toward +X; heights are the magnet's underside above the
-- floor; places are studs from the tower's middle. Pure, see InputAxes.

local MagnetCrane = {}

export type Config = {
	Radius: number,
	PadAngle: number,
	DropAngle: number,
	IdleHeight: number,
	GrabHeight: number, -- on a car's roof
	LiftHeight: number,
	Lower: number,
	Lift: number,
	Swing: number,
	Hold: number,
	Return: number,
	Settle: number,
	PadRadius: number,
	CatchHeight: number, -- a hull's middle this high above the floor or lower is on the pad
}

export type Phase = "idle" | "lowering" | "lifting" | "swinging" | "holding" | "returning" | "settling"

local function smooth(p: number): number
	return p * p * (3 - 2 * p)
end

-- Seconds into a cycle the magnet reaches the car's roof and clamps on.
function MagnetCrane.grabAt(c: Config): number
	return c.Lower
end

-- Seconds into a cycle it lets the car go over the drop.
function MagnetCrane.dropAt(c: Config): number
	return c.Lower + c.Lift + c.Swing + c.Hold
end

function MagnetCrane.cycleLength(c: Config): number
	return MagnetCrane.dropAt(c) + c.Return + c.Settle
end

-- The phase `elapsed` seconds into a cycle, and how far through it (0 to 1).
function MagnetCrane.phase(c: Config, elapsed: number): (Phase, number)
	if elapsed < 0 then
		return "idle", 0
	end
	local t = elapsed
	for _, step in
		{
			{ phase = "lowering" :: Phase, length = c.Lower },
			{ phase = "lifting" :: Phase, length = c.Lift },
			{ phase = "swinging" :: Phase, length = c.Swing },
			{ phase = "holding" :: Phase, length = c.Hold },
			{ phase = "returning" :: Phase, length = c.Return },
			{ phase = "settling" :: Phase, length = c.Settle },
		}
	do
		if t < step.length then
			return step.phase, t / step.length
		end
		t -= step.length
	end
	return "idle", 0
end

-- The boom's angle and the magnet's height `elapsed` seconds into a cycle.
function MagnetCrane.pose(c: Config, elapsed: number): (number, number)
	local phase, p = MagnetCrane.phase(c, elapsed)
	if phase == "lowering" then
		return c.PadAngle, c.IdleHeight + (c.GrabHeight - c.IdleHeight) * p * p
	elseif phase == "lifting" then
		return c.PadAngle, c.GrabHeight + (c.LiftHeight - c.GrabHeight) * smooth(p)
	elseif phase == "swinging" then
		return c.PadAngle + (c.DropAngle - c.PadAngle) * smooth(p), c.LiftHeight
	elseif phase == "holding" then
		return c.DropAngle, c.LiftHeight
	elseif phase == "returning" then
		return c.DropAngle + (c.PadAngle - c.DropAngle) * smooth(p), c.LiftHeight
	elseif phase == "settling" then
		return c.PadAngle, c.LiftHeight + (c.IdleHeight - c.LiftHeight) * smooth(p)
	end
	return c.PadAngle, c.IdleHeight
end

-- The sounds a cycle makes after `from` and by `to` seconds into it, in
-- order: "clamp" as the magnet takes hold, and "release" as it lets go.
function MagnetCrane.cues(c: Config, from: number, to: number): { string }
	local cues: { string } = {}
	for _, cue in
		{
			{ name = "clamp", at = MagnetCrane.grabAt(c) },
			{ name = "release", at = MagnetCrane.dropAt(c) },
		}
	do
		if from < cue.at and cue.at <= to then
			table.insert(cues, cue.name)
		end
	end
	return cues
end

-- Where the magnet hangs, across (x) and along (z), with the boom at `angle`.
function MagnetCrane.spot(c: Config, angle: number): (number, number)
	local a = math.rad(angle)
	return c.Radius * math.sin(a), c.Radius * math.cos(a)
end

-- Whether a hull (dx, dz) from the pad's middle and `y` above the floor is on it.
function MagnetCrane.onPad(c: Config, dx: number, dz: number, y: number): boolean
	return dx * dx + dz * dz <= c.PadRadius * c.PadRadius and y >= -2 and y <= c.CatchHeight
end

return MagnetCrane
