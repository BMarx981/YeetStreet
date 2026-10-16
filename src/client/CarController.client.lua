--!strict
-- CarController (LocalScript) -> StarterPlayerScripts.CarController
-- Drives the local player's car. The server builds the car, seats the driver,
-- and gives this client network ownership; everything about feel happens here.
--
-- Each physics step:
--   1. Raycast under each wheel to count wheels on the ground (Contact).
--   2. Jets: burn, drain, and recharge fuel, push along the nose (Jets).
--   3. On the ground: wheel motors and front wheel steering (Drive).
--      In the air: AirSpin steers the car's spin toward the input (AirControl).
--   4. Launch pads top speed up along the ramp.
--   5. Run tracking: feed the car's motion to RunTracker, score the run live,
--      and show the result when it ends. The server scores it again for real.
--   6. Reset on request, when stuck on the roof, or after falling off the map.
-- Camera and HUD update each render frame.
--
-- Stats (top speed, jet power, fuel, recharge, turn rate) come from attributes
-- the server wrote on the car, never from Tuning.StarterCar directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local AirControl = require(ReplicatedStorage.AirControl)
local Contact = require(ReplicatedStorage.Contact)
local Drive = require(ReplicatedStorage.Drive)
local InputAxes = require(ReplicatedStorage.InputAxes)
local Jets = require(ReplicatedStorage.Jets)
local RunTracker = require(ReplicatedStorage.RunTracker)
local Scoring = require(ReplicatedStorage.Scoring)
local Tuning = require(ReplicatedStorage.Tuning)
local ChaseCamera = require(script.Parent.ChaseCamera)
local Controls = require(script.Parent.Controls)
local Hud = require(script.Parent.Hud)
local TouchControls = require(script.Parent.TouchControls)

local player = Players.LocalPlayer :: Player

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
}

type Rig = {
	model: Model,
	hull: BasePart,
	wheels: { Wheel },
	spin: AngularVelocity,
	jet: VectorForce,
	flames: { ParticleEmitter },
	-- Every unanchored part that is its own assembly: hull, hubs, wheels.
	roots: { BasePart },
	rayParams: RaycastParams,
	mass: number,
	spawn: CFrame,
	topSpeed: number,
	jetPower: number,
	jetFuel: number,
	fuelRecharge: number,
	turnRate: number,
	grip: number,
	rollUnlocked: boolean,
	wheelRadius: number,
}

local rig: Rig? = nil
-- Roblox's default movement controls, switched off while driving. Found in the
-- background so driving never waits on them; nil until found, or if missing.
local defaultControls: any = nil
local contact = Contact.new()
local fuel = 0
local burning = false
local stuckTime = 0
local resetHeld = false
local run = RunTracker.new()
local lastCFrame: CFrame? = nil
local tricksShown = 0

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
	local spawn = model:GetAttribute("SpawnCFrame")
	if not (topSpeed and jetPower and jetFuel and fuelRecharge and turnRate and grip and wheelRadius) then
		return nil
	end
	if typeof(spawn) ~= "CFrame" then
		return nil
	end

	local flames: { ParticleEmitter } = {}
	local mass = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ParticleEmitter") and descendant.Name == "JetFlame" then
			table.insert(flames, descendant)
		elseif descendant:IsA("BasePart") and not descendant.Massless then
			mass += descendant:GetMass()
		end
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { model, character }

	return {
		model = model,
		hull = hull,
		wheels = wheels,
		spin = spin,
		jet = jet,
		flames = flames,
		roots = roots,
		rayParams = rayParams,
		mass = mass,
		spawn = spawn,
		topSpeed = topSpeed,
		jetPower = jetPower,
		jetFuel = jetFuel,
		fuelRecharge = fuelRecharge,
		turnRate = turnRate,
		grip = grip,
		rollUnlocked = model:GetAttribute("RollUnlocked") == true,
		wheelRadius = wheelRadius,
	}
end

local function setVelocity(r: Rig, velocity: Vector3)
	for _, part in r.roots do
		part.AssemblyLinearVelocity = velocity
	end
end

local function endRun(result: RunTracker.Result)
	Hud.result(result, Scoring.score(result, Tuning.Score))
	Hud.live(nil)
	tricksShown = 0
end

-- Feeds this step to RunTracker. The turn is the hull's rotation since the
-- last step, in its own axes, the same motion the server can see.
local function trackRun(cf: CFrame, velocity: Vector3, airborne: boolean, onPad: boolean, dt: number)
	local turn = Vector3.zero
	if lastCFrame then
		local axis, angle = lastCFrame:ToObjectSpace(cf):ToAxisAngle()
		if angle > 1e-6 then
			turn = axis * angle
		end
	end
	lastCFrame = cf

	local result = RunTracker.step(run, {
		dt = dt,
		airborne = airborne,
		onPad = onPad,
		x = cf.Position.X,
		y = cf.Position.Y,
		z = cf.Position.Z,
		turnX = turn.X,
		turnY = turn.Y,
		turnZ = turn.Z,
		speed = velocity.Magnitude,
		upY = cf.UpVector.Y,
	}, Tuning.Run)
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

local function resetCar(r: Rig)
	local result = RunTracker.abort(run)
	if result then
		endRun(result)
	end
	lastCFrame = nil
	r.model:PivotTo(r.spawn)
	for _, part in r.roots do
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
	end
	contact = Contact.new()
	fuel = r.jetFuel
	burning = false
	stuckTime = 0
end

-- Counts wheels touching the ground and returns any launch pad under them.
local function probe(r: Rig): (number, BasePart?)
	local down = -r.hull.CFrame.UpVector * (r.wheelRadius + Tuning.Contact.ProbeMargin)
	local count = 0
	local pad: BasePart? = nil
	for _, wheel in r.wheels do
		local hit = workspace:Raycast(wheel.part.Position, down, r.rayParams)
		if hit then
			count += 1
			local part = hit.Instance
			if part:IsA("BasePart") and part:GetAttribute("LaunchSpeed") then
				pad = part
			end
		end
	end
	return count, pad
end

local function launch(r: Rig, pad: BasePart)
	local speed = pad:GetAttribute("LaunchSpeed")
	if typeof(speed) ~= "number" then
		return
	end
	local dir = pad.CFrame.LookVector
	local velocity = r.hull.AssemblyLinearVelocity
	local along = velocity:Dot(dir)
	if along < speed then
		setVelocity(r, velocity + dir * (speed - along))
	end
end

local function step(r: Rig, dt: number)
	local input = Controls.read()
	local cf = r.hull.CFrame
	local velocity = r.hull.AssemblyLinearVelocity
	local forwardSpeed = velocity:Dot(cf.LookVector)

	local wheelsDown, pad = probe(r)
	contact = Contact.step(contact, wheelsDown, dt, Tuning.Contact.AirDelay, Tuning.Contact.LandWheels)
	local airborne = contact.airborne

	-- Jets
	burning = Jets.canBurn(input.jet, fuel, burning, Tuning.Jets.RelightFuel)
	fuel = Jets.stepFuel(fuel, r.jetFuel, burning, not airborne, r.fuelRecharge, dt)
	r.jet.Force = Vector3.new(0, 0, if burning then -r.jetPower * r.mass else 0)
	for _, flame in r.flames do
		flame.Enabled = burning
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
		D.SteerGrip * r.grip * workspace.Gravity,
		2 * Tuning.Chassis.WheelbaseHalf
	)
	for _, wheel in r.wheels do
		wheel.axle.AngularVelocity = wheelSpin * D.SpinSign
		wheel.axle.MotorMaxTorque = torque
		if wheel.steers then
			-- Positive steer is right, which is a negative turn about the hull's up axis.
			local base = wheel.mountBase
			wheel.mount.CFrame = CFrame.new(base.Position) * CFrame.Angles(0, math.rad(-steerAngle), 0) * base.Rotation
		end
	end

	-- Air control
	if airborne then
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

	if pad then
		launch(r, pad)
	end

	trackRun(cf, velocity, airborne, pad ~= nil, dt)

	-- Resets
	local R = Tuning.Reset
	stuckTime = Contact.stepStuck(stuckTime, cf.UpVector.Y, velocity.Magnitude, dt, R.StuckUpY, R.StuckSpeed)
	local resetPressed = input.reset and not resetHeld
	resetHeld = input.reset
	if resetPressed or stuckTime >= R.StuckTime or cf.Position.Y < Tuning.World.FallResetY then
		resetCar(r)
	end
end

local function enter(r: Rig)
	rig = r
	contact = Contact.new()
	fuel = r.jetFuel
	burning = false
	stuckTime = 0
	resetHeld = false
	run = RunTracker.new()
	lastCFrame = nil
	tricksShown = 0
	if defaultControls then
		defaultControls:Disable()
	end
	TouchControls.setVisible(true)
	Hud.setVisible(true)
end

local function leave()
	rig = nil
	if defaultControls then
		defaultControls:Enable()
	end
	TouchControls.setVisible(false)
	Hud.setVisible(false)
	ChaseCamera.release()
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
	ChaseCamera.update(current.hull, contact.airborne, dt)
	Hud.update(
		fuel / current.jetFuel,
		current.hull.AssemblyLinearVelocity.Magnitude,
		if contact.airborne then contact.airtime else nil,
		burning
	)
end)

-- Nobody oofs: no jumping out of the seat, and no reset button in the menu.
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

task.spawn(function()
	-- SetCore fails until the core scripts have registered the callback.
	for _ = 1, 20 do
		if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) then
			return
		end
		task.wait(0.5)
	end
end)
