--!strict
-- Hud (ModuleScript) -> StarterPlayerScripts.Hud
-- Jet fuel bar, the player's cash (from the Cash attribute Garage sets on the
-- player, with a short "+N" when it rises), a speed and airtime readout for
-- tuning feel, the hardest
-- recent hit the server measured (for picking toughness thresholds), and the run
-- score: live while flying, a popup per trick, and a breakdown card when the
-- run ends. A trick popup pops in big, colored by its points (Juice), dings
-- higher with each combo step, and flies into the live score. The card first
-- shows the client's own score, then the server's
-- when it arrives, since that is the one that counts. After a rebirth, the
-- card also shows the multiplier on the run's cash (the Rebirths attribute
-- Garage sets on the player). The card ends with an AGAIN button that does
-- what R does (Hud.onAgain), so a phone player is one tap from the next launch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Bonus = require(ReplicatedStorage.Bonus)
local Juice = require(ReplicatedStorage.Juice)
local Rebirth = require(ReplicatedStorage.Rebirth)
local Scoring = require(ReplicatedStorage.Scoring)
local Tuning = require(ReplicatedStorage.Tuning)
local CloseCall = require(script.Parent.CloseCall)
local TimerChip = require(script.Parent.TimerChip)
local UiStyle = require(script.Parent.UiStyle)

local H = Tuning.Hud

local Hud = {}

type Parts = {
	gui: ScreenGui,
	fill: Frame,
	readout: TextLabel,
	impact: TextLabel,
	live: TextLabel,
	liveGlow: UIStroke,
	popup: TextLabel,
	card: Frame,
	again: Frame,
	cashGui: ScreenGui,
}

local parts: Parts? = nil
local againHandler: (() -> ())? = nil
-- The clean streak from the last server card, to tell when one is lost.
local streakBefore = 0
local popupUntil = 0
local cardUntil = 0
local officialAt = -math.huge
local impactUntil = 0
local impactShown = 0
-- The trick popup still up before it flies into the live score.
local trickShown: TextLabel? = nil
-- The live score as it rolls toward the real one (nil while hidden), when it
-- last rolled, its combo tier (Juice.scoreTier), and its max combo glow.
local liveShown: number? = nil
local liveAt = 0
local liveTier = 0
local liveGlowPulse: Tween? = nil
local stampShown: TextLabel? = nil

local FUEL_COLOR = Color3.fromRGB(255, 170, 40)
local BURN_COLOR = Color3.fromRGB(255, 90, 30)
local PANEL_COLOR = Color3.fromRGB(20, 20, 28)
local CASH_COLOR = Color3.fromRGB(120, 230, 120)
local BONE_COLOR = Color3.fromRGB(230, 210, 160)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 230, 100)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
})

-- Made up front so it has loaded by the first trick. Stays on this client.
local ding = Instance.new("Sound")
ding.Name = "TrickDing"
ding.SoundId = Tuning.JuiceSounds.Ding.Id
ding.Volume = Tuning.JuiceSounds.Ding.Volume
ding.Parent = SoundService
local thump: Sound? = nil
if Tuning.JuiceSounds.Thump.Id ~= "" then
	local s = Instance.new("Sound")
	s.Name = "LandingThump"
	s.SoundId = Tuning.JuiceSounds.Thump.Id
	s.PlaybackSpeed = Tuning.JuiceSounds.Thump.Pitch
	s.Volume = Tuning.JuiceSounds.Thump.Volume
	s.Parent = SoundService
	thump = s
end

local cashDing = Instance.new("Sound")
cashDing.Name = "CashDing"
cashDing.SoundId = Tuning.JuiceSounds.Cash.Id
cashDing.PlaybackSpeed = Tuning.JuiceSounds.Cash.Pitch
cashDing.Volume = Tuning.JuiceSounds.Cash.Volume
cashDing.Parent = SoundService

local COIN_COLOR = Color3.fromRGB(255, 200, 40)
local COIN_EDGE = Color3.fromRGB(190, 120, 0)
local COIN_MARK = Color3.fromRGB(120, 70, 0)

type StampLook = { Text: string, Size: number, Color: Color3 }
local STAMPS = H.Stamps :: { [string]: StampLook }
local STAMP_EDGE = Color3.fromRGB(30, 22, 14)

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

-- What a clean streak adds to a run's pay, like "+30%".
local function streakPercent(streak: number): string
	return `+{round((Bonus.streakMultiplier(streak, Tuning.Bonus) - 1) * 100)}%`
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
	-- On the right, halfway down, clear of the road ahead in the middle.
	card.AnchorPoint = Vector2.new(1, 0.5)
	card.Position = UDim2.new(1, -16, 0.5, 0)
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
local function cardRow(card: Frame, order: number, left: string, right: string, textSize: number): Frame
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
	return row
end

-- A line across the whole card, wrapping if it must, for "So close!".
local function cardLine(card: Frame, order: number, text: string)
	local row = Instance.new("Frame")
	row.Name = `Row{order}`
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Parent = card
	local line = label("Line", row, 20)
	line.Size = UDim2.fromScale(1, 0)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.TextWrapped = true
	line.TextColor3 = FUEL_COLOR
	line.Text = text
end

-- The AGAIN row, last on the card. It stays when the card's rows are cleared.
local function buildAgain(card: Frame): Frame
	local row = Instance.new("Frame")
	row.Name = "AgainRow"
	row.LayoutOrder = 1000000
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, H.AgainHeight + 12)
	row.Parent = card
	local button = UiStyle.sticker("Again", row, "AGAIN")
	button.TextSize = 26
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = UDim2.fromOffset(H.AgainWidth, H.AgainHeight)
	UiStyle.springy(button)
	button.Activated:Connect(function()
		cardUntil = 0
		card.Visible = false
		if againHandler then
			againHandler()
		end
	end)
	return row
end

local function cardTitle(run: Scoring.Run, score: Scoring.Score): string
	if run.ending == "crashed" or run.ending == "stopped" then
		return "CRASHED"
	elseif run.ending == "aborted" then
		return "RESET"
	elseif run.ending == "wrecked" then
		return "WRECKED"
	elseif run.ending == "carried" then
		return "CAUGHT"
	end
	return if score.clean > 1 then "CLEAN LANDING" else "LANDED"
end

local function build(): Parts
	local player = Players.LocalPlayer :: Player
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
	local liveGlow = Instance.new("UIStroke")
	liveGlow.Name = "Glow"
	liveGlow.Thickness = 3
	liveGlow.Color = Color3.fromRGB(255, 230, 255)
	liveGlow.Enabled = false
	liveGlow.Parent = live

	local popup = label("TrickPopup", gui, 32)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromScale(0.5, 0.4)
	popup.Size = UDim2.fromOffset(400, 44)
	popup.TextColor3 = FUEL_COLOR
	popup.Visible = false

	local card = buildCard(gui)
	local again = buildAgain(card)

	-- The clean streak while it lasts, a chip above the timers on the left
	-- (TimerChip): just what it adds, "+30%", and the streak too on hover.
	local streakChip = TimerChip.new("Streak", 0)
	local streakShown = 0
	local function showStreak()
		local value = player:GetAttribute("CleanStreak")
		local streak = if typeof(value) == "number" then value else 0
		local percent = streakPercent(streak)
		streakChip.set("", percent, `STREAK {streak}  {percent}`, UiStyle.Yellow)
		streakChip.setVisible(streak > 0)
		if streak > streakShown then
			streakChip.bounce()
		end
		streakShown = streak
	end
	player:GetAttributeChangedSignal("CleanStreak"):Connect(showStreak)
	showStreak()

	-- Cash counter lives on its own always-on ScreenGui so it stays visible
	-- even when the rest of the HUD is hidden (e.g. outside a car).
	local cashGui = Instance.new("ScreenGui")
	cashGui.Name = "CashHud"
	cashGui.ResetOnSpawn = false
	cashGui.Parent = player:WaitForChild("PlayerGui")

	-- Beside the fuel bar, clear of the chat, the player list, and the touch
	-- buttons in the corners.
	local cash = label("Cash", cashGui, 24)
	cash.AnchorPoint = Vector2.new(0, 0)
	cash.Position = UDim2.new(0.5, 146, 0, 8)
	cash.Size = UDim2.fromOffset(200, 30)
	cash.TextXAlignment = Enum.TextXAlignment.Left
	cash.TextColor3 = CASH_COLOR

	local earned = label("CashEarned", cashGui, 20)
	earned.AnchorPoint = Vector2.new(0, 0)
	earned.Position = UDim2.new(0.5, 146, 0, 36)
	earned.Size = UDim2.fromOffset(200, 24)
	earned.TextXAlignment = Enum.TextXAlignment.Left
	earned.TextColor3 = CASH_COLOR
	earned.Visible = false

	-- The counter rolls to each new amount instead of jumping.
	local setCash = UiStyle.counter(cash, function(n: number): string
		return `$ {withCommas(n)}`
	end)

	local function coin(size: number): Frame
		local c = Instance.new("Frame")
		c.Name = "FlyingCoin"
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Size = UDim2.fromOffset(size, size)
		c.BackgroundColor3 = COIN_COLOR
		c.ZIndex = 20
		local circle = Instance.new("UICorner")
		circle.CornerRadius = UDim.new(0.5, 0)
		circle.Parent = c
		UiStyle.stroke(c, 2, COIN_EDGE, true)
		local mark = label("Mark", c, math.floor(size * 0.7))
		mark.Size = UDim2.fromScale(1, 1)
		mark.Text = "$"
		mark.TextColor3 = COIN_MARK
		mark.TextStrokeTransparency = 1
		mark.ZIndex = 21
		c.Parent = cashGui
		return c
	end

	-- The newest change to the cash. Coins from an older one still land but
	-- no longer move the counter.
	local flight = 0
	local lastDing = 0

	-- Flies a run's pay from the run card into the counter as coins, each
	-- adding its share to the counter with a ding as it lands.
	local function payIn(from: number, gain: number)
		local this = flight
		local count = Juice.flyCoins(gain, Tuning.Juice)
		local start = card.AbsolutePosition + card.AbsoluteSize / 2
		for i = 1, count do
			task.delay((i - 1) * H.CoinStagger, function()
				local c = coin(H.CoinSize)
				local s = H.CoinScatter
				c.Position = UDim2.fromOffset(start.X + math.random(-s, s), start.Y + math.random(-s, s))
				-- The amount is left aligned, so aim near the front of it.
				local to = cash.AbsolutePosition + Vector2.new(40, cash.AbsoluteSize.Y / 2)
				local info = TweenInfo.new(H.CoinFlyTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				local small = UDim2.fromOffset(H.CoinSize / 2, H.CoinSize / 2)
				local fly = TweenService:Create(c, info, { Position = UDim2.fromOffset(to.X, to.Y), Size = small })
				fly.Completed:Connect(function()
					c:Destroy()
					if flight ~= this then
						return
					end
					setCash(from + gain * i / count)
					local now = os.clock()
					if now - lastDing >= H.CoinDingGap then
						lastDing = now
						cashDing:Play()
					end
					if i == count then
						UiStyle.bounce(cash)
					end
				end)
				fly:Play()
			end)
		end
	end

	-- Coins falling down the whole screen, for a big run.
	local function rain()
		local screen = cashGui.AbsoluteSize
		for _ = 1, H.RainCoins do
			task.delay(math.random() * H.RainSpread, function()
				local c = coin(H.RainCoinSize)
				local x = math.random() * screen.X
				c.Position = UDim2.fromOffset(x, -H.RainCoinSize)
				c.Rotation = math.random(-30, 30)
				local info = TweenInfo.new(
					H.RainTime * (0.8 + math.random() * 0.4),
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)
				local goal = {
					Position = UDim2.fromOffset(x + math.random(-40, 40), screen.Y + H.RainCoinSize),
					Rotation = c.Rotation + math.random(-180, 180),
				}
				local fall = TweenService:Create(c, info, goal)
				fall.Completed:Connect(function()
					c:Destroy()
				end)
				fall:Play()
			end)
		end
	end

	local shown: number? = nil
	local earnedShows = 0
	local function showCash()
		local value = player:GetAttribute("Cash")
		if typeof(value) ~= "number" then
			cash.Text = "$ ..."
			return
		end
		flight += 1
		-- In the obby the cash is stage cash, which CashBalloon shows.
		local obby = player:GetAttribute("ObbyCheckpoint") ~= nil
		-- A rise while the run card is up is the run's pay.
		if shown and value > shown and not obby and gui.Enabled and card.Visible then
			payIn(shown, value - shown)
			if Juice.rains(value - shown, Tuning.Juice) then
				rain()
			end
		else
			setCash(value)
		end
		if shown and value > shown and not obby then
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

	-- Bone counter: sits below the cash counter, reads from the leaderstats
	-- "Bones" IntValue (created by DinoWeather when a bone is collected).
	local bone = label("Bones", cashGui, 24)
	bone.AnchorPoint = Vector2.new(0, 0)
	bone.Position = UDim2.new(0.5, 146, 0, 64)
	bone.Size = UDim2.fromOffset(200, 30)
	bone.TextXAlignment = Enum.TextXAlignment.Left
	bone.TextColor3 = BONE_COLOR
	bone.Text = "🦴 0"

	local boneEarned = label("BoneEarned", cashGui, 20)
	boneEarned.AnchorPoint = Vector2.new(0, 0)
	boneEarned.Position = UDim2.new(0.5, 146, 0, 92)
	boneEarned.Size = UDim2.fromOffset(200, 24)
	boneEarned.TextXAlignment = Enum.TextXAlignment.Left
	boneEarned.TextColor3 = BONE_COLOR
	boneEarned.Visible = false

	local boneShown: number? = nil
	local boneEarnedShows = 0
	local function showBones(value: number)
		bone.Text = `🦴 {withCommas(value)}`
		if boneShown and value > boneShown then
			boneEarned.Text = `+{withCommas(value - boneShown)}`
			boneEarned.Visible = true
			boneEarnedShows += 1
			local show = boneEarnedShows
			task.delay(H.CashEarnedTime, function()
				if boneEarnedShows == show then
					boneEarned.Visible = false
				end
			end)
		end
		boneShown = value
	end

	-- The Bones IntValue is created lazily, so we need to find it when it appears.
	local function connectBones()
		local ls = player:FindFirstChild("leaderstats")
		if not ls then return false end
		local bonesVal = ls:FindFirstChild("Bones")
		if not bonesVal or not bonesVal:IsA("IntValue") then return false end
		showBones(bonesVal.Value)
		bonesVal.Changed:Connect(showBones)
		return true
	end

	if not connectBones() then
		-- Watch for leaderstats or the Bones value being added
		local conn
		conn = player.DescendantAdded:Connect(function(desc)
			if desc:IsA("IntValue") and desc.Name == "Bones" then
				if connectBones() then
					conn:Disconnect()
				end
			end
		end)
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	return {
		gui = gui,
		fill = fill,
		readout = readout,
		impact = impact,
		live = live,
		liveGlow = liveGlow,
		popup = popup,
		card = card,
		again = again,
		cashGui = cashGui,
	}
end

-- What the card's AGAIN button does.
function Hud.onAgain(handler: () -> ())
	againHandler = handler
end

function Hud.setVisible(visible: boolean)
	if visible and not parts then
		parts = build()
	end
	if parts then
		parts.gui.Enabled = visible
		-- Cash counter always stays visible regardless of HUD visibility
		parts.cashGui.Enabled = true
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

-- Grows and recolors the live score for a combo tier, with a bounce on the
-- way up. The last tier is the max combo, which glows.
local function setLiveTier(p: Parts, tier: number, instant: boolean)
	local up = tier > liveTier
	liveTier = tier
	local size = H.LiveSizes[tier + 1]
	local goal = {
		TextSize = size,
		TextColor3 = H.LiveColors[tier + 1],
		Size = UDim2.fromOffset(p.live.Size.X.Offset, size + 6),
	}
	TweenService:Create(p.live, TweenInfo.new(if instant then 0 else H.LiveGrowTime), goal):Play()
	if up and not instant then
		UiStyle.bounce(p.live)
	end

	local glowing = tier == #Tuning.Juice.ScoreTiers
	p.liveGlow.Enabled = glowing
	if glowing and not liveGlowPulse then
		p.liveGlow.Transparency = 0.7
		local info = TweenInfo.new(H.LiveGlowPulse, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		liveGlowPulse = TweenService:Create(p.liveGlow, info, { Transparency = 0 })
		liveGlowPulse:Play()
	elseif not glowing and liveGlowPulse then
		liveGlowPulse:Cancel()
		liveGlowPulse = nil
	end
end

-- The score so far while flying; nil hides it. It rolls up to each new score
-- instead of jumping, and grows, recolors, and at the max combo glows and
-- wobbles as the combo climbs.
function Hud.live(score: Scoring.Score?)
	local p = parts
	if not p then
		return
	end
	if not score then
		if liveShown then
			liveShown = nil
			setLiveTier(p, 0, true)
			p.live.Rotation = 0
		end
		p.live.Visible = false
		return
	end

	local now = os.clock()
	local shown = if liveShown then Juice.roll(liveShown, score.total, now - liveAt, Tuning.Juice) else score.total
	liveShown = shown
	liveAt = now
	local total = withCommas(shown)
	p.live.Text = if score.combo > 1 then `{total}  {multiplier(score.combo)}` else total

	local tier = Juice.scoreTier(score.combo, Tuning.Juice)
	if tier ~= liveTier then
		setLiveTier(p, tier, false)
	end
	p.live.Rotation = if tier == #Tuning.Juice.ScoreTiers
		then math.sin(now * 2 * math.pi * H.LiveWobbleRate) * H.LiveWobbleAngle
		else 0
	p.live.Visible = true
end

-- Sends a trick popup into the live score, shrinking and fading as it goes,
-- and bounces the score when it gets there. With no live score up, it fades
-- where it is.
local function flyToScore(popup: TextLabel)
	if popup:GetAttribute("Flying") then
		return
	end
	popup:SetAttribute("Flying", true)
	if trickShown == popup then
		trickShown = nil
	end
	local p = parts
	local info = TweenInfo.new(H.TrickFlyTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local goal: { [string]: any } = { TextTransparency = 1, TextStrokeTransparency = 1 }
	local toScore = p ~= nil and p.live.Visible
	if p and toScore then
		goal.Position = p.live.Position + UDim2.fromOffset(0, p.live.Size.Y.Offset / 2)
	end
	local scale = popup:FindFirstChildOfClass("UIScale")
	if scale then
		TweenService:Create(scale, info, { Scale = H.TrickFlyScale }):Play()
	end
	local fly = TweenService:Create(popup, info, goal)
	fly.Completed:Connect(function()
		popup:Destroy()
		if p and toScore and p.live.Visible then
			UiStyle.bounce(p.live)
		end
	end)
	fly:Play()
end

-- A trick as it lands: `combo` is the run's combo with it, for the ding.
-- A newer trick sends the one before it into the score at once.
function Hud.trick(name: string, points: number, combo: number)
	local p = parts
	if not p then
		return
	end
	popupUntil = 0
	if trickShown then
		flyToScore(trickShown)
	end

	local popup = label("Trick", p.gui, p.popup.TextSize)
	popup.AnchorPoint = p.popup.AnchorPoint
	popup.Position = p.popup.Position
	popup.Size = p.popup.Size
	popup.Text = `{name}  +{withCommas(points)}`
	local tier = Juice.popupTier(points, Tuning.Juice)
	if tier == "Gold" then
		popup.TextColor3 = UiStyle.Yellow
	elseif tier == "Rainbow" then
		local gradient = Instance.new("UIGradient")
		gradient.Color = RAINBOW
		gradient.Parent = popup
		local spin = TweenInfo.new(H.TrickPopupTime + H.TrickFlyTime, Enum.EasingStyle.Linear)
		TweenService:Create(gradient, spin, { Rotation = 360 }):Play()
	end
	local scale = Instance.new("UIScale")
	scale.Scale = H.TrickPopScale
	scale.Parent = popup
	local pop = TweenInfo.new(H.TrickPopTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(scale, pop, { Scale = 1 }):Play()
	trickShown = popup
	task.delay(H.TrickPopupTime, function()
		if popup.Parent then
			flyToScore(popup)
		end
	end)

	local spec = Tuning.JuiceSounds.Ding
	ding.PlaybackSpeed = spec.Pitch * Juice.dingPitch(combo, Tuning.Score.ComboStep, Tuning.Juice)
	ding:Play()
end

-- A landing's grade, slammed onto the screen at a tilt with a thump, then
-- faded away. A newer stamp replaces one still up.
function Hud.landing(grade: Juice.Grade)
	local p = parts
	if not p then
		return
	end
	if stampShown then
		stampShown:Destroy()
	end
	local look = STAMPS[grade]
	local stamp = label("LandingStamp", p.gui, look.Size)
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Position = UDim2.fromScale(0.5, H.StampY)
	stamp.Size = UDim2.fromOffset(400, look.Size + 10)
	stamp.Rotation = H.StampTilt
	stamp.Text = look.Text
	stamp.TextColor3 = look.Color
	stamp.TextTransparency = 1
	stamp.TextStrokeTransparency = 1
	local edge = Instance.new("UIStroke")
	edge.Thickness = 3
	edge.Color = STAMP_EDGE
	edge.Transparency = 1
	edge.Parent = stamp
	local scale = Instance.new("UIScale")
	scale.Scale = H.StampFrom
	scale.Parent = stamp
	stampShown = stamp

	local slam = TweenInfo.new(H.StampSlam, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(scale, slam, { Scale = 1 }):Play()
	TweenService:Create(stamp, slam, { TextTransparency = 0 }):Play()
	TweenService:Create(edge, slam, { Transparency = 0 }):Play()
	task.delay(H.StampSlam + H.StampTime, function()
		if stamp.Parent == nil then
			return
		end
		local fade = TweenInfo.new(H.StampFade)
		TweenService:Create(edge, fade, { Transparency = 1 }):Play()
		local out = TweenService:Create(stamp, fade, { TextTransparency = 1 })
		out.Completed:Connect(function()
			stamp:Destroy()
		end)
		out:Play()
	end)
	if thump then
		thump:Play()
	end
end

-- Cash paid at once, outside any run, such as for shaking off the raptors.
function Hud.bonus(name: string, cash: number)
	local p = parts
	if not p then
		return
	end
	if trickShown then
		flyToScore(trickShown)
	end
	p.popup.Text = `{name}  +${withCommas(cash)}`
	popupUntil = os.clock() + H.TrickPopupTime
end

-- The breakdown card for a finished run. Repeats of a trick share one line.
-- `official` is the server's score for the run; it replaces the client's card,
-- and a client card arriving just after it is dropped. Only the server's card
-- has `extras`: a lucky tier, shown in gold with a flash and up longer; the
-- clean streak after the run, shown if this run added to it or lost it; and
-- what the "So close!" line at the bottom needs (CloseCall).
function Hud.result(run: Scoring.Run, score: Scoring.Score, official: boolean, extras: Bonus.Extras?)
	local p = parts
	if not p then
		return
	end
	local lucky = if extras then extras.lucky else nil
	local streak = if extras then extras.streak else nil
	local golden = if extras then extras.golden else nil
	local now = os.clock()
	if official then
		officialAt = now
	elseif now - officialAt < H.OfficialHold then
		return
	end
	for _, child in p.card:GetChildren() do
		if child:IsA("Frame") and child ~= p.again then
			child:Destroy()
		end
	end
	-- After a reset the next car is already on its way.
	p.again.Visible = run.ending ~= "aborted"

	local order = 0
	local function add(left: string, right: string, textSize: number): Frame
		order += 1
		return cardRow(p.card, order, left, right, textSize)
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
	if score.grind > 0 then
		add(string.format("Grind %.1fs", run.grind or 0), withCommas(score.grind), 18)
	end
	if score.gap > 0 then
		local gaps = run.gaps or {}
		add(table.concat(gaps, ", "), withCommas(score.gap), 18)
	end
	if score.swing > 0 then
		add("Swing landing", withCommas(score.swing), 18)
	end
	if score.targets > 0 then
		local kinds: { string } = {}
		local smashed: { [string]: number } = {}
		for _, kind in run.targets or {} do
			if not smashed[kind] then
				table.insert(kinds, kind)
				smashed[kind] = 0
			end
			smashed[kind] += 1
		end
		local labels: { string } = {}
		for _, kind in kinds do
			local name = (H.TargetLabels :: { [string]: string })[kind] or `{kind} smash`
			table.insert(labels, if smashed[kind] > 1 then `{name} x{smashed[kind]}` else name)
		end
		add(table.concat(labels, ", "), withCommas(score.targets), 18)
	end
	if score.combo > 1 then
		add("Combo", multiplier(score.combo), 18)
	end
	if score.clean > 1 then
		add("Clean landing", multiplier(score.clean), 18)
	end
	add("Total", withCommas(score.total), 26)
	local rebirths = Rebirth.count((Players.LocalPlayer :: Player):GetAttribute("Rebirths"))
	if rebirths > 0 then
		add("Rebirth pay", multiplier(Rebirth.payMultiplier(rebirths, Tuning.Rebirth)), 18)
	end
	if streak then
		if run.ending == "landed" and run.clean and streak > 0 then
			local row = add(`Clean streak {streak}`, streakPercent(streak), 18)
			for _, text in row:GetChildren() do
				if text:IsA("TextLabel") then
					text.TextColor3 = UiStyle.Yellow
				end
			end
		elseif streak == 0 and streakBefore >= H.StreakLostFrom then
			local row = add(`Streak of {streakBefore} lost`, "", 18)
			for _, text in row:GetChildren() do
				if text:IsA("TextLabel") then
					text.TextTransparency = 0.4
				end
			end
		end
		streakBefore = streak
	end
	if golden then
		local row = add("GOLDEN BOOSTER!", multiplier(golden), 24)
		for _, text in row:GetChildren() do
			if text:IsA("TextLabel") then
				text.TextColor3 = Tuning.Golden.Color
			end
		end
		UiStyle.flash(row)
		UiStyle.bounce(row)
		if not lucky then
			UiStyle.play("Buy")
		end
	end
	if lucky then
		local jackpot = lucky.Multiplier >= H.JackpotFrom
		local row = add(`{lucky.Name}!`, multiplier(lucky.Multiplier), if jackpot then 30 else 24)
		for _, text in row:GetChildren() do
			if text:IsA("TextLabel") then
				text.TextColor3 = UiStyle.Yellow
			end
		end
		UiStyle.flash(row)
		UiStyle.bounce(row)
		UiStyle.play("Buy")
		if jackpot then
			p.popup.Text = `{lucky.Name} {multiplier(lucky.Multiplier)}!`
			popupUntil = now + H.LuckyTime
			UiStyle.bounce(p.popup)
		end
	end
	if extras and extras.coins > 0 then
		add(`Coins x{extras.coins}`, `+${withCommas(extras.coinCash)}`, 18)
	end
	if extras and extras.gems > 0 then
		local name = if extras.gems > 1 then `GEMS x{extras.gems}!` else "GEM!"
		local row = add(name, `+${withCommas(extras.gemCash)}`, 22)
		for _, text in row:GetChildren() do
			if text:IsA("TextLabel") then
				text.TextColor3 = Tuning.Coins.GemColor
			end
		end
		UiStyle.bounce(row)
	end
	local close = if extras then CloseCall.line(run, score, extras) else nil
	if close then
		order += 1
		cardLine(p.card, order, close)
	end
	cardUntil = now + if lucky or golden then H.LuckyTime else H.ResultTime
end

-- Build the HUD immediately so the cash counter is always on screen,
-- even before the player enters a car. The main HUD gui starts disabled.
parts = build()
parts.gui.Enabled = false
parts.cashGui.Enabled = true

return Hud
