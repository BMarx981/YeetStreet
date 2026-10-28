--!strict
-- InviteMenu (ModuleScript) -> StarterPlayerScripts.InviteMenu
-- The invite panel: how many new friends the player has brought in (their
-- InviteFriends attribute, see InviteRewards), progress to the next
-- milestone, every milestone in Tuning.Invites, and an INVITE FRIENDS button
-- that opens Roblox's invite prompt. The INVITE button at the top of the
-- screen opens and closes it; so do the panel's X button and gamepad B.
-- While the panel is open the car gets no input (Controls).
--
-- Rewards arriving on ReplicatedStorage.InviteReward show as a notification
-- with the purchase sound.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Invites = require(ReplicatedStorage.Invites)
local Tuning = require(ReplicatedStorage.Tuning)
local UiStyle = require(script.Parent.UiStyle)

local InviteMenu = {}

local T = Tuning.Invites
local ROW = 30
local NOTICE_TIME = 8

local player = Players.LocalPlayer :: Player
local started = false
local open = false
local busy = false

local function money(n: number): string
	local digits = tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. (digits:gsub("^,", ""))
end

local function friendsText(count: number): string
	return if count == 1 then "1 FRIEND" else `{count} FRIENDS`
end

-- A Roblox notification, retried while the core scripts are still loading.
local function notify(title: string, text: string)
	task.spawn(function()
		for _ = 1, 20 do
			if
				pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
					Title = title,
					Text = text,
					Duration = NOTICE_TIME,
				})
			then
				return
			end
			task.wait(0.5)
		end
	end)
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Invite"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- above the HUD and touch buttons

	-- Under the REPLAY button, left of the fuel bar.
	local openButton = UiStyle.sticker("Open", gui, "INVITE")
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(0.5, -146, 0, 82)
	openButton.Size = UDim2.fromOffset(120, 32)
	UiStyle.springy(openButton)

	local panel, close = UiStyle.panel(gui, "INVITE", Vector2.new(380, 520))
	local top = UiStyle.HeaderHeight

	local status = UiStyle.text("Status", panel, 16, false)
	status.TextColor3 = UiStyle.Yellow
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.fromScale(0, 1)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.Text = ""

	local inviteButton = UiStyle.sticker("InviteFriends", panel, "INVITE FRIENDS")
	inviteButton.TextSize = 24
	inviteButton.AnchorPoint = Vector2.new(0.5, 1)
	inviteButton.Position = UDim2.new(0.5, 0, 1, -28)
	inviteButton.Size = UDim2.new(1, -24, 0, 48)
	UiStyle.springy(inviteButton)

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
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local order = 0
	local function line(name: string, size: number, title: boolean, height: number): TextLabel
		order += 1
		local label = UiStyle.text(name, list, size, title)
		label.LayoutOrder = order
		label.Size = UDim2.new(1, -12, 0, height)
		label.TextWrapped = true
		return label
	end

	local blurb = line("Blurb", 14, false, 38)
	blurb.Text = `Bring a friend who's new to Yeet Street. After their first launch you get {money(T.PerFriend)}, and they start with {money(T.WelcomeCash)}.`

	local count = line("Count", 26, true, 32)
	count.TextColor3 = UiStyle.Yellow

	local nextLabel = line("Next", 14, false, 20)

	order += 1
	local track = Instance.new("Frame")
	track.Name = "Progress"
	track.BackgroundColor3 = UiStyle.Ink
	track.LayoutOrder = order
	track.Size = UDim2.new(1, -12, 0, 14)
	track.Parent = list
	UiStyle.corner(track, 7)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = UiStyle.Yellow
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	UiStyle.corner(fill, 7)

	local heading = line("Milestones", 20, true, 28)
	heading.Text = "MILESTONES"

	local rows: { { frame: Frame, need: TextLabel, milestone: Invites.Milestone } } = {}
	for _, milestone in T.Milestones do
		order += 1
		local row = Instance.new("Frame")
		row.Name = `Milestone{milestone.Friends}`
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -12, 0, ROW)
		row.Parent = list
		UiStyle.corner(row, 6)
		local what = UiStyle.text("What", row, 16, true)
		what.Text = `{friendsText(milestone.Friends)}: {milestone.Label}`
		what.Position = UDim2.fromOffset(8, 0)
		what.Size = UDim2.new(1, -90, 1, 0)
		local need = UiStyle.text("Need", row, 14, false)
		need.TextXAlignment = Enum.TextXAlignment.Right
		need.AnchorPoint = Vector2.new(1, 0)
		need.Position = UDim2.new(1, -8, 0, 0)
		need.Size = UDim2.new(0, 80, 1, 0)
		table.insert(rows, { frame = row, need = need, milestone = milestone })
	end

	local function refresh()
		local friends = player:GetAttribute("InviteFriends")
		local n = if typeof(friends) == "number" then friends else 0
		count.Text = `FRIENDS BROUGHT: {n}`
		local nextUp = Invites.nextMilestone(n, T)
		if nextUp then
			nextLabel.Text = `Next: {friendsText(nextUp.Friends)} for {nextUp.Label}`
			fill.Size = UDim2.fromScale(n / nextUp.Friends, 1)
		else
			nextLabel.Text = "Every milestone reached!"
			fill.Size = UDim2.fromScale(1, 1)
		end
		for _, row in rows do
			local reached = n >= row.milestone.Friends
			row.frame.BackgroundColor3 = if reached then Color3.fromRGB(40, 110, 50) else UiStyle.Ink
			row.need.Text = if reached then "GOT IT" else `{n}/{row.milestone.Friends}`
			row.need.TextColor3 = if reached then UiStyle.Cash else Color3.new(1, 1, 1)
		end
	end
	refresh()
	player:GetAttributeChangedSignal("InviteFriends"):Connect(refresh)

	local function setOpen(value: boolean)
		open = value
		UiStyle.show(panel, value)
		if value then
			status.Text = ""
			refresh()
		end
	end

	local function invite()
		if busy then
			return
		end
		busy = true
		status.Text = ""
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then
			local options = Instance.new("ExperienceInviteOptions")
			options.PromptMessage = "Invite a friend who's new to Yeet Street!"
			options.LaunchData = tostring(player.UserId)
			local shown = pcall(SocialService.PromptGameInvite, SocialService, player, options)
			if not shown then
				status.Text = "Couldn't open the invite window."
				UiStyle.play("Denied")
			end
		else
			status.Text = "Invites aren't available right now."
			UiStyle.play("Denied")
		end
		busy = false
	end

	openButton.Activated:Connect(function()
		setOpen(not open)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	inviteButton.Activated:Connect(invite)

	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.ButtonB and open then
			setOpen(false)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")

	local reward = ReplicatedStorage:WaitForChild("InviteReward")
	if reward:IsA("RemoteEvent") then
		reward.OnClientEvent:Connect(function(info: any)
			if typeof(info) ~= "table" then
				return
			end
			UiStyle.play("Buy")
			if typeof(info.Welcome) == "number" then
				notify("Welcome gift!", `A friend invited you, so here's {money(info.Welcome)} to start.`)
			elseif typeof(info.Cash) == "number" and typeof(info.Added) == "number" then
				local text = `{if info.Added == 1 then "A new friend" else `{info.Added} new friends`} joined from your invite: +{money(info.Cash)}`
				if typeof(info.Prizes) == "table" and #info.Prizes > 0 then
					text ..= `, including {table.concat(info.Prizes, " and ")}`
				end
				notify("Invite reward!", text)
				UiStyle.bounce(openButton)
			end
		end)
	end
end

-- Builds the INVITE button and panel, once.
function InviteMenu.start()
	if not started then
		started = true
		task.spawn(build)
	end
end

-- True while the panel is open; the car takes no input then.
function InviteMenu.isOpen(): boolean
	return open
end

return InviteMenu
