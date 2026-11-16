--!strict
-- LeaderboardSigns (LocalScript) -> StarterPlayerScripts.LeaderboardSigns
-- Draws the leaderboards at spawn on this client. Each board part tagged
-- LeaderboardSign (placed by the Leaderboards script) gets a street garage
-- face: the board's title over a hazard stripe, then THIS WEEK and ALL TIME
-- side by side, top Tuning.Leaderboards.Top each, with this player's own
-- line in yellow. It redraws whenever the server publishes the board in
-- ReplicatedStorage.LeaderboardData.<BoardId> (JSON of Leaderboard.Row lists).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leaderboard = require(ReplicatedStorage.Leaderboard)
local Tuning = require(ReplicatedStorage.Tuning)
local UiStyle = require(script.Parent.UiStyle)

local B = Tuning.Leaderboards
local S = Tuning.LeaderboardSigns
local TAG = "LeaderboardSign"

local TITLE_SIZE = 56
local HEADING_SIZE = 30
local ROW_SIZE = 22
local ROW_HEIGHT = 30
local PAD = 16
local STRIPE_SCALE = 2
local MUTED = Color3.fromRGB(150, 150, 160)

local localPlayer = Players.LocalPlayer :: Player
local data = ReplicatedStorage:WaitForChild("LeaderboardData")

-- One list's column: a heading and Top rows, each a name and a value.
type Column = { names: { TextLabel }, values: { TextLabel } }

local function column(card: Frame, heading: string, x: number, top: number, color: Color3): Column
	local width = UDim2.new(0.5, -PAD * 1.5, 0, 0)
	local title = UiStyle.text("Heading", card, HEADING_SIZE, true)
	title.Text = heading
	title.TextColor3 = color
	title.Position = UDim2.new(x, if x > 0 then PAD / 2 else PAD, 0, top)
	title.Size = width + UDim2.fromOffset(0, HEADING_SIZE + 4)
	local names: { TextLabel } = {}
	local values: { TextLabel } = {}
	for i = 1, B.Top do
		local y = top + HEADING_SIZE + 8 + (i - 1) * ROW_HEIGHT
		local name = UiStyle.text(`Name{i}`, card, ROW_SIZE, false)
		name.Position = UDim2.new(x, if x > 0 then PAD / 2 else PAD, 0, y)
		name.Size = UDim2.new(0.5, -PAD * 1.5 - 110, 0, ROW_HEIGHT)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local value = UiStyle.text(`Value{i}`, card, ROW_SIZE, false)
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(x + 0.5, if x > 0 then -PAD else -PAD / 2, 0, y)
		value.Size = UDim2.fromOffset(110, ROW_HEIGHT)
		value.TextXAlignment = Enum.TextXAlignment.Right
		names[i] = name
		values[i] = value
	end
	return { names = names, values = values }
end

local function fill(col: Column, rows: { Leaderboard.Row }, kind: string)
	for i = 1, B.Top do
		local row = rows[i]
		local name, value = col.names[i], col.values[i]
		if row then
			local mine = row.UserId == localPlayer.UserId
			name.Text = `{row.Rank}. {row.Name}`
			value.Text = Leaderboard.show(kind, row.Value, B)
			name.TextColor3 = if mine then UiStyle.Yellow else Color3.new(1, 1, 1)
			value.TextColor3 = name.TextColor3
		else
			name.Text = if i == 1 then "No one yet" else ""
			name.TextColor3 = MUTED
			value.Text = ""
		end
	end
end

local function add(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("Face") then
		return
	end
	local id = part:GetAttribute("BoardId")
	local board = if typeof(id) == "string" then Leaderboard.find(id, B) else nil
	if not board then
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
	title.Text = board.Title
	title.TextColor3 = UiStyle.Yellow
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Position = UDim2.fromOffset(0, 6)
	title.Size = UDim2.new(1, 0, 0, TITLE_SIZE + 6)

	local band = UiStyle.hazard(card, STRIPE_SCALE)
	band.Position = UDim2.fromOffset(0, TITLE_SIZE + 14)

	local top = band.Position.Y.Offset + band.Size.Y.Offset + 10
	local thisWeek = column(card, "THIS WEEK", 0, top, UiStyle.Cash)
	local allTime = column(card, "ALL TIME", 0.5, top, UiStyle.Yellow)
	fill(thisWeek, {}, board.Kind)
	fill(allTime, {}, board.Kind)
	gui.Parent = part

	local source = data:WaitForChild(board.Id)
	local function redraw()
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, (source :: StringValue).Value)
		local lists = if ok and typeof(decoded) == "table" then decoded else {}
		fill(thisWeek, lists.ThisWeek or {}, board.Kind)
		fill(allTime, lists.AllTime or {}, board.Kind)
	end
	(source :: StringValue).Changed:Connect(redraw)
	redraw()
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
for _, part in CollectionService:GetTagged(TAG) do
	task.spawn(add, part)
end
