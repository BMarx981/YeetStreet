--!strict
-- SpeedLines (ModuleScript) -> StarterPlayerScripts.SpeedLines
-- Thin white streaks racing out from the middle of the screen toward its
-- edges, stronger the faster the car goes and while the jets burn
-- (Juice.speedLines), plus a wind loop that swells with them
-- (Tuning.JuiceSounds.Wind, silent until it has an Id). They only ever cover the outer ring of the screen, never the car or
-- the road ahead. ChaseCamera sets the strength each frame; without that,
-- they fade away on their own, so other cameras, replays and leaving the car
-- need nothing. Seen only on this client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Tuning = require(ReplicatedStorage.Tuning)

local H = Tuning.Hud
local WIND = Tuning.JuiceSounds.Wind

local SpeedLines = {}

type Line = { frame: Frame, angle: number, radius: number, length: number }

local gui: ScreenGui? = nil
local lines: { Line } = {}
local strength = 0 -- shown now, 0 to 1
local wanted = 0
local wantedAt = -math.huge
local wind: Sound? = nil

-- Out from the middle as a share of half the screen's diagonal: lines start
-- at SpeedLineInner and leave past the corners.
local OUTER = 1.05

local function respawn(line: Line, anywhere: boolean)
	line.angle = math.random() * 2 * math.pi
	local inner = H.SpeedLineInner
	line.radius = if anywhere then inner + math.random() * (OUTER - inner) else inner
	line.length = H.SpeedLineLength * (0.6 + math.random() * 0.8)
	line.frame.Rotation = math.deg(line.angle)
	line.frame.Size = UDim2.fromOffset(line.length, H.SpeedLineWidth)
end

local function build()
	local g = Instance.new("ScreenGui")
	g.Name = "SpeedLines"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = -1 -- under the rest of the HUD
	for i = 1, H.SpeedLineCount do
		local f = Instance.new("Frame")
		f.Name = `Line{i}`
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 1
		f.Parent = g
		local line = { frame = f, angle = 0, radius = 0, length = 0 }
		respawn(line, true)
		table.insert(lines, line)
	end
	g.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	gui = g

	if WIND.Id ~= "" then
		local s = Instance.new("Sound")
		s.Name = "WindLoop"
		s.SoundId = WIND.Id
		s.PlaybackSpeed = WIND.Pitch
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		wind = s
	end
end

local function step(dt: number)
	local g = gui
	if not g then
		return
	end
	-- Without a fresh strength this frame, fade to nothing.
	local target = if os.clock() - wantedAt < 0.1 then wanted else 0
	strength += (target - strength) * (1 - math.exp(-H.SpeedLineFade * dt))
	if strength < 0.01 and target == 0 then
		strength = 0
	end

	local s = wind
	if s then
		s.Volume = WIND.Volume * strength
		if strength > 0 and not s.IsPlaying then
			s:Play()
		elseif strength == 0 and s.IsPlaying then
			s:Stop()
		end
	end

	g.Enabled = strength > 0
	if strength == 0 then
		return
	end
	local size = g.AbsoluteSize
	local middle = size / 2
	local reach = middle.Magnitude
	local speed = H.SpeedLineSpeed * (0.5 + strength)
	local transparency = 1 - H.SpeedLineOpacity * strength
	for _, line in lines do
		line.radius += speed * dt / reach
		if line.radius > OUTER then
			respawn(line, false)
		end
		local at = middle + Vector2.new(math.cos(line.angle), math.sin(line.angle)) * (line.radius * reach)
		line.frame.Position = UDim2.fromOffset(at.X, at.Y)
		line.frame.BackgroundTransparency = transparency
	end
end

-- How strong the lines should be this frame, 0 to 1.
function SpeedLines.set(t: number)
	if not gui then
		build()
		RunService.RenderStepped:Connect(step)
	end
	wanted = t
	wantedAt = os.clock()
end

return SpeedLines
