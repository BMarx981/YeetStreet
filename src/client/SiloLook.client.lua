--!strict
-- SiloLook (LocalScript) -> StarterPlayerScripts.SiloLook
-- How the missile silo looks and sounds on this client. Buttons are each
-- player's own, so this client lights them from its player's SiloPressed
-- attribute: green once pressed, and the launch button red once all are. While
-- anyone is armed (the park folder's SiloArmed), the wall lines flash, the
-- lamps go red, and the klaxon sounds. The server keeps all the truth
-- (Parks.Silo).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Silo = require(ReplicatedStorage.Silo)
local Tuning = require(ReplicatedStorage.Tuning)
local UiStyle = require(script.Parent.UiStyle)

local S = Tuning.Silo
local A = S.Alarm
local SHAPE: Silo.Shape = S :: any

local BUTTON_COLOR = Color3.fromRGB(255, 200, 40)
local PRESSED_COLOR = Color3.fromRGB(70, 230, 90)
local LINE_OFF_COLOR = Color3.fromRGB(70, 20, 20)
local RED = Color3.fromRGB(255, 30, 20)
local LAMP_COLOR = Color3.fromRGB(255, 240, 210)

local area = MapLayout.find(Tuning.Map.Areas :: any, "Silo")
if not area then
	return
end

local player = Players.LocalPlayer
local buttons = Silo.buttons(SHAPE)

local function paint(part: BasePart, color: Color3, neon: boolean)
	part.Color = color
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = color
		light.Enabled = neon
	end
end

local pressed: { [string]: boolean } = {}

local function paintButton(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local id = part:GetAttribute("ButtonId")
	if id == "Launch" then
		local armed = Silo.armed(buttons, pressed)
		paint(part, if armed then RED else LINE_OFF_COLOR, armed)
	elseif typeof(id) == "string" then
		paint(part, if pressed[id] then PRESSED_COLOR else BUTTON_COLOR, true)
	end
end

local function pressedChanged()
	local text = player:GetAttribute("SiloPressed")
	local now = Silo.decodePressed(if typeof(text) == "string" then text else "")
	for id in now do
		if not pressed[id] then
			UiStyle.play("Buy")
			break
		end
	end
	pressed = now
	for _, part in CollectionService:GetTagged("SiloButton") do
		paintButton(part)
	end
end

player:GetAttributeChangedSignal("SiloPressed"):Connect(pressedChanged)
CollectionService:GetInstanceAddedSignal("SiloButton"):Connect(paintButton)
pressedChanged()

-- The klaxon, from an invisible part of this client's own in the shaft, so it
-- plays however much of the park has streamed in.
local speaker = Instance.new("Part")
speaker.Name = "SiloKlaxon"
speaker.Anchored = true
speaker.CanCollide = false
speaker.CanQuery = false
speaker.CanTouch = false
speaker.Transparency = 1
speaker.Size = Vector3.one
speaker.Position = Vector3.new(area.X, Tuning.Map.FloorTop + A.KlaxonHeight, area.Z)
speaker.Parent = workspace

local klaxon = Instance.new("Sound")
klaxon.SoundId = A.KlaxonId
klaxon.Looped = true
klaxon.Volume = A.KlaxonVolume
klaxon.RollOffMaxDistance = A.KlaxonReach
klaxon.Parent = speaker

local function paintLamps(armed: boolean)
	for _, lamp in CollectionService:GetTagged("SiloLamp") do
		if lamp:IsA("BasePart") then
			paint(lamp, if armed then RED else LAMP_COLOR, true)
		end
	end
end

local function paintLines(lit: boolean)
	for _, line in CollectionService:GetTagged("SiloAlarm") do
		if line:IsA("BasePart") then
			paint(line, if lit then RED else LINE_OFF_COLOR, lit)
		end
	end
end

local alarmOn = false
local lit = false
local function step()
	local parks = workspace:FindFirstChild("Parks")
	local folder = parks and parks:FindFirstChild("Silo")
	local count = folder and folder:GetAttribute("SiloArmed")
	local armed = typeof(count) == "number" and count > 0
	-- Anything newly streamed in is caught by repainting each flash.
	local flash = armed and math.floor(workspace:GetServerTimeNow() / A.Flash) % 2 == 0
	if armed ~= alarmOn then
		alarmOn = armed
		if armed then
			klaxon:Play()
		else
			klaxon:Stop()
		end
		paintLamps(armed)
	end
	if flash ~= lit then
		lit = flash
		paintLines(lit)
		if armed then
			paintLamps(true)
		end
	end
end

RunService.Heartbeat:Connect(step)
