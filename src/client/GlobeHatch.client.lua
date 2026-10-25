--!strict
-- GlobeHatch (LocalScript) -> StarterPlayerScripts.GlobeHatch
-- Opens the Corkscrew park's globe's hatch (Parks.CorkscrewGlobe, the
-- planks tagged GlobeHatch) for this client's own car, on this client only:
-- this client moves its own car, so only its own copy of the hatch matters
-- to it, and every other player sees and drives on a solid hatch.
--
-- On the way in, the hatch is open while the car is in the globe's tube,
-- and HatchHold seconds after. On the way out, a car stopped over the
-- hatch's middle (Tuning.Corkscrew.Globe.Exit) makes it flash for Wait
-- seconds, then open; once the car drops into the tube, this client asks
-- for a reset, which puts it at the funnel facing out (ScoreService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlobeRide = require(ReplicatedStorage.GlobeRide)
local Tuning = require(ReplicatedStorage.Tuning)

if not GlobeRide.ground then
	return
end

local G = Tuning.Corkscrew.Globe
local FLASH_COLOR = Color3.fromRGB(255, 255, 255)
local OPEN_TRANSPARENCY = 0.7
-- Seconds after the hatch opens under a leaving car by which it should be
-- in the tube; past this it is reset anyway, wherever it fell.
local DROP_TIME = 2

local player = Players.LocalPlayer
local carsFolder = workspace:WaitForChild("Cars")
local resetRemote = ReplicatedStorage:WaitForChild("ResetCar") :: RemoteEvent

local open = false
local flashOn = false
local openUntil = -math.huge
local waited = 0
local leavingUntil: number? = nil
-- Each plank's own color, to go back to after a flash.
local colors: { [BasePart]: Color3 } = {}

local function apply(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	if not colors[instance] then
		colors[instance] = instance.Color
	end
	instance.CanCollide = not open
	instance.Transparency = if open then OPEN_TRANSPARENCY else 0
	instance.Color = if flashOn then FLASH_COLOR else colors[instance]
end

local function applyAll()
	for _, part in CollectionService:GetTagged(GlobeRide.HATCH_TAG) do
		apply(part)
	end
end

-- Planks streamed in later take whatever the hatch is now.
CollectionService:GetInstanceAddedSignal(GlobeRide.HATCH_TAG):Connect(apply)
CollectionService:GetInstanceRemovedSignal(GlobeRide.HATCH_TAG):Connect(function(instance: Instance)
	if instance:IsA("BasePart") then
		colors[instance] = nil
	end
end)

local function ownHull(): BasePart?
	for _, car in carsFolder:GetChildren() do
		if car:IsA("Model") and car:GetAttribute("OwnerUserId") == player.UserId then
			return car.PrimaryPart
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()
	local hull = ownHull()
	local inTube = hull ~= nil and GlobeRide.pull(hull.Position) ~= nil
	if inTube then
		openUntil = now + G.HatchHold
	end

	if leavingUntil then
		if inTube or now > leavingUntil then
			leavingUntil = nil
			resetRemote:FireServer()
		end
	elseif hull and hull.AssemblyLinearVelocity.Magnitude < G.Exit.Speed and GlobeRide.overHatch(hull.Position) then
		waited += dt
		if waited >= G.Exit.Wait then
			waited = 0
			leavingUntil = now + DROP_TIME
			openUntil = now + DROP_TIME
		end
	else
		waited = 0
	end

	local shouldOpen = now < openUntil
	local shouldFlash = waited > 0 and (now * G.Exit.FlashRate) % 1 < 0.5
	if shouldOpen ~= open or shouldFlash ~= flashOn then
		open, flashOn = shouldOpen, shouldFlash
		applyAll()
	end
end)
