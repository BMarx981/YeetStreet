--!strict
-- CashBalloon (LocalScript) -> StarterPlayerScripts.CashBalloon
-- Shows the car obby's stage cash as green text that pops up beside the pad
-- just reached and floats away like a balloon, swaying, then fades. The
-- server says what was paid on ReplicatedStorage.ObbyReward (ObbyService);
-- the pads are parts tagged ObbyCheckpoint with a Checkpoint attribute. Hud
-- leaves out its own "+N" in the obby, so the cash shows only here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Tuning = require(ReplicatedStorage.Tuning)
local UiStyle = require(script.Parent:WaitForChild("UiStyle"))

local B = Tuning.Obby.Balloon
local player = Players.LocalPlayer

local STROKE_COLOR = Color3.fromRGB(20, 70, 30)
local SWAY = 6 -- degrees each way
local SWAY_TIME = 0.5 -- seconds for one swing
local POP_TIME = 0.25

local function withCommas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function padFor(checkpoint: number): BasePart?
	for _, part in CollectionService:GetTagged("ObbyCheckpoint") do
		if part:IsA("BasePart") and part:GetAttribute("Checkpoint") == checkpoint then
			return part
		end
	end
	return nil
end

-- `lift` raises it over the usual height, so two at one pad don't overlap.
local function balloon(pad: BasePart, text: string, scale: number, lift: number)
	local half = pad.Size / 2
	-- A pad faces the way the course runs, so its right is +X and ahead is -Z.
	local from = Vector3.new(half.X + B.Side, half.Y + B.Height + lift, -half.Z - B.Ahead)
	local start = pad.CFrame:VectorToWorldSpace(from)

	local gui = Instance.new("BillboardGui")
	gui.Name = "CashBalloon"
	gui.Adornee = pad
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromScale(B.Width * scale, B.TextHeight * scale)
	gui.StudsOffsetWorldSpace = start

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.2, 0.2)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = UiStyle.TitleFont
	label.TextColor3 = UiStyle.Cash
	label.TextStrokeColor3 = STROKE_COLOR
	label.TextStrokeTransparency = 0
	label.Rotation = -SWAY
	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	local pop = TweenInfo.new(POP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(label, pop, { Size = UDim2.fromScale(1, 1) }):Play()
	local rise = TweenInfo.new(B.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, rise, { StudsOffsetWorldSpace = start + Vector3.new(0, B.Rise, 0) }):Play()
	local sway = TweenInfo.new(SWAY_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(label, sway, { Rotation = SWAY }):Play()
	local fade = TweenInfo.new(B.FadeTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, B.Time - B.FadeTime)
	TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(B.Time, function()
		gui:Destroy()
	end)
end

local reward = ReplicatedStorage:WaitForChild("ObbyReward") :: RemoteEvent
reward.OnClientEvent:Connect(function(info: { Stage: number, Cash: number, Prize: number })
	local pad = padFor(info.Stage)
	if not pad then
		return
	end
	if info.Cash > 0 then
		balloon(pad, `+${withCommas(info.Cash)}`, 1, 0)
	end
	if info.Prize > 0 then
		task.delay(POP_TIME, function()
			balloon(pad, `WORLD PRIZE +${withCommas(info.Prize)}`, B.PrizeScale, B.TextHeight * 1.5)
		end)
	end
end)
