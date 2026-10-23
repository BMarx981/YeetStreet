--!strict
-- CarController (LocalScript) -> StarterPlayerScripts.CarController
-- Drives the local player's car. The server builds the car, seats the driver,
-- and gives this client network ownership; everything about feel happens here.
--
-- Each physics step:
--   1. Read the car: wheels on the ground, flying, lying, any launch pad
--      under it (CarSensor, which the server uses too).
--      Near a rail, moving along it, GrindRide puts the car on the rail and
--      rides it there instead of the steps below, except run tracking and
--      resets. On a swing seat, SwingRide does the same.
--   2. Jets: burn, drain, and recharge fuel, push along the nose (Jets).
--   3. On the ground: wheel motors and front wheel steering (Drive).
--      In the air: AirSpin steers the car's spin toward the input (AirControl).
--      Lying on its roof or side: AirSpin rolls it back onto its wheels
--      (Righting), and the player's spin input waits until it is upright.
--   4. Launch pads top speed up along the ramp, for a car heading that way.
--   5. Run tracking: feed the car's motion to RunTracker, score the run live,
--      and show the result when it ends. The server scores it again for real.
--   6. Reset on request, when still stuck on the roof after righting had its
--      chance, or after falling off the map. Resets ask the server, which
--      builds a fresh car at the last launcher, the same as after a wreck.
-- Camera and HUD update each render frame.
--
-- Stats (top speed, jet power, fuel, recharge, turn rate) come from attributes
-- the server wrote on the car, never from Tuning.StarterCar directly.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local AirControl = require(ReplicatedStorage.AirControl)
local CarSensor = require(ReplicatedStorage.CarSensor)
local GapZones = require(ReplicatedStorage.GapZones)
local Contact = require(ReplicatedStorage.Contact)
local Drive = require(ReplicatedStorage.Drive)
local InputAxes = require(ReplicatedStorage.InputAxes)
local Jets = require(ReplicatedStorage.Jets)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Righting = require(ReplicatedStorage.Righting)
local RunTracker = require(ReplicatedStorage.RunTracker)
local Scoring = require(ReplicatedStorage.Scoring)
local Tuning = require(ReplicatedStorage.Tuning)
local Tunnel = require(ReplicatedStorage.Tunnel)
local ChaseCamera = require(script.Parent.ChaseCamera)
local Controls = require(script.Parent.Controls)
local GarageMenu = require(script.Parent.GarageMenu)
local GrindRide = require(script.Parent.GrindRide)
local Hud = require(script.Parent.Hud)
local SwingRide = require(script.Parent.SwingRide)
local SwingSet = require(script.Parent.SwingSet)
local TeleportMenu = require(script.Parent.TeleportMenu)
local TouchControls = require(script.Parent.TouchControls)
local TrainSet = require(script.Parent.TrainSet)

local player = Players.LocalPlayer :: Player

-- Weather grip multiplier (1.0 = normal, lower = more slippery). Updated by server.
local weatherGripValue = ReplicatedStorage:FindFirstChild("WeatherGripValue")
local weatherGrip = 1.0
if weatherGripValue and weatherGripValue:IsA("NumberValue") then
	weatherGrip = weatherGripValue.Value
	weatherGripValue.Changed:Connect(function(v: number)
		weatherGrip = v
	end)
end

local PLAYER_MODULE_WAIT = 10

local WHEEL_NAMES = { "FL", "FR", "RL", "RR" }

local AIR_SCALES: AirControl.Scales = {
	pitch = Tuning.Air.PitchScale,
	yaw = Tuning.Air.YawScale,
	roll = Tuning.Air.RollScale,
	invertPitch = Tuning.Air.InvertPitch,
}

type Wheel = {
	part: BasePart,
	axle: HingeConstraint,
	mount: Attachment,
	mountBase: CFrame,
	steers: boolean,
	weatherGrip: number?,
}

type Rig = {
	model: Model,
	hull: BasePart,
	wheels: { Wheel },
	spin: AngularVelocity,
	jet: VectorForce,
	stick: VectorForce?, -- nil on a car built before tubes had one
	-- Every unanchored part that is its own assembly: hull, hubs, wheels.
	roots: { BasePart },
	sensor: CarSensor.Sensor,
	mass: number,
	topSpeed: number,
	jetPower: number,
	jetFuel: number,
	fuelRecharge: number,
	turnRate: number,
	grip: number,
	rollUnlocked: boolean,
	wheelRadius: number,
	isFrog: boolean,
	jumpPower: number,
	jumpCooldown: number,
}

local rig: Rig? = nil
-- Roblox's default movement controls, switched off while driving. Found in the
-- background so driving never waits on them; nil until found, or if missing.
local defaultControls: any = nil
local fuel = 0
local burning = false
-- What the server was last told about the jets burning in the T-Rex's jaws.
local heldJetsSent = false
local stuckTime = 0
local resetHeld = false
local exitHeld = false
local frogCooldown = 0
local righting = false
-- Which way is up for the car: world up, or inside a tube, toward its
-- middle line.
local up = Vector3.yAxis
local run = RunTracker.new()
local tricksShown = 0
local resetAskedAt = -math.huge
-- When the car was removed out from under the driver, for respawns.
local carGoneAt: number? = nil
-- Found in the background; nil until the server has made it.
local resetRemote: RemoteEvent? = nil
local exitRemote: RemoteEvent? = nil
local spawnRemote: RemoteEvent? = nil

local function numberAttribute(model: Model, key: string): number?
	local value = model:GetAttribute(key)
	return if typeof(value) == "number" then value else nil
end

-- Returns nil until the whole car and its attributes have replicated.
local function rigFor(model: Model, character: Model): Rig?
	local hull = model:FindFirstChild("Hull")
	if not (hull and hull:IsA("BasePart")) then
		return nil
	end
	local spin = hull:FindFirstChild("AirSpin")
	local jet = hull:FindFirstChild("Jet")
	local stick = hull:FindFirstChild("Stick")
	if not (spin and spin:IsA("AngularVelocity") and jet and jet:IsA("VectorForce")) then
		return nil
	end

	local wheels: { Wheel } = {}
	local roots: { BasePart } = { hull }
	for _, name in WHEEL_NAMES do
		local part = model:FindFirstChild(`Wheel{name}`)
		local hub = model:FindFirstChild(`Hub{name}`)
		local mount = hull:FindFirstChild(`Mount{name}`)
		local axle = part and part:FindFirstChild("Axle")
		if
			not (part and part:IsA("BasePart"))
			or not (hub and hub:IsA("BasePart"))
			or not (mount and mount:IsA("Attachment"))
			or not (axle and axle:IsA("HingeConstraint"))
		then
			return nil
		end
		table.insert(wheels, {
			part = part,
			axle = axle,
			mount = mount,
			mountBase = mount.CFrame,
			steers = mount:GetAttribute("Steers") == true,
		})
		table.insert(roots, part)
		table.insert(roots, hub)
	end

	local topSpeed = numberAttribute(model, "TopSpeed")
	local jetPower = numberAttribute(model, "JetPower")
	local jetFuel = numberAttribute(model, "JetFuel")
	local fuelRecharge = numberAttribute(model, "FuelRecharge")
	local turnRate = numberAttribute(model, "TurnRate")
	local grip = numberAttribute(model, "Grip")
	local wheelRadius = numberAttribute(model, "WheelRadius")
	if not (topSpeed and jetPower and jetFuel and fuelRecharge and turnRate and grip and wheelRadius) then
		return nil
	end
	local isFrog = model:GetAttribute("FrogCar") == true
	local jumpPower = numberAttribute(model, "JumpPower") or 0
	local jumpCooldown = numberAttribute(model, "JumpCooldown") or 0
	local sensor = CarSensor.new(model, { character })
	if not sensor then
		return nil
	end

	local mass = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Massless then
			mass += descendant:GetMass()
		end
	end

	return {
		model = model,
		hull = hull,
		wheels = wheels,
		spin = spin,
		jet = jet,
		stick = if stick and stick:IsA("VectorForce") then stick else nil,
		roots = roots,
		sensor = sensor,
		mass = mass,
		topSpeed = topSpeed,
		jetPower = jetPower,
		jetFuel = jetFuel,
		fuelRecharge = fuelRecharge,
		turnRate = turnRate,
		grip = grip,
		rollUnlocked = model:GetAttribute("RollUnlocked") == true,
		wheelRadius = wheelRadius,
		isFrog = isFrog,
		jumpPower = jumpPower,
		jumpCooldown = jumpCooldown,
	}
end

local function setVelocity(r: Rig, velocity: Vector3)
	for _, part in r.roots do
		part.AssemblyLinearVelocity = velocity
	end
end

local function endRun(result: RunTracker.Result)
	result.gaps = GapZones.find(result)
	Hud.result(result, Scoring.score(result, Tuning.Score), false)
	Hud.live(nil)
	tricksShown = 0
end

-- Feeds this step to RunTracker, from the same CarSensor sample the server
-- builds from the motion it sees.
local function trackRun(sample: RunTracker.Sample)
	local result = RunTracker.step(run, sample, Tuning.Run)
	if result then
		endRun(result)
		return
	end

	local snapshot = RunTracker.snapshot(run)
	if not snapshot then
		Hud.live(nil)
		return
	end
	local score = Scoring.score(snapshot, Tuning.Score)
	Hud.live(score)
	for i = tricksShown + 1, #snapshot.tricks do
		Hud.trick(Scoring.trickName(snapshot.tricks[i]), score.trickPoints[i])
	end
	tricksShown = #snapshot.tricks
end

-- Ends the run here so its card shows at once, and asks the server for a
-- fresh car at the last launcher. Asks again if none came after RetryTime.
local function resetCar()
	local now = os.clock()
	if now - resetAskedAt < Tuning.Reset.RetryTime then
		return
	end
	resetAskedAt = now
	local result = RunTracker.abort(run)
	if result then
		endRun(result)
	end
	if resetRemote then
		resetRemote:FireServer()
	end
end

local function launch(r: Rig, pad: BasePart)
	local speed = pad:GetAttribute("LaunchSpeed")
	if typeof(speed) ~= "number" then
		return
	end
	local direction = pad:GetAttribute("LaunchDirection")
	local dir = if typeof(direction) == "Vector3" then direction.Unit else pad.CFrame.LookVector
	local velocity = r.hull.AssemblyLinearVelocity
	local along = velocity:Dot(dir)
	-- Only a car already heading the pad's way, so crossing a bowl's rim pads
	-- on the way in doesn't throw the car back out.
	local heading = if velocity.Magnitude > 1e-3 then along / velocity.Magnitude else 0
	if heading >= Tuning.Launch.MinHeading and along < speed then
		setVelocity(r, velocity + dir * (speed - along))
	end
end

local requestExit: () -> () -- forward declaration so step() can call it

-- The middle lines of the city's tubes, the tunnel chains' (Tunnel.layout)
-- and the spiral towers' (Tunnel.spirals), in park coordinates, and the
-- park's place on the map.
local cityArea = MapLayout.find(Tuning.Map.Areas :: any, "City")
local tubes: { { Tunnel.Piece } } = {}
for _, chain in Tunnel.layout(Tuning.City :: any) do
	table.insert(tubes, chain.pieces)
end
for _, spiral in Tunnel.spirals(Tuning.City :: any, Tuning.City.Spirals :: any) do
	table.insert(tubes, spiral.pieces)
end

-- Dino Valley's volcano tube (Tunnel.volcano), in the volcano's own space,
-- which sits at its middle on the floor, turned to face its Heading.
local dinoArea = MapLayout.find(Tuning.Map.Areas :: any, "Dino")
local volcanoTuning = Tuning.Dino.Volcano
local volcanoTurn = CFrame.Angles(0, math.rad(volcanoTuning.Heading), 0)
local volcanoBase = if dinoArea
	then CFrame.new(dinoArea.X + volcanoTuning.X, Tuning.Map.FloorTop, dinoArea.Z + volcanoTuning.Z) * volcanoTurn
	else nil
local volcanoTube = Tunnel.volcano(volcanoTuning.Climb :: any, Tuning.City.Tunnels :: any).pieces

-- Which way a tube pulls a car at `position`, or nil outside them all.
local function tubePull(position: Vector3): Vector3?
	local radius = Tuning.City.Tunnels.Radius
	if cityArea then
		local x, y, z = position.X - cityArea.X, position.Y - Tuning.Map.FloorTop, position.Z - cityArea.Z
		for _, pieces in tubes do
			local px, py, pz = Tunnel.pull(pieces, radius, x, y, z)
			if px and py and pz then
				return Vector3.new(px, py, pz)
			end
		end
	end
	if volcanoBase then
		local at = volcanoBase:PointToObjectSpace(position)
		local px, py, pz = Tunnel.pull(volcanoTube, radius, at.X, at.Y, at.Z)
		if px and py and pz then
			return volcanoBase:VectorToWorldSpace(Vector3.new(px, py, pz))
		end
	end
	return nil
end

-- Boulders (Knockable parts with a BreakSpeed) streamed in here, each with
-- its BreakSpeed and the time it turns solid again (0 while it is solid).
-- A car faster than that is let through the boulders near it, on this
-- client only, so it smashes through; the server sees it pass, knocks them
-- and damages the car (PropService). A burning car is let through at any
-- speed, so it can drive out of the lava. Each stays passable for Hold
-- seconds after the car was last fast (or burning) and near it.
local boulders: { [BasePart]: { breakSpeed: number, solidAt: number } } = {}
local function trackBoulder(instance: Instance)
	local breakSpeed = instance:GetAttribute("BreakSpeed")
	if instance:IsA("BasePart") and typeof(breakSpeed) == "number" then
		boulders[instance] = { breakSpeed = breakSpeed, solidAt = 0 }
	end
end
CollectionService:GetInstanceAddedSignal("Knockable"):Connect(trackBoulder)
CollectionService:GetInstanceRemovedSignal("Knockable"):Connect(function(instance: Instance)
	boulders[instance :: BasePart] = nil
end)
for _, instance in CollectionService:GetTagged("Knockable") do
	trackBoulder(instance)
end

local function passBoulders(position: Vector3, velocity: Vector3, inLava: boolean)
	local B = Tuning.Props.Boulders
	local now = os.clock()
	local speed = velocity.Magnitude
	local reach = speed * B.LookAhead + B.Margin
	for part, boulder in boulders do
		if (speed > boulder.breakSpeed or inLava) and (part.Position - position).Magnitude < reach then
			if boulder.solidAt == 0 then
				part.CanCollide = false
			end
			boulder.solidAt = now + B.Hold
		elseif boulder.solidAt ~= 0 and now > boulder.solidAt then
			part.CanCollide = true
			boulder.solidAt = 0
		end
	end
end

local function step(r: Rig, dt: number)
	local input = Controls.read()
	local cf = r.hull.CFrame
	local velocity = r.hull.AssemblyLinearVelocity
	local forwardSpeed = velocity:Dot(cf.LookVector)

	-- Inside a tube the car is pulled toward the nearest wall instead of
	-- down, so it can drive round the walls and along the roof.
	local pull = tubePull(cf.Position)
	up = if pull then -pull else Vector3.yAxis
	if r.stick then
		r.stick.Force = if pull
			then (pull * Tuning.City.Tunnels.Pull + Vector3.yAxis) * workspace.Gravity * r.hull.AssemblyMass
			else Vector3.zero
	end

	-- A train that reaches the car pushes it ahead and a little aside.
	local pushed = TrainSet.push(r.hull)
	if pushed then
		setVelocity(r, pushed)
	end
	passBoulders(cf.Position, velocity, r.model:GetAttribute("Burning") == true)

	local reading = CarSensor.read(r.sensor, dt, up)
	local airborne = reading.airborne

	-- On a rail or a swing seat, GrindRide or SwingRide moves the car: no
	-- driving, jets, or air control.
	if
		GrindRide.step(r.model, r.hull, r.roots, input.steer, input.jet, dt)
		or SwingRide.step(r.model, r.hull, r.roots, input.throttle, input.steer, input.jet, dt)
	then
		burning = false
		r.jet.Force = Vector3.zero
		r.spin.Enabled = false
		if r.model:GetAttribute("JetsBurning") then
			r.model:SetAttribute("JetsBurning", false)
		end
		trackRun(reading.sample)
		local resetPressed = input.reset and not resetHeld
		resetHeld = input.reset
		if resetPressed then
			GrindRide.stop()
			SwingRide.stop()
			resetCar()
		end
		return
	end

	local RT = Tuning.Righting
	local upright = cf.UpVector:Dot(up)
	righting = Righting.step(righting, reading.lying, reading.wheelsDown, upright, RT)

	-- Frog jump or jets
	if r.isFrog then
		frogCooldown = math.max(0, frogCooldown - dt)
		if input.jet and not airborne and frogCooldown <= 0 then
			local vel = r.hull.AssemblyLinearVelocity
			setVelocity(r, Vector3.new(vel.X, r.jumpPower, vel.Z))
			frogCooldown = r.jumpCooldown
		end
		burning = false
		r.jet.Force = Vector3.zero
		if r.model:GetAttribute("JetsBurning") then
			r.model:SetAttribute("JetsBurning", false)
		end
	else
		burning = Jets.canBurn(input.jet, fuel, burning, Tuning.Jets.RelightFuel)
		fuel = Jets.stepFuel(fuel, r.jetFuel, burning, not airborne, r.fuelRecharge, dt)
		r.jet.Force = Vector3.new(0, 0, if burning then -r.jetPower * r.mass else 0)
		-- Set only on this client; CarVisuals lights the thruster flames from it.
		if r.model:GetAttribute("JetsBurning") ~= burning then
			r.model:SetAttribute("JetsBurning", burning)
		end
		-- The T-Rex holds a car by anchoring it, and jets help it break free,
		-- so the server hears when they start and stop burning there.
		local heldJets = burning and r.hull.Anchored
		if heldJets ~= heldJetsSent then
			heldJetsSent = heldJets
			local remote = ReplicatedStorage:FindFirstChild("HeldJets")
			if remote and remote:IsA("RemoteEvent") then
				remote:FireServer(heldJets)
			end
		end
	end

	-- In the air, gas and brake only pitch the car, and the wheels free roll so
	-- they match the ground on landing instead of grabbing it.
	local D = Tuning.Drive
	local wheelSpin: number, torque: number
	if airborne then
		wheelSpin, torque = Drive.freeRoll(forwardSpeed, r.wheelRadius), D.CoastTorque
	else
		wheelSpin, torque = Drive.motor(input.throttle, forwardSpeed, r.topSpeed, r.wheelRadius, D)
	end
	local steerAngle = Drive.steerAngle(
		input.steer,
		forwardSpeed,
		r.topSpeed,
		D.MaxSteerAngle,
		D.HighSpeedSteerFactor,
		D.SteerGrip * r.grip * weatherGrip * workspace.Gravity,
		2 * Tuning.Chassis.WheelbaseHalf
	)
	for _, wheel in r.wheels do
		wheel.axle.AngularVelocity = wheelSpin * D.SpinSign
		wheel.axle.MotorMaxTorque = torque
		-- Update wheel friction based on weather grip
		if wheel.weatherGrip ~= weatherGrip then
			wheel.weatherGrip = weatherGrip
			local baseGrip = if wheel.steers then r.grip else r.grip * Tuning.Chassis.RearGripFactor
			local frictionGrip = math.max(baseGrip * weatherGrip, 0.05)
			local density = wheel.part.CustomPhysicalProperties and wheel.part.CustomPhysicalProperties.Density or Tuning.Chassis.WheelDensity
			wheel.part.CustomPhysicalProperties = PhysicalProperties.new(density, frictionGrip, 0, 100, 100)
		end
		if wheel.steers then
			-- Positive steer is right, which is a negative turn about the hull's up axis.
			local base = wheel.mountBase
			wheel.mount.CFrame = CFrame.new(base.Position) * CFrame.Angles(0, math.rad(-steerAngle), 0) * base.Rotation
		end
	end

	-- Righting, else air control
	if righting then
		-- Worked out with `up` as Y, then turned back into world space.
		local across = up:Cross(if math.abs(up.X) < 0.9 then Vector3.xAxis else Vector3.zAxis).Unit
		local frame = if pull then CFrame.fromMatrix(Vector3.zero, across, up) else CFrame.identity
		local carUp = frame:VectorToObjectSpace(cf.UpVector)
		local look = frame:VectorToObjectSpace(cf.LookVector)
		local wx, wy, wz = Righting.rate(carUp.X, carUp.Y, carUp.Z, look.X, look.Y, look.Z, RT)
		r.spin.AngularVelocity = cf:VectorToObjectSpace(frame:VectorToWorldSpace(Vector3.new(wx, wy, wz)))
		r.spin.MaxTorque = r.mass * RT.TorquePerMass
		r.spin.Enabled = true
	elseif airborne then
		local A = Tuning.Air
		local pitchInput = InputAxes.combine({ input.throttle, input.pitch })
		local rollInput = if r.rollUnlocked then input.roll else 0
		local tx, ty, tz = AirControl.targetRates(input.steer, pitchInput, rollInput, r.turnRate, AIR_SCALES)
		local spinNow = cf:VectorToObjectSpace(r.hull.AssemblyAngularVelocity)
		r.spin.AngularVelocity = Vector3.new(
			AirControl.stepAxis(spinNow.X, tx, pitchInput ~= 0, A.AngularAccel, A.IdleDamping, dt),
			AirControl.stepAxis(spinNow.Y, ty, input.steer ~= 0, A.AngularAccel, A.IdleDamping, dt),
			AirControl.stepAxis(spinNow.Z, tz, rollInput ~= 0, A.AngularAccel, A.IdleDamping, dt)
		)
		r.spin.MaxTorque = r.mass * A.TorquePerMass
		r.spin.Enabled = true
	else
		r.spin.Enabled = false
	end

	if reading.pad then
		launch(r, reading.pad)
	end

	trackRun(reading.sample)

	-- Exit (edge-triggered so holding Space doesn't spam the server)
	local exitPressed = input.exit and not exitHeld
	exitHeld = input.exit
	if exitPressed then
		requestExit()
	end

	-- Resets
	local R = Tuning.Reset
	stuckTime = Contact.stepStuck(stuckTime, upright, velocity.Magnitude, dt, R.StuckUpY, R.StuckSpeed)
	local resetPressed = input.reset and not resetHeld
	resetHeld = input.reset
	if resetPressed or stuckTime >= R.StuckTime or cf.Position.Y < Tuning.World.FallResetY then
		resetCar()
	end
end

local function enter(r: Rig)
	rig = r
	GrindRide.stop()
	SwingRide.stop()
	fuel = r.jetFuel
	burning = false
	stuckTime = 0
	resetHeld = false
	if heldJetsSent then
		heldJetsSent = false
		local remote = ReplicatedStorage:FindFirstChild("HeldJets")
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer(false)
		end
	end
	righting = false
	run = RunTracker.new()
	tricksShown = 0
	resetAskedAt = -math.huge
	carGoneAt = nil
	exitHeld = false
	frogCooldown = 0
	if defaultControls then
		defaultControls:Disable()
	end
	-- Disable jumping while driving so Space is free for exit.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
	TouchControls.setVisible(true)
	Hud.setVisible(true)
end

local function leave()
	if rig and rig.stick then
		rig.stick.Force = Vector3.zero
	end
	rig = nil
	up = Vector3.yAxis
	GrindRide.stop()
	SwingRide.stop()
	if defaultControls then
		defaultControls:Enable()
	end
	TouchControls.setVisible(false)
	Hud.setVisible(false)
	ChaseCamera.release()
	-- Re-enable jumping now that the player is on foot.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end

-- Requests the server to eject the player from the car seat.
function requestExit()
	-- Zero the car's velocity before exiting so it stops in place.
	-- The client owns the car physics, so this change sticks.
	if rig then
		rig.hull.AssemblyLinearVelocity = Vector3.zero
		rig.hull.AssemblyAngularVelocity = Vector3.zero
		for _, wheel in rig.wheels do
			wheel.axle.AngularVelocity = 0
			wheel.axle.MotorMaxTorque = 0
		end
	end
	if exitRemote then
		exitRemote:FireServer()
	end
end

-- The car this character is seated in, if any.
local function seatedCar(character: Model?): Model?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:GetAttribute("CarSeat") then
		local model = seat.Parent
		if model and model:IsA("Model") then
			return model
		end
	end
	return nil
end

RunService.PreSimulation:Connect(function(dt: number)
	local character = player.Character
	local model = seatedCar(character)
	local current = rig
	if current and current.model ~= model then
		-- A respawn removes the old car a moment before the new one seats the
		-- driver. Hold the camera and HUD meanwhile instead of flickering.
		if not model and not current.model.Parent then
			local goneAt = carGoneAt or os.clock()
			carGoneAt = goneAt
			if os.clock() - goneAt < Tuning.Reset.RespawnWait then
				return
			end
		end
		leave()
		current = nil
	end
	if not current and model and character then
		local built = rigFor(model, character)
		if built then
			enter(built)
			current = built
		end
	end
	if current then
		step(current, dt)
	end
end)

RunService:BindToRenderStep("YeetStreetCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local current = rig
	if not current then
		return
	end
	local contact = current.sensor.contact
	ChaseCamera.update(current.hull, contact.airborne, dt, up)
	Hud.update(
		fuel / current.jetFuel,
		current.hull.AssemblyLinearVelocity.Magnitude,
		if contact.airborne then contact.airtime else nil,
		burning
	)
end)

-- Jumping is disabled while driving so the Space key is free for jets.
-- It is re-enabled in leave() when the player exits the car.
local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
end
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

task.spawn(function()
	local playerScripts = player:WaitForChild("PlayerScripts")
	local module = playerScripts:WaitForChild("PlayerModule", PLAYER_MODULE_WAIT)
	if not (module and module:IsA("ModuleScript")) then
		warn("CarController: no PlayerModule in PlayerScripts; default controls stay on")
		return
	end
	defaultControls = (require(module) :: any):GetControls()
	if rig then
		defaultControls:Disable()
	end
end)

-- The server's score for each run, which replaces the card from endRun.
task.spawn(function()
	local runResult = ReplicatedStorage:WaitForChild("RunResult")
	if not runResult:IsA("RemoteEvent") then
		warn("CarController: ReplicatedStorage.RunResult is not a RemoteEvent; run cards stay unofficial")
		return
	end
	runResult.OnClientEvent:Connect(function(result: Scoring.Run, score: Scoring.Score)
		Hud.result(result, score, true)
	end)
end)

task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild("ResetCar")
	if remote:IsA("RemoteEvent") then
		resetRemote = remote
	else
		warn("CarController: ReplicatedStorage.ResetCar is not a RemoteEvent; resets do nothing")
	end
end)

-- Standalone R-key handler so the player can respawn even when on foot.
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if input.KeyCode == Enum.KeyCode.R and not processed then
		resetCar()
	elseif input.KeyCode == Enum.KeyCode.Z and not processed then
		if spawnRemote then
			spawnRemote:FireServer()
		end
	end
end)

task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild("ExitCar")
	if remote:IsA("RemoteEvent") then
		exitRemote = remote
	else
		warn("CarController: ReplicatedStorage.ExitCar is not a RemoteEvent; exit does nothing")
	end
end)

task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild("SpawnCar")
	if remote:IsA("RemoteEvent") then
		spawnRemote = remote
	else
		warn("CarController: ReplicatedStorage.SpawnCar is not a RemoteEvent; spawn does nothing")
	end
end)

-- Hits the server measured on this car, shown while picking toughness numbers.
task.spawn(function()
	local carImpact = ReplicatedStorage:WaitForChild("CarImpact")
	if not carImpact:IsA("RemoteEvent") then
		warn("CarController: ReplicatedStorage.CarImpact is not a RemoteEvent; hits stay hidden")
		return
	end
	carImpact.OnClientEvent:Connect(
		function(strength: number, slot: string, inRun: boolean, damage: number, toughnessLeft: number)
			Hud.impact(strength, slot, inRun, damage, toughnessLeft)
		end
	)
end)

GarageMenu.start()
SwingSet.start()
TrainSet.start()
TeleportMenu.start()

task.spawn(function()
	-- SetCore fails until the core scripts have registered the callback.
	for _ = 1, 20 do
		if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) then
			return
		end
		task.wait(0.5)
	end
end)
