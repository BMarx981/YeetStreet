local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local JUMP_COOLDOWN = 1.5
local JUMP_POWER = 60
local lastJump = 0

local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.C then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local seat = humanoid.SeatPart
	if not seat then return end

	-- Check if the seat belongs to a FrogCar
	local model = seat:FindFirstAncestorOfClass("Model")
	if not model or model.Name ~= "FrogCar" then return end

	-- Cooldown check
	local now = os.clock()
	if now - lastJump < JUMP_COOLDOWN then return end
	lastJump = now

	-- Find the chassis to apply the jump force
	local chassis = model:FindFirstChild("Chassis")
	if not chassis then return end

	-- Temporarily disable BodyPosition so the jump isn't fought
	local bodyPos = chassis:FindFirstChild("BodyPosition")
	local bodyGyro = chassis:FindFirstChild("BodyGyro")

	if bodyPos then
		bodyPos.MaxForce = Vector3.new(0, 0, 0)
	end
	if bodyGyro then
		bodyGyro.MaxTorque = Vector3.new(0, 400000, 0)
	end

	-- Apply upward velocity (the jump!)
	chassis.AssemblyLinearVelocity = Vector3.new(
		chassis.AssemblyLinearVelocity.X,
		JUMP_POWER,
		chassis.AssemblyLinearVelocity.Z
	)

	-- Re-enable stabilization after the jump arc
	task.delay(0.2, function()
		if bodyGyro then
			bodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
		end
	end)
	task.delay(1.5, function()
		if bodyPos then
			bodyPos.MaxForce = Vector3.new(0, 0, 0)
		end
		if bodyGyro then
			bodyGyro.MaxTorque = Vector3.new(0, 0, 0)
		end
	end)
end

UserInputService.InputBegan:Connect(onInputBegan)