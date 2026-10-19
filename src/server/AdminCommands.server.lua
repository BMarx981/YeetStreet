local Players = game:GetService("Players")

-- Only these usernames have admin access
local ADMINS = {
	["bananadad981"] = true,
	["bannanaman0175"] = true,
}

local PREFIX = ":"

-- Helper: find a player by partial name match (case-insensitive)
local function findPlayer(query)
	query = string.lower(query)
	for _, player in Players:GetPlayers() do
		if string.lower(player.Name):sub(1, #query) == query then
			return player
		end
	end
	return nil
end

local Lighting = game:GetService("Lighting")
local MessagingService = game:GetService("MessagingService")
local TELEMETRY_TOPIC = "AdminCommands_Global"

-- Commands that should be broadcast to all servers
local GLOBAL_COMMANDS = {
	weather = true,
	time = true,
	kick = true,
	global = true,
	money = true,
}

-- Weather presets
local WEATHER_PRESETS = {
	clear = {
		FogEnd = 100000,
		Brightness = 3,
		Ambient = Color3.fromRGB(128, 128, 128),
		OutdoorAmbient = Color3.fromRGB(128, 128, 128),
		ClockTime = 14,
	},
	sunny = {
		FogEnd = 100000,
		Brightness = 4,
		Ambient = Color3.fromRGB(170, 170, 170),
		OutdoorAmbient = Color3.fromRGB(170, 170, 170),
		ClockTime = 12,
	},
	rain = {
		FogEnd = 500,
		FogColor = Color3.fromRGB(100, 100, 110),
		Brightness = 1.5,
		Ambient = Color3.fromRGB(90, 90, 100),
		OutdoorAmbient = Color3.fromRGB(90, 90, 100),
		ClockTime = 10,
	},
	storm = {
		FogEnd = 300,
		FogColor = Color3.fromRGB(60, 60, 70),
		Brightness = 0.8,
		Ambient = Color3.fromRGB(50, 50, 60),
		OutdoorAmbient = Color3.fromRGB(50, 50, 60),
		ClockTime = 8,
	},
	snow = {
		FogEnd = 400,
		FogColor = Color3.fromRGB(200, 200, 210),
		Brightness = 2.5,
		Ambient = Color3.fromRGB(150, 150, 160),
		OutdoorAmbient = Color3.fromRGB(150, 150, 160),
		ClockTime = 11,
	},
	cloudy = {
		FogEnd = 3000,
		FogColor = Color3.fromRGB(170, 170, 180),
		Brightness = 2,
		Ambient = Color3.fromRGB(120, 120, 130),
		OutdoorAmbient = Color3.fromRGB(120, 120, 130),
		ClockTime = 12,
	},
	fog = {
		FogEnd = 80,
		FogColor = Color3.fromRGB(180, 180, 180),
		Brightness = 2,
		Ambient = Color3.fromRGB(120, 120, 120),
		OutdoorAmbient = Color3.fromRGB(120, 120, 120),
		ClockTime = 9,
	},
	night = {
		FogEnd = 800,
		Brightness = 1,
		Ambient = Color3.fromRGB(40, 40, 50),
		OutdoorAmbient = Color3.fromRGB(40, 40, 50),
		ClockTime = 0,
	},
	coinrain = {
		FogEnd = 2000,
		FogColor = Color3.fromRGB(255, 220, 150),
		Brightness = 2.5,
		Ambient = Color3.fromRGB(180, 160, 100),
		OutdoorAmbient = Color3.fromRGB(180, 160, 100),
		ClockTime = 14,
	},
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Garage = require(game:GetService("ServerScriptService").Garage)
local adminCommandEvent = ReplicatedStorage:WaitForChild("AdminCommandEvent")
local adminFeedbackEvent = ReplicatedStorage:WaitForChild("AdminFeedbackEvent")
local weatherUpdateEvent = ReplicatedStorage:WaitForChild("WeatherUpdateEvent")

-- Track active weathers as an ordered list (multiple can be active at once)
local activeWeathers = {"clear"}

-- Re-apply all active weather presets to Lighting (in order, later ones override)
local function applyWeathers()
	-- Reset Lighting to defaults first
	Lighting.FogEnd = 100000
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(128, 128, 128)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	Lighting.ClockTime = 14
	Lighting.FogColor = Color3.fromRGB(192, 192, 192)
	for _, weatherName in ipairs(activeWeathers) do
		local preset = WEATHER_PRESETS[weatherName]
		if preset then
			for prop, value in pairs(preset) do
				Lighting[prop] = value
			end
		end
	end
end

-- Send the current active weathers to a specific player (or all players if nil)
local function notifyWeather(player)
	if player then
		weatherUpdateEvent:FireClient(player, activeWeathers)
	else
		for _, p in Players:GetPlayers() do
			weatherUpdateEvent:FireClient(p, activeWeathers)
		end
	end
end

-- ===== COIN RAIN (admin-only special weather) =====
local COIN_VALUE = 100
local COIN_GROUND_LIFETIME = 20
local COIN_SPAWN_INTERVAL = 0.5
local COINS_PER_SPAWN = 3
local COIN_SPAWN_RADIUS = 200
local COIN_SPAWN_HEIGHT = 300

local coinRainActive = false
local coinFolder = nil

local function createCoin(position)
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 2.2, 2.2)
	coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	coin.Color = Color3.fromRGB(255, 200, 0)
	coin.Material = Enum.Material.Metal
	coin.CanCollide = true
	coin.Anchored = false
	coin.Parent = coinFolder

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 0)
	light.Range = 12
	light.Brightness = 2
	light.Parent = coin

	local collected = false
	local destroyed = false

	local function cleanup()
		if destroyed then return end
		destroyed = true
		if coin and coin.Parent then
			coin:Destroy()
		end
	end

	coin.Touched:Connect(function(otherPart)
		if collected then return end
		local character = otherPart.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			collected = true
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				local currentCash = player:GetAttribute("Cash") or 0
				player:SetAttribute("Cash", currentCash + COIN_VALUE)
			end
			cleanup()
		end
	end)

	-- Wait for the coin to land on the ground, then start the ground lifetime timer
	task.spawn(function()
		-- Wait until the coin has settled (low vertical velocity for a few frames)
		local landed = false
		local lowVelocityFrames = 0
		while not landed and not collected and coin and coin.Parent do
			task.wait(0.1)
			if coin.AssemblyLinearVelocity.Magnitude < 2 then
				lowVelocityFrames += 1
				if lowVelocityFrames >= 3 then
					landed = true
				end
			else
				lowVelocityFrames = 0
			end
		end
		-- Coin has landed; anchor it in place and start the ground lifetime countdown
		if coin and coin.Parent and not collected then
			coin.Anchored = true
			task.delay(COIN_GROUND_LIFETIME, cleanup)
		end
	end)
end

local function startCoinRain()
	if coinRainActive then return end
	coinRainActive = true

	coinFolder = Instance.new("Folder")
	coinFolder.Name = "CoinRain"
	coinFolder.Parent = workspace

	task.spawn(function()
		while coinRainActive do
			task.wait(COIN_SPAWN_INTERVAL)
			for _ = 1, COINS_PER_SPAWN do
				local x = math.random(-COIN_SPAWN_RADIUS, COIN_SPAWN_RADIUS)
				local z = math.random(-COIN_SPAWN_RADIUS, COIN_SPAWN_RADIUS)
				createCoin(Vector3.new(x, COIN_SPAWN_HEIGHT, z))
			end
		end
	end)
end

local function stopCoinRain()
	coinRainActive = false
	if coinFolder then
		coinFolder:Destroy()
		coinFolder = nil
	end
end

-- Commands table: each command takes (adminPlayer, argsString)
local COMMANDS = {
	kick = function(adminPlayer, args)
		local targetName = string.match(args, "%S+")
		if not targetName then
			return "Usage: :kick <playerName>"
		end

		local target = findPlayer(targetName)
		if not target then
			-- Player not on this server; the MessagingService broadcast will kick them on their server
			return "Kick command broadcast to all servers for: " .. targetName
		end

		if ADMINS[target.Name] then
			return "You cannot kick another admin."
		end

		local reason = string.match(args, "%S+%s+(.+)") or "Kicked by an admin."
		target:Kick(reason)
		return "Kicked " .. target.Name .. "."
	end,

		money = function(adminPlayer, args)
		local targetName, amountStr = string.match(args, "(%S+)%s+(%S+)")
		if not targetName or not amountStr then
			return "Usage: :money <username|all> <amount>"
		end

		local amount = tonumber(amountStr)
		if not amount or amount <= 0 then
			return "Invalid amount. Use a positive number."
		end

		if string.lower(targetName) == "all" then
			for _, p in Players:GetPlayers() do
				Garage.pay(p, amount)
			end
			return "Gave " .. amount .. " cash to all players."
		end

		local target = findPlayer(targetName)
		if not target then
			return "Player not found: " .. targetName
		end

		Garage.pay(target, amount)
		return "Gave " .. amount .. " cash to " .. target.Name .. "."
	end,

	weather = function(adminPlayer, args)
		local weatherName = string.match(args, "%S+")
		if not weatherName then
			return "Usage: :weather <clear|sunny|rain|storm|snow|cloudy|fog|night|coinrain> (toggle on/off, multiple can stack)"
		end

		weatherName = string.lower(weatherName)
		local preset = WEATHER_PRESETS[weatherName]
		if not preset then
			return "Unknown weather: '" .. weatherName .. "'. Available: clear, sunny, rain, storm, snow, cloudy, fog, night, coinrain"
		end

		-- "clear" resets everything to just clear weather
		if weatherName == "clear" then
			activeWeathers = {"clear"}
			stopCoinRain()
			applyWeathers()
			notifyWeather()
			return "Weather cleared."
		end

		-- Remove "clear" from the list since a real weather is being toggled
		for i = #activeWeathers, 1, -1 do
			if activeWeathers[i] == "clear" then
				table.remove(activeWeathers, i)
			end
		end

		-- Toggle: if already active, remove it; otherwise add it
		local found = false
		for i, w in ipairs(activeWeathers) do
			if w == weatherName then
				table.remove(activeWeathers, i)
				found = true
				break
			end
		end

		if not found then
			table.insert(activeWeathers, weatherName)
		end

		-- If no weathers active, default back to clear
		if #activeWeathers == 0 then
			activeWeathers = {"clear"}
		end

		-- Handle special admin-only weathers
		if weatherName == "coinrain" then
			if found then
				stopCoinRain()
			else
				startCoinRain()
			end
		end

		applyWeathers()
		notifyWeather()

		if found then
			return "Weather removed: " .. weatherName .. ". Active: " .. table.concat(activeWeathers, ", ")
		else
			return "Weather added: " .. weatherName .. ". Active: " .. table.concat(activeWeathers, ", ")
		end
	end,

	time = function(adminPlayer, args)
		local timeVal = string.match(args, "%S+")
		if not timeVal then
			return "Usage: :time <0-24>"
		end

		local num = tonumber(timeVal)
		if not num or num < 0 or num > 24 then
			return "Invalid time. Use a number between 0 and 24."
		end

		Lighting.ClockTime = num
		return "Time set to: " .. num
	end,

	global = function(adminPlayer, args)
		local messageText = string.match(args, "%S+%s+(.+)")
		if not messageText then
			return "Usage: :global message <text>"
		end

		-- Extract the subcommand (should be "message")
		local subCmd, actualMessage = string.match(args, "(%S+)%s+(.+)")
		if not subCmd or string.lower(subCmd) ~= "message" then
			return "Usage: :global message <text>"
		end

		local senderName = adminPlayer and adminPlayer.Name or "Admin"
		return "[Global] " .. senderName .. ": " .. actualMessage, senderName, actualMessage
	end,

	promote = function(adminPlayer, args)
		local targetName = string.match(args, "%S+")
		if not targetName then
			return "Usage: :promote <playerName>"
		end

		local target = findPlayer(targetName)
		if not target then
			return "Player not found: " .. targetName
		end

		if ADMINS[target.Name] then
			return target.Name .. " is already an admin."
		end

		ADMINS[target.Name] = true
		-- Notify the promoted player's client to activate the admin command bar
		adminFeedbackEvent:FireClient(target, "__PROMOTED__")
		return target.Name .. " has been promoted to admin."
	end,

	admin = function(adminPlayer, args)
		local subCmd = string.match(args, "%S+")
		if subCmd and string.lower(subCmd) == "abuse" then
			return [[
--- ADMIN COMMAND LIST ---
(Global - affects ALL servers)
:kick <player> [reason] - Kick a player from all servers
:weather <type> - Toggle weather on/off (clear, sunny, rain, storm, snow, cloudy, fog, night, coinrain). Multiple can stack!
  coinrain - Coins fall from the sky! Walk over them to collect $100 each (admin-only)
:time <0-24> - Set the time of day everywhere
:money <username|all> <amount> - Give cash to a specific player or everyone
:promote <playerName> - Make a player an admin (gives them the admin command bar)
:global message <text> - Send a global message to all servers
:admin abuse - Show this help list
--------------------------]]
		end
		return "Usage: :admin abuse - shows the list of admin commands"
	end,
}

-- (ReplicatedStorage events, activeWeathers, applyWeathers, and notifyWeather
--  are declared above, before the COMMANDS table)

local function processCommand(player, message)
	-- Only admins can use commands
	if not ADMINS[player.Name] then
		return
	end

	if string.sub(message, 1, #PREFIX) ~= PREFIX then
		return
	end

	local commandText = string.sub(message, #PREFIX + 1)
	local commandName, args = string.match(commandText, "(%S+)%s*(.*)")
	commandName = commandName and string.lower(commandName) or ""

	local commandFunc = COMMANDS[commandName]
	if commandFunc then
		local result, senderName, actualMessage = commandFunc(player, args or "")

		-- If this command should affect all servers, broadcast it via MessagingService
		if GLOBAL_COMMANDS[commandName] then
			local broadcastData = {
				commandName = commandName,
				args = args or "",
			}
			-- For global messages, include the sender's name so other servers know who sent it
			if commandName == "global" and senderName then
				broadcastData.senderName = senderName
				broadcastData.messageText = actualMessage
			end
			MessagingService:PublishAsync(TELEMETRY_TOPIC, broadcastData)
		end

		-- Send feedback to the admin via the feedback RemoteEvent
		adminFeedbackEvent:FireClient(player, result or "Command executed.")
	end
end

-- Handle messages from other servers (received via MessagingService)
MessagingService:SubscribeAsync(TELEMETRY_TOPIC, function(message)
	local cmd = message.data
	if not cmd or not cmd.commandName then
		return
	end

	-- For global messages, fire the feedback event to all players on this server
	if cmd.commandName == "global" and cmd.messageText then
		local displayText = "[Global] " .. (cmd.senderName or "Admin") .. ": " .. cmd.messageText
		for _, p in Players:GetPlayers() do
			adminFeedbackEvent:FireClient(p, displayText)
		end
		return
	end

	local commandFunc = COMMANDS[cmd.commandName]
	if commandFunc then
		-- Execute the command on this server (no feedback needed, it's already shown on the originating server)
		commandFunc(nil, cmd.args or "")
		-- If weather changed, notify all players on this server
		if cmd.commandName == "weather" then
			notifyWeather()
		end
	end
end)

-- Handle commands from the command bar GUI
adminCommandEvent.OnServerEvent:Connect(function(player, message)
	processCommand(player, message)
end)

-- Connect chat for all existing and future players (chat commands still work too)
local function onPlayerAdded(player)
	-- Tell the new player what the current weather is
	notifyWeather(player)

	player.Chatted:Connect(function(message)
		processCommand(player, message)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- ===== NATURAL WEATHER CYCLE =====
-- These weathers can naturally occur every 5 minutes.
-- To add more weathers in the future, add their name to this list
-- and add a corresponding preset to WEATHER_PRESETS above.
local NATURAL_WEATHERS = {
	"sunny",
	"rain",
	"storm",
	"snow",
	"cloudy",
}

local WEATHER_INTERVAL = 300 -- 5 minutes in seconds

local lastNaturalWeather = nil

local function cycleWeather()
	-- Pick a random weather, avoiding repeating the same one twice in a row
	local available = {}
	for _, w in ipairs(NATURAL_WEATHERS) do
		if w ~= lastNaturalWeather then
			table.insert(available, w)
		end
	end

	local nextWeather = available[math.random(1, #available)]
	lastNaturalWeather = nextWeather

	stopCoinRain()
	activeWeathers = {nextWeather}
	applyWeathers()
	notifyWeather()
	print("[Weather] Natural weather changed to: " .. nextWeather)
end

-- Start the natural weather cycle
task.spawn(function()
	while true do
		task.wait(WEATHER_INTERVAL)
		cycleWeather()
	end
end)
