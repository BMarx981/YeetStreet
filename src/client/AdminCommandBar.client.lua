local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local adminCommandEvent = ReplicatedStorage:WaitForChild("AdminCommandEvent")
local adminFeedbackEvent = ReplicatedStorage:WaitForChild("AdminFeedbackEvent")
local weatherUpdateEvent = ReplicatedStorage:WaitForChild("WeatherUpdateEvent")

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
	coinrain = { icon = "🪙", label = "Coin Rain", color = Color3.fromRGB(255, 200, 0) },
}

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
	for name, frame in pairs(weatherIconFrames) do
		if not newSet[name] then
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
	if not ADMINS[player.Name] then
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
if ADMINS[player.Name] then
	setupAdminBar()
end

-- Listen for runtime promotion from the server
adminFeedbackEvent.OnClientEvent:Connect(function(message)
	if message == "__PROMOTED__" then
		ADMINS[player.Name] = true
		setupAdminBar()
	end
end)