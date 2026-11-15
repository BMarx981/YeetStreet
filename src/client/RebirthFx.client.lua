--!strict
-- RebirthFx (LocalScript) -> StarterPlayerScripts.RebirthFx
-- When anyone is reborn (Garage fires ReplicatedStorage.Reborn to every
-- client), shows a banner on this screen and sets off a burst of sparks with
-- a sound on their new car, in the color of the trail they now wear (Trails).
-- The car comes nil when it isn't on this client (far away with streaming,
-- or the respawn was slow); then only the banner shows.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Rebirth = require(ReplicatedStorage.Rebirth)
local Trails = require(ReplicatedStorage.Trails)
local Tuning = require(ReplicatedStorage.Tuning)
local UiStyle = require(script.Parent.UiStyle)

local FX = Tuning.RebirthFx
local FADE = TweenInfo.new(0.4)

local localPlayer = Players.LocalPlayer :: Player

local gui = Instance.new("ScreenGui")
gui.Name = "RebirthBanner"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4 -- under the garage panel
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local banner = UiStyle.text("Banner", gui, 34, true)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.fromScale(0.5, 0.2)
banner.Size = UDim2.new(1, -32, 0, 44)
banner.TextXAlignment = Enum.TextXAlignment.Center
banner.TextScaled = true
banner.Visible = false
local outline = banner:FindFirstChildWhichIsA("UIStroke")
local shown = 0

local function colorFor(count: number): Color3
	local id = Trails.forRebirths(count, Tuning.Trails.Rebirth)
	local look = if id then (Tuning.Trails.Looks :: { [string]: { Color: { number } } })[id] else nil
	return if look then Color3.fromRGB(look.Color[1], look.Color[2], look.Color[3]) else UiStyle.Yellow
end

local function showBanner(text: string, color: Color3)
	shown += 1
	local mine = shown
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency = 0
	if outline then
		outline.Transparency = 0
	end
	banner.Visible = true
	task.delay(FX.BannerTime, function()
		if shown ~= mine then
			return
		end
		TweenService:Create(banner, FADE, { TextTransparency = 1 }):Play()
		if outline then
			TweenService:Create(outline, FADE, { Transparency = 1 }):Play()
		end
	end)
end

local function burst(car: Model, color: Color3)
	local hull = car:WaitForChild("Hull", 2)
	if not (hull and hull:IsA("BasePart")) then
		return
	end
	local at = Instance.new("Attachment")
	at.Name = "RebirthBurst"
	at.Parent = hull
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Rate = 0
	sparks.Speed = NumberRange.new(FX.BurstSpeed[1], FX.BurstSpeed[2])
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(FX.BurstLifetime * 0.6, FX.BurstLifetime)
	sparks.Size = NumberSequence.new(FX.BurstSize, 0)
	sparks.Drag = 2
	sparks.Parent = at
	sparks:Emit(FX.BurstCount)
	local sound = Instance.new("Sound")
	sound.SoundId = FX.Sound.Id
	sound.PlaybackSpeed = FX.Sound.Pitch
	sound.Volume = FX.Sound.Volume
	sound.RollOffMaxDistance = FX.SoundReach
	sound.Parent = hull
	sound:Play()
	Debris:AddItem(at, FX.BurstLifetime + 1)
	Debris:AddItem(sound, 5)
end

local reborn = ReplicatedStorage:WaitForChild("Reborn")
if not reborn:IsA("RemoteEvent") then
	warn("RebirthFx: ReplicatedStorage.Reborn is not a RemoteEvent; rebirths show nothing")
	return
end
reborn.OnClientEvent:Connect(function(player: Player, count: number, car: Model?)
	local color = colorFor(count)
	local pay = Rebirth.payMultiplier(count, Tuning.Rebirth)
	local who = if player == localPlayer then "You were" else `{player.DisplayName} was`
	showBanner(`{who} reborn! Run pay x{pay}`, color)
	if car and car:IsA("Model") then
		burst(car, color)
	end
end)
