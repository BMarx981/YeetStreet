--!strict
-- ParkPreview (ModuleScript) -> ServerStorage.Dev.ParkPreview
-- A Studio tool for building parks by hand next to the test park. The test
-- park is built by code when a server starts, so edit mode shows nothing.
-- Run this from the command bar in edit mode to build a copy of it as
-- workspace.ParkPreview, which is never saved with the place or copied into
-- Play, so it never doubles up with the real one.
--
--   local P = require(game.ServerStorage.Dev.ParkPreview:Clone())
--   P.show()
--   P.clear()
--
-- Hand-built parts in workspace are saved with the place and show up in Play.
-- A part with a LaunchSpeed attribute is a launch pad, a RespawnCFrame
-- attribute on it sets where a reset or wreck puts the car, and a part tagged
-- Knockable gets knocked over by cars.

local ServerScriptService = game:GetService("ServerScriptService")

local ParkPreview = {}

local FOLDER_NAME = "ParkPreview"

function ParkPreview.show()
	ParkPreview.clear()
	local TestPark = (require :: any)(ServerScriptService.TestPark:Clone())
	local folder = TestPark.build()
	folder.Name = FOLDER_NAME
	folder.Archivable = false -- never saved with the place or copied into Play
	print("ParkPreview: built the test park preview.")
end

function ParkPreview.clear()
	local old = workspace:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
end

return ParkPreview
