--!strict
-- ParkFreeze (ModuleScript) -> ServerStorage.Dev.ParkFreeze
-- A Studio tool that freezes a park: run from the command bar in edit mode,
-- it builds the park once the way a server does (ParkBuilder) and leaves it
-- in workspace.Parks, to be saved with the place. Servers then leave a saved
-- park's parts as they are and only start what moves in it (ParkService),
-- and its parts can be edited by hand in Studio like any others.
--
--   local F = require(game.ServerStorage.Dev.ParkFreeze:Clone())
--   F.freeze("City")
--   F.thaw("City")
--
-- thaw deletes the saved park, so servers build it from code again. Freezing
-- the city cuts the train line's holes into workspace.TestPark's ground
-- tiles for good; a thaw leaves them cut, and the code build cuts the same
-- holes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ParkFreeze = {}

local function areaOf(id: string): any
	local Tuning = (require :: any)(ReplicatedStorage.Tuning)
	for _, area in Tuning.Map.Areas do
		if area.Id == id then
			return area
		end
	end
	return nil
end

local function parksFolder(): Instance
	local parks = workspace:FindFirstChild("Parks")
	if not parks then
		parks = Instance.new("Folder")
		parks.Name = "Parks"
		parks.Parent = workspace
	end
	return parks :: Instance
end

function ParkFreeze.freeze(id: string)
	local area = areaOf(id)
	assert(area, `ParkFreeze: no area {id} in Tuning.Map.Areas`)
	local parks = parksFolder()
	assert(not parks:FindFirstChild(id), `ParkFreeze: {id} is already frozen; thaw it first`)
	-- Saved parts keep their collision groups only if the place has them.
	require(ServerScriptService.CollisionGroups :: ModuleScript)
	local ParkBuilder = (require :: any)(ServerScriptService.ParkBuilder:Clone())
	local folder = ParkBuilder.build(area)
	assert(folder, `ParkFreeze: {id} has nothing to build`)
	folder.Parent = parks
	print(
		`ParkFreeze: froze {area.Name}, {#folder:GetDescendants()} instances, fingerprint {folder:GetAttribute(
			"Fingerprint"
		)}. Save the place to keep it.`
	)
end

function ParkFreeze.thaw(id: string)
	local parks = parksFolder()
	local saved = parks:FindFirstChild(id)
	assert(saved, `ParkFreeze: {id} is not frozen`)
	saved:Destroy()
	print(`ParkFreeze: thawed {id}; servers build it from code again once the place is saved.`)
end

return ParkFreeze
