--!strict
-- Leaderstats (ModuleScript) -> ServerScriptService.Leaderstats
-- The player list columns. Several scripts add their own, so each asks here
-- and the folder is made once.

local Leaderstats = {}

-- The player's leaderstats value called `name`, made if it isn't there yet.
-- Columns show in the order they are first asked for.
function Leaderstats.value(player: Player, name: string): IntValue
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	local value = folder:FindFirstChild(name)
	if value and value:IsA("IntValue") then
		return value
	end
	local made = Instance.new("IntValue")
	made.Name = name
	made.Parent = folder
	return made
end

return Leaderstats
