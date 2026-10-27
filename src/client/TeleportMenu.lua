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

	local panel, close = UiStyle.panel(gui, "TELEPORT", Vector2.new(340, 440))
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
	-- Room for the plates' outlines, which would clip at the edges.
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
		local b = Instance.new("TextButton")
		b.Name = place.id
		b.Text = string.upper(place.label)
		b.Font = UiStyle.TitleFont
		b.TextSize = 22
		b.TextColor3 = UiStyle.Ink
		b.AutoButtonColor = true
		b.LayoutOrder = i
		b.Size = UDim2.new(1, -12, 0, 46)
		b.Parent = list
		UiStyle.plate(b)
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
