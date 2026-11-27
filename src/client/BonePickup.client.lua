--!strict
-- BonePickup (LocalScript) -> StarterPlayerScripts.BonePickup
-- The little reward for grabbing a bone in bone rain (DinoWeather fires
-- BonePickupEvent): a chime that climbs a step for each bone grabbed close
-- together, and a quick bone white glow over the player's car. The HUD's
-- bone counter bounces by itself (Hud).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Tuning = require(ReplicatedStorage.Tuning)

local B = Tuning.BonePickup

local player = Players.LocalPlayer :: Player

local chime = Instance.new("Sound")
chime.Name = "BoneChime"
chime.SoundId = B.Sound.Id
chime.Volume = B.Sound.Volume
chime.Parent = SoundService

local streak = 0
local lastAt = -math.huge

local function myCar(): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = seat and seat:GetAttribute("CarSeat") and seat.Parent
	return if model and model:IsA("Model") then model else nil
end

-- One Highlight per car, restarted by each bone, so a run of bones never
-- stacks them up.
local flashFade: Tween? = nil
local function flash()
	local car = myCar()
	if not car then
		return
	end
	local glow = car:FindFirstChild("BoneFlash")
	if not (glow and glow:IsA("Highlight")) then
		local h = Instance.new("Highlight")
		h.Name = "BoneFlash"
		h.FillColor = B.Color
		h.OutlineTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = car
		h.Parent = car
		glow = h
	end
	local h = glow :: Highlight
	if flashFade then
		flashFade:Cancel()
	end
	h.FillTransparency = B.FlashTransparency
	local fade = TweenService:Create(h, TweenInfo.new(B.FlashTime), { FillTransparency = 1 })
	flashFade = fade
	fade:Play()
end

local event = ReplicatedStorage:WaitForChild("BonePickupEvent") :: RemoteEvent
event.OnClientEvent:Connect(function()
	local now = os.clock()
	streak = if now - lastAt <= B.StreakGap then streak + 1 else 0
	lastAt = now
	chime.PlaybackSpeed = math.min(B.Sound.Pitch + streak * B.PitchStep, B.PitchMax)
	chime:Play()
	flash()
end)
