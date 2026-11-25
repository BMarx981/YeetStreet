--!strict
-- TimerChip (ModuleScript) -> StarterPlayerScripts.TimerChip
-- Small timer chips stacked down the left of the screen, each an icon and the
-- time ("🚀 4:12"). The full line ("MEGA BOOSTERS in 4:12") shows while the
-- mouse is over a chip, or for Tuning.Hud.TimerTapShow seconds after a tap,
-- since phones have no hover. EventHud and GoldenLook each own one, and Hud
-- one for the clean streak above them. Hidden while a replay plays, like the
-- rest of the HUD.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)
local ReplayPlayer = require(script.Parent.ReplayPlayer)
local UiStyle = require(script.Parent.UiStyle)

local TimerChip = {}

export type Chip = {
	-- `short` and `full` without the icon, which goes in front of both. An
	-- empty icon leaves just the text.
	set: (icon: string, short: string, full: string, color: Color3) -> (),
	setVisible: (on: boolean) -> (),
	bounce: () -> (),
}

local HEIGHT = 30

local stack: Frame? = nil

-- The column the chips sit in: left edge, a third of the way down, under
-- the chat and above the phone's touch buttons.
local function column(): Frame
	if stack then
		return stack
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Timers"
	gui.ResetOnSpawn = false
	local frame = Instance.new("Frame")
	frame.Name = "Stack"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.new(0, 12, 0.3, 0)
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Parent = gui
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = frame
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	RunService.Heartbeat:Connect(function()
		gui.Enabled = not ReplayPlayer.isPlaying()
	end)
	stack = frame
	return frame
end

-- A hidden chip; `order` places it in the column, lowest at the top.
function TimerChip.new(name: string, order: number): Chip
	local chip = Instance.new("TextButton")
	chip.Name = name
	chip.LayoutOrder = order
	chip.Text = ""
	chip.AutoButtonColor = false
	chip.BackgroundColor3 = UiStyle.Ink
	chip.BackgroundTransparency = 0.25
	chip.Size = UDim2.fromOffset(0, HEIGHT)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Visible = false
	UiStyle.corner(chip, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = chip
	local text = UiStyle.text("Text", chip, 20, true)
	text.Size = UDim2.fromOffset(0, HEIGHT)
	text.AutomaticSize = Enum.AutomaticSize.X
	chip.Parent = column()

	local shortText, fullText = "", ""
	local hovered = false
	local tappedUntil = 0
	local function draw()
		text.Text = if hovered or os.clock() < tappedUntil then fullText else shortText
	end
	chip.MouseEnter:Connect(function()
		hovered = true
		draw()
	end)
	chip.MouseLeave:Connect(function()
		hovered = false
		draw()
	end)
	chip.Activated:Connect(function()
		tappedUntil = os.clock() + Tuning.Hud.TimerTapShow
		draw()
		task.delay(Tuning.Hud.TimerTapShow, draw)
	end)

	return {
		set = function(icon: string, short: string, full: string, color: Color3)
			local front = if icon == "" then "" else `{icon} `
			shortText = front .. short
			fullText = front .. full
			text.TextColor3 = color
			draw()
		end,
		setVisible = function(on: boolean)
			chip.Visible = on
		end,
		bounce = function()
			UiStyle.bounce(chip)
		end,
	}
end

return TimerChip
