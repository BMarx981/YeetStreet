--!strict
-- EruptionCamera (ModuleScript) -> StarterPlayerScripts.EruptionCamera
-- After a launch zone with a WatchPoint (the volcano's vent), swings the chase
-- camera up over the car and behind it, looking down between the car and the
-- point, so the eruption stays in view behind the car while the player flies.
-- It stays behind the way the car was thrown, so the controls don't turn round.
-- Runs after ChaseCamera each frame and swings back once its time is up or the
-- car lands. Numbers are in Tuning.Dino.Volcano.Watch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)
local Volcano = require(ReplicatedStorage.Volcano)

local W = Tuning.Dino.Volcano.Watch

local EruptionCamera = {}

local point: Vector3? = nil
local behind = Vector3.zAxis
local startedAt = 0

-- Called every step the car is in the zone, so its time starts as it leaves.
function EruptionCamera.start(watch: Vector3, direction: Vector3)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	point = watch
	behind = -flat.Unit
	startedAt = os.clock()
end

function EruptionCamera.update(hull: BasePart, airborne: boolean)
	local watch = point
	if not watch then
		return
	end
	local since = os.clock() - startedAt
	local weight = Volcano.watchWeight(W, since)
	if weight <= 0 and since > W.EaseIn or (not airborne and since > W.Grace) then
		point = nil
		return
	end
	local camera = workspace.CurrentCamera
	local position = hull.Position + Vector3.yAxis * W.Above + behind * W.Back
	local toCar, toPoint = hull.Position - position, watch - position
	local x, y, z = Volcano.watchLook(toCar.X, toCar.Y, toCar.Z, toPoint.X, toPoint.Y, toPoint.Z)
	local view = CFrame.lookAt(position, position + Vector3.new(x, y, z), -behind)
	camera.CFrame = camera.CFrame:Lerp(view, weight)
end

return EruptionCamera
