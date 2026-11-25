--!strict
-- Flail (ModuleScript) -> StarterPlayerScripts.Flail
-- How a driver's arms flail over their head while a tornado carries their
-- car: the turn of each R15 arm joint (RightShoulder, LeftShoulder,
-- RightElbow, LeftElbow) at time `t`, as a joint's Transform. TornadoRiders
-- turns live drivers' joints with it, and ReplayPlayer the replay ghost's
-- driver, on the replay's clock. Numbers are in Tuning.Tornado.Flail.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local F = Tuning.Tornado.Flail

local Flail = {}

-- The arm joints, by name, turned at time `t`.
function Flail.joints(t: number): { [string]: CFrame }
	local a, b = F.Rates[1], F.Rates[2]
	return {
		RightShoulder = CFrame.Angles(F.Raise + F.Swing * math.sin(t * a), 0, -F.Out + F.Side * math.sin(t * b + 1)),
		LeftShoulder = CFrame.Angles(F.Raise + F.Swing * math.sin(t * b + 2), 0, F.Out + F.Side * math.sin(t * a + 3)),
		RightElbow = CFrame.Angles(F.Bend + F.BendSwing * math.sin(t * b * 1.3), 0, 0),
		LeftElbow = CFrame.Angles(F.Bend + F.BendSwing * math.sin(t * a * 1.3 + 1), 0, 0),
	}
end

return Flail
