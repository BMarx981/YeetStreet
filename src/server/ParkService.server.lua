--!strict
-- ParkService (Script) -> ServerScriptService.ParkService
-- Builds each stunt park in Tuning.Map into its own folder, workspace.Parks.<Id>,
-- and starts what moves in it (ParkBuilder). A park whose folder is already
-- in workspace was saved with the place (frozen), so its parts are left as
-- they are and it is only started. Warns at startup about anything wrong
-- with the layout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local ParkBuilder = require(ServerScriptService.ParkBuilder)

local M = Tuning.Map
local areas: { MapLayout.Area } = M.Areas :: any

for _, problem in MapLayout.problems(areas, M.Bounds, M.Gap) do
	warn(`ParkService: {problem}`)
end

-- The area marks for building in edit mode (ServerStorage.Dev.ParkAreas)
-- never show in game.
local marks = workspace:FindFirstChild("ParkAreas")
if marks then
	marks:Destroy()
end

local parks: Instance = workspace:FindFirstChild("Parks") or Instance.new("Folder")
parks.Name = "Parks"
parks.Parent = workspace

for _, area in areas do
	local saved = parks:FindFirstChild(area.Id)
	if saved and saved:IsA("Folder") then
		ParkBuilder.start(saved, area, true)
	else
		local folder = ParkBuilder.build(area)
		if folder then
			folder.Parent = parks
			ParkBuilder.start(folder, area, false)
		end
	end
end
