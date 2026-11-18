--!strict
-- DailyMenu (ModuleScript) -> StarterPlayerScripts.DailyMenu
-- The daily reward panel: the streak, the calendar (Tuning.Daily.Days) with
-- each day got, ready, or still to come (DailyReward.tiles), the double cash
-- launches left, and a CLAIM button that counts down to the next day while
-- there's nothing to claim. The DAILY button at the top of the screen opens
-- and closes it; so do the panel's X button and gamepad B. A red badge on
-- the DAILY button shows while a claim is ready. While the panel is open the
-- car gets no input (Controls).
--
-- The calendar comes from the attributes DailyRewards puts on the player,
-- and the day from the server's clock (workspace:GetServerTimeNow), so this
-- agrees with the server about what can be claimed. CLAIM asks on
-- ReplicatedStorage.DailyClaimEvent, and the reward that comes back shows
-- in the panel with the purchase sound.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local DailyReward = require(ReplicatedStorage.DailyReward)
local Tuning = require(ReplicatedStorage.Tuning)
local UiStyle = require(script.Parent.UiStyle)

local DailyMenu = {}

local T = Tuning.Daily
local DAYS = #T.Days
local COLUMNS = 4
local TILE = Vector2.new(88, 84)
local TILE_GAP = 8
local CLAIM_WAIT = 5 -- seconds before CLAIM can be pressed again with no answer

-- One day on the calendar.
type TileView = { frame: Frame, prize: TextLabel, done: Frame }

local player = Players.LocalPlayer :: Player
local started = false
local open = false

local function money(n: number): string
	local digits = tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. (digits:gsub("^,", ""))
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- The player's calendar from the attributes DailyRewards sets.
local function state(): DailyReward.State
	return DailyReward.reconcile({
		LastDay = player:GetAttribute("DailyLastDay"),
		Streak = player:GetAttribute("DailyStreak"),
		Weeks = player:GetAttribute("DailyWeeks"),
		DoubleLaunches = player:GetAttribute("DailyDoubleLaunches"),
	})
end

local function loaded(): boolean
	return player:GetAttribute("DailyStreak") ~= nil
end

local function rewardText(day: DailyReward.Day): string
	if day.DoubleLaunches then
		return `2X CASH\n{day.DoubleLaunches} LAUNCHES`
	end
	return money(day.Cash or 0)
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Daily"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- above the HUD and touch buttons

	-- Top right, in the Roblox top bar so the player list can't cover it. Left
	-- of the TELEPORT button.
	local openButton = UiStyle.sticker("Open", gui, "DAILY")
	openButton.AnchorPoint = Vector2.new(1, 1)
	openButton.Position = UDim2.new(1, -396, 0, -4)
	openButton.Size = UDim2.fromOffset(120, 32)
	UiStyle.springy(openButton)

	local badge = Instance.new("TextLabel")
	badge.Name = "Ready"
	badge.Text = "!"
	badge.Font = UiStyle.TitleFont
	badge.TextSize = 18
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.BackgroundColor3 = UiStyle.Red
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.Size = UDim2.fromOffset(22, 22)
	badge.ZIndex = 2
	badge.Visible = false
	badge.Parent = openButton
	UiStyle.corner(badge, 11)
	UiStyle.stroke(badge, 2, Color3.new(1, 1, 1), true)

	local panel, close = UiStyle.panel(gui, "DAILY", Vector2.new(420, 520))
	local top = UiStyle.HeaderHeight

	local status = UiStyle.text("Status", panel, 16, false)
	status.TextColor3 = UiStyle.Cash
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.fromScale(0, 1)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.Text = ""

	local claimButton = UiStyle.sticker("Claim", panel, "CLAIM")
	claimButton.TextSize = 24
	claimButton.AnchorPoint = Vector2.new(0.5, 1)
	claimButton.Position = UDim2.new(0.5, 0, 1, -28)
	claimButton.Size = UDim2.new(1, -24, 0, 48)
	UiStyle.springy(claimButton)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Details"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, top)
	list.Size = UDim2.new(1, 0, 1, -top - 86)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UiStyle.Yellow
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list

	local streak = UiStyle.text("Streak", list, 26, true)
	streak.TextColor3 = UiStyle.Yellow
	streak.TextXAlignment = Enum.TextXAlignment.Center
	streak.LayoutOrder = 1
	streak.Size = UDim2.new(1, -12, 0, 30)

	local blurb = UiStyle.text("Blurb", list, 14, false)
	blurb.Text = "Claim once a day. Miss a day and you start over at day 1."
	blurb.TextWrapped = true
	blurb.TextXAlignment = Enum.TextXAlignment.Center
	blurb.LayoutOrder = 2
	blurb.Size = UDim2.new(1, -12, 0, 20)

	local rows = math.ceil(DAYS / COLUMNS)
	local calendar = Instance.new("Frame")
	calendar.Name = "Calendar"
	calendar.BackgroundTransparency = 1
	calendar.LayoutOrder = 3
	calendar.Size = UDim2.fromOffset(COLUMNS * TILE.X + (COLUMNS - 1) * TILE_GAP, rows * TILE.Y + (rows - 1) * TILE_GAP)
	calendar.Parent = list
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(TILE.X, TILE.Y)
	grid.CellPadding = UDim2.fromOffset(TILE_GAP, TILE_GAP)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = calendar

	local tiles: { TileView } = {}
	for i, day in T.Days do
		local frame = Instance.new("Frame")
		frame.Name = `Day{i}`
		frame.LayoutOrder = i
		frame.Parent = calendar
		UiStyle.plate(frame)
		local title = UiStyle.text("Title", frame, 18, true)
		title.Text = `DAY {i}`
		title.TextColor3 = UiStyle.Yellow
		title.TextStrokeTransparency = 0
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.Position = UDim2.fromOffset(0, 4)
		title.Size = UDim2.new(1, 0, 0, 20)
		local what = UiStyle.text("What", frame, 15, false)
		what.Text = rewardText(day)
		what.TextColor3 = Color3.new(1, 1, 1)
		what.TextStrokeTransparency = 0.4
		what.TextXAlignment = Enum.TextXAlignment.Center
		what.TextScaled = true
		what.Position = UDim2.fromOffset(4, 24)
		what.Size = UDim2.new(1, -8, 0, 34)
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = 15
		fit.Parent = what
		local prize = UiStyle.text("Prize", frame, 12, true)
		prize.Text = "+ WEEK PRIZE"
		prize.TextColor3 = UiStyle.Yellow
		prize.TextStrokeTransparency = 0.2
		prize.TextXAlignment = Enum.TextXAlignment.Center
		prize.Position = UDim2.new(0, 0, 1, -22)
		prize.Size = UDim2.new(1, 0, 0, 16)
		prize.Visible = false
		-- Darkens a day already claimed this time through the calendar.
		local done = Instance.new("Frame")
		done.Name = "Done"
		done.BackgroundColor3 = UiStyle.Ink
		done.BackgroundTransparency = 0.35
		done.BorderSizePixel = 0
		done.Size = UDim2.fromScale(1, 1)
		done.ZIndex = 2
		done.Visible = false
		done.Parent = frame
		UiStyle.corner(done, 8)
		local mark = UiStyle.text("Mark", done, 20, true)
		mark.Text = "GOT IT"
		mark.TextColor3 = UiStyle.Cash
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.Size = UDim2.fromScale(1, 1)
		mark.ZIndex = 3
		table.insert(tiles, { frame = frame, prize = prize, done = done })
	end

	local doubles = UiStyle.text("Doubles", list, 18, true)
	doubles.TextColor3 = UiStyle.Cash
	doubles.TextXAlignment = Enum.TextXAlignment.Center
	doubles.LayoutOrder = 4
	doubles.Size = UDim2.new(1, -12, 0, 24)

	local waiting = false -- a claim was sent and its answer hasn't come
	local wasReady = false

	local function refresh()
		local s = state()
		local today = DailyReward.dayOf(now())
		local claimable = DailyReward.status(s, today, DAYS)
		local ready = loaded() and claimable.CanClaim

		badge.Visible = ready
		if ready and not wasReady then
			UiStyle.bounce(openButton)
		end
		wasReady = ready

		local days = DailyReward.streak(s, today)
		streak.Text = if days == 1 then "STREAK: 1 DAY" else `STREAK: {days} DAYS`

		local shown = DailyReward.tiles(s, today, DAYS)
		for i, tile in tiles do
			local look = shown[i]
			tile.done.Visible = look == "got"
			UiStyle.setGlow(tile.frame, look == "ready" and loaded())
			tile.prize.Visible = i == DAYS and look ~= "got" and T.WeekPrizes[s.Weeks + 1] ~= nil
		end

		doubles.Visible = s.DoubleLaunches > 0
		doubles.Text = if s.DoubleLaunches == 1
			then "2X CASH: 1 LAUNCH LEFT"
			else `2X CASH: {s.DoubleLaunches} LAUNCHES LEFT`

		local canPress = ready and not waiting
		claimButton.Active = canPress
		UiStyle.setSticker(claimButton, canPress)
		if ready then
			claimButton.Text = `CLAIM DAY {claimable.Day}`
		elseif loaded() then
			claimButton.Text = `NEXT IN {DailyReward.countdown(DailyReward.secondsToNext(now()))}`
		else
			claimButton.Text = "LOADING..."
		end
	end

	local event = ReplicatedStorage:WaitForChild("DailyClaimEvent") :: RemoteEvent

	local function claim()
		if not claimButton.Active then
			return
		end
		waiting = true
		status.Text = ""
		refresh()
		event:FireServer()
		task.delay(CLAIM_WAIT, function()
			if waiting then
				waiting = false
				status.Text = "Couldn't claim. Try again."
				refresh()
			end
		end)
	end

	event.OnClientEvent:Connect(function(reward: any)
		waiting = false
		if typeof(reward) ~= "table" or typeof(reward.Day) ~= "number" then
			refresh()
			return
		end
		UiStyle.play("Buy")
		local parts: { string } = {}
		if typeof(reward.Cash) == "number" and reward.Cash > 0 then
			table.insert(parts, `+{money(reward.Cash)}`)
		end
		if typeof(reward.DoubleLaunches) == "number" and reward.DoubleLaunches > 0 then
			table.insert(parts, `+{reward.DoubleLaunches} double cash launches`)
		end
		if reward.Prize ~= nil then
			table.insert(parts, "and a week prize")
		end
		status.Text = table.concat(parts, " ") .. "!"
		local tile = tiles[reward.Day]
		if tile then
			UiStyle.flash(tile.frame)
		end
		refresh()
	end)

	local function setOpen(value: boolean)
		if value then
			UiStyle.closeOtherMenus(panel)
			status.Text = ""
			refresh()
			list.CanvasPosition = Vector2.zero
		end
		open = value
		UiStyle.show(panel, value)
	end
	UiStyle.registerMenu(panel, function()
		if open then
			setOpen(false)
		end
	end)

	openButton.Activated:Connect(function()
		setOpen(not open)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	claimButton.Activated:Connect(claim)

	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.ButtonB and open then
			setOpen(false)
		end
	end)

	for _, name in { "DailyLastDay", "DailyStreak", "DailyWeeks", "DailyDoubleLaunches" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The day turns over at UTC midnight with no attribute changing, and the
	-- countdown ticks.
	while true do
		task.wait(1)
		refresh()
	end
end

-- Builds the DAILY button and panel, once.
function DailyMenu.start()
	if not started then
		started = true
		task.spawn(build)
	end
end

-- True while the panel is open; the car takes no input then.
function DailyMenu.isOpen(): boolean
	return open
end

return DailyMenu
