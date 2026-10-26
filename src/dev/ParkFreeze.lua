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

-- Studio keeps the first require of each module for the whole session, so
-- after an edit a park's modules would build from old code and tuning.
-- While `run` runs, every ModuleScript in ReplicatedStorage and
-- ServerScriptService (except those inside another, copied along with it)
-- is swapped for a fresh copy, so each require gets the file as it is now.
-- The originals go back after, so Rojo still syncs them.
local function fresh(run: () -> ())
	local swaps: { { original: Instance, copy: Instance } } = {}
	for _, root in { ReplicatedStorage, ServerScriptService } do
		for _, module in root:GetDescendants() do
			if module:IsA("ModuleScript") and not module:FindFirstAncestorWhichIsA("ModuleScript") then
				table.insert(swaps, { original = module, copy = module:Clone() })
			end
		end
	end
	for _, swap in swaps do
		swap.copy.Parent = swap.original.Parent
		swap.original.Parent = nil
	end
	local ok, problem = pcall(run)
	for _, swap in swaps do
		swap.original.Parent = swap.copy.Parent
		swap.copy:Destroy()
	end
	if not ok then
		error(problem, 0)
	end
end

function ParkFreeze.freeze(id: string)
	local area = areaOf(id)
	assert(area, `ParkFreeze: no area {id} in Tuning.Map.Areas`)
	local parks = parksFolder()
	assert(not parks:FindFirstChild(id), `ParkFreeze: {id} is already frozen; thaw it first`)
	local folder: Folder? = nil
	fresh(function()
		-- Saved parts keep their collision groups only if the place has them.
		require(ServerScriptService.CollisionGroups :: ModuleScript)
		folder = (require :: any)(ServerScriptService.ParkBuilder).build(area)
	end)
	assert(folder, `ParkFreeze: {id} has nothing to build`)
	folder.Parent = parks
	print(
		`ParkFreeze: froze {area.Name}, {#folder:GetDescendants()} instances, fingerprint {folder:GetAttribute(
			"Fingerprint"
		)}. Save the place to keep it.`
	)
end

-- Rebuilds one piece of a frozen park in place, one its module lists in
-- `patches`, leaving the rest of the saved parts and any edits to them
-- alone, and stamps the folder's Fingerprint again. Only use it when the
-- piece's tuning and code are all that changed since the park was frozen.
function ParkFreeze.patch(id: string, piece: string)
	local area = areaOf(id)
	assert(area, `ParkFreeze: no area {id} in Tuning.Map.Areas`)
	local saved = parksFolder():FindFirstChild(id)
	assert(saved, `ParkFreeze: {id} is not frozen`)
	fresh(function()
		local park = (require :: any)(ServerScriptService.ParkBuilder).module(area)
		local patch = park and park.patches and park.patches[piece]
		assert(patch, `ParkFreeze: {id} has no piece {piece} to patch`)
		patch(saved, area)
		if park.fingerprint then
			saved:SetAttribute("Fingerprint", park.fingerprint())
		end
	end)
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
