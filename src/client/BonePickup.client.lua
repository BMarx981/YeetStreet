--!strict
-- BonePickup (LocalScript) -> StarterPlayerScripts.BonePickup
-- The little reward for grabbing a bone in bone rain: a chime that climbs a
-- step for each bone grabbed close together, and a quick bone white glow over
-- the player's car. The HUD's bone counter bounces by itself (Hud).
-- It plays the moment this player's car reaches a bone, by the same hull
-- check the server uses (DinoWeather), and hides that bone here, so the
-- server's lag never shows. The server's word for a bone (BonePickupEvent)
-- then plays nothing if a bone was already played within PredictWindow
-- seconds; on foot, the server's word is what plays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local played: { number } = {} -- when bones were played ahead of the server
local hidden: { [BasePart]: boolean } = {}

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

local function reward()
	local now = os.clock()
	streak = if now - lastAt <= B.StreakGap then streak + 1 else 0
	lastAt = now
	chime.PlaybackSpeed = math.min(B.Sound.Pitch + streak * B.PitchStep, B.PitchMax)
	chime:Play()
	flash()
end

-- Hides a bone's look here; the server removes it for everyone.
local function hide(bone: BasePart)
	hidden[bone] = true
	bone.Destroying:Once(function()
		hidden[bone] = nil
	end)
	for _, piece in bone:GetChildren() do
		if piece:IsA("BasePart") then
			piece.LocalTransparencyModifier = 1
		end
	end
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

RunService.Heartbeat:Connect(function()
	local bones = workspace:FindFirstChild("BoneRain")
	local car = bones and myCar()
	local hull = car and car:FindFirstChild("Hull")
	if not (bones and hull and hull:IsA("BasePart")) then
		return
	end
	overlap.FilterDescendantsInstances = { bones }
	for _, part in workspace:GetPartBoundsInBox(hull.CFrame, hull.Size + B.Reach * 2, overlap) do
		if part.Name == "DinoBone" and not hidden[part] then
			hide(part)
			table.insert(played, os.clock())
			reward()
		end
	end
end)

local event = ReplicatedStorage:WaitForChild("BonePickupEvent") :: RemoteEvent
event.OnClientEvent:Connect(function()
	local now = os.clock()
	while played[1] and now - played[1] > B.PredictWindow do
		table.remove(played, 1)
	end
	if played[1] then
		table.remove(played, 1)
	else
		reward()
	end
end)
