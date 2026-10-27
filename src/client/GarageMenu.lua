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
local Pips = require(ReplicatedStorage.Pips)
local Tuning = require(ReplicatedStorage.Tuning)
local UiStyle = require(script.Parent.UiStyle)

local GarageMenu = {}

local GARAGE_TAG = "Garage"

type Tab = "Upgrades" | "Cars" | "Limiteds" | "Bones" | "Event"

type Row = {
	frame: Frame,
	detail: TextLabel,
	button: TextButton,
}

type StatRow = Row & {
	pips: Frame,
	level: TextLabel,
}

local STATS: { { stat: Economy.StatName, about: string, icon: string } } = {
	{ stat = "Speed", about = "Top speed on the ground", icon = "⚡" },
	{ stat = "Jets", about = "Jet power, fuel, recharge, and air turning", icon = "🚀" },
	{ stat = "Toughness", about = "How hard a hit the car takes before it wrecks", icon = "🛡️" },
	{ stat = "Grip", about = "Tire grip for corners and landings", icon = "🧲" },
}

local PIP_COUNT = 10

local REASONS: { [string]: string } = {
	NotEnoughCash = "Not enough cash yet.",
	AtCap = "This car is maxed out there. A better car raises the limit.",
	Owned = "You already own that.",
	NotOwned = "Buy that car first.",
	TooSoon = "One moment...",
	NotLoaded = "Your garage is still loading.",
	SoldOut = "That item is sold out.",
	UnknownLimited = "That item doesn't exist.",
	NotEnoughBones = "Not enough bones yet.",
	UnknownBoneShop = "That trade doesn't exist.",
}

local player = Players.LocalPlayer :: Player
local started = false
local open = false
local busy = false
local tab: Tab = "Upgrades"

local function withCommas(n: number): string
	local digits = tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (digits:gsub("^,", ""))
end

-- `buy` marks a purchase; its row glows while the player can afford it.
local function setButton(b: TextButton, label: string, enabled: boolean, buy: boolean?)
	b.Text = label
	b.Active = enabled
	b.AutoButtonColor = enabled
	b.Selectable = enabled
	UiStyle.setSticker(b, enabled)
	b.TextTransparency = if enabled then 0 else 0.35
	local plate = b.Parent
	if plate and plate:IsA("GuiObject") then
		UiStyle.setGlow(plate, enabled and buy == true)
	end
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

	local openButton = UiStyle.sticker("Open", gui, "GARAGE")
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(0.5, -146, 0, 6)
	openButton.Size = UDim2.fromOffset(110, 32)
	openButton.Visible = false
	openButton.Active = false
	openButton.Selectable = false

	local panel, close = UiStyle.panel(gui, "GARAGE", Vector2.new(600, 460))
	local top = UiStyle.HeaderHeight

	local cash = UiStyle.text("Cash", panel, 28, true)
	cash.AnchorPoint = Vector2.new(1, 0)
	cash.Position = UDim2.new(1, -48, 0, 0)
	cash.Size = UDim2.new(0.5, 0, 0, 38)
	cash.TextXAlignment = Enum.TextXAlignment.Right
	cash.TextColor3 = UiStyle.Cash

	local function tabButton(name: Tab, x: number): TextButton
		local b = UiStyle.sticker(`{name}Tab`, panel, string.upper(name))
		b.Position = UDim2.fromOffset(x, top)
		b.Size = UDim2.fromOffset(108, 32)
		b.TextSize = 18
		return b
	end
	local upgradesTab = tabButton("Upgrades", 0)
	local carsTab = tabButton("Cars", 114)
	local limitedsTab = tabButton("Limiteds", 228)
	local eventTab = tabButton("Event", 342)
	local bonesTab = tabButton("Bones", 456)

	local status = UiStyle.text("Status", panel, 16, false)
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.fromScale(0, 1)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.TextColor3 = UiStyle.Yellow
	status.Text = ""

	local function tabList(name: Tab): ScrollingFrame
		local list = Instance.new("ScrollingFrame")
		list.Name = `{name}List`
		list.Position = UDim2.fromOffset(0, top + 42)
		list.Size = UDim2.new(1, 0, 1, -(top + 42) - 26)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 6
		list.ScrollBarImageColor3 = UiStyle.Yellow
		list.CanvasSize = UDim2.new()
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.Parent = panel
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = list
		-- Room for the plates' outlines, which would clip at the edges.
		local inset = Instance.new("UIPadding")
		inset.PaddingTop = UDim.new(0, 3)
		inset.PaddingBottom = UDim.new(0, 3)
		inset.PaddingLeft = UDim.new(0, 3)
		inset.Parent = list
		return list
	end
	local upgradesList = tabList("Upgrades")
	local carsList = tabList("Cars")
	local limitedsList = tabList("Limiteds")
	local bonesList = tabList("Bones")
	local eventList = tabList("Event")

	local function row(list: ScrollingFrame, order: number, name: string): Row
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, -12, 0, 62)
		frame.Parent = list
		UiStyle.plate(frame)
		local heading = UiStyle.text("Name", frame, 24, true)
		heading.Text = string.upper(name)
		heading.Position = UDim2.fromOffset(22, 6)
		heading.Size = UDim2.new(1, -166, 0, 26)
		local detail = UiStyle.text("Detail", frame, 14, false)
		detail.TextColor3 = UiStyle.Ink
		detail.Position = UDim2.fromOffset(22, 34)
		detail.Size = UDim2.new(1, -166, 0, 20)
		detail.TextTruncate = Enum.TextTruncate.AtEnd
		local action = UiStyle.sticker("Action", frame, "")
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.new(1, -16, 0.5, 0)
		action.Size = UDim2.fromOffset(124, 38)
		return { frame = frame, detail = detail, button = action }
	end

	-- An upgrade row: a taller plate with the stat's icon and a level bar.
	local function statRow(order: number, name: string, icon: string): StatRow
		local r = row(upgradesList, order, name)
		r.frame.Size = UDim2.new(1, -12, 0, 80)
		local badge = UiStyle.badge(r.frame, icon, 50)
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 16, 0.5, 0)
		local heading = r.frame:FindFirstChild("Name") :: TextLabel
		heading.Position = UDim2.fromOffset(80, 6)
		heading.Size = UDim2.new(1, -224, 0, 26)
		local pips = UiStyle.pips(r.frame, PIP_COUNT)
		pips.Position = UDim2.fromOffset(80, 36)
		local level = UiStyle.text("Level", r.frame, 18, true)
		level.Position = UDim2.fromOffset(80 + pips.Size.X.Offset + 10, 31)
		level.Size = UDim2.fromOffset(90, 20)
		r.detail.Position = UDim2.fromOffset(80, 52)
		r.detail.Size = UDim2.new(1, -224, 0, 20)
		return {
			frame = r.frame,
			detail = r.detail,
			button = r.button,
			pips = pips,
			level = level,
		}
	end

	local statRows: { [Economy.StatName]: StatRow } = {}
	for i, info in STATS do
		statRows[info.stat] = statRow(i, info.stat, info.icon)
	end
	local carRows: { [string]: Row } = {}
	local eventRows: { [string]: Row } = {}
	for i, car in Tuning.Ladder do
		if car.Tier == "Dino" then
			eventRows[car.Id] = row(eventList, i, car.Name)
		else
			carRows[car.Id] = row(carsList, i, car.Name)
		end
	end
	local limitedRows: { [string]: Row } = {}
	for i, item in Tuning.Limiteds do
		limitedRows[item.Id] = row(limitedsList, i, item.Name)
	end
	local boneRows: { [string]: Row } = {}
	for i, item in Tuning.BoneShop do
		boneRows[item.Id] = row(bonesList, i, item.Name)
	end

	local function nearBoneTrader(): boolean
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not (hrp and hrp:IsA("BasePart")) then
			return false
		end
		for _, trader in CollectionService:GetTagged("BoneTrader") do
			if
				trader:IsA("PVInstance")
				and (trader:GetPivot().Position - hrp.Position).Magnitude <= Tuning.Garage.Reach
			then
				return true
			end
		end
		return false
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
			local counts = if level > cap then ` This car uses {cap}.` else ""
			local free = if car.Bonus > 0 then ` +{car.Bonus} free.` else ""
			r.level.Text = `{level} / {cap}`
			UiStyle.setPips(r.pips, Pips.filled(level, cap, PIP_COUNT))
			r.detail.Text = `{info.about}.{counts}{free}`
			if level >= cap then
				setButton(r.button, "MAX", false)
			else
				local cost = Economy.upgradeCost(level, Tuning.Upgrades)
				setButton(r.button, `$ {withCommas(cost)}`, loaded and not busy and money >= cost, true)
			end
		end

		local cars = owned()
		for _, ladderCar in Tuning.Ladder do
			local r = carRows[ladderCar.Id]
			if not r then continue end
			r.detail.Text = carText(ladderCar)
			if ladderCar.Id == equipped then
				setButton(r.button, "DRIVING", false)
			elseif table.find(cars, ladderCar.Id) then
				setButton(r.button, "EQUIP", loaded and not busy)
			else
				setButton(r.button, `$ {withCommas(ladderCar.Price)}`, loaded and not busy and money >= ladderCar.Price, true)
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
							setButton(r.button, "UNEQUIP", loaded and not busy)
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
					setButton(r.button, `$ {withCommas(item.Price)}`, loaded and not busy and money >= item.Price, true)
				end
			end
		end

		-- Bone shop tab
		local boneCoinsVal = player:GetAttribute("BoneCoins")
		local boneBalance = if typeof(boneCoinsVal) == "number" then boneCoinsVal else 0
		for _, item in Tuning.BoneShop do
			local r = boneRows[item.Id]
			r.detail.Text = `{item.Description} You have {boneBalance} bones.`
			local boneOwned = item.CarId and table.find(cars, item.CarId) ~= nil
			if boneOwned then
				setButton(r.button, "OWNED", false)
			else
				setButton(r.button, `{item.BonePrice} bones`, loaded and not busy and boneBalance >= item.BonePrice, true)
			end
		end

		-- Event tab
		for _, ladderCar in Tuning.Ladder do
			if ladderCar.Tier ~= "Dino" then continue end
			local r = eventRows[ladderCar.Id]
			if r then
				if table.find(cars, ladderCar.Id) then
					if ladderCar.Id == equipped then
						r.detail.Text = "Currently equipped. Click unequip to go back to your previous car."
						setButton(r.button, "UNEQUIP", loaded and not busy)
					else
						r.detail.Text = "You own this car. Click equip to drive it!"
						setButton(r.button, "EQUIP", loaded and not busy)
					end
				else
					r.detail.Text = "Not owned. Visit the Bone Trader during bone rain to buy this car for 1,000 bones."
					setButton(r.button, "LOCKED", false)
				end
			end
		end

		local atBoneTrader = nearBoneTrader()
		if tab == "Bones" and not atBoneTrader then
			tab = "Upgrades"
		end
		bonesTab.Visible = atBoneTrader
		upgradesList.Visible = tab == "Upgrades"
		carsList.Visible = tab == "Cars"
		limitedsList.Visible = tab == "Limiteds"
		bonesList.Visible = tab == "Bones" and atBoneTrader
		eventList.Visible = tab == "Event"
		UiStyle.setSticker(upgradesTab, tab == "Upgrades")
		UiStyle.setSticker(carsTab, tab == "Cars")
		UiStyle.setSticker(limitedsTab, tab == "Limiteds")
		UiStyle.setSticker(bonesTab, tab == "Bones")
		UiStyle.setSticker(eventTab, tab == "Event")
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
		if not r then continue end
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
	for _, item in Tuning.BoneShop do
		local r = boneRows[item.Id]
		r.button.Activated:Connect(function()
			if not r.button.Active then
				return
			end
			ask("BuyBoneShop", item.Id, if item.Mystery then "The egg is hatching... what's inside?" elseif item.CarId then `Got the {item.Name}! Equip it to drive it.` else `Traded {item.BonePrice} bones for $ {withCommas(item.CashReward)}!`)
		end)
	end
	for _, ladderCar in Tuning.Ladder do
		if ladderCar.Tier ~= "Dino" then continue end
		local r = eventRows[ladderCar.Id]
		if r then
			r.button.Activated:Connect(function()
				if not r.button.Active then
					return
				end
				local currentEquipped = player:GetAttribute("Equipped")
				if typeof(currentEquipped) ~= "string" then
					currentEquipped = Tuning.Ladder[1].Id
				end
				if ladderCar.Id == currentEquipped then
					ask("EquipCar", Tuning.Ladder[1].Id, `Unequipped the {ladderCar.Name}.`)
				else
					ask("EquipCar", ladderCar.Id, `Now driving the {ladderCar.Name}!`)
				end
			end)
		end
	end

	local function setOpen(value: boolean, byGamepad: boolean)
		open = value
		panel.Visible = value
		if value then
			status.Text = ""
			refresh()
		end
		if value and byGamepad then
			local sel: TextButton? = if tab == "Upgrades" then upgradesTab elseif tab == "Cars" then carsTab elseif tab == "Bones" then bonesTab elseif tab == "Event" then eventTab else limitedsTab
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
	bonesTab.Activated:Connect(function()
		showTab("Bones")
	end)
	eventTab.Activated:Connect(function()
		showTab("Event")
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

	local refreshAttrs = { "Cash", "Speed", "Jets", "Toughness", "Grip", "Equipped", "CarsOwned", "LimitedsOwned", "FrogCarEquipped", "BoneCoins" }
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
