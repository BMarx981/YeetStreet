--!strict
-- EventHud (LocalScript) -> StarterPlayerScripts.EventHud
-- Shows the timed events (EventService) on the HUD: a line left of the fuel
-- bar counting down to the next event ("MEGA BOOSTERS in 4:12"), or the time
-- left in the one on now, and a banner with a sound when one starts. Reads
-- the workspace attributes EventService sets. Steps aside while a replay
-- plays, like the rest of the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local TimedEvents = require(ReplicatedStorage.TimedEvents)
local Tuning = require(ReplicatedStorage.Tuning)
local ReplayPlayer = require(script.Parent.ReplayPlayer)
local UiStyle = require(script.Parent.UiStyle)

local TE = Tuning.TimedEvents
local UPDATE_EVERY = 0.2 -- seconds between countdown redraws

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Events"
gui.ResetOnSpawn = false

-- Mirrors the cash line on the other side of the fuel bar (Hud).
local line = UiStyle.text("Countdown", gui, 20, true)
line.AnchorPoint = Vector2.new(1, 0)
line.Position = UDim2.new(0.5, -146, 0, 8)
line.Size = UDim2.fromOffset(300, 26)
line.TextXAlignment = Enum.TextXAlignment.Right

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.3)
banner.Size = UDim2.new(0.8, 0, 0, 96)
banner.BackgroundColor3 = UiStyle.Ink
banner.BackgroundTransparency = 0.1
banner.BorderSizePixel = 0
banner.Visible = false
banner.Parent = gui
UiStyle.corner(banner, 10)
UiStyle.stroke(banner, 3, UiStyle.Yellow, true)
local widest = Instance.new("UISizeConstraint")
widest.MaxSize = Vector2.new(620, math.huge)
widest.Parent = banner
local band = UiStyle.hazard(banner)
band.Position = UDim2.new(0, 0, 1, -12)

local title = UiStyle.text("Title", banner, 44, true)
title.TextColor3 = UiStyle.Yellow
title.TextXAlignment = Enum.TextXAlignment.Center
title.Position = UDim2.fromOffset(0, 6)
title.Size = UDim2.new(1, 0, 0, 48)
title.TextScaled = true
local titleMax = Instance.new("UITextSizeConstraint")
titleMax.MaxTextSize = 44
titleMax.Parent = title

local blurb = UiStyle.text("Blurb", banner, 20, false)
blurb.TextXAlignment = Enum.TextXAlignment.Center
blurb.Position = UDim2.fromOffset(0, 54)
blurb.Size = UDim2.new(1, 0, 0, 24)

local fanfare = Instance.new("Sound")
fanfare.Name = "EventStart"
fanfare.SoundId = TE.StartSound.Id
fanfare.PlaybackSpeed = TE.StartSound.Pitch
fanfare.Volume = TE.StartSound.Volume
fanfare.Parent = SoundService

gui.Parent = player:WaitForChild("PlayerGui")

local shownEvent: string? = workspace:GetAttribute("Event") :: string?
local bannerUntil = 0

local function titleOf(name: any): string
	return if typeof(name) == "string" then TE.Titles[name] or name else ""
end

local function showBanner(name: string)
	title.Text = `{titleOf(name)}!`
	blurb.Text = TE.Blurbs[name] or ""
	banner.Visible = true
	bannerUntil = os.clock() + TE.BannerTime
	UiStyle.bounce(banner)
	fanfare:Play()
end

-- A player who joins mid-event gets the banner too.
if shownEvent then
	task.defer(showBanner, shownEvent)
end

workspace:GetAttributeChangedSignal("Event"):Connect(function()
	local name = workspace:GetAttribute("Event")
	local event: string? = if typeof(name) == "string" then name else nil
	if event and event ~= shownEvent then
		showBanner(event)
	end
	shownEvent = event
end)

local function redraw()
	gui.Enabled = not ReplayPlayer.isPlaying()
	if banner.Visible and os.clock() > bannerUntil then
		banner.Visible = false
	end
	local now = workspace:GetServerTimeNow()
	local event = workspace:GetAttribute("Event")
	local endsAt = workspace:GetAttribute("EventEndsAt")
	if typeof(event) == "string" and typeof(endsAt) == "number" then
		line.Text = `{titleOf(event)} {TimedEvents.clock(endsAt - now)} left`
		line.TextColor3 = UiStyle.Yellow
		return
	end
	local nextEvent = workspace:GetAttribute("NextEvent")
	local nextAt = workspace:GetAttribute("NextEventAt")
	if typeof(nextEvent) == "string" and typeof(nextAt) == "number" then
		line.Text = `{titleOf(nextEvent)} in {TimedEvents.clock(nextAt - now)}`
		line.TextColor3 = Color3.new(1, 1, 1)
	else
		line.Text = ""
	end
end

local since = 0
RunService.Heartbeat:Connect(function(dt: number)
	since += dt
	if since >= UPDATE_EVERY then
		since = 0
		redraw()
	end
end)
