--!strict
-- CrusherCamera (ModuleScript) -> StarterPlayerScripts.CrusherCamera
-- While the local player's car is in the Scrapyard's crusher (its Crushing
-- attribute), the chase camera would sit inside the head coming down, so
-- CarController hands the camera here instead: it eases out to a spot
-- beside the bed (Tuning.Scrapyard.Crusher.Watch) and watches the car get
-- crushed. Also where the bed is, for CrusherLook.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)

local C = Tuning.Scrapyard.Crusher
local W = C.Watch

local CrusherCamera = {}

local area = MapLayout.find(Tuning.Map.Areas :: any, "Scrapyard")
local turn = CFrame.Angles(0, math.rad(C.Turn), 0)

-- The bed's middle on its top, facing the way cars drive in. The same as
-- ScrapyardCrusher's.
CrusherCamera.frame = if area
	then CFrame.new(area.X + C.X, Tuning.Map.FloorTop + C.BedHeight, area.Z + C.Z) * turn
	else CFrame.identity

function CrusherCamera.update(dt: number)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local frame = CrusherCamera.frame
	local focus = frame * Vector3.new(0, W.Focus, 0)
	local want = CFrame.lookAt(frame * Vector3.new(W.Side, W.Up, W.Along), focus)
	camera.CFrame = camera.CFrame:Lerp(want, 1 - math.exp(-W.Sharpness * dt))
end

return CrusherCamera
