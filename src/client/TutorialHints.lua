--!strict
-- TutorialHints (ModuleScript) -> StarterPlayerScripts.TutorialHints
-- Shows the tutorial (Tutorial): one prompt at a time in the middle of the
-- screen, naming the player's own controls, with a SKIP button, and a
-- bobbing arrow over the hub ramp while they should head for it, or over the
-- nearest garage while they should drive to one. The Upgrade line shows on
-- the garage panel's status line instead (GarageMenu.setHint), since the
-- panel covers the middle of the screen. It starts
-- by itself once the server says the player hasn't done it (the TutorialDone
-- attribute, TutorialService), and again from the CONTROLS panel (start).
-- CarController feeds it each frame (frame) and each run's end (runEnded).
-- On the player's first tutorial it tells the server (TutorialEvent) each
-- step reached, for the Tutorial funnel, and when it is finished or skipped,
-- so it never starts by itself again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Tutorial = require(ReplicatedStorage.Tutorial)
local Tuning = require(ReplicatedStorage.Tuning)
local GarageMenu = require(script.Parent.GarageMenu)
local UiStyle = require(script.Parent.UiStyle)

local T: Tutorial.Tuning = Tuning.Tutorial :: any
local ARROW = Tuning.Tutorial.Arrow
local BOB_HEIGHT = 4 -- studs the arrow bobs up and down
local BOB_SPEED = 3 -- radians per second
local LEVELS = { "Speed", "Jets", "Toughness", "Grip", "Brakes" }

local player = Players.LocalPlayer

local TutorialHints = {}

local state: Tutorial.State? = nil
local shown: string? = nil -- the text on screen, so it only changes when it must
local sentStep: string? = nil -- the last step told to the server
local hidden = false

local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Prompt"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.58)
panel.Size = UDim2.new(0.7, 0, 0, 60)
panel.BackgroundColor3 = UiStyle.Ink
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui
UiStyle.corner(panel, 10)
UiStyle.stroke(panel, 3, UiStyle.Yellow, true)
local widest = Instance.new("UISizeConstraint")
widest.MaxSize = Vector2.new(560, math.huge)
widest.Parent = panel

local line = UiStyle.text("Line", panel, 28, true)
line.Size = UDim2.new(1, -24, 1, -12)
line.Position = UDim2.fromOffset(12, 6)
line.TextXAlignment = Enum.TextXAlignment.Center
line.TextScaled = true
local biggest = Instance.new("UITextSizeConstraint")
biggest.MaxTextSize = 28
biggest.Parent = line

local skip = UiStyle.sticker("Skip", panel, "SKIP")
skip.AnchorPoint = Vector2.new(1, 0)
skip.Position = UDim2.new(1, 0, 1, 8)
skip.Size = UDim2.fromOffset(72, 30)
skip.TextSize = 16

local arrowPart = Instance.new("Part")
arrowPart.Name = "TutorialArrow"
arrowPart.Anchored = true
arrowPart.CanCollide = false
arrowPart.CanQuery = false
arrowPart.CanTouch = false
arrowPart.Transparency = 1
arrowPart.Size = Vector3.one
arrowPart.Position = Vector3.new(ARROW.X, ARROW.Height, ARROW.Z)

local board = Instance.new("BillboardGui")
board.Name = "Arrow"
board.AlwaysOnTop = true
board.Size = UDim2.fromOffset(120, 130)
board.Enabled = false
board.Parent = arrowPart

local rampLabel = UiStyle.text("Label", board, 30, true)
rampLabel.Text = "RAMP"
rampLabel.Size = UDim2.new(1, 0, 0, 40)
rampLabel.TextXAlignment = Enum.TextXAlignment.Center
rampLabel.TextColor3 = UiStyle.Yellow

local arrowLabel = UiStyle.text("Down", board, 80, true)
arrowLabel.Text = "▼"
arrowLabel.Position = UDim2.fromOffset(0, 36)
arrowLabel.Size = UDim2.new(1, 0, 0, 90)
arrowLabel.TextXAlignment = Enum.TextXAlignment.Center
arrowLabel.TextColor3 = UiStyle.Yellow

arrowPart.Parent = workspace

-- Tells the server, only on the player's first tutorial: replays log nothing.
local function tell(kind: string, name: string?)
	if player:GetAttribute("TutorialDone") ~= true then
		local remote = ReplicatedStorage:FindFirstChild("TutorialEvent")
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer(kind, name)
		end
	end
end

local function stop()
	state = nil
	shown = nil
	sentStep = nil
	gui.Enabled = false
	board.Enabled = false
	GarageMenu.setHint(nil)
end

-- Whether the player owns any upgrade level.
local function upgraded(): boolean
	for _, name in LEVELS do
		local level = player:GetAttribute(name)
		if typeof(level) == "number" and level > 0 then
			return true
		end
	end
	return false
end

local function finish()
	stop()
	tell("Done")
end

local function skipNow()
	local current = state
	local step = if current then current.step else nil
	stop()
	tell("Skip", step)
end

local function show()
	local current = state
	if not current then
		return
	end
	if current.done then
		finish()
		return
	end
	if current.step ~= sentStep then
		sentStep = current.step
		tell("Step", current.step)
	end
	local prompt = Tutorial.prompt(current)
	if not prompt then
		return
	end
	local device = Tutorial.device(UserInputService:GetLastInputType().Name)
	local text = Tutorial.text(prompt, device, T)
	local onPanel = prompt == "Upgrade"
	if text ~= shown then
		shown = text
		line.Text = text
		if not onPanel then
			UiStyle.bounce(panel)
		end
	end
	GarageMenu.setHint(if onPanel then text else nil)
	gui.Enabled = not hidden and not onPanel
	local arrow = Tutorial.arrow(current)
	local target: Vector3? = nil
	if arrow == "Ramp" then
		target = Vector3.new(ARROW.X, ARROW.Height, ARROW.Z)
	elseif arrow == "Garage" then
		local garage = GarageMenu.nearestGarage()
		target = if garage then garage + Vector3.new(0, ARROW.GarageLift, 0) else nil
	end
	board.Enabled = not hidden and target ~= nil
	if target then
		arrowPart.Position = target
		rampLabel.Text = if arrow == "Garage" then "GARAGE" else "RAMP"
		board.StudsOffsetWorldSpace = Vector3.new(0, math.sin(os.clock() * BOB_SPEED) * BOB_HEIGHT, 0)
	end
end

-- Starts the tutorial from its first step.
function TutorialHints.start()
	state = Tutorial.new()
	shown = nil
	show()
end

-- Feeds one frame of driving to the tutorial.
function TutorialHints.frame(frame: Tutorial.Frame)
	local current = state
	if current then
		frame.atGarage = GarageMenu.atGarage()
		frame.garageOpen = GarageMenu.isGarageOpen()
		frame.canAfford = GarageMenu.canAffordUpgrade()
		frame.upgraded = upgraded()
		Tutorial.step(current, frame, T)
		show()
	end
end

-- Call when a run ends.
function TutorialHints.runEnded()
	local current = state
	if current then
		Tutorial.runEnded(current, T)
		show()
	end
end

-- True while the tutorial is on screen.
function TutorialHints.isRunning(): boolean
	return state ~= nil
end

-- Hides the prompt and arrow while a replay plays, without stopping it.
function TutorialHints.setVisible(visible: boolean)
	hidden = not visible
	if state then
		show()
	end
end

skip.Activated:Connect(skipNow)

local function checkDone()
	if player:GetAttribute("TutorialDone") == false and not state then
		TutorialHints.start()
	end
end
player:GetAttributeChangedSignal("TutorialDone"):Connect(checkDone)
checkDone()

return TutorialHints
