--!strict
-- GlobeHatch (LocalScript) -> StarterPlayerScripts.GlobeHatch
-- Opens the Corkscrew park's globe's hatch (Parks.CorkscrewGlobe, the
-- planks tagged GlobeHatch) for this client's own car coming up the globe's
-- tube: while the car is in the tube, and HatchHold seconds after, the
-- hatch does not collide on this client. This client moves its own car, so
-- only its own copy of the hatch matters to it; every other car, and this
-- one at any other time, finds the hatch solid.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlobeRide = require(ReplicatedStorage.GlobeRide)
local Tuning = require(ReplicatedStorage.Tuning)

if not GlobeRide.ground then
	return
end

local player = Players.LocalPlayer
local carsFolder = workspace:WaitForChild("Cars")
local open = false
local openUntil = -math.huge

local function apply(part: Instance)
	if part:IsA("BasePart") then
		part.CanCollide = not open
	end
end

-- Planks streamed in later take whatever the hatch is now.
CollectionService:GetInstanceAddedSignal(GlobeRide.HATCH_TAG):Connect(apply)

local function ownHull(): BasePart?
	for _, car in carsFolder:GetChildren() do
		if car:IsA("Model") and car:GetAttribute("OwnerUserId") == player.UserId then
			return car.PrimaryPart
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local hull = ownHull()
	if hull and GlobeRide.pull(hull.Position) then
		openUntil = now + Tuning.Corkscrew.Globe.HatchHold
	end
	local shouldOpen = now < openUntil
	if shouldOpen ~= open then
		open = shouldOpen
		for _, part in CollectionService:GetTagged(GlobeRide.HATCH_TAG) do
			apply(part)
		end
	end
end)
