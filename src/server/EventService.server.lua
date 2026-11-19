--!strict
-- EventService (Script) -> ServerScriptService.EventService
-- Runs the timed events (TimedEvents, Tuning.TimedEvents) from the clock, so
-- every server has the same one on at the same time. Bone Rain is started
-- and stopped through ServerScriptService.BoneRainToggle (DinoWeather).
-- Mega Boosters needs nothing here: clients and ScoreService read the Event
-- attribute.
--
-- Workspace attributes, for the HUD and ScoreService:
--   Event        the event on now, nil between events
--   EventEndsAt  when it ends, on workspace:GetServerTimeNow()'s clock
--   NextEvent    the next scheduled event
--   NextEventAt  when it starts, on the same clock
--
-- ServerStorage.ForceEvent (a BindableEvent, fired by the `:event` admin
-- command) with an event name puts that event on for one Duration, and with
-- nil stops the one on now until it would have ended.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TimedEvents = require(ReplicatedStorage.TimedEvents)
local Tuning = require(ReplicatedStorage.Tuning)

local T: TimedEvents.Tuning = Tuning.TimedEvents :: any
local CHECK_EVERY = 0.5 -- seconds
local DRIFT = 0.5 -- seconds a published time may drift before it is sent again

local boneRainToggle = ServerScriptService:WaitForChild("BoneRainToggle") :: BindableEvent

local override: TimedEvents.Override? = nil
local running: string? = nil

local function unixNow(): number
	return DateTime.now().UnixTimestampMillis / 1000
end

local function setRunning(name: string?)
	if name == running then
		return
	end
	if running == "BoneRain" then
		boneRainToggle:Fire(false)
	end
	running = name
	if name == "BoneRain" then
		boneRainToggle:Fire(true)
	end
	print(`EventService: {name or "no event"} now`)
end

-- Sets a time attribute only when it moved more than DRIFT, so clients
-- aren't sent a new number every check.
local function publishTime(name: string, value: number?)
	local old = workspace:GetAttribute(name)
	if value == nil or typeof(old) ~= "number" or math.abs(old - value) > DRIFT then
		workspace:SetAttribute(name, value)
	end
end

local function update()
	local now = TimedEvents.at(unixNow(), T, override)
	setRunning(now.current)
	local serverNow = workspace:GetServerTimeNow()
	workspace:SetAttribute("Event", now.current)
	publishTime("EventEndsAt", if now.current then serverNow + now.endsIn else nil)
	workspace:SetAttribute("NextEvent", now.next)
	publishTime("NextEventAt", serverNow + now.startsIn)
end

local forceEvent = Instance.new("BindableEvent")
forceEvent.Name = "ForceEvent"
forceEvent.Event:Connect(function(name: string?)
	local time = unixNow()
	if name then
		override = { name = name, untilTime = time + T.Duration }
	else
		local now = TimedEvents.at(time, T, override)
		override = { name = nil, untilTime = time + now.endsIn }
	end
	update()
end)
forceEvent.Parent = ServerStorage

while true do
	update()
	task.wait(CHECK_EVERY)
end
