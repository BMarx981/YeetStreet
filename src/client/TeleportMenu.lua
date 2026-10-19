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

local TeleportMenu = {}

local REASONS: { [string]: string } = {
	TooSoon = "One moment...",
	NoGarage = "There's no garage on the map yet.",
	Unknown = "That place isn't on the map.",
	NotReady = "Wait for your car to spawn.",
}

local PANEL_COLOR = Color3.fromRGB(20, 20, 28)
local GO_COLOR = Color3.fromRGB(60, 120, 200)
local OFF_COLOR = Color3.fromRGB(70, 70, 80)

local player = Players.LocalPlayer :: Player
local started = false
local open = false
local busy = false

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function button(name: string, parent: Instance, label: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = label
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 18
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = GO_COLOR
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	return b
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Teleport"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- above the HUD and touch buttons

	-- Where the garage panel's hidden GARAGE button was, left of the fuel bar.
	local openButton = button("Open", gui, "TELEPORT")
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(0.5, -146, 0, 6)
	openButton.Size = UDim2.fromOffset(120, 32)
	openButton.BackgroundColor3 = PANEL_COLOR
	openButton.BackgroundTransparency = 0.3

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.8, 0.8)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.1
	panel.Active = true
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 14)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(320, 380)
	limit.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 24
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "TELEPORT"
	title.Size = UDim2.new(1, -40, 0, 32)
	title.Parent = panel

	local close = button("Close", panel, "X")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(32, 32)
	close.BackgroundColor3 = OFF_COLOR

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextSize = 16
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.fromScale(0, 1)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.Text = ""
	status.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Name = "Places"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, 42)
	list.Size = UDim2.new(1, 0, 1, -70)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

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
		local b = button(place.id, list, place.label)
		b.LayoutOrder = i
		b.Size = UDim2.new(1, -10, 0, 44)
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
