local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local FrogCarAdmin = {}

local SPAWN_OFFSET = Vector3.new(0, 5, 10)

local function findPlayer(targetName)
	for _, plr in ipairs(Players:GetPlayers()) do
		if string.lower(plr.Name):sub(1, #string.lower(targetName)) == string.lower(targetName) then
			return plr
		end
	end
	return nil
end

local function findPlayerCar(player)
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local seat = humanoid.SeatPart
	if not seat then return nil end
	local model = seat:FindFirstAncestorOfClass("Model")
	return model
end

local commands = {}

local function registerCommand(name, description, func)
	commands[name] = { description = description, func = func }
end

-- replaceCarWithFrog: Replace whatever car the player is currently sitting in with a FrogCar
registerCommand("frog", "targetName - replaces the player's current car with a FrogCar", function(targetName)
	local template = ServerStorage:FindFirstChild("FrogCar")
	if not template then return "FrogCar template not found in ServerStorage" end

	local target = findPlayer(targetName)
	if not target then return "Player '" .. targetName .. "' not found" end

	local oldCar = findPlayerCar(target)
	if not oldCar then return target.Name .. " is not sitting in any car" end

	-- Get position and rotation of the old car
	local oldPivot = oldCar:GetPivot()

	-- Remove the old car
	oldCar.Parent = nil

	-- Spawn FrogCar at the same position
	local newCar = template:Clone()
	newCar:PivotTo(oldPivot)
	newCar.Parent = workspace

	return "Replaced " .. oldCar.Name .. " with FrogCar for " .. target.Name
end)

function FrogCarAdmin.frog(targetName)
	return commands.frog.func(targetName)
end

function FrogCarAdmin.list()
	local lines = {
		"",
		"=== ADMIN ABUSE COMMANDS ===",
		"",
	}
	for name, info in pairs(commands) do
		table.insert(lines, string.format("  %s(%s)", name, info.description))
	end
	table.insert(lines, "")
	table.insert(lines, "Usage from command bar:")
	table.insert(lines, "  require(game.ServerScriptService.FrogCarAdmin).list()")
	table.insert(lines, "  require(game.ServerScriptService.FrogCarAdmin).frog(\"PlayerName\")")
	table.insert(lines, "  require(game.ServerScriptService.FrogCarAdmin).giveFrogCar(\"PlayerName\")")
	table.insert(lines, "  require(game.ServerScriptService.FrogCarAdmin).speedBoost(\"PlayerName\", 100, 15)")
	table.insert(lines, "  require(game.ServerScriptService.FrogCarAdmin).heal(\"PlayerName\")")
	table.insert(lines, "  require(game.ServerScriptService.FrogCarAdmin).kick(\"PlayerName\", \"reason\")")
	table.insert(lines, "  require(game.ServerScriptService.FrogCarAdmin).teleport(\"Player1\", \"Player2\")")
	table.insert(lines, "")
	table.insert(lines, "Shortcut:")
	table.insert(lines, "  adminabuse()                                  -- shows this list")
	table.insert(lines, "  adminabuse(\"frog\", \"PlayerName\")            -- replace current car with FrogCar")
	table.insert(lines, "")
	return table.concat(lines, "\n")
end

-- giveFrogCar
registerCommand("giveFrogCar", "targetName - gives a FrogCar to the specified player", function(targetName)
	local template = ServerStorage:FindFirstChild("FrogCar")
	if not template then return "FrogCar template not found in ServerStorage" end

	local target = findPlayer(targetName)
	if not target then return "Player '" .. targetName .. "' not found" end

	local character = target.Character
	if not character then return target.Name .. " has no character" end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return target.Name .. " has no HumanoidRootPart" end

	local car = template:Clone()
	car:PivotTo(hrp.CFrame * CFrame.new(SPAWN_OFFSET))
	car.Parent = workspace
	return "Gave FrogCar to " .. target.Name
end)

function FrogCarAdmin.giveFrogCar(targetName)
	return commands.giveFrogCar.func(targetName)
end

-- speedBoost
registerCommand("speedBoost", "targetName, speed=50, duration=10 - temporarily boosts a player's speed", function(targetName, speed, duration)
	speed = speed or 50
	duration = duration or 10
	local target = findPlayer(targetName)
	if not target then return "Player '" .. targetName .. "' not found" end
	local character = target.Character
	if not character then return target.Name .. " has no character" end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return target.Name .. " has no Humanoid" end
	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = speed
	task.delay(duration, function()
		if humanoid and humanoid.Parent then humanoid.WalkSpeed = originalSpeed end
	end)
	return "Gave " .. target.Name .. " speed boost of " .. speed .. " for " .. duration .. "s"
end)

function FrogCarAdmin.speedBoost(targetName, speed, duration)
	return commands.speedBoost.func(targetName, speed, duration)
end

-- heal
registerCommand("heal", "targetName - fully heals the specified player", function(targetName)
	local target = findPlayer(targetName)
	if not target then return "Player '" .. targetName .. "' not found" end
	local character = target.Character
	if not character then return target.Name .. " has no character" end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return target.Name .. " has no Humanoid" end
	humanoid.Health = humanoid.MaxHealth
	return "Healed " .. target.Name
end)

function FrogCarAdmin.heal(targetName)
	return commands.heal.func(targetName)
end

-- kick
registerCommand("kick", "targetName, reason=nil - kicks the specified player", function(targetName, reason)
	local target = findPlayer(targetName)
	if not target then return "Player '" .. targetName .. "' not found" end
	target:Kick(reason or "Kicked by admin")
	return "Kicked " .. target.Name
end)

function FrogCarAdmin.kick(targetName, reason)
	return commands.kick.func(targetName, reason)
end

-- teleport
registerCommand("teleport", "targetName, destName - teleports targetName to destName", function(targetName, destName)
	local target = findPlayer(targetName)
	if not target then return "Player '" .. targetName .. "' not found" end
	local dest = findPlayer(destName)
	if not dest then return "Destination player '" .. destName .. "' not found" end
	local targetChar = target.Character
	local destChar = dest.Character
	if not targetChar or not destChar then return "One or both players have no character" end
	local destHrp = destChar:FindFirstChild("HumanoidRootPart")
	if not destHrp then return dest.Name .. " has no HumanoidRootPart" end
	targetChar:PivotTo(destHrp.CFrame * CFrame.new(0, 0, 5))
	return "Teleported " .. target.Name .. " to " .. dest.Name
end)

function FrogCarAdmin.teleport(targetName, destName)
	return commands.teleport.func(targetName, destName)
end

-- Set up global for command bar use
_G.adminabuse = function(...)
	local args = {...}
	if #args == 0 then
		return FrogCarAdmin.list()
	end
	local cmdName = args[1]
	local cmd = commands[cmdName]
	if not cmd then
		return "Unknown command '" .. tostring(cmdName) .. "'. Call adminabuse() with no args to see all commands."
	end
	return cmd.func(select(2, ...))
end

return FrogCarAdmin