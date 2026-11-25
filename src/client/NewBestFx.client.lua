--!strict
-- NewBestFx (LocalScript) -> StarterPlayerScripts.NewBestFx
-- When a run beats its player's Best (ScoreService fires ReplicatedStorage
-- .NewBest), that player gets a big NEW BEST banner with the score, a
-- fanfare, and confetti falling down the screen. Everyone else gets one line
-- low on the screen, for new bests of Tuning.NewBest.ShoutFrom or more.
-- Nothing shows while the tutorial is running, so it can't cover the prompts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Tuning = require(ReplicatedStorage.Tuning)
local TutorialHints = require(script.Parent.TutorialHints)
local UiStyle = require(script.Parent.UiStyle)

local NB = Tuning.NewBest
local FADE = TweenInfo.new(0.4)
local CONFETTI_COLORS = {
	UiStyle.Yellow,
	UiStyle.Red,
	UiStyle.Cash,
	Color3.fromRGB(80, 160, 255),
	Color3.new(1, 1, 1),
}

local localPlayer = Players.LocalPlayer :: Player
local random = Random.new()

local gui = Instance.new("ScreenGui")
gui.Name = "NewBest"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4 -- under the garage panel
gui.IgnoreGuiInset = true -- confetti falls from the very top
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local title = UiStyle.text("Title", gui, 64, true)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.55)
title.Size = UDim2.fromOffset(420, 72)
title.TextXAlignment = Enum.TextXAlignment.Center
title.TextColor3 = UiStyle.Yellow
title.Text = "NEW BEST!"
title.Visible = false

local scoreLabel = UiStyle.text("Score", gui, 40, true)
scoreLabel.AnchorPoint = Vector2.new(0.5, 0)
scoreLabel.Position = UDim2.new(0.5, 0, 0.55, 40)
scoreLabel.Size = UDim2.fromOffset(420, 48)
scoreLabel.TextXAlignment = Enum.TextXAlignment.Center
scoreLabel.Visible = false

local line = UiStyle.text("Line", gui, 22, false)
line.AnchorPoint = Vector2.new(0.5, 0.5)
line.Position = UDim2.fromScale(0.5, 0.8)
line.Size = UDim2.new(1, -32, 0, 30)
line.TextXAlignment = Enum.TextXAlignment.Center
line.RichText = true
UiStyle.stroke(line, 2, UiStyle.Ink, false)
line.Visible = false

local fanfare = Instance.new("Sound")
fanfare.Name = "NewBestFanfare"
fanfare.SoundId = NB.Sound.Id
fanfare.PlaybackSpeed = NB.Sound.Pitch
fanfare.Volume = NB.Sound.Volume
fanfare.Parent = SoundService

local function withCommas(n: number): string
	local digits = tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (digits:gsub("^,", ""))
end

local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- Shows labels, then fades them after `time`, unless shown again by then.
local showings: { [TextLabel]: number } = {}
local function showFor(labels: { TextLabel }, time: number)
	for _, label in labels do
		local mine = (showings[label] or 0) + 1
		showings[label] = mine
		label.TextTransparency = 0
		local outline = label:FindFirstChildWhichIsA("UIStroke")
		if outline then
			outline.Transparency = 0
		end
		label.Visible = true
		task.delay(time, function()
			if showings[label] ~= mine then
				return
			end
			TweenService:Create(label, FADE, { TextTransparency = 1 }):Play()
			if outline then
				TweenService:Create(outline, FADE, { Transparency = 1 }):Play()
			end
		end)
	end
end

local function confetti()
	for _ = 1, NB.ConfettiCount do
		local piece = Instance.new("Frame")
		piece.Name = "Confetti"
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = CONFETTI_COLORS[random:NextInteger(1, #CONFETTI_COLORS)]
		local size = random:NextNumber(NB.ConfettiSize[1], NB.ConfettiSize[2])
		piece.Size = UDim2.fromOffset(size, size * 0.6)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		local x = random:NextNumber(0, 1)
		piece.Position = UDim2.fromScale(x, random:NextNumber(-0.15, -0.02))
		piece.Rotation = random:NextNumber(0, 360)
		piece.Parent = gui
		local fall = TweenInfo.new(
			random:NextNumber(NB.ConfettiFall[1], NB.ConfettiFall[2]),
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		local tween = TweenService:Create(piece, fall, {
			Position = UDim2.fromScale(x + random:NextNumber(-0.1, 0.1), 1.1),
			Rotation = piece.Rotation + random:NextNumber(-720, 720),
		})
		tween.Completed:Connect(function()
			piece:Destroy()
		end)
		tween:Play()
	end
end

local remote = ReplicatedStorage:WaitForChild("NewBest")
if not remote:IsA("RemoteEvent") then
	warn("NewBestFx: ReplicatedStorage.NewBest is not a RemoteEvent; new bests show nothing")
	return
end
remote.OnClientEvent:Connect(function(player: Player, best: number)
	if TutorialHints.isRunning() then
		return
	end
	if player == localPlayer then
		scoreLabel.Text = withCommas(best)
		showFor({ title, scoreLabel }, NB.BannerTime)
		UiStyle.bounce(title)
		fanfare:Play()
		confetti()
	else
		line.Text = `<font color="#FFC400">{escape(player.DisplayName)}</font> beat their best: {withCommas(best)}!`
		showFor({ line }, NB.LineTime)
	end
end)
