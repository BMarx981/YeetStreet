--!strict
-- UpgradeHint (ModuleScript) -> StarterPlayerScripts.UpgradeHint
-- After a run that paid, tells a player who has never bought an upgrade, and
-- can now afford one, to buy it at the garage (UpgradeNudge). It waits for
-- the tutorial's last line to go, shows in the same spot for ShowTime
-- seconds, and goes early when the garage opens or a level is bought.
-- CarController calls runPaid with each official run's score, and setVisible
-- while a replay plays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Economy)
local Tuning = require(ReplicatedStorage.Tuning)
local UpgradeNudge = require(ReplicatedStorage.UpgradeNudge)
local GarageMenu = require(script.Parent.GarageMenu)
local TutorialHints = require(script.Parent.TutorialHints)
local UiStyle = require(script.Parent.UiStyle)

local T = Tuning.UpgradeNudge
local LEVELS = { "Speed", "Jets", "Toughness", "Grip", "Brakes" }

local player = Players.LocalPlayer

local UpgradeHint = {}

local shown = 0
local showing = 0 -- counts shows, so an old timer doesn't hide a newer one
local hidden = false -- while a replay plays
local live = false -- within its ShowTime
local waiting = false

local gui = Instance.new("ScreenGui")
gui.Name = "UpgradeHint"
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

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function hide()
	showing += 1
	live = false
	gui.Enabled = false
end

local function input(paid: number): UpgradeNudge.Input
	local levels = {}
	for _, name in LEVELS do
		table.insert(levels, number(name))
	end
	return {
		paid = paid,
		cash = number("Cash"),
		cheapest = Economy.upgradeCost(0, Tuning.Upgrades),
		levels = levels,
		rebirths = number("Rebirths"),
		shown = shown,
	}
end

local function show(paid: number)
	if not UpgradeNudge.due(input(paid), T) or GarageMenu.isOpen() then
		return
	end
	shown += 1
	showing += 1
	local mine = showing
	line.Text = UpgradeNudge.text(number("Cash"), T)
	live = true
	gui.Enabled = not hidden
	UiStyle.bounce(panel)
	task.delay(T.ShowTime, function()
		if showing == mine then
			hide()
		end
	end)
end

-- Call with the server's score for each run that ends.
function UpgradeHint.runPaid(score: number)
	if score <= 0 or waiting then
		return
	end
	waiting = true
	task.spawn(function()
		local waited = 0
		while TutorialHints.isRunning() and waited < T.TutorialWait do
			waited += task.wait(0.5)
		end
		waiting = false
		if not TutorialHints.isRunning() then
			show(score)
		end
	end)
end

-- Hides it while a replay plays, without dropping it.
function UpgradeHint.setVisible(visible: boolean)
	hidden = not visible
	gui.Enabled = live and not hidden
end

for _, name in LEVELS do
	player:GetAttributeChangedSignal(name):Connect(hide)
end
task.spawn(function()
	while true do
		task.wait(0.25)
		if live and GarageMenu.isOpen() then
			hide()
		end
	end
end)

return UpgradeHint
