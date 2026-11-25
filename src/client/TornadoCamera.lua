--!strict
-- TornadoCamera (ModuleScript) -> StarterPlayerScripts.TornadoCamera
-- While a tornado carries the car (TornadoService sets the car's Tornado
-- attribute), the camera sits outside the funnel: Back studs further out
-- from the funnel's middle than the car, and at least Clear studs outside the
-- funnel's width there, Lift up, looking at the car, so the car whirls round
-- in front of the tornado instead of the chase camera swinging behind it. It
-- eases after the car at Follow. Numbers are in Tuning.Tornado.Camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tornado = require(ReplicatedStorage.Tornado)
local Tuning = require(ReplicatedStorage.Tuning)

local T: Tornado.Tuning = Tuning.Tornado :: any
local C = Tuning.Tornado.Camera
local NO_AREA: Tornado.Area = { X = 0, Z = 0, Width = 0, Depth = 0 }

local TornadoCamera = {}

local view: CFrame? = nil

-- Places the camera for `hull` riding round a funnel `height` tall whose
-- middle is at `base` on the ground.
function TornadoCamera.update(hull: BasePart, base: Vector3, height: number, dt: number)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local at = hull.Position
	local flat = Vector3.new(at.X - base.X, 0, at.Z - base.Z)
	local out = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	local funnel = Tornado.radiusAt(Tornado.new(0, 0, height, 0, NO_AREA), at.Y - base.Y, T)
	local away = math.max(flat.Magnitude + C.Back, funnel + C.Clear)
	local spot = Vector3.new(base.X, at.Y + C.Lift, base.Z) + out * away
	local want = CFrame.lookAt(spot, at)
	local last = view
	view = if last then last:Lerp(want, 1 - math.exp(-C.Follow * dt)) else want
	camera.CFrame = view :: CFrame
end

-- Forgets the last view, so the next ride starts where it should.
function TornadoCamera.release()
	view = nil
end

return TornadoCamera
