local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local adminCommandEvent = ReplicatedStorage:WaitForChild("AdminCommandEvent")
local adminFeedbackEvent = ReplicatedStorage:WaitForChild("AdminFeedbackEvent")
local weatherUpdateEvent = ReplicatedStorage:WaitForChild("WeatherUpdateEvent")
local boneRainEvent = ReplicatedStorage:WaitForChild("BoneRainEvent")
local commandListEvent = ReplicatedStorage:WaitForChild("CommandListEvent")

-- Weather icon/emoji mapping
local WEATHER_ICONS = {
	clear = { icon = "☀", label = "Clear", color = Color3.fromRGB(255, 220, 100) },
	sunny = { icon = "☼", label = "Sunny", color = Color3.fromRGB(255, 200, 60) },
	rain = { icon = "🌧", label = "Rain", color = Color3.fromRGB(100, 150, 255) },
	storm = { icon = "⛈", label = "Storm", color = Color3.fromRGB(80, 80, 120) },
	snow = { icon = "❄", label = "Snow", color = Color3.fromRGB(200, 230, 255) },
	cloudy = { icon = "☁", label = "Cloudy", color = Color3.fromRGB(180, 180, 190) },
	fog = { icon = "🌫", label = "Fog", color = Color3.fromRGB(180, 180, 190) },
	night = { icon = "🌙", label = "Night", color = Color3.fromRGB(80, 80, 140) },
	coinrain = { icon = "💸", label = "Coin Rain", color = Color3.fromRGB(255, 200, 0) },
	bonerain = { icon = "🦴", label = "Bone Rain", color = Color3.fromRGB(230, 210, 160) },
}

-- Usernames in lowercase; lookups lowercase the name, since Roblox names ignore case.
local ADMINS = {
	["bananadad981"] = true,
	["bannanaman0175"] = true,
}

-- ===== GLOBAL MESSAGE DISPLAY (visible to ALL players) =====
local playerGui = player:WaitForChild("PlayerGui")

local globalMessageGui = Instance.new("ScreenGui")
globalMessageGui.Name = "GlobalMessageDisplay"
globalMessageGui.ResetOnSpawn = false
globalMessageGui.IgnoreGuiInset = true
globalMessageGui.Parent = playerGui

local globalMessageLabel = Instance.new("TextLabel")
globalMessageLabel.Name = "GlobalMessageLabel"
globalMessageLabel.Size = UDim2.new(1, 0, 0, 40)
globalMessageLabel.Position = UDim2.new(0, 0, 0, -50)
globalMessageLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
globalMessageLabel.BackgroundTransparency = 0.15
globalMessageLabel.Text = ""
globalMessageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
globalMessageLabel.Font = Enum.Font.GothamBold
globalMessageLabel.TextSize = 16
globalMessageLabel.TextWrapped = true
globalMessageLabel.Visible = false
globalMessageLabel.Parent = globalMessageGui

local globalCorner = Instance.new("UICorner")
globalCorner.CornerRadius = UDim.new(0, 0)
globalCorner.Parent = globalMessageLabel

local globalPadding = Instance.new("UIPadding")
globalPadding.PaddingLeft = UDim.new(0, 20)
globalPadding.PaddingRight = UDim.new(0, 20)
globalPadding.PaddingTop = UDim.new(0, 8)
globalPadding.PaddingBottom = UDim.new(0, 8)
globalPadding.Parent = globalMessageLabel

-- ===== WEATHER ICON DISPLAY (visible to ALL players, bottom center, supports multiple) =====
local weatherGui = Instance.new("ScreenGui")
weatherGui.Name = "WeatherIconDisplay"
weatherGui.ResetOnSpawn = false
weatherGui.Parent = playerGui

-- Container at bottom-center of screen, auto-sized to fit content
local weatherContainer = Instance.new("Frame")
weatherContainer.Name = "WeatherContainer"
weatherContainer.Size = UDim2.new(1, 0, 0, 90)
weatherContainer.Position = UDim2.new(0, 0, 1, -100)
weatherContainer.BackgroundTransparency = 1
weatherContainer.Parent = weatherGui

-- Horizontal layout for multiple weather icons across the bottom
local weatherLayout = Instance.new("UIListLayout")
weatherLayout.FillDirection = Enum.FillDirection.Horizontal
weatherLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
weatherLayout.VerticalAlignment = Enum.VerticalAlignment.Center
weatherLayout.Padding = UDim.new(0, 10)
weatherLayout.Parent = weatherContainer

-- Track existing icon frames so we can remove/update them
local weatherIconFrames = {}

local function createWeatherIcon(weatherName)
	local weatherInfo = WEATHER_ICONS[weatherName]
	if not weatherInfo then return nil end

	local frame = Instance.new("Frame")
	frame.Name = "Weather_" .. weatherName
	frame.Size = UDim2.new(0, 80, 0, 80)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = weatherContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "WeatherIcon"
	iconLabel.Size = UDim2.new(1, 0, 0, 44)
	iconLabel.Position = UDim2.new(0, 0, 0, 4)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = weatherInfo.icon
	iconLabel.TextColor3 = weatherInfo.color
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextSize = 32
	iconLabel.Parent = frame

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "WeatherLabel"
	textLabel.Size = UDim2.new(1, 0, 0, 20)
	textLabel.Position = UDim2.new(0, 0, 0, 52)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = weatherInfo.label
	textLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	textLabel.Font = Enum.Font.Gotham
	textLabel.TextSize = 12
	textLabel.Parent = frame

	-- Pop-in animation
	frame.Size = UDim2.new(0, 60, 0, 60)
	TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 80, 0, 80),
	}):Play()

	return frame
end

-- Handle bone rain separately (separate event so it doesn't conflict with regular weather icons)
local boneRainActive = false

local function updateBoneRainIcon()
	if boneRainActive and not weatherIconFrames["bonerain"] then
		weatherIconFrames["bonerain"] = createWeatherIcon("bonerain")
	elseif not boneRainActive and weatherIconFrames["bonerain"] then
		local frame = weatherIconFrames["bonerain"]
		weatherIconFrames["bonerain"] = nil
		local tween = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function()
			frame:Destroy()
		end)
	end
end

boneRainEvent.OnClientEvent:Connect(function(isRaining)
	boneRainActive = isRaining
	updateBoneRainIcon()
end)

-- ===== WEATHER PARTICLE EFFECTS (rain, snow, storm lightning) =====
-- A hidden part above the camera that emits weather particles
local weatherEffectPart = Instance.new("Part")
weatherEffectPart.Name = "WeatherEffectPart"
weatherEffectPart.Anchored = true
weatherEffectPart.CanCollide = false
weatherEffectPart.CanQuery = false
weatherEffectPart.CanTouch = false
weatherEffectPart.Transparency = 1
weatherEffectPart.Size = Vector3.new(400, 1, 400)
weatherEffectPart.Parent = workspace

-- Track active emitters and lightning task
local weatherEmitters = {}
local lightningTask = nil

local function stopEffect(name)
	local emitter = weatherEmitters[name]
	if emitter then
		emitter.Enabled = false
		weatherEmitters[name] = nil
		task.delay(4, function()
			if emitter and emitter.Parent then
				emitter:Destroy()
			end
		end)
	end
end

local function startRain()
	if weatherEmitters["rain"] then return end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Rain"
	emitter.Rate = 700
	emitter.Lifetime = NumberRange.new(2, 3)
	emitter.Speed = NumberRange.new(90, 110)
	emitter.SpreadAngle = Vector2.new(5, 5)
	emitter.Color = ColorSequence.new(Color3.fromRGB(160, 190, 255))
	emitter.Transparency = NumberSequence.new(0.5)
	emitter.Size = NumberSequence.new(0.8)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.LightEmission = 0.1
	emitter.Parent = weatherEffectPart
	weatherEmitters["rain"] = emitter
end

local function startSnow()
	if weatherEmitters["snow"] then return end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Snow"
	emitter.Rate = 200
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Speed = NumberRange.new(8, 12)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.Color = ColorSequence.new(Color3.fromRGB(240, 245, 255))
	emitter.Transparency = NumberSequence.new(0.2)
	emitter.Size = NumberSequence.new(1.2)
	emitter.Acceleration = Vector3.new(3, -3, 3)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.LightEmission = 0.3
	emitter.Parent = weatherEffectPart
	weatherEmitters["snow"] = emitter
end

-- Folder to hold lightning bolts in the world
local lightningFolder = Instance.new("Folder")
lightningFolder.Name = "LightningBolts"
lightningFolder.Parent = workspace

local function stopLightning()
	if lightningTask then
		task.cancel(lightningTask)
		lightningTask = nil
	end
	for _, effect in Lighting:GetChildren() do
		if effect.Name == "LightningFlash" then
			effect:Destroy()
		end
	end
	for _, bolt in lightningFolder:GetChildren() do
		bolt:Destroy()
	end
end

-- Build a jagged lightning bolt from `topPos` down to `bottomPos` using thin parts
local function createLightningBolt(topPos: Vector3, bottomPos: Vector3)
	local segments = 14
	local jaggedness = 25
	local points = {}
	for i = 0, segments do
		local t = i / segments
		local base = topPos:Lerp(bottomPos, t)
		-- Add horizontal jagged offset, less near the top and bottom
		local edgeFade = math.sin(t * math.pi)
		local offset = Vector3.new(
			(math.random() - 0.5) * jaggedness * edgeFade,
			0,
			(math.random() - 0.5) * jaggedness * edgeFade
		)
		table.insert(points, base + offset)
	end

	local bolt = Instance.new("Model")
	bolt.Name = "LightningBolt"

	for i = 1, #points - 1 do
		local a = points[i]
		local b = points[i + 1]
		local mid = (a + b) / 2
		local dist = (b - a).Magnitude
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(200, 220, 255)
		part.Transparency = 0.2
		part.Size = Vector3.new(0.6, dist, 0.6)
		part.CFrame = CFrame.lookAt(mid, b) * CFrame.Angles(math.rad(90), 0, 0)
		part.Parent = bolt

		-- Glow light at each segment for a bright bolt
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(200, 220, 255)
		glow.Range = 30
		glow.Brightness = 3
		glow.Parent = part
	end

	-- Bright point light at the strike point
	local strikeLight = Instance.new("Part")
	strikeLight.Anchored = true
	strikeLight.CanCollide = false
	strikeLight.Transparency = 1
	strikeLight.Size = Vector3.new(1, 1, 1)
	strikeLight.CFrame = CFrame.new(bottomPos)
	strikeLight.Parent = bolt
	local impactLight = Instance.new("PointLight")
	impactLight.Color = Color3.fromRGB(200, 220, 255)
	impactLight.Range = 60
	impactLight.Brightness = 5
	impactLight.Parent = strikeLight

	bolt.Parent = lightningFolder

	-- Fade out and destroy the bolt
	task.spawn(function()
		task.wait(0.12)
		for _, p in bolt:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency < 1 then
				TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			elseif p:IsA("PointLight") then
				TweenService:Create(p, TweenInfo.new(0.25), { Brightness = 0 }):Play()
			end
		end
		task.wait(0.3)
		if bolt.Parent then bolt:Destroy() end
	end)
end

local function startLightning()
	if lightningTask then return end
	lightningTask = task.spawn(function()
		while true do
			task.wait(math.random(5, 14))
			local camera = workspace.CurrentCamera
			if not camera then continue end
			local camPos = camera.CFrame.Position
			-- Random strike position within 300 studs of the camera
			local angle = math.random() * math.pi * 2
			local dist = math.random(50, 300)
			local strikeX = camPos.X + math.cos(angle) * dist
			local strikeZ = camPos.Z + math.sin(angle) * dist
			local topPos = Vector3.new(strikeX, camPos.Y + 200, strikeZ)
			local bottomPos = Vector3.new(strikeX, camPos.Y - 50, strikeZ)

			createLightningBolt(topPos, bottomPos)

			-- Subtle screen flash synced with the strike
			local flash = Instance.new("ColorCorrectionEffect")
			flash.Name = "LightningFlash"
			flash.Brightness = 0.2
			flash.Parent = Lighting
			TweenService:Create(flash, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Brightness = 0,
			}):Play()
			task.delay(0.3, function()
				if flash and flash.Parent then flash:Destroy() end
			end)
		end
	end)
end

-- Follow the camera each frame so particles always fall around the player
RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if camera then
		local pos = camera.CFrame.Position
		weatherEffectPart.CFrame = CFrame.new(pos.X, pos.Y + 80, pos.Z)
	end
end)

-- Update weather particle effects based on active weathers
local function updateWeatherEffects(weatherNames)
	local hasRain = false
	local hasStorm = false
	local hasSnow = false
	for _, name in ipairs(weatherNames) do
		if name == "rain" then hasRain = true end
		if name == "storm" then hasStorm = true end
		if name == "snow" then hasSnow = true end
	end
	-- Rain (also enabled during storm)
	if hasRain or hasStorm then
		startRain()
	else
		stopEffect("rain")
	end
	-- Snow
	if hasSnow then
		startSnow()
	else
		stopEffect("snow")
	end
	-- Lightning (only during storm)
	if hasStorm then
		startLightning()
	else
		stopLightning()
	end
end

-- Handle weather updates from the server (receives an array of active weather names)
weatherUpdateEvent.OnClientEvent:Connect(function(weatherNames)
	-- Backward compat: if a single string is received, wrap it in a table
	if typeof(weatherNames) == "string" then
		weatherNames = {weatherNames}
	end

	-- Build a set of new weather names for quick lookup
	local newSet = {}
	for _, name in ipairs(weatherNames) do
		newSet[name] = true
	end

	-- Remove icons for weathers that are no longer active (animate out, then destroy)
	-- Skip "bonerain" since it is managed by the separate BoneRainEvent
	for name, frame in pairs(weatherIconFrames) do
		if name ~= "bonerain" and not newSet[name] then
			weatherIconFrames[name] = nil
			local tween = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
			})
			tween:Play()
			tween.Completed:Connect(function()
				frame:Destroy()
			end)
		end
	end

	-- Add icons for newly active weathers
	for _, name in ipairs(weatherNames) do
		if WEATHER_ICONS[name] and not weatherIconFrames[name] then
			weatherIconFrames[name] = createWeatherIcon(name)
		end
	end

	-- Update particle effects (rain, snow, lightning)
	updateWeatherEffects(weatherNames)
end)

-- Feedback label for admin command responses (created early so the event handler can use it)
local feedbackLabel = Instance.new("TextLabel")
feedbackLabel.Name = "FeedbackLabel"
feedbackLabel.Size = UDim2.new(0, 400, 0, 24)
feedbackLabel.Position = UDim2.new(0.5, -200, 1, -82)
feedbackLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
feedbackLabel.BackgroundTransparency = 0.2
feedbackLabel.Text = ""
feedbackLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
feedbackLabel.Font = Enum.Font.Code
feedbackLabel.TextSize = 13
feedbackLabel.TextWrapped = true
feedbackLabel.TextYAlignment = Enum.TextYAlignment.Top
feedbackLabel.Visible = false

local feedbackPadding = Instance.new("UIPadding")
feedbackPadding.PaddingLeft = UDim.new(0, 6)
feedbackPadding.PaddingRight = UDim.new(0, 6)
feedbackPadding.PaddingTop = UDim.new(0, 4)
feedbackPadding.PaddingBottom = UDim.new(0, 4)
feedbackPadding.Parent = feedbackLabel

local feedbackCorner = Instance.new("UICorner")
feedbackCorner.CornerRadius = UDim.new(0, 4)
feedbackCorner.Parent = feedbackLabel

-- Handle all feedback from the server (global messages + admin command feedback)
adminFeedbackEvent.OnClientEvent:Connect(function(message)
	-- Check if this is a global message from an admin
	if string.sub(message, 1, 8) == "[Global]" then
		globalMessageLabel.Text = message
		globalMessageLabel.Visible = true

		-- Animate sliding down from the top
		globalMessageLabel.Position = UDim2.new(0, 0, 0, -50)
		TweenService:Create(globalMessageLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 10),
		}):Play()

		-- Slide back up after 8 seconds
		task.delay(8, function()
			local slideUp = TweenService:Create(globalMessageLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0, 0, 0, -50),
			})
			slideUp:Play()
			slideUp.Completed:Connect(function()
				globalMessageLabel.Visible = false
			end)
		end)
		return
	end

	-- ===== ADMIN FEEDBACK (only for admins) =====
	if not ADMINS[string.lower(player.Name)] then
		return
	end

	feedbackLabel.Text = message

	-- Check if this is the multi-line admin help list
	local isHelpList = string.find(message, "ADMIN COMMAND LIST") ~= nil

	if isHelpList then
		feedbackLabel.Size = UDim2.new(0, 400, 0, 150)
		feedbackLabel.Position = UDim2.new(0.5, -200, 1, -208)
		feedbackLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		task.delay(15, function()
			feedbackLabel.Visible = false
		end)
	else
		feedbackLabel.Size = UDim2.new(0, 400, 0, 24)
		feedbackLabel.Position = UDim2.new(0.5, -200, 1, -82)
		feedbackLabel.TextColor3 = string.find(message, "not found") and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100)
		task.delay(3, function()
			feedbackLabel.Visible = false
		end)
	end

	feedbackLabel.Visible = true
end)

-- ===== ADMIN COMMAND BAR (only for admins) =====
local adminBarSetup = false

local function setupAdminBar()
	if adminBarSetup then return end
	adminBarSetup = true

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AdminCommandBar"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Parent the feedback label into the admin command bar GUI
	feedbackLabel.Parent = screenGui

	-- Main container frame
	local frame = Instance.new("Frame")
	frame.Name = "CommandBarFrame"
	frame.Size = UDim2.new(0, 400, 0, 36)
	frame.Position = UDim2.new(0.5, -200, 1, -50)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	-- Padding
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = frame

	-- Prefix label
	local prefixLabel = Instance.new("TextLabel")
	prefixLabel.Name = "PrefixLabel"
	prefixLabel.Size = UDim2.new(0, 16, 1, 0)
	prefixLabel.BackgroundTransparency = 1
	prefixLabel.Text = ":"
	prefixLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	prefixLabel.Font = Enum.Font.Code
	prefixLabel.TextSize = 16
	prefixLabel.Parent = frame

	-- Text box for entering commands
	local textBox = Instance.new("TextBox")
	textBox.Name = "CommandInput"
	textBox.Size = UDim2.new(1, -22, 1, 0)
	textBox.Position = UDim2.new(0, 18, 0, 0)
	textBox.BackgroundTransparency = 1
	textBox.Text = ""
	textBox.PlaceholderText = "Type a command... (e.g. kick playername)"
	textBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
	textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	textBox.Font = Enum.Font.Code
	textBox.TextSize = 15
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.ClearTextOnFocus = false
	textBox.Parent = frame

	-- Handle submitting a command
	textBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			local text = textBox.Text
			if text ~= "" then
				-- Prepend the prefix if the user didn't type it
				if string.sub(text, 1, 1) ~= ":" then
					text = ":" .. text
				end
				adminCommandEvent:FireServer(text)
			end
			textBox.Text = ""
		end
	end)

	-- Toggle command bar visibility with the ";" key
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Semicolon then
			frame.Visible = not frame.Visible
			if frame.Visible then
				textBox:CaptureFocus()
			end
		end
	end)

	-- Start with the bar visible and focused for admins
	frame.Visible = true
	textBox:CaptureFocus()
end

-- Set up admin bar immediately for existing admins
if ADMINS[string.lower(player.Name)] then
	setupAdminBar()
end

-- Listen for runtime promotion from the server
adminFeedbackEvent.OnClientEvent:Connect(function(message)
	if message == "__PROMOTED__" then
		ADMINS[string.lower(player.Name)] = true
		setupAdminBar()
	end
end)

-- ===== COMMAND LIST GUI (interactive, clickable, auto-updating, with option sub-panels) =====

-- Weather options (must match the server's WEATHER_PRESETS)
local WEATHER_OPTIONS = { "clear", "sunny", "rain", "storm", "snow", "cloudy", "fog", "night", "coinrain", "bonerain" }

-- Time presets
local TIME_PRESETS = { { label = "Morning (6)", value = 6 }, { label = "Noon (12)", value = 12 }, { label = "Evening (18)", value = 18 }, { label = "Midnight (0)", value = 0 }, { label = "Dawn (5)", value = 5 } }

local commandListGui
local commandListFrame
local commandListScroll
local optionsFrame
local optionsScroll
local optionsTitleLabel
local lastCommandInfoList

-- Helper: send a full command string to the server via the admin command bar event
local function sendCommand(cmdString)
	if string.sub(cmdString, 1, 1) ~= ":" then
		cmdString = ":" .. cmdString
	end
	adminCommandEvent:FireServer(cmdString)
end

-- Helper: create a styled clickable button for the options sub-panel
local function createOptionButton(text, parent, onClick)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -4, 0, 44)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(100, 255, 150)
	label.Font = Enum.Font.Code
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = btn

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
		local stroke = Instance.new("UIStroke")
		stroke.Name = "HoverStroke"
		stroke.Color = Color3.fromRGB(100, 200, 255)
		stroke.Thickness = 1.5
		stroke.Parent = btn
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		local s = btn:FindFirstChild("HoverStroke")
		if s then s:Destroy() end
	end)
	btn.MouseButton1Click:Connect(onClick)
	return btn
end

-- Show the options sub-panel for a given command
local function showOptions(info)
	if not optionsFrame then return end

	-- Hide the command list, show the options panel
	commandListScroll.Visible = false
	optionsFrame.Visible = true

	optionsTitleLabel.Text = "  :" .. info.name

	-- Clear old option buttons
	for _, child in ipairs(optionsScroll:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("Frame") or child:IsA("TextBox") then
			child:Destroy()
		end
	end

	local optType = info.optionsType or "none"

	if optType == "none" then
		-- No options: send the command directly
		sendCommand(info.name)
		commandListGui.Enabled = false

	elseif optType == "weather" then
		for _, w in ipairs(WEATHER_OPTIONS) do
			createOptionButton(w, optionsScroll, function()
				sendCommand("weather " .. w)
				commandListGui.Enabled = false
			end)
		end

	elseif optType == "player" then
		for _, p in ipairs(Players:GetPlayers()) do
			createOptionButton(p.Name, optionsScroll, function()
				sendCommand(info.name .. " " .. p.Name)
				commandListGui.Enabled = false
			end)
		end

	elseif optType == "player_amount" then
		-- First show player buttons + "all"
		createOptionButton("all", optionsScroll, function()
			-- Now show amount input
			for _, c in ipairs(optionsScroll:GetChildren()) do
				if c:IsA("TextButton") then c:Destroy() end
			end
			optionsTitleLabel.Text = "  :" .. info.name .. " all — Enter amount"
			local amountInput = Instance.new("TextBox")
			amountInput.Size = UDim2.new(1, -4, 0, 44)
			amountInput.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
			amountInput.BorderSizePixel = 0
			amountInput.Text = ""
			amountInput.PlaceholderText = "Type amount..."
			amountInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
			amountInput.TextColor3 = Color3.fromRGB(100, 255, 150)
			amountInput.Font = Enum.Font.Code
			amountInput.TextSize = 16
			amountInput.TextXAlignment = Enum.TextXAlignment.Left
			amountInput.ClearTextOnFocus = false
			amountInput.Parent = optionsScroll
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = amountInput
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 12)
			pad.PaddingRight = UDim.new(0, 12)
			pad.Parent = amountInput
			amountInput:CaptureFocus()
			local confirmBtn = createOptionButton("Confirm", optionsScroll, function()
				local amt = tonumber(amountInput.Text)
				if amt and amt > 0 then
					sendCommand(info.name .. " all " .. amt)
					commandListGui.Enabled = false
				end
			end)
			amountInput.FocusLost:Connect(function(enter)
				if enter then
					local amt = tonumber(amountInput.Text)
					if amt and amt > 0 then
						sendCommand(info.name .. " all " .. amt)
						commandListGui.Enabled = false
					end
				end
			end)
		end)
		for _, p in ipairs(Players:GetPlayers()) do
			createOptionButton(p.Name, optionsScroll, function()
				for _, c in ipairs(optionsScroll:GetChildren()) do
					if c:IsA("TextButton") then c:Destroy() end
				end
				optionsTitleLabel.Text = "  :" .. info.name .. " " .. p.Name .. " — Enter amount"
				local amountInput = Instance.new("TextBox")
				amountInput.Size = UDim2.new(1, -4, 0, 44)
				amountInput.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
				amountInput.BorderSizePixel = 0
				amountInput.Text = ""
				amountInput.PlaceholderText = "Type amount..."
				amountInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
				amountInput.TextColor3 = Color3.fromRGB(100, 255, 150)
				amountInput.Font = Enum.Font.Code
				amountInput.TextSize = 16
				amountInput.TextXAlignment = Enum.TextXAlignment.Left
				amountInput.ClearTextOnFocus = false
				amountInput.Parent = optionsScroll
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 8)
				corner.Parent = amountInput
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 12)
				pad.PaddingRight = UDim.new(0, 12)
				pad.Parent = amountInput
				amountInput:CaptureFocus()
				local confirmBtn = createOptionButton("Confirm", optionsScroll, function()
					local amt = tonumber(amountInput.Text)
					if amt and amt > 0 then
						sendCommand(info.name .. " " .. p.Name .. " " .. amt)
						commandListGui.Enabled = false
					end
				end)
				amountInput.FocusLost:Connect(function(enter)
					if enter then
						local amt = tonumber(amountInput.Text)
						if amt and amt > 0 then
							sendCommand(info.name .. " " .. p.Name .. " " .. amt)
							commandListGui.Enabled = false
						end
					end
				end)
			end)
		end

	elseif optType == "time" then
		-- Show preset buttons
		for _, preset in ipairs(TIME_PRESETS) do
			createOptionButton(preset.label, optionsScroll, function()
				sendCommand("time " .. preset.value)
				commandListGui.Enabled = false
			end)
		end
		-- Add a custom text input
		local customInput = Instance.new("TextBox")
		customInput.Size = UDim2.new(1, -4, 0, 44)
		customInput.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		customInput.BorderSizePixel = 0
		customInput.Text = ""
		customInput.PlaceholderText = "Custom time (0-24)..."
		customInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
		customInput.TextColor3 = Color3.fromRGB(100, 255, 150)
		customInput.Font = Enum.Font.Code
		customInput.TextSize = 16
		customInput.TextXAlignment = Enum.TextXAlignment.Left
		customInput.ClearTextOnFocus = false
		customInput.Parent = optionsScroll
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = customInput
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = customInput
		customInput.FocusLost:Connect(function(enter)
			if enter then
				local num = tonumber(customInput.Text)
				if num and num >= 0 and num <= 24 then
					sendCommand("time " .. num)
					commandListGui.Enabled = false
				end
			end
		end)

	elseif optType == "text" then
		-- Text input for commands like :global message <text>
		local textInput = Instance.new("TextBox")
		textInput.Size = UDim2.new(1, -4, 0, 44)
		textInput.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		textInput.BorderSizePixel = 0
		textInput.Text = ""
		textInput.PlaceholderText = "Type your message..."
		textInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
		textInput.TextColor3 = Color3.fromRGB(100, 255, 150)
		textInput.Font = Enum.Font.Code
		textInput.TextSize = 16
		textInput.TextXAlignment = Enum.TextXAlignment.Left
		textInput.ClearTextOnFocus = false
		textInput.Parent = optionsScroll
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = textInput
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = textInput
		textInput:CaptureFocus()
		local confirmBtn = createOptionButton("Send Message", optionsScroll, function()
			if textInput.Text ~= "" then
				sendCommand("global " .. textInput.Text)
				commandListGui.Enabled = false
			end
		end)
		textInput.FocusLost:Connect(function(enter)
			if enter and textInput.Text ~= "" then
				sendCommand("global " .. textInput.Text)
				commandListGui.Enabled = false
			end
		end)
	end
end

local function buildCommandList(commandInfoList)
	if not commandInfoList then return end
	lastCommandInfoList = commandInfoList

	-- Create the GUI if it doesn't exist yet
	if not commandListGui then
		commandListGui = Instance.new("ScreenGui")
		commandListGui.Name = "CommandListGui"
		commandListGui.ResetOnSpawn = false
		commandListGui.IgnoreGuiInset = true
		commandListGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		commandListGui.Parent = playerGui

		-- Dark backdrop that dims the rest of the screen for visibility
		local backdrop = Instance.new("Frame")
		backdrop.Name = "Backdrop"
		backdrop.Size = UDim2.new(1, 0, 1, 0)
		backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		backdrop.BackgroundTransparency = 0.4
		backdrop.BorderSizePixel = 0
		backdrop.Parent = commandListGui

		-- Click the backdrop to close
		backdrop.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				commandListGui.Enabled = false
			end
		end)

		-- Main panel — large, centered, high contrast
		commandListFrame = Instance.new("Frame")
		commandListFrame.Name = "CommandListPanel"
		commandListFrame.Size = UDim2.new(0, 520, 0, 420)
		commandListFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
		commandListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		commandListFrame.BorderSizePixel = 0
		commandListFrame.Parent = commandListGui

		local panelCorner = Instance.new("UICorner")
		panelCorner.CornerRadius = UDim.new(0, 12)
		panelCorner.Parent = commandListFrame

		local panelStroke = Instance.new("UIStroke")
		panelStroke.Color = Color3.fromRGB(80, 160, 255)
		panelStroke.Thickness = 2
		panelStroke.Transparency = 0.2
		panelStroke.Parent = commandListFrame

		-- Title bar
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "TitleLabel"
		titleLabel.Size = UDim2.new(1, 0, 0, 48)
		titleLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
		titleLabel.BorderSizePixel = 0
		titleLabel.Text = "  COMMAND LIST"
		titleLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextSize = 22
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Parent = commandListFrame

		local titleCorner = Instance.new("UICorner")
		titleCorner.CornerRadius = UDim.new(0, 12)
		titleCorner.Parent = titleLabel

		-- Close button (top-right)
		local closeButton = Instance.new("TextButton")
		closeButton.Name = "CloseButton"
		closeButton.Size = UDim2.new(0, 36, 0, 36)
		closeButton.Position = UDim2.new(1, -42, 0, 6)
		closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		closeButton.Text = "X"
		closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		closeButton.Font = Enum.Font.GothamBold
		closeButton.TextSize = 18
		closeButton.Parent = commandListFrame

		local closeCorner = Instance.new("UICorner")
		closeCorner.CornerRadius = UDim.new(0, 8)
		closeCorner.Parent = closeButton

		closeButton.MouseButton1Click:Connect(function()
			commandListGui.Enabled = false
		end)

		-- Scrolling frame for command entries
		commandListScroll = Instance.new("ScrollingFrame")
		commandListScroll.Name = "CommandScroll"
		commandListScroll.Size = UDim2.new(1, -16, 1, -60)
		commandListScroll.Position = UDim2.new(0, 8, 0, 52)
		commandListScroll.BackgroundTransparency = 1
		commandListScroll.ScrollBarThickness = 6
		commandListScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 160, 255)
		commandListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		commandListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		commandListScroll.Parent = commandListFrame

		local commandListLayout = Instance.new("UIListLayout")
		commandListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		commandListLayout.Padding = UDim.new(0, 6)
		commandListLayout.Parent = commandListScroll

		-- ===== Options sub-panel (shown when a command is clicked) =====
		optionsFrame = Instance.new("Frame")
		optionsFrame.Name = "OptionsPanel"
		optionsFrame.Size = UDim2.new(1, -16, 1, -60)
		optionsFrame.Position = UDim2.new(0, 8, 0, 52)
		optionsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		optionsFrame.BorderSizePixel = 0
		optionsFrame.Visible = false
		optionsFrame.Parent = commandListFrame

		local optionsCorner = Instance.new("UICorner")
		optionsCorner.CornerRadius = UDim.new(0, 8)
		optionsCorner.Parent = optionsFrame

		-- Options title bar
		optionsTitleLabel = Instance.new("TextLabel")
		optionsTitleLabel.Name = "OptionsTitle"
		optionsTitleLabel.Size = UDim2.new(1, -100, 0, 40)
		optionsTitleLabel.Position = UDim2.new(0, 8, 0, 4)
		optionsTitleLabel.BackgroundTransparency = 1
		optionsTitleLabel.Text = "  Options"
		optionsTitleLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		optionsTitleLabel.Font = Enum.Font.GothamBold
		optionsTitleLabel.TextSize = 18
		optionsTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		optionsTitleLabel.Parent = optionsFrame

		-- Back button (returns to command list)
		local backButton = Instance.new("TextButton")
		backButton.Name = "BackButton"
		backButton.Size = UDim2.new(0, 80, 0, 32)
		backButton.Position = UDim2.new(1, -90, 0, 8)
		backButton.BackgroundColor3 = Color3.fromRGB(60, 100, 160)
		backButton.Text = "< Back"
		backButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		backButton.Font = Enum.Font.GothamBold
		backButton.TextSize = 14
		backButton.Parent = optionsFrame

		local backCorner = Instance.new("UICorner")
		backCorner.CornerRadius = UDim.new(0, 6)
		backCorner.Parent = backButton

		backButton.MouseButton1Click:Connect(function()
			optionsFrame.Visible = false
			commandListScroll.Visible = true
		end)

		-- Options scrolling frame
		optionsScroll = Instance.new("ScrollingFrame")
		optionsScroll.Name = "OptionsScroll"
		optionsScroll.Size = UDim2.new(1, -16, 1, -56)
		optionsScroll.Position = UDim2.new(0, 8, 0, 48)
		optionsScroll.BackgroundTransparency = 1
		optionsScroll.ScrollBarThickness = 6
		optionsScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 160, 255)
		optionsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		optionsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		optionsScroll.Parent = optionsFrame

		local optionsLayout = Instance.new("UIListLayout")
		optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		optionsLayout.Padding = UDim.new(0, 6)
		optionsLayout.Parent = optionsScroll
	end

	-- Reset to command list view (hide options if shown)
	if optionsFrame then
		optionsFrame.Visible = false
	end
	commandListScroll.Visible = true

	-- Clear old entries
	for _, child in ipairs(commandListScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Build a clickable entry for each command
	for i, info in ipairs(commandInfoList) do
		local entry = Instance.new("Frame")
		entry.Name = "Command_" .. info.name
		entry.Size = UDim2.new(1, -4, 0, 64)
		entry.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		entry.BorderSizePixel = 0
		entry.Parent = commandListScroll

		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, 8)
		entryCorner.Parent = entry

		-- Usage line (the actual command you type)
		local usageLabel = Instance.new("TextLabel")
		usageLabel.Name = "UsageLabel"
		usageLabel.Size = UDim2.new(1, -16, 0, 28)
		usageLabel.Position = UDim2.new(0, 8, 0, 4)
		usageLabel.BackgroundTransparency = 1
		usageLabel.Text = info.usage or info.name
		usageLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
		usageLabel.Font = Enum.Font.Code
		usageLabel.TextSize = 18
		usageLabel.TextXAlignment = Enum.TextXAlignment.Left
		usageLabel.Parent = entry

		-- Description line
		local descLabel = Instance.new("TextLabel")
		descLabel.Name = "DescLabel"
		descLabel.Size = UDim2.new(1, -16, 0, 28)
		descLabel.Position = UDim2.new(0, 8, 0, 32)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = info.desc or ""
		descLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 14
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextWrapped = true
		descLabel.Parent = entry

		-- Make the whole entry clickable
		local clickButton = Instance.new("TextButton")
		clickButton.Name = "ClickOverlay"
		clickButton.Size = UDim2.new(1, 0, 1, 0)
		clickButton.BackgroundTransparency = 1
		clickButton.Text = ""
		clickButton.Parent = entry

		-- Hover highlight
		clickButton.MouseEnter:Connect(function()
			entry.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
			local stroke = Instance.new("UIStroke")
			stroke.Name = "HoverStroke"
			stroke.Color = Color3.fromRGB(100, 200, 255)
			stroke.Thickness = 1.5
			stroke.Parent = entry
		end)
		clickButton.MouseLeave:Connect(function()
			entry.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
			local stroke = entry:FindFirstChild("HoverStroke")
			if stroke then stroke:Destroy() end
		end)

		-- Click: show options sub-panel for this command
		clickButton.MouseButton1Click:Connect(function()
			showOptions(info)
		end)
	end

	-- Show the GUI
	commandListGui.Enabled = true
end

-- Receive the command list from the server (fires when admin types :cmd)
commandListEvent.OnClientEvent:Connect(function(commandInfoList)
	buildCommandList(commandInfoList)
end)