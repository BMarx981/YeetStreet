--!strict
-- ScrapyardStacks (ModuleScript) -> ServerScriptService.Parks.ScrapyardStacks
-- Stacks of crushed cars dotted over the Scrapyard's open floor
-- (Tuning.Scrapyard.Stacks): Scatter picks the spots clear of the machines,
-- and Junk.stack piles each one's cars. Every car is a knockable prop in its
-- stack's Shatter model, so a car hitting any of it bursts the whole stack
-- with a crash, and it is a Junk stack target on a run (PropService).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Junk = require(ReplicatedStorage.Junk)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Rng = require(ReplicatedStorage.Rng)
local Scatter = require(ReplicatedStorage.Scatter)
local Tuning = require(ReplicatedStorage.Tuning)
local JunkPieces = require(ServerScriptService.Pieces.JunkPieces)

local S = Tuning.Scrapyard.Stacks

local ScrapyardStacks = {}

function ScrapyardStacks.build(folder: Folder, area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "JunkStacks"
	local rng = Rng.new(S.Seed)
	for _, spot in Scatter.points(rng, S.Count, S.Area, S.Gap, S.KeepOut) do
		local stack = Instance.new("Model")
		stack.Name = "Stack"
		stack:SetAttribute("Shatter", true)
		stack:SetAttribute("BurstSound", "Junk")
		local foot = CFrame.new(area.X + spot.x, Tuning.Map.FloorTop, area.Z + spot.z)
		for _, car in Junk.stack(S :: any, rng) do
			local at = foot * CFrame.new(car.x, car.y, car.z) * CFrame.Angles(0, math.rad(car.yaw), 0)
			local part = JunkPieces.make(stack, car.kind, at, rng)
			part:SetAttribute("Target", "Junk stack")
			part:SetAttribute("ResetTime", S.ResetTime)
			CollectionService:AddTag(part, "Knockable")
		end
		stack.Parent = model
	end
	model.Parent = folder
end

return ScrapyardStacks
