--!strict
-- ReplayWorld (ModuleScript) -> StarterPlayerScripts.ReplayWorld
-- The moment the world is drawn at: while a replay plays (ReplayPlayer), the
-- moment of the replay being watched, otherwise now.
--
-- Scripts that draw things moving on the server's clock ask it the time
-- (serverTime), so in a replay they are where they were then: the trains
-- (TrainSet), wrecking balls (WreckingBallLook), walkers (PedestrianLook),
-- the gravitron's stripes (GravitronLook), and the brontosaurus's tail
-- (DinoTail). Anything that pushes the real car, like TrainSet.push and
-- WreckingBalls.push in CarController, keeps to the real time.

local ReplayWorld = {}

local watching: number? = nil

-- The server time to draw the world at.
function ReplayWorld.serverTime(): number
	return watching or workspace:GetServerTimeNow()
end

-- Whether the world is drawn at a replay's moment rather than now.
function ReplayWorld.isWatching(): boolean
	return watching ~= nil
end

-- Draws the world at server time `time`, or now again when nil.
function ReplayWorld.watch(time: number?)
	watching = time
end

return ReplayWorld
