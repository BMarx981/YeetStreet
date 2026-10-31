--!strict
-- SiloRide (LocalScript) -> StarterPlayerScripts.SiloRide
-- While this player rides a silo missile, sends its steering to the server
-- (Parks.SiloMissile) SendRate times a second: steer turns it, gas and brake
-- or the stick nose it down and up, the same way they pitch a car in the air.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tuning = require(ReplicatedStorage.Tuning)
local Controls = require(script.Parent.Controls)

local GAP = 1 / Tuning.Silo.Missile.SendRate

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("MissileSteer") :: RemoteEvent
local sinceSent = 0

RunService.Heartbeat:Connect(function(dt: number)
	if player:GetAttribute("OnMissile") ~= true then
		return
	end
	sinceSent += dt
	if sinceSent < GAP then
		return
	end
	sinceSent = 0
	local input = Controls.read()
	remote:FireServer(input.steer, -math.clamp(input.throttle + input.pitch, -1, 1))
end)
