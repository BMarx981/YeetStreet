--!strict
-- CoinLook (LocalScript) -> StarterPlayerScripts.CoinLook
-- Draws this player's coins and gems (CoinService) from the JSON in
-- ReplicatedStorage.CoinLines: spinning gold coins along each launcher's
-- flight path and a glowing gem above it, made here and seen only here.
-- A coin the server says this player grabbed (CoinPickup) hides with a chime
-- that climbs with each coin in the run, until the run ends (CoinsBack). A
-- grabbed gem hides with a ding and a "+$" popup (Hud) until it comes back.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Rebirth = require(ReplicatedStorage.Rebirth)
local Tuning = require(ReplicatedStorage.Tuning)
local Hud = require(script.Parent.Hud)

local C = Tuning.Coins

local player = Players.LocalPlayer :: Player

type Spinner = { part: BasePart, at: Vector3 }

local folder = Instance.new("Folder")
folder.Name = "MyCoins"
folder.Parent = workspace

-- By line, then index; and each line's gem.
local coinParts: { { Spinner } } = {}
local gemParts: { [number]: Spinner } = {}
local spinners: { Spinner } = {}
local gemShowing = 0 -- counts gem hides, so an old timer doesn't show a newer one
local gemHides: { [number]: number } = {}
local grabbed = 0

local function sound(name: string, spec: { Id: string, Pitch: number, Volume: number }): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = spec.Id
	s.PlaybackSpeed = spec.Pitch
	s.Volume = spec.Volume
	s.Parent = SoundService
	return s
end
local chime = sound("CoinChime", C.CoinSound)
local ding = sound("GemDing", C.GemSound)

local function loose(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder
end

local function coin(at: Vector3): Spinner
	local part = Instance.new("Part")
	part.Name = "Coin"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(C.CoinSize / 6, C.CoinSize, C.CoinSize)
	part.Material = Enum.Material.Neon
	part.Color = C.CoinColor
	part.CFrame = CFrame.new(at)
	loose(part)
	return { part = part, at = at }
end

local function gem(at: Vector3): Spinner
	local part = Instance.new("Part")
	part.Name = "Gem"
	part.Size = Vector3.one * C.GemSize
	part.Material = Enum.Material.Neon
	part.Color = C.GemColor
	part.CFrame = CFrame.new(at)
	local glow = Instance.new("PointLight")
	glow.Color = C.GemColor
	glow.Range = C.GemSize * 3
	glow.Parent = part
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = C.GemColor
	sparkles.Parent = part
	loose(part)
	return { part = part, at = at }
end

local function show(s: Spinner, visible: boolean)
	s.part.Transparency = if visible then 0 else 1
	for _, child in s.part:GetChildren() do
		if child:IsA("Light") or child:IsA("Sparkles") then
			child.Enabled = visible
		end
	end
end

local function build(source: StringValue)
	folder:ClearAllChildren()
	coinParts, gemParts, spinners = {}, {}, {}
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, source.Value)
	if not ok or typeof(decoded) ~= "table" then
		return
	end
	for li, line in decoded do
		local row: { Spinner } = {}
		for _, p in line.Coins or {} do
			local s = coin(Vector3.new(p[1], p[2], p[3]))
			table.insert(row, s)
			table.insert(spinners, s)
		end
		coinParts[li] = row
		local g = line.Gem
		if g then
			local s = gem(Vector3.new(g[1], g[2], g[3]))
			gemParts[li] = s
			table.insert(spinners, s)
		end
	end
end

local lines = ReplicatedStorage:WaitForChild("CoinLines")
if not lines:IsA("StringValue") then
	warn("CoinLook: ReplicatedStorage.CoinLines is not a StringValue; no coins show")
	return
end
lines.Changed:Connect(function()
	build(lines)
end)
build(lines)

local pickup = ReplicatedStorage:WaitForChild("CoinPickup") :: RemoteEvent
pickup.OnClientEvent:Connect(function(kind: string, li: number, value: number)
	if kind == "coin" then
		local row = coinParts[li]
		local s = row and row[value]
		if s then
			show(s, false)
		end
		chime.PlaybackSpeed = math.min(C.CoinSound.Pitch + grabbed * C.PitchStep, C.PitchMax)
		chime:Play()
		grabbed += 1
	elseif kind == "gem" then
		local s = gemParts[li]
		if s then
			show(s, false)
			gemShowing += 1
			local mine = gemShowing
			gemHides[li] = mine
			task.delay(value, function()
				if gemHides[li] == mine then
					show(s, true)
				end
			end)
		end
		ding:Play()
		local cash = C.GemCash * Rebirth.payMultiplier(Rebirth.count(player:GetAttribute("Rebirths")), Tuning.Rebirth)
		Hud.bonus("GEM!", cash)
	end
end)

local back = ReplicatedStorage:WaitForChild("CoinsBack") :: RemoteEvent
back.OnClientEvent:Connect(function()
	grabbed = 0
	for _, row in coinParts do
		for _, s in row do
			show(s, true)
		end
	end
end)

local angle = 0
RunService.RenderStepped:Connect(function(dt: number)
	angle = (angle + C.Spin * dt) % (2 * math.pi)
	local turn = CFrame.Angles(0, angle, 0)
	for _, s in spinners do
		s.part.CFrame = CFrame.new(s.at) * turn
	end
end)
