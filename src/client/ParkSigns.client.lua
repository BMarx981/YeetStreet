--!strict
-- ParkSigns (LocalScript) -> StarterPlayerScripts.ParkSigns
-- Paints each park's sign board (built by ParkBuilder) like its teleport menu
-- card, on both faces, and turns the boards slowly. The turn only happens on
-- each client, timed from the server's clock so every player sees the same.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local ParkLooks = require(ReplicatedStorage.ParkLooks)
local Tuning = require(ReplicatedStorage.Tuning)
local UiStyle = require(script.Parent.UiStyle)

local S = Tuning.ParkSign
local TAG = "ParkSign"

local BADGE_SIZE = 160
local BADGE_RIM = 8
local NAME_STROKE = 6
local STRIPE_SCALE = 3

-- Where each board sits before its turn.
local boards: { [BasePart]: CFrame } = {}

local function paintFace(board: BasePart, face: Enum.NormalId, area: MapLayout.Area, look: ParkLooks.Look)
	local gui = Instance.new("SurfaceGui")
	gui.Name = `Sign{face.Name}`
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = S.PixelsPerStud
	gui.LightInfluence = 0

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromHex(look.color)
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = gui
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	shade.Parent = card

	local badge = UiStyle.badge(card, look.icon, BADGE_SIZE)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 24, 0.5, -18)
	badge:FindFirstChildWhichIsA("UIStroke").Thickness = BADGE_RIM

	local name = UiStyle.text("Name", card, 92, true)
	name.Text = string.upper(area.Name)
	name.Position = UDim2.fromOffset(208, 34)
	name.Size = UDim2.new(1, -224, 0, 96)
	name:FindFirstChildWhichIsA("UIStroke").Thickness = NAME_STROKE

	local tagline = UiStyle.text("Tagline", card, 44, false)
	tagline.Text = look.tagline
	tagline.Position = UDim2.fromOffset(208, 136)
	tagline.Size = UDim2.new(1, -224, 0, 44)

	local band =
		UiStyle.hazard(card, STRIPE_SCALE, Color3.fromHex(look.sign.stripe), Color3.fromHex(look.sign.stripeBack))
	band.AnchorPoint = Vector2.new(0, 1)
	band.Position = UDim2.fromScale(0, 1)

	gui.Parent = board
end

local function add(board: Instance)
	if not board:IsA("BasePart") then
		return
	end
	local id = board:GetAttribute("AreaId")
	local area = if typeof(id) == "string" then MapLayout.find(Tuning.Map.Areas :: any, id) else nil
	if not area then
		return
	end
	local look = ParkLooks.of(area.Id)
	paintFace(board, Enum.NormalId.Front, area, look)
	paintFace(board, Enum.NormalId.Back, area, look)
	boards[board] = board.CFrame
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(board: Instance)
	boards[board :: BasePart] = nil
end)
for _, board in CollectionService:GetTagged(TAG) do
	add(board)
end

RunService.Heartbeat:Connect(function()
	local turn = CFrame.Angles(0, math.rad(workspace:GetServerTimeNow() * S.SpinSpeed % 360), 0)
	for board, rest in boards do
		board.CFrame = rest * turn
	end
end)
