--!strict
-- GarageMenu (ModuleScript) -> StarterPlayerScripts.GarageMenu
-- The garage panel: buy upgrade levels and ladder cars, equip owned cars, and
-- buy and wear other bodies for a car whose ladder entry lists some. Prize
-- bodies any car can wear (Tuning.AnyBodies) show under every car with a
-- generated look once the player has one, and can't be bought. Once the
-- player has won a prize jet flame (FlameService), a JET FLAME row under
-- REBIRTH turns it on and off, and once they have more than one trail to
-- pick from, a TRAIL row switches between them and off (TrailService). The
-- Cars tab starts with a REBIRTH row, which asks on RebirthConfirm first.
-- The Limiteds tab lists the player's limiteds and the ones on sale now,
-- with the time left and a Robux button (RobuxShop).
-- Within Tuning.Garage.Reach of a model tagged Garage, the ring painted on
-- the ground (GarageRing), it opens in full with G or E (E shows the Cars tab)
-- on a keyboard, or the GARAGE button that shows inside the ring. Anywhere
-- else, the GARAGE button at the left end of the top right row (left of
-- REPLAY while it shows) opens it away from a garage while the car is on the
-- ground: only the Upgrades, Cars and Event tabs, no REBIRTH row. C on a
-- keyboard and X on a gamepad open it either way, on the Upgrades tab while
-- a level is affordable and no new car is, otherwise the Cars tab. The same
-- keys, the panel's X button, and gamepad B close it. During bone rain the
-- Bone Trader's "Trade bones" prompt (E, gamepad X, or a tap) opens it on the
-- Bones tab, which shows anywhere near the trader.
--
-- While the player can afford an upgrade level on the equipped car, red "!"
-- badges show on the GARAGE buttons and the UPGRADES tab. While they can
-- afford a new car, the GARAGE buttons' badges show a car instead, and so
-- does one on the CARS tab. Either way the GARAGE button showing, or the
-- cheapest such price on the open tab, bounces every Tuning.Garage.PulseEvery
-- seconds. The tutorial (TutorialHints) puts its
-- line on the panel's status line with setHint.
--
-- Everything shown comes from the attributes Garage sets on the player, with
-- prices and caps worked out by the same Economy and Tuning the server uses.
-- Purchases go to the server's RemoteFunctions, which decide; the panel only
-- reports why one failed. The first time it opens each session it tells the
-- server, for the onboarding funnel (GarageOpenedEvent, AnalyticsWatch).
-- While the panel is open the car gets no input (Controls), so a gamepad A
-- press on a button doesn't also fire the jets.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CarDesign = require(ReplicatedStorage.CarDesign)
local CarKit = require(ReplicatedStorage.CarKit)
local DinoBox = require(ReplicatedStorage.DinoBox)
local Economy = require(ReplicatedStorage.Economy)
local Flames = require(ReplicatedStorage.Flames)
local Pips = require(ReplicatedStorage.Pips)
local Rebirth = require(ReplicatedStorage.Rebirth)
local Rng = require(ReplicatedStorage.Rng)
local Trails = require(ReplicatedStorage.Trails)
local Tuning = require(ReplicatedStorage.Tuning)
local CarPreview = require(script.Parent.CarPreview)
local DinoSpin = require(script.Parent.DinoSpin)
local RebirthConfirm = require(script.Parent.RebirthConfirm)
local ReplayControls = require(script.Parent.ReplayControls)
local UiStyle = require(script.Parent.UiStyle)

local GarageMenu = {}

local GARAGE_TAG = "Garage"
local CAR_ICON = "🚗" -- the badges' look while a new car is affordable
-- The centers of the away GARAGE button's spots in the top right row of 120
-- by 32 stickers, 128 apart: where REPLAY sits (ReplayControls), and one
-- further left.
local AWAY_BY_DAILY = UDim2.new(1, -584, 0, -20)
local AWAY_BY_REPLAY = UDim2.new(1, -712, 0, -20)

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
	prize: boolean, -- an any-car body, given and never sold
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
	NotEnoughBones = "Not enough bones yet.",
	AllOwned = "You already have every dino car!",
	UnknownBoneShop = "That trade doesn't exist.",
	UnknownBody = "That body doesn't exist.",
	NeedsCar = "You don't own the car this rebirth needs yet.",
	Locked = "Rebirth more to unlock that car.",
	OffSale = "That's not on sale right now.",
	UnknownLimited = "That item doesn't exist.",
	NotWearable = "That one isn't worn on the car.",
	InAir = "Get your wheels on the ground first.",
}

local player = Players.LocalPlayer :: Player
local started = false
local open = false
local away = false -- opened away from a garage: only the Upgrades, Cars and Event tabs
local busy = false
local tab: Tab = "Upgrades"
local hint: string? = nil -- the tutorial's line, shown on the status line
local toldOpened = false -- whether the server has heard the panel opened
local setStatusHint: ((string?, string?) -> ())? = nil -- set once built

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

-- The limiteds with a look the player has on (Garage's LimitedsWorn).
local function limitedsWorn(): { string }
	local value = player:GetAttribute("LimitedsWorn")
	return if typeof(value) == "string" and value ~= "" then string.split(value, ",") else {}
end

-- The prize flames the player has (FlameService's FlamesOwned), oldest first.
local function flamesOwned(): { string }
	local value = player:GetAttribute("FlamesOwned")
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

-- The any-car bodies the player has, from Garage's BodiesOwned_Any.
local function anyBodiesOwned(): { number }
	local value = player:GetAttribute("BodiesOwned_Any")
	local seeds = {}
	if typeof(value) == "string" and value ~= "" then
		for _, text in string.split(value, ",") do
			table.insert(seeds, tonumber(text) :: number)
		end
	end
	return seeds
end

-- The bodies a car can wear besides its own seed: its list, then the
-- any-car bodies if it has a generated look.
local function wearable(car: Economy.Car): { Economy.Body }
	local bodies = table.clone(car.Bodies or {})
	if car.Look == nil then
		for _, body in Tuning.AnyBodies do
			table.insert(bodies, body)
		end
	end
	return bodies
end

local function bodyWorn(car: Economy.Car): number
	local value = player:GetAttribute(`BodyWorn_{car.Id}`)
	return if typeof(value) == "number" then value else car.Seed
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

-- The stat whose next level is the cheapest the player can buy now on the
-- equipped car, or nil.
local function cheapestUpgrade(): Economy.StatName?
	if typeof(player:GetAttribute("Cash")) ~= "number" then
		return nil
	end
	local equippedValue = player:GetAttribute("Equipped")
	local equipped = if typeof(equippedValue) == "string" then equippedValue else Tuning.Ladder[1].Id
	local car = Economy.findCar(Tuning.Ladder, equipped) or Tuning.Ladder[1]
	return Economy.cheapestUpgrade(levels(), car.Caps, number("Cash"), Tuning.Upgrades)
end

-- The cheapest new car the player can buy now, or nil.
local function cheapestCar(): Economy.Car?
	if typeof(player:GetAttribute("Cash")) ~= "number" then
		return nil
	end
	local rebirths = Rebirth.count(player:GetAttribute("Rebirths"))
	return Economy.cheapestCar(Tuning.Ladder, owned(), number("Cash"), rebirths)
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Garage"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5 -- above the HUD and touch buttons

	local openButton = UiStyle.sticker("Open", gui, "GARAGE")
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(0.5, -146, 0, 40) -- left of the fuel bar
	openButton.Size = UDim2.fromOffset(110, 32)
	openButton.Visible = false
	openButton.Active = false
	openButton.Selectable = false
	UiStyle.springy(openButton)
	local garageAlert = UiStyle.alert(openButton)

	-- Whenever the ring's GARAGE button isn't showing. Top right, in the
	-- Roblox top bar like the row it ends: left of REPLAY while that shows,
	-- otherwise in its place left of DAILY.
	local awayButton = UiStyle.sticker("Away", gui, "GARAGE")
	awayButton.AnchorPoint = Vector2.new(0.5, 0.5)
	awayButton.Position = AWAY_BY_DAILY
	awayButton.Size = UDim2.fromOffset(120, 32)
	awayButton.Visible = false
	awayButton.Active = false
	awayButton.Selectable = false
	UiStyle.springy(awayButton)
	local awayAlert = UiStyle.alert(awayButton)

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
	-- Where the tabs sit once springy has centered their anchors. Away from a
	-- garage EVENT moves into LIMITEDS' spot.
	local limitedsSpot = limitedsTab.Position
	local eventSpot = eventTab.Position
	local bonesSpot = bonesTab.Position
	local upgradesAlert = UiStyle.alert(upgradesTab)
	local carsAlert = UiStyle.alert(carsTab)
	UiStyle.setAlertIcon(carsAlert, CAR_ICON)

	local status = UiStyle.text("Status", panel, 16, false)
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.fromScale(0, 1)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.TextColor3 = UiStyle.Yellow
	status.Text = ""
	-- Swaps the tutorial's line on the status line, leaving any other message.
	setStatusHint = function(old: string?, new: string?)
		if status.Text == "" or status.Text == old then
			status.Text = new or ""
		end
	end

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
			local archetype = Economy.withSeed(car, seed, Tuning.AnyBodies).Archetype
			local input = { archetype = archetype, tier = car.Tier, levels = BARE }
			local name = CarDesign.design(Rng.new(seed), input, CarKit, Tuning.CarLooks).name
			local r = carRow(order + k, name)
			r.frame.Visible = false
			local prize = k - 1 > #(car.Bodies or {}) -- wearable puts the any-car bodies last
			local what = if prize then "prize body" else "body"
			table.insert(rows, {
				frame = r.frame,
				detail = r.detail,
				button = r.button,
				preview = r.preview,
				seed = seed,
				name = name,
				kind = `{string.upper(string.sub(archetype, 1, 1))}{string.sub(archetype, 2)} {what}.`,
				prize = prize,
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
			local bodies = wearable(car)
			if #bodies > 0 then
				bodyLists[car.Id] = {
					toggle = row(carsList, order + 1, `{car.Name} bodies`),
					rows = bodyRows(car, bodies, order + 1),
					showing = false,
				}
			end
		end
	end
	local rebirthRow = row(carsList, 0, "Rebirth")
	local flameRow = row(carsList, 1, "Jet flame")
	local trailRow = row(carsList, 2, "Trail")
	local limitedRows: { [string]: Row } = {}
	for i, item in Tuning.Limiteds do
		limitedRows[item.Id] = row(limitedsList, i, item.Name)
	end
	-- Shown when no limited is on sale or owned.
	local noLimitedsRow = row(limitedsList, #Tuning.Limiteds + 1, "Nothing on sale")
	noLimitedsRow.detail.Text = "Limiteds come and go. Check back soon!"
	noLimitedsRow.button.Visible = false
	-- The limited whose Robux prompt is open, to cheer when it arrives.
	local awaitedLimited: string? = nil
	-- Robux prices by product id, asked of Roblox once each.
	local robuxPrices: { [number]: number } = {}
	local askedPrices: { [number]: boolean } = {}
	local function robuxPrice(productId: number, ready: () -> ()): number?
		if not askedPrices[productId] then
			askedPrices[productId] = true
			task.spawn(function()
				local ok, info =
					pcall(MarketplaceService.GetProductInfo, MarketplaceService, productId, Enum.InfoType.Product)
				if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
					robuxPrices[productId] = info.PriceInRobux
					ready()
				end
			end)
		end
		return robuxPrices[productId]
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
			or player:GetAttribute("AxolotlEquipped") == true
			or player:GetAttribute("VelociraptorEquipped") == true
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
		local rebirths = Rebirth.count(player:GetAttribute("Rebirths"))
		local needs = Rebirth.neededCar(rebirths, Tuning.Rebirth)
		local needsCar = Economy.findCar(Tuning.Ladder, needs)
		local nextPay = `x{Rebirth.payMultiplier(rebirths + 1, Tuning.Rebirth)} run pay`
		local done = if rebirths > 0 then `Rebirths: {rebirths}. ` else ""
		if table.find(cars, needs) then
			rebirthRow.detail.Text = `{done}Start over for {nextPay} forever.`
			setButton(rebirthRow.button, "REBIRTH", loaded and not busy, true)
		else
			rebirthRow.detail.Text =
				`{done}Own the {if needsCar then needsCar.Name else needs} to rebirth for {nextPay}.`
			setButton(rebirthRow.button, "LOCKED", false)
		end

		local flames = flamesOwned()
		local newest = flames[#flames]
		local flameLook = if newest then (Tuning.Flames.Looks :: { [string]: Flames.Look })[newest] else nil
		local flameOn = player:GetAttribute("FlameWorn")
		local lit = typeof(flameOn) == "string" and flameOn ~= ""
		flameRow.frame.Visible = flameLook ~= nil
		if flameLook then
			flameRow.detail.Text = if lit
				then `{flameLook.Name} jet flames are on. Off shows your Jets level colors.`
				else `{flameLook.Name} jet flames are off.`
			setButton(flameRow.button, if lit then "TURN OFF" else "TURN ON", loaded and not busy)
		end

		local trailsOwned = player:GetAttribute("TrailsOwned")
		local trailChoice = player:GetAttribute("TrailChoice")
		local trailState: Trails.State = {
			Owned = if typeof(trailsOwned) == "string" and trailsOwned ~= ""
				then string.split(trailsOwned, ",")
				else {},
			Choice = if typeof(trailChoice) == "string" then trailChoice else nil,
		}
		local trailNow = Trails.current(trailState, rebirths)
		trailRow.frame.Visible = #Trails.options(trailState, rebirths) > 1
		if trailNow == "Off" then
			trailRow.detail.Text = "No trail. SWITCH to pick one."
		elseif trailNow == "Rebirth" then
			trailRow.detail.Text = "Your rebirth trail is on."
		else
			local look = (Tuning.Trails.Looks :: { [string]: { Name: string? } })[trailNow]
			trailRow.detail.Text = `{if look and look.Name then look.Name else trailNow} trail is on.`
		end
		setButton(trailRow.button, "SWITCH", loaded and not busy)

		for _, ladderCar in Tuning.Ladder do
			local r = carRows[ladderCar.Id]
			if not r then continue end
			r.detail.Text = carText(ladderCar)
			-- Built the first time the Cars tab shows, with the player's levels
			-- as that car would count them.
			if open and tab == "Cars" then
				r.preview.set(
					Economy.withSeed(ladderCar, bodyWorn(ladderCar), Tuning.AnyBodies),
					Economy.lookLevels(lv, ladderCar)
				)
			end
			if ladderCar.Id == equipped and not inAdminCar() then
				setButton(r.button, "DRIVING", false)
			elseif table.find(cars, ladderCar.Id) then
				setButton(r.button, "EQUIP", loaded and not busy)
			elseif ladderCar.ForSale == false then
				local friends = prizeFriends(ladderCar.Id)
				setButton(r.button, if friends then `{friends} FRIENDS` else "LOCKED", false)
			elseif rebirths < (ladderCar.Rebirths or 0) then
				r.detail.Text = `Unlocks at rebirth {ladderCar.Rebirths}. {r.detail.Text}`
				setButton(r.button, `REBIRTH {ladderCar.Rebirths}`, false)
			else
				setButton(r.button, `$ {withCommas(ladderCar.Price)}`, loaded and not busy and money >= ladderCar.Price, true)
			end
			local list = bodyLists[ladderCar.Id]
			if list then
				local ownsCar = table.find(cars, ladderCar.Id) ~= nil
				local bought = bodiesOwned(ladderCar)
				local given = anyBodiesOwned()
				local worn = bodyWorn(ladderCar)
				local price = ladderCar.BodyPrice or 0
				local function hasBody(body: BodyRow): boolean
					return body.seed == ladderCar.Seed
						or table.find(if body.prize then given else bought, body.seed) ~= nil
				end
				local ownedCount = 0
				for _, body in list.rows do
					if hasBody(body) then
						ownedCount += 1
					end
				end
				-- A car with no list of its own shows its bodies once the
				-- player has a prize body to put on it.
				local listed = ladderCar.Bodies ~= nil or #given > 0
				list.toggle.frame.Visible = listed
				list.toggle.detail.Text = if ownsCar
					then `{ownedCount} of {#list.rows} owned. Same stats, new shape.`
					else `{#list.rows} shapes to collect once you own the {ladderCar.Name}.`
				setButton(list.toggle.button, if list.showing then "HIDE" else "SHOW", true)
				for _, body in list.rows do
					body.frame.Visible = listed and list.showing
					if open and tab == "Cars" and listed and list.showing then
						body.preview.set(Economy.withSeed(ladderCar, body.seed, Tuning.AnyBodies), BARE)
					end
					if not ownsCar then
						body.detail.Text = `{body.kind} Buy the {ladderCar.Name} to use it.`
						setButton(body.button, "LOCKED", false)
					elseif body.seed == worn then
						body.detail.Text = `{body.kind} On your {ladderCar.Name} now.`
						setButton(body.button, "WEARING", false)
					elseif hasBody(body) then
						body.detail.Text = `{body.kind} Yours. Same stats, different shape.`
						setButton(body.button, "WEAR", loaded and not busy)
					elseif body.prize then
						body.detail.Text = if body.seed == Tuning.Daily.BodySeed
							then `{body.kind} Win it on day 7 of the daily reward.`
							else `{body.kind} Won as a prize, never sold.`
						setButton(body.button, "PRIZE", false)
					else
						body.detail.Text = `{body.kind} Same stats as your {ladderCar.Name}.`
						setButton(body.button, `$ {withCommas(price)}`, loaded and not busy and money >= price, true)
					end
				end
			end
		end

		-- Limiteds tab: owned ones, and ones on sale now with time left.
		local ownedLimiteds = limitedsOwned()
		local now = workspace:GetServerTimeNow()
		local limitedsShown = 0
		for _, item: Economy.Limited in Tuning.Limiteds do
			local r = limitedRows[item.Id]
			local isOwned = table.find(ownedLimiteds, item.Id) ~= nil
			local left = if item.ProductId then Economy.saleLeft(item, now) else nil
			r.frame.Visible = isOwned or left ~= nil
			if r.frame.Visible then
				limitedsShown += 1
			end
			r.detail.Text = if left and not isOwned
				then `LEAVES IN {Economy.leavesIn(left)}. {item.Description}`
				elseif isOwned and item.Trail then "Pick it in the Cars tab's TRAIL row."
				else item.Description
			if isOwned then
				if item.Look then
					local worn = table.find(limitedsWorn(), item.Id) ~= nil
					setButton(r.button, if worn then "TAKE OFF" else "WEAR", loaded and not busy)
				elseif item.Id == "FrogCar" then
					local frogEquipped = player:GetAttribute("FrogCarEquipped") == true
					if frogEquipped then
						setButton(r.button, "UNEQUIP", loaded and not busy)
					else
						setButton(r.button, "EQUIP", loaded and not busy)
					end
				else
					setButton(r.button, "OWNED", false)
				end
			elseif item.ProductId and left then
				local price = robuxPrice(item.ProductId, function()
					if open then
						refresh()
					end
				end)
				setButton(r.button, if price then `R$ {withCommas(price)}` else "BUY", loaded and not busy, true)
			end
		end
		noLimitedsRow.frame.Visible = limitedsShown == 0

		-- Bone shop tab
		local bonesVal = player:GetAttribute("Bones")
		local boneBalance = if typeof(bonesVal) == "number" then bonesVal else 0
		for _, item in Tuning.BoneShop do
			local r = boneRows[item.Id]
			r.detail.Text = `{item.Description} You have {boneBalance} bones.`
			local boneOwned = item.CarId and table.find(cars, item.CarId) ~= nil
			if boneOwned then
				setButton(r.button, "OWNED", false)
			elseif item.Mystery and DinoBox.allOwned(Tuning.DinoMystery.Rewards, cars) then
				setButton(r.button, "ALL OWNED", false)
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
					r.detail.Text = "Not owned. Win it from the Dino Mystery Box at the Bone Trader during bone rain."
					setButton(r.button, "LOCKED", false)
				end
			end
		end

		local atBoneTrader = nearBoneTrader()
		if tab == "Bones" and not atBoneTrader then
			tab = "Upgrades"
		end
		if away and tab == "Limiteds" then
			tab = "Upgrades"
		end
		bonesTab.Visible = atBoneTrader
		limitedsTab.Visible = not away
		eventTab.Position = if away then limitedsSpot else eventSpot
		bonesTab.Position = if away then eventSpot else bonesSpot
		rebirthRow.frame.Visible = not away
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
	-- from bounces and flashes when it goes through, and `after` gets what the
	-- server sent back.
	local function ask(remoteName: string, arg: string, success: string, r: Row, seed: number?, after: ((string?) -> ())?)
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
			if after then
				after(reason)
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
					local given = if body.prize then anyBodiesOwned() else bodiesOwned(ladderCar)
					if body.seed == ladderCar.Seed or table.find(given, body.seed) then
						ask("WearBody", ladderCar.Id, `Your {ladderCar.Name} is now the {body.name}.`, body, body.seed)
					else
						ask("BuyBody", ladderCar.Id, `Bought the {body.name}. Press WEAR to put it on.`, body, body.seed)
					end
				end)
			end
		end
	end
	for _, item: Economy.Limited in Tuning.Limiteds do
		local r = limitedRows[item.Id]
		r.button.Activated:Connect(function()
			if not r.button.Active then
				return
			end
			if not table.find(limitedsOwned(), item.Id) then
				ask("BuyLimited", item.Id, "Finish buying in the Robux window.", r, nil, function()
					awaitedLimited = item.Id
				end)
			elseif item.Look then
				local worn = table.find(limitedsWorn(), item.Id) ~= nil
				ask("WearLimited", item.Id, if worn then `{item.Name} off.` else `{item.Name} on!`, r)
			elseif item.Id == "FrogCar" then
				local remote = ReplicatedStorage:FindFirstChild("ToggleFrogCar")
				if remote and remote:IsA("RemoteEvent") then
					remote:FireServer()
				end
			end
		end)
	end
	player:GetAttributeChangedSignal("LimitedsOwned"):Connect(function()
		local id = awaitedLimited
		if id and table.find(limitedsOwned(), id) then
			awaitedLimited = nil
			local item = Economy.findLimited(Tuning.Limiteds, id)
			status.Text = `Got the {if item then item.Name else id}!`
			UiStyle.flash(limitedRows[id].frame)
		end
	end)
	flameRow.button.Activated:Connect(function()
		if not flameRow.button.Active then
			return
		end
		local flames = flamesOwned()
		local newest = flames[#flames]
		local flameOn = player:GetAttribute("FlameWorn")
		if typeof(flameOn) == "string" and flameOn ~= "" then
			ask("WearFlame", "", "Jet flames back to your Jets level colors.", flameRow)
		elseif newest then
			ask("WearFlame", newest, "Prize jet flames on.", flameRow)
		end
	end)

	trailRow.button.Activated:Connect(function()
		if trailRow.button.Active then
			ask("NextTrail", "", "Trail switched.", trailRow)
		end
	end)

	local confirm = RebirthConfirm.new(player:WaitForChild("PlayerGui"))
	rebirthRow.button.Activated:Connect(function()
		if not rebirthRow.button.Active then
			return
		end
		local rebirths = Rebirth.count(player:GetAttribute("Rebirths"))
		local summary: RebirthConfirm.Summary = {
			cash = number("Cash"),
			cars = owned(),
			rebirths = rebirths,
			limiteds = #limitedsOwned(),
			bones = number("Bones"),
		}
		confirm.ask(summary, function()
			local pay = Rebirth.payMultiplier(rebirths + 1, Tuning.Rebirth)
			ask("Rebirth", "", `Reborn! Run pay is now x{pay}.`, rebirthRow)
		end)
	end)

	local spin = DinoSpin.new(player:WaitForChild("PlayerGui"))
	local function spinTo(winner: string)
		busy = true
		refresh()
		spin.play(winner, function()
			busy = false
			refresh()
		end, function()
			local r = eventRows[winner]
			local car = Economy.findCar(Tuning.Ladder, winner)
			if r and car then
				ask("EquipCar", winner, `Now driving the {car.Name}!`, r)
			end
		end)
	end
	for _, item in Tuning.BoneShop do
		local r = boneRows[item.Id]
		r.button.Activated:Connect(function()
			if not r.button.Active then
				return
			end
			if item.Mystery then
				ask("BuyBoneShop", item.Id, "", r, nil, function(winner: string?)
					if winner then
						spinTo(winner)
					end
				end)
				return
			end
			ask("BuyBoneShop", item.Id, if item.CarId then `Got the {item.Name}! Equip it to drive it.` else `Traded {item.BonePrice} bones for $ {withCommas(item.CashReward)}!`, r)
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
		if not value then
			away = false
			spin.close()
			confirm.close()
		end
		if value and not toldOpened then
			toldOpened = true
			local remote = ReplicatedStorage:FindFirstChild("GarageOpenedEvent")
			if remote and remote:IsA("RemoteEvent") then
				remote:FireServer()
			end
		end
		if value then
			status.Text = hint or ""
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
		status.Text = hint or ""
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

	-- Opens in full at a garage. Anywhere else it opens away from a garage, but
	-- only with the car on the ground: the server refuses to rebuild a car in
	-- the air. Either way it starts on Upgrades while a level is affordable.
	local function toggleAnywhere(byGamepad: boolean)
		if open then
			setOpen(false, byGamepad)
			return
		end
		local atGarage = nearGarage()
		if not atGarage and eIsForFlying() then
			UiStyle.play("Denied")
			return
		end
		away = not atGarage
		showTab(if cheapestUpgrade() and not cheapestCar() then "Upgrades" else "Cars")
		setOpen(true, byGamepad)
	end
	awayButton.Activated:Connect(function()
		toggleAnywhere(false)
	end)

	-- The Bone Trader's "Trade bones" prompt (DinoWeather) opens the panel on
	-- the Bones tab, or closes it. While the prompt shows, E and gamepad X are
	-- its keys, so they don't also open the garage. In the air E is a roll.
	local tradePromptShown = false
	local function isTradePrompt(prompt: ProximityPrompt): boolean
		return prompt.Name == "TradePrompt"
	end
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if isTradePrompt(prompt) then
			tradePromptShown = true
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		if isTradePrompt(prompt) then
			tradePromptShown = false
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if not isTradePrompt(prompt) then
			return
		end
		local byGamepad = string.sub(UserInputService:GetLastInputType().Name, 1, 7) == "Gamepad"
		if open then
			setOpen(false, byGamepad)
		elseif not eIsForFlying() then
			away = not nearGarage()
			showTab("Bones")
			setOpen(true, byGamepad)
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
		elseif input.KeyCode == Enum.KeyCode.E and not processed and not tradePromptShown then
			if open or (nearGarage() and not eIsForFlying()) then
				showTab("Cars")
				setOpen(not open, false)
			end
		elseif input.KeyCode == Enum.KeyCode.C and not processed then
			toggleAnywhere(false)
		elseif input.KeyCode == Enum.KeyCode.ButtonX and not tradePromptShown then
			toggleAnywhere(true)
		elseif input.KeyCode == Enum.KeyCode.ButtonB and open then
			setOpen(false, true)
		end
	end)

	-- The ring's GARAGE button shows while the player is inside a garage's
	-- ring, and the away GARAGE button everywhere else. While a level or a new
	-- car is affordable the badges show and the GARAGE button showing or the
	-- cheapest price on the open tab bounces.
	local lastPulse = 0
	task.spawn(function()
		while true do
			task.wait(Tuning.Garage.Ring.CheckEvery)
			local garage = if open then not away else nearGarage()
			openButton.Visible = garage
			openButton.Active = garage
			awayButton.Visible = not garage
			awayButton.Active = not garage

			local stat = cheapestUpgrade()
			local newCar = cheapestCar()
			for _, dot in { garageAlert, awayAlert } do
				dot.Visible = stat ~= nil or newCar ~= nil
				UiStyle.setAlertIcon(dot, if newCar then CAR_ICON else nil)
			end
			upgradesAlert.Visible = stat ~= nil and tab ~= "Upgrades"
			carsAlert.Visible = newCar ~= nil and tab ~= "Cars"
			if (stat or newCar) and os.clock() - lastPulse >= Tuning.Garage.PulseEvery then
				lastPulse = os.clock()
				local newCarRow = if newCar then carRows[newCar.Id] else nil
				if open and tab == "Upgrades" and stat and not busy then
					UiStyle.pulse(statRows[stat].button)
				elseif open and tab == "Cars" and newCarRow and not busy then
					UiStyle.pulse(newCarRow.button)
				elseif not open then
					UiStyle.pulse(if garage then openButton else awayButton)
				end
			end
		end
	end)

	-- The car previews only spin while someone can see them.
	RunService.RenderStepped:Connect(function(dt: number)
		awayButton.Position = if ReplayControls.buttonShown() then AWAY_BY_REPLAY else AWAY_BY_DAILY
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

	-- The Limiteds tab's sale countdowns tick while it shows.
	task.spawn(function()
		while true do
			task.wait(1)
			if open and tab == "Limiteds" and not busy then
				refresh()
			end
		end
	end)

	local refreshAttrs = { "Cash", "Speed", "Jets", "Toughness", "Grip", "Brakes", "Equipped", "CarsOwned", "LimitedsOwned", "FrogCarEquipped", "HeliCarEquipped", "PlaneCarEquipped", "AxolotlEquipped", "VelociraptorEquipped", "Bones", "Rebirths" }
	for id in bodyLists do
		table.insert(refreshAttrs, `BodiesOwned_{id}`)
		table.insert(refreshAttrs, `BodyWorn_{id}`)
	end
	table.insert(refreshAttrs, "BodiesOwned_Any")
	table.insert(refreshAttrs, "FlamesOwned")
	table.insert(refreshAttrs, "FlameWorn")
	table.insert(refreshAttrs, "TrailsOwned")
	table.insert(refreshAttrs, "TrailChoice")
	table.insert(refreshAttrs, "LimitedsWorn")
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

-- True if the player can buy an upgrade level on the equipped car now.
function GarageMenu.canAffordUpgrade(): boolean
	return cheapestUpgrade() ~= nil
end

-- Shows a line on the panel's status line until replaced, or nil to clear it.
function GarageMenu.setHint(text: string?)
	if text == hint then
		return
	end
	local old = hint
	hint = text
	local set = setStatusHint
	if set then
		set(old, text)
	end
end

return GarageMenu
