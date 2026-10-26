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
--   F.patch("City", "Roofs")
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

-- Studio keeps the first require of a module for the whole session, so the
-- Tuning the park's modules hold can be older than the file. Copies the
-- file's numbers into it in place, so every table they hold sees them.
local function refreshTuning()
	local function copy(into: any, from: any)
		for key, value in from do
			if type(value) == "table" and type(into[key]) == "table" then
				copy(into[key], value)
			else
				into[key] = value
			end
		end
		for key in into do
			if from[key] == nil then
				into[key] = nil
			end
		end
	end
	copy((require :: any)(ReplicatedStorage.Tuning), (require :: any)(ReplicatedStorage.Tuning:Clone()))
end

-- Rebuilds one piece of a frozen park in place, one its module lists in
-- `patches`, leaving the rest of the saved parts and any edits to them
-- alone, and stamps the folder's Fingerprint again. Only use it when the
-- piece's tuning is all that changed since the park was frozen. It picks up
-- new tuning, but not changes to the code, which need Studio restarted.
function ParkFreeze.patch(id: string, piece: string)
	refreshTuning()
	local area = areaOf(id)
	assert(area, `ParkFreeze: no area {id} in Tuning.Map.Areas`)
	local saved = parksFolder():FindFirstChild(id)
	assert(saved, `ParkFreeze: {id} is not frozen`)
	local ParkBuilder = (require :: any)(ServerScriptService.ParkBuilder:Clone())
	local park = ParkBuilder.module(area)
	local patch = park and park.patches and park.patches[piece]
	assert(patch, `ParkFreeze: {id} has no piece {piece} to patch`)
	patch(saved, area)
	if park.fingerprint then
		saved:SetAttribute("Fingerprint", park.fingerprint())
	end
	print(`ParkFreeze: rebuilt {piece} in {area.Name}. Save the place to keep it.`)
end

function ParkFreeze.thaw(id: string)
	local parks = parksFolder()
	local saved = parks:FindFirstChild(id)
	assert(saved, `ParkFreeze: {id} is not frozen`)
	saved:Destroy()
	print(`ParkFreeze: thawed {id}; servers build it from code again once the place is saved.`)
end

return ParkFreeze
