--!strict
-- Hud (ModuleScript) -> StarterPlayerScripts.Hud
-- Jet fuel bar, the player's cash (from the Cash attribute Garage sets on the
-- player, with a short "+N" when it rises), a speed and airtime readout for
-- tuning feel, the hardest
-- recent hit the server measured (for picking toughness thresholds), and the run
-- score: live while flying, a popup per trick, and a breakdown card when the
-- run ends. The card first shows the client's own score, then the server's
-- when it arrives, since that is the one that counts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Scoring = require(ReplicatedStorage.Scoring)
local Tuning = require(ReplicatedStorage.Tuning)

local H = Tuning.Hud

local Hud = {}

type Parts = {
	gui: ScreenGui,
	fill: Frame,
	readout: TextLabel,
	impact: TextLabel,
	live: TextLabel,
	popup: TextLabel,
	card: Frame,
}

local parts: Parts? = nil
local popupUntil = 0
local cardUntil = 0
local officialAt = -math.huge
local impactUntil = 0
local impactShown = 0

local FUEL_COLOR = Color3.fromRGB(255, 170, 40)
local BURN_COLOR = Color3.fromRGB(255, 90, 30)
local PANEL_COLOR = Color3.fromRGB(20, 20, 28)
local CASH_COLOR = Color3.fromRGB(120, 230, 120)

local function round(x: number): number
	return math.floor(x + 0.5)
end

local function withCommas(n: number): string
	local digits = tostring(round(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (digits:gsub("^,", ""))
end

local function multiplier(x: number): string
	return `x{string.format("%g", x)}`
end

local function label(name: string, parent: Instance, textSize: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextSize = textSize
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Parent = parent
	return text
end

local function buildCard(gui: ScreenGui): Frame
	local card = Instance.new("Frame")
	card.Name = "RunCard"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 116)
	card.Size = UDim2.fromOffset(300, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = PANEL_COLOR
	card.BackgroundTransparency = 0.3
	card.Visible = false
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = card
	return card
end

-- One line of the run card: a name on the left, points on the right.
local function cardRow(card: Frame, order: number, left: string, right: string, textSize: number)
	local row = Instance.new("Frame")
	row.Name = `Row{order}`
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, textSize + 6)
	row.Parent = card
	local name = label("Name", row, textSize)
	name.Size = UDim2.fromScale(0.7, 1)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = left
	local points = label("Points", row, textSize)
	points.AnchorPoint = Vector2.new(1, 0)
	points.Position = UDim2.fromScale(1, 0)
	points.Size = UDim2.fromScale(0.3, 1)
	points.TextXAlignment = Enum.TextXAlignment.Right
	points.Text = right
end

local function cardTitle(run: Scoring.Run, score: Scoring.Score): string
	if run.ending == "crashed" or run.ending == "stopped" then
		return "CRASHED"
	elseif run.ending == "aborted" then
		return "RESET"
	elseif run.ending == "wrecked" then
		return "WRECKED"
	end
	return if score.clean > 1 then "CLEAN LANDING" else "LANDED"
end

local function build(): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	local bar = Instance.new("Frame")
	bar.Name = "Fuel"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 16)
	bar.Size = UDim2.fromOffset(260, 16)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	bar.BackgroundTransparency = 0.3
	bar.Parent = gui
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = FUEL_COLOR
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = fill

	local readout = Instance.new("TextLabel")
	readout.Name = "Readout"
	readout.AnchorPoint = Vector2.new(0.5, 0)
	readout.Position = UDim2.new(0.5, 0, 0, 36)
	readout.Size = UDim2.fromOffset(260, 28)
	readout.BackgroundTransparency = 1
	readout.Font = Enum.Font.GothamBold
	readout.TextSize = 20
	readout.TextColor3 = Color3.new(1, 1, 1)
	readout.TextStrokeTransparency = 0.5
	readout.Parent = gui

	local impact = Instance.new("TextLabel")
	impact.Name = "Impact"
	-- Low and centered, clear of the chat window in the top left.
	impact.AnchorPoint = Vector2.new(0.5, 0.5)
	impact.Position = UDim2.fromScale(0.5, 0.7)
	impact.Size = UDim2.fromOffset(320, 28)
	impact.BackgroundTransparency = 1
	impact.Font = Enum.Font.GothamBold
	impact.TextSize = 20
	impact.TextColor3 = Color3.new(1, 1, 1)
	impact.TextStrokeTransparency = 0.5
	impact.Visible = false
	impact.Parent = gui

	local live = label("LiveScore", gui, 34)
	live.AnchorPoint = Vector2.new(0.5, 0)
	live.Position = UDim2.new(0.5, 0, 0, 68)
	live.Size = UDim2.fromOffset(300, 40)
	live.Visible = false

	local popup = label("TrickPopup", gui, 32)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromScale(0.5, 0.4)
	popup.Size = UDim2.fromOffset(400, 44)
	popup.TextColor3 = FUEL_COLOR
	popup.Visible = false

	local card = buildCard(gui)

	-- Beside the fuel bar, clear of the chat, the player list, and the touch
	-- buttons in the corners.
	local cash = label("Cash", gui, 24)
	cash.AnchorPoint = Vector2.new(0, 0)
	cash.Position = UDim2.new(0.5, 146, 0, 8)
	cash.Size = UDim2.fromOffset(200, 30)
	cash.TextXAlignment = Enum.TextXAlignment.Left
	cash.TextColor3 = CASH_COLOR

	local earned = label("CashEarned", gui, 20)
	earned.AnchorPoint = Vector2.new(0, 0)
	earned.Position = UDim2.new(0.5, 146, 0, 36)
	earned.Size = UDim2.fromOffset(200, 24)
	earned.TextXAlignment = Enum.TextXAlignment.Left
	earned.TextColor3 = CASH_COLOR
	earned.Visible = false

	local player = Players.LocalPlayer :: Player
	local shown: number? = nil
	local earnedShows = 0
	local function showCash()
		local value = player:GetAttribute("Cash")
		if typeof(value) ~= "number" then
			cash.Text = "$ ..."
			return
		end
		cash.Text = `$ {withCommas(value)}`
		if shown and value > shown then
			earned.Text = `+{withCommas(value - shown)}`
			earned.Visible = true
			earnedShows += 1
			local show = earnedShows
			task.delay(H.CashEarnedTime, function()
				if earnedShows == show then
					earned.Visible = false
				end
			end)
		end
		shown = value
	end
	player:GetAttributeChangedSignal("Cash"):Connect(showCash)
	showCash()

	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, fill = fill, readout = readout, impact = impact, live = live, popup = popup, card = card }
end

function Hud.setVisible(visible: boolean)
	if visible and not parts then
		parts = build()
	end
	if parts then
		parts.gui.Enabled = visible
	end
end

-- `airtime` is nil on the ground.
function Hud.update(fuelFraction: number, speed: number, airtime: number?, burning: boolean)
	local p = parts
	if not p then
		return
	end
	p.fill.Size = UDim2.fromScale(math.clamp(fuelFraction, 0, 1), 1)
	p.fill.BackgroundColor3 = if burning then BURN_COLOR else FUEL_COLOR
	local text = `{math.floor(speed + 0.5)} studs/s`
	if airtime then
		text ..= string.format("   air %.1fs", airtime)
	end
	p.readout.Text = text

	local now = os.clock()
	p.popup.Visible = now < popupUntil
	p.card.Visible = now < cardUntil
	p.impact.Visible = now < impactUntil
end

-- A hit the server measured, in studs per second, the toughness it cost, and
-- what is left. Keeps showing the hardest one until ImpactTime passes without
-- a harder one.
function Hud.impact(strength: number, slot: string, inRun: boolean, damage: number, toughnessLeft: number)
	local p = parts
	if not p then
		return
	end
	local now = os.clock()
	if now < impactUntil and strength < impactShown then
		return
	end
	impactShown = strength
	impactUntil = now + H.ImpactTime
	local cost = if damage > 0 then `  -{round(damage)}, {round(toughnessLeft)} left` else ""
	p.impact.Text = `Hit {round(strength)} {slot}{if inRun then "" else " (no run)"}{cost}`
end

-- The score so far while flying; nil hides it.
function Hud.live(score: Scoring.Score?)
	local p = parts
	if not p then
		return
	end
	if score then
		local total = withCommas(score.total)
		p.live.Text = if score.combo > 1 then `{total}  {multiplier(score.combo)}` else total
	end
	p.live.Visible = score ~= nil
end

function Hud.trick(name: string, points: number)
	local p = parts
	if not p then
		return
	end
	p.popup.Text = `{name}  +{withCommas(points)}`
	popupUntil = os.clock() + H.TrickPopupTime
end

-- The breakdown card for a finished run. Repeats of a trick share one line.
-- `official` is the server's score for the run; it replaces the client's card,
-- and a client card arriving just after it is dropped.
function Hud.result(run: Scoring.Run, score: Scoring.Score, official: boolean)
	local p = parts
	if not p then
		return
	end
	local now = os.clock()
	if official then
		officialAt = now
	elseif now - officialAt < H.OfficialHold then
		return
	end
	for _, child in p.card:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local order = 0
	local function add(left: string, right: string, textSize: number)
		order += 1
		cardRow(p.card, order, left, right, textSize)
	end

	add(cardTitle(run, score), "", 22)
	add(string.format("Airtime %.1fs", run.airtime), withCommas(score.airtime), 18)
	add(`Distance {withCommas(run.distance)}`, withCommas(score.distance), 18)
	add(`Height {withCommas(run.height)}`, withCommas(score.height), 18)

	local names: { string } = {}
	local counts: { [string]: number } = {}
	local points: { [string]: number } = {}
	for i, trick in run.tricks do
		local name = Scoring.trickName(trick)
		if not counts[name] then
			table.insert(names, name)
			counts[name] = 0
			points[name] = 0
		end
		counts[name] += 1
		points[name] += score.trickPoints[i]
	end
	for _, name in names do
		add(if counts[name] > 1 then `{name} x{counts[name]}` else name, withCommas(points[name]), 18)
	end

	if score.smash > 0 then
		add("Smash", withCommas(score.smash), 18)
	end
	if score.combo > 1 then
		add("Combo", multiplier(score.combo), 18)
	end
	if score.clean > 1 then
		add("Clean landing", multiplier(score.clean), 18)
	end
	add("Total", withCommas(score.total), 26)
	cardUntil = now + H.ResultTime
end

return Hud
