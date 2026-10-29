--!strict
-- ObbyHud (ModuleScript) -> StarterPlayerScripts.ObbyHud
-- The car obby's HUD, shown only in the obby (while the player has an
-- ObbyCheckpoint attribute, see ObbyService): a strip under the fuel bar with
-- the visit's clock and a pip per stage. The clock starts on arrival and
-- stops at the finish. Tapping or clicking the strip opens the stage select,
-- a grid of the course's pads by the number painted on them; picking a
-- reached one asks the server to respawn the car there
-- (ReplicatedStorage.ObbySelect). While the grid is open the car gets no
-- input (Controls).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Obby = require(ReplicatedStorage.Obby)
local Tuning = require(ReplicatedStorage.Tuning)
local UiStyle = require(script.Parent.UiStyle)

local T = Tuning.Obby
local STAGES = T.Stages
local COLORS = T.StageColors

local ObbyHud = {}

local REASONS: { [string]: string } = {
	TooSoon = "One moment...",
	NotInObby = "You're not in the obby.",
	NotReached = "You haven't reached that pad yet.",
	NoPad = "That pad is missing.",
}

-- Narrow enough that the strip fits between the menu buttons on its left and
-- the cash and bone counters on its right.
local PIP_WIDTH = 9
local PIP_HEIGHT = 8
local PIP_GAP = 2
local COLUMNS = 5

local player = Players.LocalPlayer :: Player
local started = false
local open = false
local busy = false

local function stageColor(stage: number): Color3
	return COLORS[(stage - 1) % #COLORS + 1]
end

-- The visit as the server shows it, or nil outside the obby.
local function currentVisit(): Obby.Visit?
	local current = player:GetAttribute("ObbyCheckpoint")
	if typeof(current) ~= "number" then
		return nil
	end
	local reached = player:GetAttribute("ObbyReached")
	return { Reached = if typeof(reached) == "number" then reached else current, Current = current }
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ObbyHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- above the HUD and touch buttons, like the menus
	gui.Enabled = false

	-- The strip, under the fuel bar and speed readout, where a run's live
	-- score would go (the obby has no runs).
	local strip = Instance.new("TextButton")
	strip.Name = "Strip"
	strip.Text = ""
	strip.AutoButtonColor = false
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.Position = UDim2.new(0.5, 0, 0, 68)
	strip.Size = UDim2.fromOffset(STAGES * (PIP_WIDTH + PIP_GAP) - PIP_GAP + 24, 52)
	strip.BackgroundColor3 = UiStyle.Asphalt
	strip.BackgroundTransparency = 0.15
	strip.Parent = gui
	UiStyle.corner(strip, 10)
	UiStyle.stroke(strip, 2, UiStyle.Ink, true)

	local clock = UiStyle.text("Clock", strip, 24, true)
	clock.Position = UDim2.fromOffset(12, 4)
	clock.Size = UDim2.new(0.6, 0, 0, 26)
	clock.Text = Obby.clock(0)

	local hint = UiStyle.text("Hint", strip, 16, true)
	hint.TextColor3 = UiStyle.Yellow
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.AnchorPoint = Vector2.new(1, 0)
	hint.Position = UDim2.new(1, -12, 0, 8)
	hint.Size = UDim2.new(0.4, 0, 0, 20)
	hint.Text = "STAGES"

	local pipRow = Instance.new("Frame")
	pipRow.Name = "Pips"
	pipRow.BackgroundTransparency = 1
	pipRow.Position = UDim2.fromOffset(12, 36)
	pipRow.Size = UDim2.fromOffset(STAGES * (PIP_WIDTH + PIP_GAP) - PIP_GAP, PIP_HEIGHT)
	pipRow.Parent = strip
	local pips: { Frame } = {}
	local pipEdges: { UIStroke } = {}
	for stage = 1, STAGES do
		local pip = Instance.new("Frame")
		pip.Name = `Pip{stage}`
		pip.Position = UDim2.fromOffset((stage - 1) * (PIP_WIDTH + PIP_GAP), 0)
		pip.Size = UDim2.fromOffset(PIP_WIDTH, PIP_HEIGHT)
		pip.BorderSizePixel = 0
		pip.Parent = pipRow
		UiStyle.corner(pip, 3)
		pips[stage] = pip
		pipEdges[stage] = UiStyle.stroke(pip, 1.5, UiStyle.Ink, true)
	end
	UiStyle.springy(strip)

	-- The stage select: START and pads 1 to 19, five to a row. Pad n ends
	-- stage n, so its tile wears the color of stage n + 1, which starts there.
	local panel, close = UiStyle.panel(gui, "STAGES", Vector2.new(400, 440))
	local top = UiStyle.HeaderHeight

	local status = UiStyle.text("Status", panel, 16, false)
	status.TextColor3 = UiStyle.Yellow
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.fromScale(0, 1)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.Text = ""

	local about = UiStyle.text("About", panel, 20, true)
	about.AnchorPoint = Vector2.new(0, 1)
	about.Position = UDim2.new(0, 0, 1, -24)
	about.Size = UDim2.new(1, 0, 0, 26)
	about.TextTruncate = Enum.TextTruncate.AtEnd

	local grid = Instance.new("Frame")
	grid.Name = "Pads"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, top)
	grid.Size = UDim2.new(1, 0, 1, -top - 56)
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.CellSize = UDim2.new(1 / COLUMNS, -8, 1 / math.ceil(STAGES / COLUMNS), -8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local tiles: { [number]: TextButton } = {}
	local function describe(checkpoint: number)
		local next = T.World1.Stages[checkpoint + 1]
		local where = if checkpoint == 0 then "START" else `PAD {checkpoint}`
		about.Text = if next then `{where}: {string.upper(next.Name)}` else where
	end

	local function refresh()
		local visit = currentVisit()
		if not visit then
			return
		end
		for stage = 1, STAGES do
			local state = Obby.stageState(stage, visit, T)
			local pip = pips[stage]
			pip.BackgroundColor3 = if state == "Current"
				then UiStyle.Yellow
				elseif state == "Cleared" then stageColor(stage)
				else UiStyle.Asphalt
			pip.BackgroundTransparency = if state == "Ahead" then 0.4 else 0
			pipEdges[stage].Color = if state == "Current" then Color3.new(1, 1, 1) else UiStyle.Ink
		end
		for checkpoint, tile in tiles do
			local state = Obby.padState(checkpoint, visit)
			tile.Active = state ~= "Locked"
			tile.BackgroundColor3 = if state == "Locked" then UiStyle.Asphalt else stageColor(checkpoint + 1)
			tile.TextTransparency = if state == "Locked" then 0.6 else 0
			UiStyle.setGlow(tile, state == "Here")
		end
		describe(visit.Current)
	end

	local function setOpen(value: boolean)
		if value == open then
			return
		end
		open = value
		UiStyle.show(panel, value)
		if value then
			status.Text = ""
			refresh()
		elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
	end

	local function go(checkpoint: number)
		if busy then
			return
		end
		local remote = ReplicatedStorage:FindFirstChild("ObbySelect")
		if not (remote and remote:IsA("RemoteFunction")) then
			status.Text = "Stage select isn't ready yet."
			return
		end
		busy = true
		status.Text = ""
		local ok, done, reason = pcall(remote.InvokeServer, remote, checkpoint)
		busy = false
		if ok and done then
			setOpen(false)
		elseif ok then
			status.Text = REASONS[reason] or "Couldn't go there."
			UiStyle.play("Denied")
		else
			status.Text = "Couldn't reach the server."
			UiStyle.play("Denied")
		end
	end

	for checkpoint = 0, STAGES - 1 do
		local tile = Instance.new("TextButton")
		tile.Name = `Pad{checkpoint}`
		tile.Text = if checkpoint == 0 then "START" else tostring(checkpoint)
		tile.Font = UiStyle.TitleFont
		tile.TextScaled = true
		tile.TextColor3 = Color3.new(1, 1, 1)
		tile.AutoButtonColor = true
		tile.LayoutOrder = checkpoint
		tile.Parent = grid
		UiStyle.corner(tile, 10)
		UiStyle.stroke(tile, 2, UiStyle.Ink, true)
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = if checkpoint == 0 then 18 else 30
		fit.Parent = tile
		local inset = Instance.new("UIPadding")
		inset.PaddingLeft = UDim.new(0, 4)
		inset.PaddingRight = UDim.new(0, 4)
		inset.Parent = tile
		-- The tiles sit in a grid, where growing one would shove the others,
		-- so they don't spring; hovering one names the stage it starts.
		tile.MouseEnter:Connect(function()
			describe(checkpoint)
		end)
		tile.SelectionGained:Connect(function()
			describe(checkpoint)
		end)
		tile.Activated:Connect(function()
			if tile.Active then
				UiStyle.play("Click")
				go(checkpoint)
			end
		end)
		tile.InputBegan:Connect(function(input: InputObject)
			local press = input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			if press and not tile.Active then
				UiStyle.play("Denied")
				UiStyle.shake(tile)
			end
		end)
		tiles[checkpoint] = tile
	end

	strip.Activated:Connect(function()
		setOpen(not open)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)

	-- The clock runs from arriving in the obby to the finish.
	local arrivedAt = 0
	local finishedAt: number? = nil
	local function onVisit()
		local visit = currentVisit()
		local inObby = visit ~= nil
		if inObby and not gui.Enabled then
			arrivedAt = os.clock()
			finishedAt = nil
		end
		gui.Enabled = inObby
		if not visit then
			setOpen(false)
			return
		end
		if Obby.finished(visit, T) and not finishedAt then
			finishedAt = os.clock()
		end
		refresh()
	end
	player:GetAttributeChangedSignal("ObbyCheckpoint"):Connect(onVisit)
	player:GetAttributeChangedSignal("ObbyReached"):Connect(onVisit)
	onVisit()

	RunService.Heartbeat:Connect(function()
		if gui.Enabled then
			clock.Text = Obby.clock((finishedAt or os.clock()) - arrivedAt)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Builds the obby strip and stage select, once.
function ObbyHud.start()
	if not started then
		started = true
		build()
	end
end

-- True while the stage select is open; the car takes no input then.
function ObbyHud.isOpen(): boolean
	return open
end

return ObbyHud
