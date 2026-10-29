--!strict
-- ReplayDebris (ModuleScript) -> StarterPlayerScripts.ReplayDebris
-- Where a part knocked off the ghost car in a replay (ReplayPlayer) flies.
-- Real broken parts fly by physics (CarVisuals), which would carry on at full
-- speed while a replay is paused or slowed. So a ghost's part follows a path
-- worked out once, when it breaks off: it falls under gravity, tumbles, and
-- bounces off what real broken parts hit (the Props collision group) until
-- it stops. The path has a point every DebrisStep seconds, so the part can be
-- put anywhere along it for any replay time.
--
-- A wheel (a cylinder on its x axis) rolls: on level ground it turns up onto
-- its tread, spins as fast as it moves, and loses little speed, so it rolls
-- away and down slopes. It feels for the ground below it each step, so it
-- rides along it rather than sinking in.

local Tuning = require(game:GetService("ReplicatedStorage").Tuning)

local R = Tuning.Replay
local T = Tuning.Toughness

local PROPS_GROUP = "Props" -- CollisionGroups.Props, a server module

local ReplayDebris = {}

-- The path of a part of `size` leaving `start` at `velocity`, tumbling at
-- `spin` (axis times radians per second). Never hits anything in `exclude`.
-- `wheel` is true for a wheel, which rolls.
function ReplayDebris.path(
	start: CFrame,
	velocity: Vector3,
	size: Vector3,
	spin: Vector3,
	exclude: { Instance },
	wheel: boolean?
): { CFrame }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.CollisionGroup = PROPS_GROUP
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local radius = if wheel then size.Y / 2 else math.min(size.X, size.Y, size.Z) / 2
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	local dt = R.DebrisStep
	local position = start.Position
	local turn = start.Rotation
	local frames = { start }
	for _ = 1, math.ceil(T.PartLifetime / dt) do
		velocity += gravity * dt
		local move = velocity * dt
		local hit = if move.Magnitude > 1e-6
			then workspace:Raycast(position, move + move.Unit * radius, params)
			else nil
		if not hit and wheel then
			position += move
			move = Vector3.zero
			local below = workspace:Raycast(position, Vector3.new(0, -radius, 0), params)
			if below and velocity:Dot(below.Normal) < 0 then
				hit = below
			end
		end
		if hit then
			position = hit.Position + hit.Normal * radius
			local into = velocity:Dot(hit.Normal)
			local along = velocity - hit.Normal * into
			if wheel and hit.Normal.Y >= R.RollGround then
				velocity = along * (1 - R.RollFriction) - hit.Normal * into * R.DebrisBounce
				local axle = hit.Normal:Cross(velocity)
				if axle.Magnitude > 1e-3 then
					local now = turn.RightVector
					local goal = if now:Dot(axle) < 0 then -axle.Unit else axle.Unit
					local tilt = now:Cross(goal)
					if tilt.Magnitude > 1e-4 then
						local angle = math.asin(math.min(tilt.Magnitude, 1)) * R.RollUpright
						turn = CFrame.fromAxisAngle(tilt.Unit, angle) * turn
					end
				end
				spin = axle / radius
			else
				velocity = along * (1 - R.DebrisFriction) - hit.Normal * into * R.DebrisBounce
				spin *= R.DebrisBounce
			end
			if velocity.Magnitude < R.DebrisRest then
				table.insert(frames, CFrame.new(position) * turn)
				break
			end
		else
			position += move
		end
		if spin.Magnitude > 1e-6 then
			turn = CFrame.fromAxisAngle(spin.Unit, spin.Magnitude * dt) * turn
		end
		table.insert(frames, CFrame.new(position) * turn)
	end
	return frames
end

-- Where a part on `path` is `t` seconds after it broke off. It stays where
-- the path ends.
function ReplayDebris.at(path: { CFrame }, t: number): CFrame
	local u = math.max(t, 0) / R.DebrisStep
	local i = math.floor(u) + 1
	if i >= #path then
		return path[#path]
	end
	return path[i]:Lerp(path[i + 1], u - (i - 1))
end

return ReplayDebris
