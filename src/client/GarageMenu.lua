--!strict
-- GarageMenu (ModuleScript) -> StarterPlayerScripts.GarageMenu
-- The garage panel: buy upgrade levels and ladder cars, equip owned cars, and
-- buy and wear other bodies for a car whose ladder entry lists some.
-- It opens only within Tuning.Garage.Reach of a model tagged Garage, the ring
-- painted on the ground (GarageRing), with G or E (E shows the Cars tab) on a
-- keyboard or X on a gamepad. The same keys, the panel's X button, and gamepad
-- B close it.
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
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CarDesign = require(ReplicatedStorage.CarDesign)
local CarKit = require(ReplicatedStorage.CarKit)
local Economy = require(ReplicatedStorage.Economy)
local Pips = require(ReplicatedStorage.Pips)
local Rng = require(ReplicatedStorage.Rng)
local Tuning = require(ReplicatedStorage.Tuning)
local CarPreview = require(script.Parent.CarPreview)
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

type CarRow = Row & {
	preview: CarPreview.Preview,
}

type BodyRow = CarRow & {
	seed: number,
	name: string,
	kind: string, -- says the car type, such as "Hover body."
}

-- A car's bodies: a row that shows or hides the list, and the list itself.
type BodyList = {
	toggle: Row,
	rows: { BodyRow },
	showing: boolean,
}

local STATS: { { stat: Economy.StatName, about: string, icon: string } } = {
	{ stat = "Speed", about = "Top speed on the ground", icon = "⚡" },
	{ stat = "Jets", about = "Jet power, fuel, recharge, and air turning", icon = "🚀" },
	{ stat = "Toughness", about = "How hard a hit the car takes before it wrecks", icon = "🛡️" },
	{ stat = "Grip", about = "Tire grip for corners and landings", icon = "🧲" },
	{ stat = "Brakes", about = "How fast the car stops on the ground", icon = "🛑" },
}

local PIP_COUNT = 10

-- Body previews show no upgrade parts, which would hide the shapes.
local BARE: Economy.Levels = { Speed = 0, Jets = 0, Toughness = 0, Grip = 0, Brakes = 0 }

local REASONS: { [string]: string } = {
	NotEnoughCash = "Not enough cash yet.",
	AtCap = "This car is maxed out there. A better car raises the limit.",
	Owned = "You already own that.",
	NotOwned = "Buy that car first.",
	NotForSale = "That car can't be bought. Invite friends to win it!",
	TooSoon = "One moment...",
	NotLoaded = "Your garage is still loading.",
	SoldOut = "That item is sold out.",
	UnknownLimited = "That item doesn't exist.",
	NotEnoughBones = "Not enough bones yet.",
	UnknownBoneShop = "That trade doesn't exist.",
	UnknownBody = "That body doesn't exist.",
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
		Brakes = number("Brakes"),
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

local function bodiesOwned(car: Economy.Car): { number }
	local value = player:GetAttribute(`BodiesOwned_{car.Id}`)
	local seeds = {}
	if typeof(value) == "string" and value ~= "" then
		for _, text in string.split(value, ",") do
			table.insert(seeds, tonumber(text) :: number)
		end
	end
	return seeds
end

local function bodyWorn(car: Economy.Car): number
	local value = player:GetAttribute(`BodyWorn_{car.Id}`)
	return if typeof(value) == "number" then value else car.Seed
end

local function limitedStockRemaining(id: string): number
	local value = player:GetAttribute(`LimitedStock_{id}`)
	return if typeof(value) == "number" then value else 0
end

local function carText(car: Economy.Car): string
	local caps = car.Caps
	local free = if car.Bonus > 0 then `+{car.Bonus} free levels. ` else ""
	if
		caps.Speed == caps.Jets
		and caps.Jets == caps.Toughness
		and caps.Toughness == caps.Grip
		and caps.Grip == caps.Brakes
	then
		return `{free}Max level {caps.Speed} on every stat`
	end
	return `{free}Max: Speed {caps.Speed}, Jets {caps.Jets}, Tough {caps.Toughness}, Grip {caps.Grip}, Brakes {caps.Brakes}`
end

-- How many invited friends win the car, if it is an invite prize.
local function prizeFriends(id: string): number?
	for _, milestone in Tuning.Invites.Milestones do
		if milestone.CarId == id then
			return milestone.Friends
		end
	end
	return nil
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
	local setCash = UiStyle.counter(cash, function(n: number): string
		return `$ {withCommas(n)}`
	end)

	local function tabButton(name: Tab, x: number): TextButton
		local b = UiStyle.sticker(`{name}Tab`, panel, string.upper(name))
		b.Position = UDim2.fromOffset(x, top)
		b.Size = UDim2.fromOffset(108, 32)
		b.TextSize = 18
		UiStyle.springy(b)
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
		UiStyle.springy(action)
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

	-- A car row: a taller plate with a dark window showing the car spinning.
	local function carRow(order: number, name: string): CarRow
		local r = row(carsList, order, name)
		r.frame.Size = UDim2.new(1, -12, 0, 96)
		local window = Instance.new("Frame")
		window.Name = "Window"
		window.AnchorPoint = Vector2.new(0, 0.5)
		window.Position = UDim2.new(0, 16, 0.5, 0)
		window.Size = UDim2.fromOffset(140, 80)
		window.BackgroundColor3 = UiStyle.Asphalt
		window.Parent = r.frame
		UiStyle.corner(window, 6)
		UiStyle.stroke(window, 2, UiStyle.Ink, true)
		local preview = CarPreview.new(window)
		local heading = r.frame:FindFirstChild("Name") :: TextLabel
		heading.Position = UDim2.fromOffset(168, 10)
		heading.Size = UDim2.new(1, -312, 0, 26)
		r.detail.Position = UDim2.fromOffset(168, 40)
		r.detail.Size = UDim2.new(1, -312, 0, 36)
		r.detail.TextWrapped = true
		r.detail.TextYAlignment = Enum.TextYAlignment.Top
		return {
			frame = r.frame,
			detail = r.detail,
			button = r.button,
			preview = preview,
		}
	end

	-- The rows for a car's own seed and each body on its list, hidden until
	-- asked for.
	local function bodyRows(car: Economy.Car, bodies: { Economy.Body }, order: number): { BodyRow }
		local rows: { BodyRow } = {}
		local seeds = { car.Seed }
		for _, body in bodies do
			table.insert(seeds, body.Seed)
		end
		for k, seed in seeds do
			local archetype = Economy.withSeed(car, seed).Archetype
			local input = { archetype = archetype, tier = car.Tier, levels = BARE }
			local name = CarDesign.design(Rng.new(seed), input, CarKit, Tuning.CarLooks).name
			local r = carRow(order + k, name)
			r.frame.Visible = false
			table.insert(rows, {
				frame = r.frame,
				detail = r.detail,
				button = r.button,
				preview = r.preview,
				seed = seed,
				name = name,
				kind = `{string.upper(string.sub(archetype, 1, 1))}{string.sub(archetype, 2)} body.`,
			})
		end
		return rows
	end

	local carRows: { [string]: CarRow } = {}
	local eventRows: { [string]: Row } = {}
	local bodyLists: { [string]: BodyList } = {}
	for i, car in Tuning.Ladder do
		if car.Tier == "Dino" then
			eventRows[car.Id] = row(eventList, i, car.Name)
		else
			local order = i * 100 -- room for the car's body rows right under it
			carRows[car.Id] = carRow(order, car.Name)
			if car.Bodies then
				bodyLists[car.Id] = {
					toggle = row(carsList, order + 1, `{car.Name} bodies`),
					rows = bodyRows(car, car.Bodies, order + 1),
					showing = false,
				}
			end
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

	-- In a car from an admin toggle, the saved car isn't the one being driven,
	-- so it can be picked (Garage takes the player out of the toggled one).
	local function inAdminCar(): boolean
		return player:GetAttribute("HeliCarEquipped") == true
			or player:GetAttribute("PlaneCarEquipped") == true
			or player:GetAttribute("FrogCarEquipped") == true
	end

	local function refresh()
		local cashValue = player:GetAttribute("Cash")
		local loaded = typeof(cashValue) == "number"
		local money = number("Cash")
		if loaded then
			setCash(money)
		else
			cash.Text = "$ ..."
		end
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
			-- Built the first time the Cars tab shows, with the player's levels
			-- as that car would count them.
			if open and tab == "Cars" then
				r.preview.set(Economy.withSeed(ladderCar, bodyWorn(ladderCar)), Economy.lookLevels(lv, ladderCar))
			end
			if ladderCar.Id == equipped and not inAdminCar() then
				setButton(r.button, "DRIVING", false)
			elseif table.find(cars, ladderCar.Id) then
				setButton(r.button, "EQUIP", loaded and not busy)
			elseif ladderCar.ForSale == false then
				local friends = prizeFriends(ladderCar.Id)
				setButton(r.button, if friends then `{friends} FRIENDS` else "LOCKED", false)
			else
				setButton(r.button, `$ {withCommas(ladderCar.Price)}`, loaded and not busy and money >= ladderCar.Price, true)
			end
			local list = bodyLists[ladderCar.Id]
			if list then
				local ownsCar = table.find(cars, ladderCar.Id) ~= nil
				local bought = bodiesOwned(ladderCar)
				local worn = bodyWorn(ladderCar)
				local price = ladderCar.BodyPrice or 0
				list.toggle.detail.Text = if ownsCar
					then `{#bought + 1} of {#list.rows} owned. Same stats, new shape.`
					else `{#list.rows} shapes to collect once you own the {ladderCar.Name}.`
				setButton(list.toggle.button, if list.showing then "HIDE" else "SHOW", true)
				for _, body in list.rows do
					body.frame.Visible = list.showing
					if open and tab == "Cars" and list.showing then
						body.preview.set(Economy.withSeed(ladderCar, body.seed), BARE)
					end
					if not ownsCar then
						body.detail.Text = `{body.kind} Buy the {ladderCar.Name} to use it.`
						setButton(body.button, "LOCKED", false)
					elseif body.seed == worn then
						body.detail.Text = `{body.kind} On your {ladderCar.Name} now.`
						setButton(body.button, "WEARING", false)
					elseif body.seed == ladderCar.Seed or table.find(bought, body.seed) then
						body.detail.Text = `{body.kind} Yours. Same stats, different shape.`
						setButton(body.button, "WEAR", loaded and not busy)
					else
						body.detail.Text = `{body.kind} Same stats as your {ladderCar.Name}.`
						setButton(body.button, `$ {withCommas(price)}`, loaded and not busy and money >= price, true)
					end
				end
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
					if ladderCar.Id == equipped and not inAdminCar() then
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

	-- Sends one request to the server and reports how it went. The row it came
	-- from bounces and flashes when it goes through.
	local function ask(remoteName: string, arg: string, success: string, r: Row, seed: number?)
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
		local ok, done, reason = pcall(remote.InvokeServer, remote, arg, seed)
		busy = false
		if ok and done then
			status.Text = success
		elseif ok then
			status.Text = REASONS[reason] or "Couldn't do that."
		else
			status.Text = "Couldn't reach the server."
		end
		refresh()
		if ok and done then
			UiStyle.bounce(r.button)
			UiStyle.flash(r.frame)
			if string.sub(remoteName, 1, 3) == "Buy" then
				UiStyle.play("Buy")
			end
		else
			UiStyle.play("Denied")
		end
	end

	for _, info in STATS do
		statRows[info.stat].button.Activated:Connect(function()
			if statRows[info.stat].button.Active then
				ask("BuyUpgrade", info.stat, `{info.stat} upgraded.`, statRows[info.stat])
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
				ask("EquipCar", ladderCar.Id, `Now driving the {ladderCar.Name}.`, r)
			else
				ask("BuyCar", ladderCar.Id, `Bought the {ladderCar.Name}. Equip it to drive it.`, r)
			end
		end)
		local list = bodyLists[ladderCar.Id]
		if list then
			list.toggle.button.Activated:Connect(function()
				list.showing = not list.showing
				refresh()
			end)
			for _, body in list.rows do
				body.button.Activated:Connect(function()
					if not body.button.Active then
						return
					end
					if body.seed == ladderCar.Seed or table.find(bodiesOwned(ladderCar), body.seed) then
						ask("WearBody", ladderCar.Id, `Your {ladderCar.Name} is now the {body.name}.`, body, body.seed)
					else
						ask("BuyBody", ladderCar.Id, `Bought the {body.name}. Press WEAR to put it on.`, body, body.seed)
					end
				end)
			end
		end
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
				ask("BuyLimited", item.Id, `Got the {item.Name}!`, r)
			end
		end)
	end
	for _, item in Tuning.BoneShop do
		local r = boneRows[item.Id]
		r.button.Activated:Connect(function()
			if not r.button.Active then
				return
			end
			ask("BuyBoneShop", item.Id, if item.Mystery then "The egg is hatching... what's inside?" elseif item.CarId then `Got the {item.Name}! Equip it to drive it.` else `Traded {item.BonePrice} bones for $ {withCommas(item.CashReward)}!`, r)
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
				if ladderCar.Id == currentEquipped and not inAdminCar() then
					ask("EquipCar", Tuning.Ladder[1].Id, `Unequipped the {ladderCar.Name}.`, r)
				else
					ask("EquipCar", ladderCar.Id, `Now driving the {ladderCar.Name}!`, r)
				end
			end)
		end
	end

	local function setOpen(value: boolean, byGamepad: boolean)
		if value then
			UiStyle.closeOtherMenus(panel)
		end
		open = value
		UiStyle.show(panel, value)
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
	UiStyle.registerMenu(panel, function()
		if open then
			setOpen(false, false)
		end
	end)

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

	-- E is for flying while the car is in the air (roll) or a HeliCar's rotor is
	-- out (climb), so only G opens the panel then.
	local function eIsForFlying(): boolean
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local car = seat and seat.Parent
		if not (character and seat and car) then
			return false
		end
		if car:GetAttribute("RotorOut") == true then
			return true
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, car }
		params.RespectCanCollide = true
		return workspace:Raycast(seat.Position, Vector3.new(0, -Tuning.Garage.GroundCheck, 0), params) == nil
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
			if open or (nearGarage() and not eIsForFlying()) then
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

	-- The car previews only spin while someone can see them.
	RunService.RenderStepped:Connect(function(dt: number)
		if open and tab == "Cars" then
			for _, r in carRows do
				r.preview.spin(dt)
			end
			for _, list in bodyLists do
				if list.showing then
					for _, body in list.rows do
						body.preview.spin(dt)
					end
				end
			end
		end
	end)

	local refreshAttrs = { "Cash", "Speed", "Jets", "Toughness", "Grip", "Brakes", "Equipped", "CarsOwned", "LimitedsOwned", "FrogCarEquipped", "HeliCarEquipped", "PlaneCarEquipped", "BoneCoins" }
	for _, item in Tuning.Limiteds do
		table.insert(refreshAttrs, `LimitedStock_{item.Id}`)
	end
	for id in bodyLists do
		table.insert(refreshAttrs, `BodiesOwned_{id}`)
		table.insert(refreshAttrs, `BodyWorn_{id}`)
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
