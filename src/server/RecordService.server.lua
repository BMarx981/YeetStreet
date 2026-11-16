--!strict
-- RecordService (Script) -> ServerScriptService.RecordService
-- The launcher records (LaunchRecords) on the server.
--
-- ScoreService reports each unflagged run from a record launcher on
-- ServerStorage.LauncherRun. A distance that beats this server's copy of the
-- launcher's weekly or all-time record is saved through
-- PlayerData.raiseRecord, which keeps whichever is farther if another server
-- got there first. The new record shows here at once.
--
-- Every RefreshEvery seconds every record is read again
-- (PlayerData.readRecords), keeping the farther of what was read and what
-- this server holds. Each launcher's records are published for clients as
-- JSON in ReplicatedStorage.LaunchRecordData.<Id>: { Week, AllTime,
-- ThisWeek }, each a LaunchRecords.Record, or missing when there is none.
-- Studio keeps its records in a store of its own.
--
-- It also places each launcher's sign beside its first pad
-- (Tuning.LaunchRecordSigns), which every client draws from that JSON
-- (LaunchRecordSigns).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local LaunchRecords = require(ReplicatedStorage.LaunchRecords)
local Leaderboard = require(ReplicatedStorage.Leaderboard)
local Tuning = require(ReplicatedStorage.Tuning)
local PlayerData = require(ServerScriptService.PlayerData)

local R = Tuning.LaunchRecords
local storeName = LaunchRecords.storeName(RunService:IsStudio(), R)

-- This server's copy of every record, by key.
local held: { [string]: LaunchRecords.Record } = {}

local folder = Instance.new("Folder")
folder.Name = "LaunchRecordData"
folder.Parent = ReplicatedStorage
local published: { [string]: StringValue } = {}
for _, launcher in R.Launchers do
	local value = Instance.new("StringValue")
	value.Name = launcher.Id
	value.Parent = folder
	published[launcher.Id] = value
end

local function publish()
	local week = Leaderboard.week(os.time())
	for _, launcher in R.Launchers do
		published[launcher.Id].Value = HttpService:JSONEncode({
			Week = week,
			AllTime = held[LaunchRecords.key(launcher.Id, nil)],
			ThisWeek = held[LaunchRecords.key(launcher.Id, week)],
		})
	end
end

-- Keeps the farther of `record` and the one held for `key`.
local function hold(key: string, record: LaunchRecords.Record)
	if LaunchRecords.beats(held[key], record.Value) then
		held[key] = record
	end
end

-- `player` flew `value` studs, beating the record `key` as this server knows it.
local function claim(player: Player, key: string, value: number)
	local record = { UserId = player.UserId, Name = player.DisplayName, Value = value }
	hold(key, record)
	publish()
	local saved = PlayerData.raiseRecord(storeName, key, record)
	if saved then
		hold(key, saved)
		publish()
	end
end

local launcherRun = ServerStorage:WaitForChild("LauncherRun") :: BindableEvent
launcherRun.Event:Connect(function(player: Player, launcherId: string, distance: number)
	if not LaunchRecords.find(launcherId, R) then
		return
	end
	local value = LaunchRecords.encode(distance)
	local week = Leaderboard.week(os.time())
	for _, key in { LaunchRecords.key(launcherId, nil), LaunchRecords.key(launcherId, week) } do
		if LaunchRecords.beats(held[key], value) then
			task.spawn(claim, player, key, value)
		end
	end
end)

local function refresh()
	local week = Leaderboard.week(os.time())
	local keys: { string } = {}
	for _, launcher in R.Launchers do
		table.insert(keys, LaunchRecords.key(launcher.Id, nil))
		table.insert(keys, LaunchRecords.key(launcher.Id, week))
	end
	local found = PlayerData.readRecords(storeName, keys)
	if found then
		for key, record in found do
			hold(key, record)
		end
	end
	publish()
end

-- The signs: plain tagged parts on posts, which each client draws
-- (LaunchRecordSigns). Built at start, so nothing is saved in the place.
local S = Tuning.LaunchRecordSigns
local INK = Color3.fromRGB(22, 22, 26)

type Offset = { Back: boolean?, Side: number?, Ahead: number?, Out: number?, Turn: number? }
local NO_OFFSET: Offset = {}

-- `launcher`'s model, waiting for its park to be built.
local function launcherModel(launcher: LaunchRecords.Launcher): Instance?
	local at: Instance = workspace
	for name in string.gmatch(launcher.Path, "[^%.]+") do
		local child = at:WaitForChild(name, S.FindWait)
		if not child then
			warn(`RecordService: no {launcher.Path} for the {launcher.Id} sign`)
			return nil
		end
		at = child
	end
	return at
end

-- How far `part` reaches either side of its middle along `axis`.
local function reach(part: BasePart, axis: Vector3): number
	local cf, size = part.CFrame, part.Size
	return (
		math.abs(cf.RightVector:Dot(axis)) * size.X
		+ math.abs(cf.UpVector:Dot(axis)) * size.Y
		+ math.abs(cf.LookVector:Dot(axis)) * size.Z
	) / 2
end

local function placeSign(launcher: LaunchRecords.Launcher, signs: Folder)
	local model = launcherModel(launcher)
	if not model then
		return
	end
	local pads: { BasePart } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("LaunchSpeed") and part:GetAttribute("NoRun") ~= true then
			table.insert(pads, part)
		end
	end
	if #pads == 0 then
		warn(`RecordService: no launch pads in {launcher.Path} for its sign`)
		return
	end

	-- The way cars come in across the ground (the way runs leave, unless the
	-- launcher is driven into backwards), and the driver's right.
	local offset = S.Offsets[launcher.Id] or NO_OFFSET
	local way = Vector3.zero
	for _, pad in pads do
		local direction = pad:GetAttribute("LaunchDirection")
		local push = if typeof(direction) == "Vector3" then direction else pad.CFrame.LookVector
		way += Vector3.new(push.X, 0, push.Z)
	end
	local ahead = (if way.Magnitude > 1e-3 then way.Unit else -Vector3.zAxis) * (if offset.Back then -1 else 1)
	local right = ahead:Cross(Vector3.yAxis)

	local side = offset.Side or S.Side
	local first = pads[1]
	local outer = -math.huge
	for _, pad in pads do
		if pad.Position:Dot(ahead) < first.Position:Dot(ahead) then
			first = pad
		end
		outer = math.max(outer, pad.Position:Dot(right) * side + reach(pad, right))
	end
	local out = outer + S.Gap + S.Width / 2 + (offset.Out or 0)
	local flat = Vector3.new(first.Position.X, 0, first.Position.Z)
	local spot = flat + right * (side * out - first.Position:Dot(right)) + ahead * (offset.Ahead or 0)

	local top = first.Position.Y + reach(first, Vector3.yAxis) + S.RayAbove
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { signs }
	local hit = workspace:Raycast(Vector3.new(spot.X, top, spot.Z), Vector3.new(0, -S.RayDown, 0), params)
	local ground = if hit then hit.Position.Y else first.Position.Y - reach(first, Vector3.yAxis)
	local base = CFrame.lookAt(Vector3.new(spot.X, ground, spot.Z), Vector3.new(spot.X, ground, spot.Z) - ahead)
		* CFrame.Angles(0, -math.rad(S.TurnIn * side + (offset.Turn or 0)), 0)

	local sign = Instance.new("Model")
	sign.Name = launcher.Id
	for _, x in { -1, 1 } do
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Anchored = true
		post.Size = Vector3.new(S.PostWidth, S.BottomHeight, S.PostWidth)
		post.CFrame = base * CFrame.new(x * (S.Width / 2 - S.PostWidth * 2), S.BottomHeight / 2, 0)
		post.Color = INK
		post.Material = Enum.Material.Metal
		post.Parent = sign
	end
	local board = Instance.new("Part")
	board.Name = "Board"
	board.Anchored = true
	board.Size = Vector3.new(S.Width, S.Height, S.Thickness)
	board.CFrame = base * CFrame.new(0, S.BottomHeight + S.Height / 2, 0)
	board.Color = INK
	board.Material = Enum.Material.SmoothPlastic
	board:SetAttribute("LauncherId", launcher.Id)
	board:AddTag("LaunchRecordSign")
	board.Parent = sign
	sign.Parent = signs
end

local signs = Instance.new("Folder")
signs.Name = "LaunchRecordSigns"
signs.Parent = workspace
for _, launcher in R.Launchers do
	task.spawn(placeSign, launcher, signs)
end

while true do
	refresh()
	task.wait(R.RefreshEvery)
end
