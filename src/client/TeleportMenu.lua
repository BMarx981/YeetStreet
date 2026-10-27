--!strict
-- TeleportMenu (ModuleScript) -> StarterPlayerScripts.TeleportMenu
-- The teleport menu: a list of places, the nearest garage first, then the hub
-- and each park in Tuning.Map. The TELEPORT button at the top of the screen,
-- T on a keyboard, or d-pad up on a gamepad opens and closes it; so do the
-- panel's X button and gamepad B. Picking a place asks the server
-- (ReplicatedStorage.Teleport, see TeleportService), which moves the car and
-- ends the run like a reset. While the menu is open the car gets no input
-- (Controls).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local UiStyle = require(script.Parent.UiStyle)

local TeleportMenu = {}

local REASONS: { [string]: string } = {
	TooSoon = "One moment...",
	NoGarage = "There's no garage on the map yet.",
	Unknown = "That place isn't on the map.",
	NotReady = "Wait for your car to spawn.",
}

type Look = { color: Color3, icon: string, tagline: string }

-- Each place's card, by area Id. A park missing here gets DEFAULT_LOOK.
local LOOKS: { [string]: Look } = {
	Garage = { color = Color3.fromRGB(230, 150, 20), icon = "🔧", tagline = "Upgrades and new cars" },
	Hub = { color = Color3.fromRGB(60, 110, 190), icon = "⭐", tagline = "The big launcher in the middle" },
	Skate = { color = Color3.fromRGB(180, 60, 170), icon = "🛹", tagline = "Bowls, ramps, and rails" },
	Corkscrew = { color = Color3.fromRGB(20, 150, 140), icon = "🌀", tagline = "Tubes, the Gravitron, and the Globe" },
	City = { color = Color3.fromRGB(200, 70, 50), icon = "🏙️", tagline = "Trains, cranes, and a kaiju" },
	Dino = { color = Color3.fromRGB(70, 150, 50), icon = "🦖", tagline = "Volcano, T-Rex, and raptors" },
}
local DEFAULT_LOOK: Look = { color = Color3.fromRGB(96, 102, 112), icon = "🏁", tagline = "" }

local player = Players.LocalPlayer :: Player
local started = false
local open = false
local busy = false

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Teleport"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- above the HUD and touch buttons

	-- Where the garage panel's hidden GARAGE button was, left of the fuel bar.
	local openButton = UiStyle.sticker("Open", gui, "TELEPORT")
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(0.5, -146, 0, 6)
	openButton.Size = UDim2.fromOffset(120, 32)

	local panel, close = UiStyle.panel(gui, "TELEPORT", Vector2.new(380, 560))
	local top = UiStyle.HeaderHeight

	local status = UiStyle.text("Status", panel, 16, false)
	status.TextColor3 = UiStyle.Yellow
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.fromScale(0, 1)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.Text = ""

	local list = Instance.new("ScrollingFrame")
	list.Name = "Places"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, top)
	list.Size = UDim2.new(1, 0, 1, -top - 28)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UiStyle.Yellow
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	-- Room for the cards' outlines, which would clip at the edges.
	local inset = Instance.new("UIPadding")
	inset.PaddingTop = UDim.new(0, 3)
	inset.PaddingBottom = UDim.new(0, 3)
	inset.PaddingLeft = UDim.new(0, 3)
	inset.Parent = list

	local function setOpen(value: boolean, byGamepad: boolean)
		open = value
		panel.Visible = value
		if value then
			status.Text = ""
		end
		if value and byGamepad then
			GuiService.SelectedObject = list:FindFirstChildWhichIsA("TextButton")
		elseif not value and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
	end

	local function go(destination: string)
		if busy then
			return
		end
		local remote = ReplicatedStorage:FindFirstChild("Teleport")
		if not (remote and remote:IsA("RemoteFunction")) then
			status.Text = "Teleport isn't ready yet."
			return
		end
		busy = true
		status.Text = ""
		local ok, done, reason = pcall(remote.InvokeServer, remote, destination)
		busy = false
		if ok and done then
			setOpen(false, false)
		elseif ok then
			status.Text = REASONS[reason] or "Couldn't go there."
		else
			status.Text = "Couldn't reach the server."
		end
	end

	local places: { { id: string, label: string } } = { { id = "Garage", label = "Garage" } }
	for _, area in MapLayout.stops(Tuning.Map.Areas :: any) do
		table.insert(places, { id = area.Id, label = area.Name })
	end
	for i, place in places do
		local look = LOOKS[place.id] or DEFAULT_LOOK
		local b = Instance.new("TextButton")
		b.Name = place.id
		b.Text = ""
		b.AutoButtonColor = true
		b.BackgroundColor3 = look.color
		b.LayoutOrder = i
		b.Size = UDim2.new(1, -12, 0, 64)
		b.Parent = list
		UiStyle.corner(b, 10)
		UiStyle.stroke(b, 2, UiStyle.Ink, true)
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
		shade.Parent = b
		local badge = UiStyle.badge(b, look.icon, 46)
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 10, 0.5, 0)
		local name = UiStyle.text("Name", b, 24, true)
		name.Text = string.upper(place.label)
		name.Position = UDim2.fromOffset(68, if look.tagline == "" then 18 else 8)
		name.Size = UDim2.new(1, -130, 0, 28)
		local tagline = UiStyle.text("Tagline", b, 13, false)
		tagline.Text = look.tagline
		tagline.Position = UDim2.fromOffset(68, 36)
		tagline.Size = UDim2.new(1, -130, 0, 18)
		tagline.TextTruncate = Enum.TextTruncate.AtEnd
		local goLabel = Instance.new("TextLabel")
		goLabel.Name = "Go"
		goLabel.Text = "GO"
		goLabel.Font = UiStyle.TitleFont
		goLabel.TextSize = 18
		goLabel.TextColor3 = UiStyle.Ink
		goLabel.BackgroundColor3 = UiStyle.Yellow
		goLabel.AnchorPoint = Vector2.new(1, 0.5)
		goLabel.Position = UDim2.new(1, -12, 0.5, 0)
		goLabel.Size = UDim2.fromOffset(46, 30)
		goLabel.Rotation = -4
		goLabel.Parent = b
		UiStyle.corner(goLabel, 6)
		UiStyle.stroke(goLabel, 2, Color3.new(1, 1, 1), true)
		b.Activated:Connect(function()
			go(place.id)
		end)
	end

	openButton.Activated:Connect(function()
		setOpen(not open, false)
	end)
	close.Activated:Connect(function()
		setOpen(false, false)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.KeyCode == Enum.KeyCode.T and not processed then
			setOpen(not open, false)
		elseif input.KeyCode == Enum.KeyCode.DPadUp then
			setOpen(not open, true)
		elseif input.KeyCode == Enum.KeyCode.ButtonB and open then
			setOpen(false, true)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Builds the TELEPORT button and menu, once.
function TeleportMenu.start()
	if not started then
		started = true
		build()
	end
end

-- True while the menu is open; the car takes no input then.
function TeleportMenu.isOpen(): boolean
	return open
end

return TeleportMenu
