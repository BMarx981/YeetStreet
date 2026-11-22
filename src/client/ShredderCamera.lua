--!strict
-- ShredderCamera (ModuleScript) -> StarterPlayerScripts.ShredderCamera
-- While the local player's car is in the Scrapyard's shredder (its
-- Shredding attribute), the chase camera would sit low behind it, inside
-- the hopper's wall, so CarController hands the camera here instead: it
-- eases back along the kicker's line and up (Tuning.Scrapyard.Shredder
-- .Watch), looking down into the opening as the car is chewed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShredderWorld = require(ReplicatedStorage.ShredderWorld)
local Tuning = require(ReplicatedStorage.Tuning)

local W = Tuning.Scrapyard.Shredder.Watch

local ShredderCamera = {}

function ShredderCamera.update(dt: number)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local frame = ShredderWorld.frame
	local want = CFrame.lookAt(frame * Vector3.new(0, W.Up, W.Back), frame * Vector3.new(0, W.Focus, 0))
	camera.CFrame = camera.CFrame:Lerp(want, 1 - math.exp(-W.Sharpness * dt))
end

return ShredderCamera
