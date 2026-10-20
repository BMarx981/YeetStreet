--!strict
-- GarageMenu (ModuleScript) -> StarterPlayerScripts.GarageMenu
-- The garage panel: buy upgrade levels and ladder cars, and equip owned cars.
-- It opens only within Tuning.Garage.Reach of a model tagged Garage, with G or
-- E (E shows the Cars tab) on a keyboard or X on a gamepad. The same keys,
-- the panel's X button, and gamepad B close it.
--
-- Everything shown comes from the attributes Garage sets on the player, with
-- prices and caps worked out by the same Economy and Tuning the server uses.
-- Purchases go to the server's RemoteFunctions, which decide; the panel only
-- reports why one failed. While the panel is open the car gets no input
-- (Controls), so a gamepad A press on a button doesn't also fire the jets.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Economy = require(ReplicatedStorage.Economy)
local Tuning = require(ReplicatedStorage.Tuning)

local GarageMenu = {}

local GARAGE_TAG = "Garage"

type Tab = "Upgrades" | "Cars" | "Limiteds"

type Row = {
	frame: Frame,
	detail: TextLabel,
	button: TextButton,
}

local STATS: { { stat: Economy.StatName, about: string } } = {
	{ stat = "Speed", about = "Top speed on the ground" },
	{ stat = "Jets", about = "Jet power, fuel, recharge, and air turning" },
	{ stat = "Toughness", about = "How hard a hit the car takes before it wrecks" },
	{ stat = "Grip", about = "Tire grip for corners and landings" },
}

local REASONS: { [string]: string } = {
	NotEnoughCash = "Not enough cash yet.",
	AtCap = "This car is maxed out there. A better car raises the limit.",
	Owned = "You already own that.",
	NotOwned = "Buy that car first.",
	TooSoon = "One moment...",
	NotLoaded = "Your garage is still loading.",
	SoldOut = "That item is sold out.",
	UnknownLimited = "That item doesn't exist.",
}

local PANEL_COLOR = Color3.fromRGB(20, 20, 28)
local ROW_COLOR = Color3.fromRGB(40, 40, 52)
local BUY_COLOR = Color3.fromRGB(60, 170, 80)
local OFF_COLOR = Color3.fromRGB(70, 70, 80)
local CASH_COLOR = Color3.fromRGB(120, 230, 120)

local player = Players.LocalPlayer :: Player
local started = false
local open = false
local busy = false
local tab: Tab = "Upgrades"

local function withCommas(n: number): string
	local digits = tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (digits:gsub("^,", ""))
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(name: string, parent: Instance, size: number, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function button(name: string, parent: Instance, label: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = label
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 18
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = BUY_COLOR
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	return b
end

local function setButton(b: TextButton, label: string, enabled: boolean)
	b.Text = label
	b.Active = enabled
	b.AutoButtonColor = enabled
	b.Selectable = enabled
	b.BackgroundColor3 = if enabled then BUY_COLOR else OFF_COLOR
	b.TextTransparency = if enabled then 0 else 0.35
end

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function levels(): Economy.Levels
	return {
		Speed = number("Speed"),
		Jets = number("Jets"),
		Toughness = number("Toughness"),
		Grip = number("Grip"),
	}
end

local function owned(): { string }
	local value = player:GetAttribute("CarsOwned")
	return if typeof(value) == "string" and value ~= "" then string.split(value, ",") else {}
end

local function limitedsOwned(): { string }
	local value = player:GetAttribute("LimitedsOwned")
	return if typeof(value) == "string" and value ~= "" then string.split(value, ",") else {}
end

local function limitedStockRemaining(id: string): number
	local value = player:GetAttribute(`LimitedStock_{id}`)
	return if typeof(value) == "number" then value else 0
end

local function carText(car: Economy.Car): string
	local caps = car.Caps
	local free = if car.Bonus > 0 then `+{car.Bonus} free levels. ` else ""
	if caps.Speed == caps.Jets and caps.Jets == caps.Toughness and caps.Toughness == caps.Grip then
		return `{free}Max level {caps.Speed} on every stat`
	end
	return `{free}Max: Speed {caps.Speed}, Jets {caps.Jets}, Tough {caps.Toughness}, Grip {caps.Grip}`
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Garage"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- above the HUD and touch buttons

	local openButton = button("Open", gui, "GARAGE")
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(0.5, -146, 0, 6)
	openButton.Size = UDim2.fromOffset(110, 32)
	openButton.BackgroundColor3 = PANEL_COLOR
	openButton.BackgroundTransparency = 0.3
	openButton.Visible = false
	openButton.Active = false
	openButton.Selectable = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.85)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.1
	panel.Active = true
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 14)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 420)
	limit.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local title = text("Title", panel, 24, Enum.Font.GothamBlack)
	title.Text = "GARAGE"
	title.Size = UDim2.new(0.4, 0, 0, 32)

	local cash = text("Cash", panel, 22, Enum.Font.GothamBlack)
	cash.AnchorPoint = Vector2.new(1, 0)
	cash.Position = UDim2.new(1, -44, 0, 0)
	cash.Size = UDim2.new(0.5, 0, 0, 32)
	cash.TextXAlignment = Enum.TextXAlignment.Right
	cash.TextColor3 = CASH_COLOR

	local close = button("Close", panel, "X")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(32, 32)
	close.BackgroundColor3 = OFF_COLOR

	local function tabButton(name: Tab, x: number): TextButton
		local b = button(`{name}Tab`, panel, string.upper(name))
		b.Position = UDim2.fromOffset(x, 40)
		b.Size = UDim2.fromOffset(130, 30)
		return b
	end
	local upgradesTab = tabButton("Upgrades", 0)
	local carsTab = tabButton("Cars", 138)
	local limitedsTab = tabButton("Limiteds", 276)

	local status = text("Status", panel, 16, Enum.Font.GothamBold)
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.fromScale(0, 1)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.TextColor3 = Color3.fromRGB(255, 200, 120)
	status.Text = ""

	local function tabList(name: Tab): ScrollingFrame
		local list = Instance.new("ScrollingFrame")
		list.Name = `{name}List`
		list.Position = UDim2.fromOffset(0, 78)
		list.Size = UDim2.new(1, 0, 1, -78 - 26)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 6
		list.CanvasSize = UDim2.new()
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.Parent = panel
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.Parent = list
		return list
	end
	local upgradesList = tabList("Upgrades")
	local carsList = tabList("Cars")
	local limitedsList = tabList("Limiteds")

	local function row(list: ScrollingFrame, order: number, name: string): Row
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, -8, 0, 58)
		frame.BackgroundColor3 = ROW_COLOR
		frame.Parent = list
		corner(frame, 10)
		local heading = text("Name", frame, 20, Enum.Font.GothamBlack)
		heading.Text = name
		heading.Position = UDim2.fromOffset(12, 6)
		heading.Size = UDim2.new(1, -150, 0, 24)
		local detail = text("Detail", frame, 14, Enum.Font.GothamMedium)
		detail.Position = UDim2.fromOffset(12, 30)
		detail.Size = UDim2.new(1, -150, 0, 22)
		detail.TextTruncate = Enum.TextTruncate.AtEnd
		local action = button("Action", frame, "")
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.new(1, -10, 0.5, 0)
		action.Size = UDim2.fromOffset(124, 38)
		return { frame = frame, detail = detail, button = action }
	end

	local statRows: { [Economy.StatName]: Row } = {}
	for i, info in STATS do
		statRows[info.stat] = row(upgradesList, i, info.stat)
	end
	local carRows: { [string]: Row } = {}
	for i, car in Tuning.Ladder do
		carRows[car.Id] = row(carsList, i, car.Name)
	end
	local limitedRows: { [string]: Row } = {}
	for i, item in Tuning.Limiteds do
		limitedRows[item.Id] = row(limitedsList, i, item.Name)
	end

	local function refresh()
		local cashValue = player:GetAttribute("Cash")
		local loaded = typeof(cashValue) == "number"
		local money = number("Cash")
		cash.Text = if loaded then `$ {withCommas(money)}` else "$ ..."
		local equippedValue = player:GetAttribute("Equipped")
		local equipped = if typeof(equippedValue) == "string" then equippedValue else Tuning.Ladder[1].Id
		local car = Economy.findCar(Tuning.Ladder, equipped) or Tuning.Ladder[1]
		local lv = levels()

		for _, info in STATS do
			local r = statRows[info.stat]
			local level = Economy.level(lv, info.stat)
			local cap = Economy.level(car.Caps, info.stat)
			local counts = if level > cap then ` (this car uses {cap})` else ""
			local free = if car.Bonus > 0 then ` +{car.Bonus} free` else ""
			r.detail.Text = `Level {level} / {cap}{counts}{free}. {info.about}`
			if level >= cap then
				setButton(r.button, "MAX", false)
			else
				local cost = Economy.upgradeCost(level, Tuning.Upgrades)
				setButton(r.button, `$ {withCommas(cost)}`, loaded and not busy and money >= cost)
			end
		end

		local cars = owned()
		for _, ladderCar in Tuning.Ladder do
			local r = carRows[ladderCar.Id]
			r.detail.Text = carText(ladderCar)
			if ladderCar.Id == equipped then
				setButton(r.button, "DRIVING", false)
			elseif table.find(cars, ladderCar.Id) then
				setButton(r.button, "EQUIP", loaded and not busy)
			else
				setButton(r.button, `$ {withCommas(ladderCar.Price)}`, loaded and not busy and money >= ladderCar.Price)
			end
		end

		-- Limiteds tab
		local ownedLimiteds = limitedsOwned()
		for _, item in Tuning.Limiteds do
			local r = limitedRows[item.Id]
			if item.AdminOnly then
				r.detail.Text = item.Description
				if table.find(ownedLimiteds, item.Id) then
					if item.Id == "FrogCar" then
						local frogEquipped = player:GetAttribute("FrogCarEquipped") == true
						if frogEquipped then
							setButton(r.button, "DRIVING", false)
						else
							setButton(r.button, "EQUIP", loaded and not busy)
						end
					else
						setButton(r.button, "OWNED", false)
					end
				else
					setButton(r.button, "LOCKED", false)
				end
			else
				local remaining = limitedStockRemaining(item.Id)
				r.detail.Text = `{item.Description} {remaining} left in stock.`
				if table.find(ownedLimiteds, item.Id) then
					setButton(r.button, "OWNED", false)
				elseif remaining <= 0 then
					setButton(r.button, "SOLD OUT", false)
				else
					setButton(r.button, `$ {withCommas(item.Price)}`, loaded and not busy and money >= item.Price)
				end
			end
		end

		upgradesList.Visible = tab == "Upgrades"
		carsList.Visible = tab == "Cars"
		limitedsList.Visible = tab == "Limiteds"
		upgradesTab.BackgroundColor3 = if tab == "Upgrades" then BUY_COLOR else OFF_COLOR
		carsTab.BackgroundColor3 = if tab == "Cars" then BUY_COLOR else OFF_COLOR
		limitedsTab.BackgroundColor3 = if tab == "Limiteds" then BUY_COLOR else OFF_COLOR
	end

	-- Sends one request to the server and reports how it went.
	local function ask(remoteName: string, arg: string, success: string)
		if busy then
			return
		end
		local remote = ReplicatedStorage:FindFirstChild(remoteName)
		if not (remote and remote:IsA("RemoteFunction")) then
			status.Text = "The garage isn't ready yet."
			return
		end
		busy = true
		status.Text = ""
		refresh()
		local ok, done, reason = pcall(remote.InvokeServer, remote, arg)
		busy = false
		if ok and done then
			status.Text = success
		elseif ok then
			status.Text = REASONS[reason] or "Couldn't do that."
		else
			status.Text = "Couldn't reach the server."
		end
		refresh()
	end

	for _, info in STATS do
		statRows[info.stat].button.Activated:Connect(function()
			if statRows[info.stat].button.Active then
				ask("BuyUpgrade", info.stat, `{info.stat} upgraded.`)
			end
		end)
	end
	for _, ladderCar in Tuning.Ladder do
		local r = carRows[ladderCar.Id]
		r.button.Activated:Connect(function()
			if not r.button.Active then
				return
			end
			if table.find(owned(), ladderCar.Id) then
				ask("EquipCar", ladderCar.Id, `Now driving the {ladderCar.Name}.`)
			else
				ask("BuyCar", ladderCar.Id, `Bought the {ladderCar.Name}. Equip it to drive it.`)
			end
		end)
	end
	for _, item in Tuning.Limiteds do
		local r = limitedRows[item.Id]
		r.button.Activated:Connect(function()
			if not r.button.Active then
				return
			end
			if item.AdminOnly and item.Id == "FrogCar" then
				local remote = ReplicatedStorage:FindFirstChild("ToggleFrogCar")
				if remote and remote:IsA("RemoteEvent") then
					remote:FireServer()
				end
			else
				ask("BuyLimited", item.Id, `Got the {item.Name}!`)
			end
		end)
	end

	local function setOpen(value: boolean, byGamepad: boolean)
		open = value
		panel.Visible = value
		if value then
			status.Text = ""
			refresh()
		end
		if value and byGamepad then
			local sel: TextButton? = if tab == "Upgrades" then upgradesTab elseif tab == "Cars" then carsTab else limitedsTab
			GuiService.SelectedObject = sel
		elseif not value and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
	end

	local function showTab(name: Tab)
		tab = name
		status.Text = ""
		refresh()
	end
	upgradesTab.Activated:Connect(function()
		showTab("Upgrades")
	end)
	carsTab.Activated:Connect(function()
		showTab("Cars")
	end)
	limitedsTab.Activated:Connect(function()
		showTab("Limiteds")
	end)
	local function nearGarage(): boolean
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not (hrp and hrp:IsA("BasePart")) then
			return false
		end
		for _, garage in CollectionService:GetTagged(GARAGE_TAG) do
			if
				garage:IsA("PVInstance")
				and (garage:GetPivot().Position - hrp.Position).Magnitude <= Tuning.Garage.Reach
			then
				return true
			end
		end
		return false
	end

	openButton.Activated:Connect(function()
		if open or nearGarage() then
			setOpen(not open, false)
		end
	end)
	close.Activated:Connect(function()
		setOpen(false, false)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.KeyCode == Enum.KeyCode.G and not processed then
			if open or nearGarage() then
				setOpen(not open, false)
			end
		elseif input.KeyCode == Enum.KeyCode.E and not processed then
			if open or nearGarage() then
				showTab("Cars")
				setOpen(not open, false)
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonX then
			if open or nearGarage() then
				setOpen(not open, true)
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonB and open then
			setOpen(false, true)
		end
	end)

	local refreshAttrs = { "Cash", "Speed", "Jets", "Toughness", "Grip", "Equipped", "CarsOwned", "LimitedsOwned", "FrogCarEquipped" }
	for _, item in Tuning.Limiteds do
		table.insert(refreshAttrs, `LimitedStock_{item.Id}`)
	end
	for _, attribute in refreshAttrs do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if open then
				refresh()
			end
		end)
	end

	refresh()
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Builds the GARAGE button and panel, once.
function GarageMenu.start()
	if not started then
		started = true
		build()
	end
end

-- True while the panel is open; the car takes no input then.
function GarageMenu.isOpen(): boolean
	return open
end

return GarageMenu
