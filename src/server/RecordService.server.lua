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

while true do
	refresh()
	task.wait(R.RefreshEvery)
end
