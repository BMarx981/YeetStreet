--!strict
-- RebirthConfirm (ModuleScript) -> StarterPlayerScripts.RebirthConfirm
-- The screen that asks before a rebirth, over the garage panel. It lists what
-- the player loses and what they keep, with the cars from the same
-- Rebirth.split the server's reset uses. Only its REBIRTH button goes ahead;
-- CANCEL, its X, and the garage closing shut it.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Economy)
local Rebirth = require(ReplicatedStorage.Rebirth)
local Tuning = require(ReplicatedStorage.Tuning)
local UiStyle = require(script.Parent.UiStyle)

local RebirthConfirm = {}

-- What the player has now, from the attributes Garage sets.
export type Summary = {
	cash: number,
	cars: { string }, -- owned car ids
	rebirths: number, -- so far
	limiteds: number, -- how many limited items they own
	boneCoins: number,
}

export type Confirm = {
	ask: (summary: Summary, onYes: () -> ()) -> (),
	close: () -> (),
}

local LOSE_COLOR = Color3.fromRGB(255, 120, 110)

local function withCommas(n: number): string
	local digits = tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (digits:gsub("^,", ""))
end

local function carName(id: string): string
	local car = Economy.findCar(Tuning.Ladder, id)
	return if car then car.Name else id
end

local function bullets(lines: { string }): string
	return `• {table.concat(lines, "\n• ")}`
end

-- One of the two lists: a heading and a scrolling block of lines.
local function column(panel: Frame, name: string, heading: string, color: Color3, x: number, top: number): TextLabel
	local box = Instance.new("Frame")
	box.Name = name
	box.Position = UDim2.new(x, if x > 0 then 6 else 0, 0, top)
	box.Size = UDim2.new(0.5, -6, 1, -(top + 62))
	box.BackgroundColor3 = UiStyle.Ink
	box.Parent = panel
	UiStyle.corner(box, 8)
	local title = UiStyle.text("Heading", box, 24, true)
	title.Text = heading
	title.TextColor3 = color
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 28)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Lines"
	scroll.Position = UDim2.fromOffset(12, 38)
	scroll.Size = UDim2.new(1, -18, 1, -46)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = UiStyle.Yellow
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = box
	local lines = UiStyle.text("Text", scroll, 16, false)
	lines.Size = UDim2.new(1, -8, 0, 0)
	lines.AutomaticSize = Enum.AutomaticSize.Y
	lines.TextWrapped = true
	lines.TextYAlignment = Enum.TextYAlignment.Top
	lines.LineHeight = 1.15
	return lines
end

function RebirthConfirm.new(parent: Instance): Confirm
	local gui = Instance.new("ScreenGui")
	gui.Name = "RebirthConfirm"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6 -- above the garage panel
	gui.Parent = parent

	local panel, closeButton = UiStyle.panel(gui, "REBIRTH?", Vector2.new(560, 440))
	local top = UiStyle.HeaderHeight

	local gain = UiStyle.text("Gain", panel, 22, true)
	gain.Position = UDim2.fromOffset(0, top)
	gain.Size = UDim2.new(1, 0, 0, 28)
	gain.TextXAlignment = Enum.TextXAlignment.Center
	gain.TextColor3 = UiStyle.Yellow

	local loseLines = column(panel, "Lose", "YOU LOSE", LOSE_COLOR, 0, top + 36)
	local keepLines = column(panel, "Keep", "YOU KEEP", UiStyle.Cash, 0.5, top + 36)

	local function button(name: string, label: string, x: number): TextButton
		local b = UiStyle.sticker(name, panel, label)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.new(x, 0, 1, -26)
		b.Size = UDim2.fromOffset(170, 44)
		b.TextSize = 24
		UiStyle.springy(b)
		return b
	end
	local cancelButton = button("Cancel", "CANCEL", 0.28)
	local yesButton = button("Rebirth", "REBIRTH", 0.72)
	yesButton.BackgroundColor3 = UiStyle.Red
	yesButton.TextColor3 = Color3.new(1, 1, 1)

	local onYes: (() -> ())? = nil

	local function close()
		onYes = nil
		if panel.Visible then
			UiStyle.show(panel, false)
		end
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
	end

	local function ask(summary: Summary, yes: () -> ())
		local lost, kept = Rebirth.split(summary.cars, Tuning.Ladder)
		local first = carName(Tuning.Ladder[1].Id)
		local multiplier = Rebirth.payMultiplier(summary.rebirths + 1, Tuning.Rebirth)
		gain.Text = `RUN PAY x{multiplier} FOREVER`

		local lose = { `Your cash ($ {withCommas(summary.cash)})`, "Every upgrade level" }
		if summary.boneCoins > 0 then
			table.insert(lose, `Your bones ({withCommas(summary.boneCoins)})`)
		end
		for _, id in lost do
			table.insert(lose, `The {carName(id)}`)
		end
		table.insert(lose, `You start over in the {first}`)
		loseLines.Text = bullets(lose)

		local keep: { string } = {}
		for _, id in kept do
			table.insert(keep, `The {carName(id)}`)
		end
		table.insert(keep, "Bodies you own, worn again when you buy their car back")
		if summary.limiteds > 0 then
			table.insert(keep, "Your limited items")
		end
		table.insert(keep, "Your best score and invite progress")
		keepLines.Text = bullets(keep)

		onYes = yes
		local gamepad = GuiService.SelectedObject ~= nil
		UiStyle.show(panel, true)
		if gamepad then
			GuiService.SelectedObject = cancelButton
		end
	end

	yesButton.Activated:Connect(function()
		local yes = onYes
		close()
		if yes then
			yes()
		end
	end)
	cancelButton.Activated:Connect(close)
	closeButton.Activated:Connect(close)

	return { ask = ask, close = close }
end

return RebirthConfirm
