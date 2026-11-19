--!strict
-- Leaderboards (Script) -> ServerScriptService.Leaderboards
-- The global leaderboards (Leaderboard) on the server.
--
-- Sending: every SendEvery seconds, each of a player's lists that beats what
-- this session last sent goes to its ordered store through
-- PlayerData.raiseBoard. A session starts with nothing sent, so the first
-- send after joining puts all of a player's bests up, including ones from
-- before the boards existed. A best set less than SendEvery before leaving
-- goes up on the next join.
--
-- Reading: every RefreshEvery seconds, the top of each board's all-time and
-- this week's lists is read (PlayerData.readBoard), names are looked up
-- (cached, and once per refresh for any new ones), and each board is
-- published for clients as JSON in ReplicatedStorage.LeaderboardData.<Id>:
-- { Week, AllTime = rows, ThisWeek = rows } (Leaderboard.Row). A list that
-- can't be read keeps what it showed before.
--
-- Studio sends to and reads its own lists.
--
-- It also places the boards at spawn (Tuning.LeaderboardSigns), which every
-- client draws from that JSON (LeaderboardSigns).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local UserService = game:GetService("UserService")

local Leaderboard = require(ReplicatedStorage.Leaderboard)
local Tuning = require(ReplicatedStorage.Tuning)
local PlayerData = require(ServerScriptService.PlayerData)

local B = Tuning.Leaderboards
local studio = RunService:IsStudio()

-- By player, what this session has sent to each list.
local sent: { [Player]: { [string]: number } } = {}

local function send(player: Player)
	local data = PlayerData.get(player)
	local mine = sent[player]
	if not (data and mine) then
		return
	end
	local week = Leaderboard.weekRecord(data.ThisWeek, Leaderboard.week(os.time()))
	local lists = Leaderboard.lists(data.Best, data.BestAirtime, data.Rebirths, data.MegaBest, week, studio, B)
	for name, value in Leaderboard.changed(lists, mine) do
		if PlayerData.raiseBoard(name, player.UserId, value) then
			mine[name] = value
		end
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	sent[player] = {}
end)
for _, player in Players:GetPlayers() do
	sent[player] = {}
end
Players.PlayerRemoving:Connect(function(player: Player)
	sent[player] = nil
end)

-- Display names by UserId, kept for the server's life.
local names: { [number]: string } = {}
local namesWarned = false

local function lookUpNames(ids: { number })
	local missing: { number } = {}
	for _, id in ids do
		local here = Players:GetPlayerByUserId(id)
		if here then
			names[id] = here.DisplayName
		elseif not names[id] and not table.find(missing, id) then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if ok and typeof(infos) == "table" then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	elseif not namesWarned then
		namesWarned = true
		warn(`Leaderboards: couldn't look up names ({infos})`)
	end
end

local folder = Instance.new("Folder")
folder.Name = "LeaderboardData"
folder.Parent = ReplicatedStorage
local published: { [string]: StringValue } = {}
for _, board in B.Boards do
	local value = Instance.new("StringValue")
	value.Name = board.Id
	value.Parent = folder
	published[board.Id] = value
end

-- The last rows shown for each list, by store name, kept when a read fails.
local shown: { [string]: { Leaderboard.Row } } = {}

local function refresh()
	local week = Leaderboard.week(os.time())
	local pages: { [string]: { { key: string, value: number } } } = {}
	local ids: { number } = {}
	for _, board in B.Boards do
		local lists = {
			Leaderboard.storeName(board.Id, nil, studio, B),
			Leaderboard.storeName(board.Id, week, studio, B),
		}
		for _, name in lists do
			local page = PlayerData.readBoard(name, B.Top)
			if page then
				pages[name] = page
				for _, entry in page do
					local id = tonumber(entry.key)
					if id then
						table.insert(ids, id)
					end
				end
			end
		end
	end
	lookUpNames(ids)
	for _, board in B.Boards do
		local allName = Leaderboard.storeName(board.Id, nil, studio, B)
		local weekName = Leaderboard.storeName(board.Id, week, studio, B)
		for _, name in { allName, weekName } do
			local page = pages[name]
			if page then
				shown[name] = Leaderboard.rows(page, names, B)
			end
		end
		published[board.Id].Value = HttpService:JSONEncode({
			Week = week,
			AllTime = shown[allName] or {},
			ThisWeek = shown[weekName] or {},
		})
	end
end

-- The boards at spawn: plain tagged parts on posts, which each client draws
-- (LeaderboardSigns). Built at start, so nothing is saved in the place.
local function placeSigns()
	local S = Tuning.LeaderboardSigns
	local row = CFrame.lookAt(Vector3.new(S.CenterX, 0, S.CenterZ), Vector3.new(S.FaceX, 0, S.FaceZ))
	local signs = Instance.new("Folder")
	signs.Name = "LeaderboardSigns"
	for i, board in B.Boards do
		-- A CFrame's right points to the viewer's left when it faces them.
		local spot = row * CFrame.new(((#B.Boards + 1) / 2 - i) * (S.Width + S.Gap), 0, 0)
		local model = Instance.new("Model")
		model.Name = board.Id
		for _, side in { -1, 1 } do
			local post = Instance.new("Part")
			post.Name = "Post"
			post.Anchored = true
			post.Size = Vector3.new(S.PostWidth, S.BottomHeight, S.PostWidth)
			post.CFrame = spot * CFrame.new(side * (S.Width / 2 - S.PostWidth * 2), S.BottomHeight / 2, 0)
			post.Color = Color3.fromRGB(22, 22, 26)
			post.Material = Enum.Material.Metal
			post.Parent = model
		end
		local part = Instance.new("Part")
		part.Name = "Board"
		part.Anchored = true
		part.Size = Vector3.new(S.Width, S.Height, S.Thickness)
		part.CFrame = spot * CFrame.new(0, S.BottomHeight + S.Height / 2, 0)
		part.Color = Color3.fromRGB(22, 22, 26)
		part.Material = Enum.Material.SmoothPlastic
		part:SetAttribute("BoardId", board.Id)
		part:AddTag("LeaderboardSign")
		part.Parent = model
		model.Parent = signs
	end
	signs.Parent = workspace
end
placeSigns()

task.spawn(function()
	while true do
		task.wait(B.SendEvery)
		for player in sent do
			task.spawn(send, player)
		end
	end
end)

while true do
	refresh()
	task.wait(B.RefreshEvery)
end
