--!strict
-- CityKaiju (ModuleScript) -> ServerScriptService.Parks.CityKaiju
-- Downtown's kaiju, built into the city's folder by City.build. It hunts
-- cars and players on foot the way Dino Valley's T-Rex does, and Parks.DinoRex
-- runs it, but it keeps to Downtown's streets (Tuning.City.Kaiju.Streets),
-- walking round the blocks to reach a car on another street. Each client
-- draws it from the two parts DinoRex moves (KaijuLook).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Rex = require(ReplicatedStorage.Rex)
local Tuning = require(ReplicatedStorage.Tuning)
local DinoRex = require(script.Parent.DinoRex)

local K = Tuning.City.Kaiju
local FLOOR = Tuning.Map.FloorTop

local CityKaiju = {}

function CityKaiju.build(parent: Instance, area: MapLayout.Area)
	local model = Instance.new("Model")
	model.Name = "Kaiju"
	-- Persistent, so streaming never takes it from a client.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent

	local streets: { Rex.Rect } = {}
	for _, street in K.Streets do
		table.insert(streets, {
			MinX = area.X + street.MinX,
			MaxX = area.X + street.MaxX,
			MinZ = area.Z + street.MinZ,
			MaxZ = area.Z + street.MaxZ,
		})
	end
	local territory: Rex.Territory = {
		rect = {
			MinX = area.X - area.Width / 2,
			MaxX = area.X + area.Width / 2,
			MinZ = area.Z - area.Depth / 2,
			MaxZ = area.Z + area.Depth / 2,
		},
		keepOut = {},
		floor = FLOOR,
		streets = streets,
	}
	DinoRex.start(
		model,
		territory,
		area.X + K.X,
		area.Z + K.Z,
		math.rad(K.Heading),
		{ tuning = K :: any, name = "Kaiju" }
	)
end

return CityKaiju
