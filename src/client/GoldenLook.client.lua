--!strict
-- GoldenLook (LocalScript) -> StarterPlayerScripts.GoldenLook
-- Shows the golden booster (GoldenService) on this client while the
-- workspace's GoldenBooster attribute names a launcher: a gold outline on
-- the launcher that shows through walls, a pillar of light above it, sparkles
-- on its pads, and a timer chip on the left (TimerChip, "⭐ 0:45", in full
-- with the launcher's name). When someone claims it (GoldenTakenBy), the chip
-- says TAKEN, and in full who, for TakenTime seconds. All of it is made here
-- and touches nothing the server owns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)
local TimerChip = require(script.Parent.TimerChip)
local UiStyle = require(script.Parent.UiStyle)

local G = Tuning.Golden
local UPDATE_EVERY = 0.2

local player = Players.LocalPlayer :: Player

local chip = TimerChip.new("Golden", 2)

local shown: { Instance } = {}
local shownId: string? = nil
local takenUntil = 0
local takenText = ""

local function launcherOf(id: string): (string, Instance?)
	for _, launcher in Tuning.LaunchRecords.Launchers do
		if launcher.Id == id then
			local at: Instance? = workspace
			for name in string.gmatch(launcher.Path, "[^%.]+") do
				at = if at then at:FindFirstChild(name) else nil
			end
			return launcher.Name, at
		end
	end
	return id, nil
end

local function clear()
	for _, thing in shown do
		thing:Destroy()
	end
	shown = {}
	shownId = nil
end

local function dress(model: Instance)
	local highlight = Instance.new("Highlight")
	highlight.Name = "GoldenBooster"
	highlight.FillColor = G.Color
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = model
	highlight.Parent = model
	table.insert(shown, highlight)

	local pads: { BasePart } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("LaunchSpeed") and part:GetAttribute("NoRun") ~= true then
			table.insert(pads, part)
		end
	end
	if #pads == 0 then
		return
	end
	local sum, top = Vector3.zero, -math.huge
	for _, pad in pads do
		sum += pad.Position
		top = math.max(top, pad.Position.Y + pad.Size.Magnitude / 2)
	end
	local middle = sum / #pads

	local pillar = Instance.new("Part")
	pillar.Name = "GoldenPillar"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = G.Color
	pillar.Transparency = 0.55
	pillar.Size = Vector3.new(G.PillarHeight, G.PillarWidth, G.PillarWidth)
	-- A cylinder runs along its X axis, so turn it upright.
	pillar.CFrame = CFrame.new(middle.X, top + G.PillarHeight / 2, middle.Z) * CFrame.Angles(0, 0, math.pi / 2)
	pillar.Parent = workspace
	table.insert(shown, pillar)

	local step = math.max(math.floor(#pads / G.SparklePads), 1)
	for i = 1, #pads, step do
		local sparkles = Instance.new("Sparkles")
		sparkles.Name = "GoldenSparkles"
		sparkles.SparkleColor = G.Color
		sparkles.Parent = pads[i]
		table.insert(shown, sparkles)
	end
end

local function update()
	local id = workspace:GetAttribute("GoldenBooster")
	if typeof(id) ~= "string" then
		if shownId then
			clear()
		end
		chip.set(G.Icon, "TAKEN", takenText, G.Color)
		chip.setVisible(os.clock() < takenUntil)
		return
	end
	local name, model = launcherOf(id)
	if shownId ~= id then
		clear()
		shownId = id
		if model then
			dress(model)
		end
		UiStyle.play("Open")
		chip.bounce()
	end
	local ends = workspace:GetAttribute("GoldenEnds")
	local left = if typeof(ends) == "number" then math.max(ends - workspace:GetServerTimeNow(), 0) else 0
	local clock = `{math.floor(left / 60)}:{string.format("%02d", math.floor(left % 60))}`
	chip.set(G.Icon, clock, `GOLDEN x{G.Multiplier}: {name} {clock}`, G.Color)
	chip.setVisible(true)
end

workspace:GetAttributeChangedSignal("GoldenTakenBy"):Connect(function()
	local who = workspace:GetAttribute("GoldenTakenBy")
	if typeof(who) == "string" then
		takenUntil = os.clock() + G.TakenTime
		takenText = if who == player.DisplayName
			then "You grabbed the golden booster!"
			else `{who} grabbed the golden booster!`
	end
end)

while true do
	update()
	task.wait(UPDATE_EVERY)
end
