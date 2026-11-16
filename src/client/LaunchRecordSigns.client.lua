--!strict
-- LaunchRecordSigns (LocalScript) -> StarterPlayerScripts.LaunchRecordSigns
-- Draws the launcher record signs on this client. Each board part tagged
-- LaunchRecordSign (placed by the RecordService script) gets a street garage
-- face: the launcher's name over a hazard stripe, then THIS WEEK and ALL TIME
-- side by side, each the holder's name and distance, with this player's own
-- record in yellow. It redraws whenever the server publishes the launcher in
-- ReplicatedStorage.LaunchRecordData.<LauncherId> (JSON of LaunchRecords.Record).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LaunchRecords = require(ReplicatedStorage.LaunchRecords)
local Tuning = require(ReplicatedStorage.Tuning)
local UiStyle = require(script.Parent.UiStyle)

local R = Tuning.LaunchRecords
local S = Tuning.LaunchRecordSigns
local TAG = "LaunchRecordSign"

local TITLE_SIZE = 52
local HEADING_SIZE = 30
local NAME_SIZE = 30
local VALUE_SIZE = 44
local PAD = 16
local STRIPE_SCALE = 2
local MUTED = Color3.fromRGB(150, 150, 160)

local localPlayer = Players.LocalPlayer :: Player
local data = ReplicatedStorage:WaitForChild("LaunchRecordData")

-- One record's column: a heading, the holder, and the distance.
type Column = { name: TextLabel, value: TextLabel }

local function column(card: Frame, heading: string, x: number, top: number, color: Color3): Column
	local left = if x > 0 then PAD / 2 else PAD
	local width = UDim2.new(0.5, -PAD * 1.5, 0, 0)
	local title = UiStyle.text("Heading", card, HEADING_SIZE, true)
	title.Text = heading
	title.TextColor3 = color
	title.Position = UDim2.new(x, left, 0, top)
	title.Size = width + UDim2.fromOffset(0, HEADING_SIZE + 4)
	local name = UiStyle.text("Holder", card, NAME_SIZE, false)
	name.Position = UDim2.new(x, left, 0, top + HEADING_SIZE + 12)
	name.Size = width + UDim2.fromOffset(0, NAME_SIZE + 6)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local value = UiStyle.text("Distance", card, VALUE_SIZE, true)
	value.Position = UDim2.new(x, left, 0, top + HEADING_SIZE + NAME_SIZE + 24)
	value.Size = width + UDim2.fromOffset(0, VALUE_SIZE + 6)
	return { name = name, value = value }
end

local function fill(col: Column, saved: any)
	local record = LaunchRecords.reconcile(saved)
	if record then
		local color = if record.UserId == localPlayer.UserId then UiStyle.Yellow else Color3.new(1, 1, 1)
		col.name.Text = record.Name
		col.name.TextColor3 = color
		col.value.Text = LaunchRecords.show(record.Value)
		col.value.TextColor3 = color
	else
		col.name.Text = "No record yet"
		col.name.TextColor3 = MUTED
		col.value.Text = ""
	end
end

local function add(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("Face") then
		return
	end
	local id = part:GetAttribute("LauncherId")
	local launcher = if typeof(id) == "string" then LaunchRecords.find(id, R) else nil
	if not launcher then
		return
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = S.PixelsPerStud
	gui.LightInfluence = 0

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = UiStyle.Asphalt
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = gui

	local title = UiStyle.text("Title", card, TITLE_SIZE, true)
	title.Text = launcher.Name
	title.TextColor3 = UiStyle.Yellow
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Position = UDim2.fromOffset(0, 6)
	title.Size = UDim2.new(1, 0, 0, TITLE_SIZE + 6)

	local band = UiStyle.hazard(card, STRIPE_SCALE)
	band.Position = UDim2.fromOffset(0, TITLE_SIZE + 14)

	local top = band.Position.Y.Offset + band.Size.Y.Offset + 14
	local thisWeek = column(card, "THIS WEEK", 0, top, UiStyle.Cash)
	local allTime = column(card, "ALL TIME", 0.5, top, UiStyle.Yellow)
	fill(thisWeek, nil)
	fill(allTime, nil)
	gui.Parent = part

	local source = data:WaitForChild(launcher.Id) :: StringValue
	local function redraw()
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, source.Value)
		local records = if ok and typeof(decoded) == "table" then decoded else {}
		fill(thisWeek, records.ThisWeek)
		fill(allTime, records.AllTime)
	end
	local changed = source.Changed:Connect(redraw)
	gui.Destroying:Connect(function()
		changed:Disconnect()
	end)
	redraw()
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
for _, part in CollectionService:GetTagged(TAG) do
	task.spawn(add, part)
end
