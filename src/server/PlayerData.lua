--!strict
-- PlayerData (ModuleScript) -> ServerScriptService.PlayerData
-- Loads and saves every player's data. The only code that calls
-- DataStoreService.
--
-- Each record is session locked (SaveRecord): it is claimed on join, written
-- every Tuning.Save.AutosaveInterval, and written and released on leave and
-- when the server shuts down. Loaded data goes through Economy.reconcile, so
-- the rest of the game always sees a valid state.
--
-- If the DataStore can't be reached (in Studio without API access, or an
-- outage), the player plays on fresh data that is never saved, so a failed
-- load can't overwrite real progress. Output says so.
--
-- Other scripts read with PlayerData.get or wait with PlayerData.waitFor, and
-- change data with PlayerData.update.
--
-- It also keeps invite credits (InviteRewards) in a store of their own, keyed
-- by the inviter: the UserIds of friends they brought in. A friend's server
-- adds to it, since the inviter's record is locked to their own server.
--
-- It also writes and reads the global leaderboards' ordered stores
-- (raiseBoard, readBoard), for the Leaderboards script, and the launcher
-- records (raiseRecord, readRecords), for the LaunchRecords script.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DailyReward = require(ReplicatedStorage.DailyReward)
local Economy = require(ReplicatedStorage.Economy)
local EngineSound = require(ReplicatedStorage.EngineSound)
local Flames = require(ReplicatedStorage.Flames)
local Invites = require(ReplicatedStorage.Invites)
local LaunchRecords = require(ReplicatedStorage.LaunchRecords)
local Leaderboard = require(ReplicatedStorage.Leaderboard)
local Purchases = require(ReplicatedStorage.Purchases)
local Rebirth = require(ReplicatedStorage.Rebirth)
local SaveRecord = require(ReplicatedStorage.SaveRecord)
local Trails = require(ReplicatedStorage.Trails)
local Tutorial = require(ReplicatedStorage.Tutorial)
local Tuning = require(ReplicatedStorage.Tuning)

local S = Tuning.Save

-- Bump only for a change old saves can't be reconciled from.
local STORE_NAME = "PlayerData1"
local VERSION = 1
local CREDIT_STORE_NAME = "InviteCredits1"

export type Data = {
	Version: number,
	Economy: Economy.State,
	Best: number, -- best run score
	BestAirtime: number, -- seconds, the longest airtime of one run
	ThisWeek: Leaderboard.Week, -- this week's bests, as the boards store them
	Invites: Invites.State,
	ObbyCleared: boolean, -- whether the obby's world prize has been paid
	Rebirths: number, -- times reborn (Rebirth)
	EngineSound: string, -- the engine sound setting's name (EngineSound.setting)
	Daily: DailyReward.State, -- the daily reward calendar (DailyRewards)
	Flames: Flames.State, -- prize jet flames (FlameService)
	Trails: Trails.State, -- prize trails and the trail picked (TrailService)
	Purchases: Purchases.State, -- Robux receipts already granted (RobuxShop)
	TutorialDone: boolean, -- finished or skipped the tutorial (TutorialService)
}

type Session = {
	data: Data,
	saves: boolean, -- false when the load failed: this data is never written
	new: boolean, -- true when the player had no saved record
}

local PlayerData = {}

-- One id per server, since game.JobId is empty in Studio.
local sessionId = HttpService:GenerateGUID(false)
local sessions: { [Player]: Session } = {}
local loaded = Instance.new("BindableEvent")
local pendingSaves = 0

-- Players whose leave save is still running, so waitFor stops waiting on them.
local leaving: { [Player]: boolean } = {}

local storeOk, store = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
local storeProblem = if storeOk then "" else tostring(store)
if storeOk and RunService:IsStudio() then
	-- One read up front, so a Studio session without API access doesn't sit
	-- through every retry for each player.
	local probeOk, err = pcall(store.GetAsync, store, "Probe")
	if not probeOk then
		storeOk = false
		storeProblem = tostring(err)
	end
end
if not storeOk then
	warn(`PlayerData: no DataStore, progress won't save ({storeProblem})`)
end
local creditStore = if storeOk then DataStoreService:GetDataStore(CREDIT_STORE_NAME) else nil

local function key(player: Player): string
	return `Player_{player.UserId}`
end

local function reconcile(saved: any): Data
	local raw = if typeof(saved) == "table" then saved else {}
	local best = raw.Best
	local airtime = raw.BestAirtime
	return {
		Version = VERSION,
		Economy = Economy.reconcile(raw.Economy, Tuning.Ladder),
		Best = if typeof(best) == "number" and best >= 0 then best else 0,
		BestAirtime = if typeof(airtime) == "number" and airtime >= 0 and airtime < math.huge then airtime else 0,
		ThisWeek = Leaderboard.weekRecord(raw.ThisWeek, Leaderboard.week(os.time())),
		Invites = Invites.reconcile(raw.Invites),
		ObbyCleared = raw.ObbyCleared == true,
		Rebirths = Rebirth.count(raw.Rebirths),
		EngineSound = EngineSound.setting(raw.EngineSound, Tuning.EngineSound.Settings),
		Daily = DailyReward.reconcile(raw.Daily),
		Flames = Flames.reconcile(raw.Flames, Tuning.Flames.Looks),
		Trails = Trails.reconcile(raw.Trails, Tuning.Trails.Prizes),
		Purchases = Purchases.reconcile(raw.Purchases),
		TutorialDone = Tutorial.reconcile(raw.TutorialDone, raw.Best),
	}
end

-- Claims the player's record, retrying while another server holds it and
-- forcing the last try. Returns whether it was claimed, and the saved data
-- (nil for a first join).
local function claim(player: Player): (boolean, any)
	local lastProblem = "never tried"
	for attempt = 1, S.LoadAttempts do
		local claimed: SaveRecord.Record? = nil
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(stored: any): SaveRecord.Record?
				local record, reason =
					SaveRecord.claim(stored, sessionId, os.time(), S.LockTimeout, attempt == S.LoadAttempts)
				claimed = record
				lastProblem = reason or ""
				return record
			end)
		end)
		if ok and claimed then
			return true, claimed.Data
		end
		if not ok then
			lastProblem = tostring(err)
		end
		if attempt < S.LoadAttempts then
			task.wait(S.LoadRetryGap)
		end
		if not player.Parent then
			return false, nil
		end
	end
	warn(`PlayerData: couldn't load {player.Name}, progress won't save ({lastProblem})`)
	return false, nil
end

-- Writes the player's data, and releases the lock if `release`. Returns
-- whether it was written.
local function save(player: Player, session: Session, release: boolean): boolean
	if not session.saves then
		return false
	end
	pendingSaves += 1
	local problem: string? = nil
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(stored: any): SaveRecord.Record?
			local record, reason = SaveRecord.write(stored, sessionId, os.time(), session.data, release)
			problem = reason
			return record
		end)
	end)
	pendingSaves -= 1
	if not ok then
		warn(`PlayerData: save failed for {player.Name} ({err})`)
	elseif problem then
		-- Another server took the record; stop writing so its data wins. An
		-- autosave that lands after the leave save released it is refused too,
		-- which is fine and not worth a warning.
		session.saves = false
		if sessions[player] == session then
			warn(`PlayerData: {player.Name}'s data moved to another server, stopped saving here`)
		end
	end
	return ok and not problem
end

local function onPlayerAdded(player: Player)
	local claimed, saved = false, nil
	if storeOk then
		claimed, saved = claim(player)
	end
	local session: Session = {
		data = reconcile(saved),
		saves = claimed,
		new = claimed and saved == nil,
	}
	if not player.Parent or leaving[player] then
		save(player, session, true)
		return
	end
	sessions[player] = session
	loaded:Fire(player)
end

-- The player's data, or nil if it hasn't loaded yet.
function PlayerData.get(player: Player): Data?
	local session = sessions[player]
	return session and session.data
end

-- Waits until the player's data is loaded. Nil if they leave first.
function PlayerData.waitFor(player: Player): Data?
	while player.Parent and not leaving[player] and not sessions[player] do
		loaded.Event:Wait()
	end
	return PlayerData.get(player)
end

-- Changes the player's data in place. It saves with the next autosave.
function PlayerData.update(player: Player, change: (Data) -> ())
	local session = sessions[player]
	if session then
		change(session.data)
	end
end

-- Writes the player's data now, without waiting for the autosave. Returns
-- whether it was written: false if they've left, their data doesn't save
-- (a failed load), or the write failed. Yields.
function PlayerData.saveNow(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and save(player, session, false)
end

-- Whether this is the player's first time in the game: their record loaded
-- and nothing was saved in it before. False when the load failed.
function PlayerData.isNew(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.new
end

-- Adds `friendId` to `inviterId`'s invite credits. Returns whether it saved.
function PlayerData.addInviteCredit(inviterId: number, friendId: number): boolean
	if not creditStore then
		return false
	end
	local ok, err = pcall(function()
		creditStore:UpdateAsync(`Inviter_{inviterId}`, function(stored: any): { number }
			local friends = if typeof(stored) == "table" then stored else {}
			if not table.find(friends, friendId) then
				table.insert(friends, friendId)
			end
			return friends
		end)
	end)
	if not ok then
		warn(`PlayerData: couldn't save an invite credit for {inviterId} ({err})`)
	end
	return ok
end

local boardStores: { [string]: OrderedDataStore } = {}

local function boardStore(name: string): OrderedDataStore
	local board = boardStores[name]
	if not board then
		board = DataStoreService:GetOrderedDataStore(name)
		boardStores[name] = board
	end
	return board
end

-- Raises `userId`'s entry on the leaderboard list `name` (an ordered store,
-- see Leaderboard.storeName) to `value`, a whole number. Never lowers it.
-- Returns whether the list holds at least `value` now.
function PlayerData.raiseBoard(name: string, userId: number, value: number): boolean
	if not storeOk then
		return false
	end
	local ok, err = pcall(function()
		boardStore(name):UpdateAsync(tostring(userId), function(old: any): number
			return if typeof(old) == "number" then math.max(old, value) else value
		end)
	end)
	if not ok then
		warn(`PlayerData: couldn't send {value} to {name} for {userId} ({err})`)
	end
	return ok
end

-- The top `count` entries of the leaderboard list `name`, best first, as
-- { key, value }; nil if it can't be read.
function PlayerData.readBoard(name: string, count: number): { { key: string, value: number } }?
	if not storeOk then
		return nil
	end
	local ok, page = pcall(function()
		return boardStore(name):GetSortedAsync(false, count):GetCurrentPage()
	end)
	if not ok then
		warn(`PlayerData: couldn't read {name} ({page})`)
		return nil
	end
	return page :: any
end

local recordStores: { [string]: DataStore } = {}

local function recordStore(name: string): DataStore
	local records = recordStores[name]
	if not records then
		records = DataStoreService:GetDataStore(name)
		recordStores[name] = records
	end
	return records
end

-- Saves `record` as the launcher record `recordKey` in the store `name`
-- (LaunchRecords), only if it still beats the one saved there. Returns the
-- record held there now, either way; nil if the store can't be reached.
function PlayerData.raiseRecord(name: string, recordKey: string, record: LaunchRecords.Record): LaunchRecords.Record?
	if not storeOk then
		return nil
	end
	local held: LaunchRecords.Record? = nil
	local ok, err = pcall(function()
		recordStore(name):UpdateAsync(recordKey, function(saved: any): any
			local current = LaunchRecords.reconcile(saved)
			if LaunchRecords.beats(current, record.Value) then
				held = record
				return record
			end
			held = current
			return nil
		end)
	end)
	if not ok then
		warn(`PlayerData: couldn't save the record {recordKey} ({err})`)
		return nil
	end
	return held
end

-- The launcher records `keys` in the store `name`, by key; a key with no
-- whole record saved is left out. Nil if the store can't be read.
function PlayerData.readRecords(name: string, keys: { string }): { [string]: LaunchRecords.Record }?
	if not storeOk then
		return nil
	end
	local found: { [string]: LaunchRecords.Record } = {}
	for _, recordKey in keys do
		local ok, saved = pcall(recordStore(name).GetAsync, recordStore(name), recordKey)
		if not ok then
			warn(`PlayerData: couldn't read the record {recordKey} ({saved})`)
			return nil
		end
		local record = LaunchRecords.reconcile(saved)
		if record then
			found[recordKey] = record
		end
	end
	return found
end

-- `inviterId`'s invite credits, or nil if they can't be read.
function PlayerData.inviteCredits(inviterId: number): { number }?
	if not creditStore then
		return nil
	end
	local ok, stored = pcall(creditStore.GetAsync, creditStore, `Inviter_{inviterId}`)
	if not ok then
		warn(`PlayerData: couldn't read invite credits for {inviterId} ({stored})`)
		return nil
	end
	return if typeof(stored) == "table" then stored else {}
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	leaving[player] = true
	loaded:Fire(player)
	local session = sessions[player]
	if session then
		sessions[player] = nil
		save(player, session, true)
	end
	leaving[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(S.AutosaveInterval)
		for player, session in sessions do
			task.spawn(save, player, session, false)
		end
	end
end)

game:BindToClose(function()
	for player, session in sessions do
		sessions[player] = nil
		task.spawn(save, player, session, true)
	end
	while pendingSaves > 0 do
		task.wait()
	end
end)

return PlayerData
