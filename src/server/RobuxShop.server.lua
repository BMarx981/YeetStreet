--!strict
-- RobuxShop (Script) -> ServerScriptService.RobuxShop
-- Robux purchases. The only code that sets MarketplaceService.ProcessReceipt,
-- since a game can have just one.
--
-- Limiteds (Tuning.Limiteds) sell as developer products. The client asks
-- through the RemoteFunction ReplicatedStorage.BuyLimited(id), which returns
-- (ok, reason): the server checks the item is on sale with a product and not
-- owned (Economy.robuxProblem), then opens Roblox's purchase prompt.
--
-- A receipt grants its limited and records its id in the player's data
-- (Purchases), then saves at once. Only a saved grant tells Roblox it was
-- granted; otherwise Roblox sends the receipt again later, and the recorded
-- id stops a second grant. A receipt that arrives after the sale window
-- closed still grants, since the player paid. In Studio, where data may not
-- save, a grant counts without the save.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ReplicatedStorage.Economy)
local Purchases = require(ReplicatedStorage.Purchases)
local Tuning = require(ReplicatedStorage.Tuning)
local Garage = require(ServerScriptService.Garage)
local PlayerData = require(ServerScriptService.PlayerData)

local lastAskAt: { [Player]: number } = {}

local buyLimited = Instance.new("RemoteFunction")
buyLimited.Name = "BuyLimited"
buyLimited.OnServerInvoke = function(player: Player, id: any): (boolean, string?)
	local now = os.clock()
	if now - (lastAskAt[player] or -math.huge) < Tuning.Garage.RequestGap then
		return false, "TooSoon"
	end
	lastAskAt[player] = now
	local item = if typeof(id) == "string" then Economy.findLimited(Tuning.Limiteds, id) else nil
	if not item then
		return false, "UnknownLimited"
	end
	local data = PlayerData.get(player)
	if not data then
		return false, "NotLoaded"
	end
	local problem = Economy.robuxProblem(data.Economy, item, os.time())
	if problem then
		return false, problem
	end
	MarketplaceService:PromptProductPurchase(player, item.ProductId :: number)
	return true, nil
end
buyLimited.Parent = ReplicatedStorage

Players.PlayerRemoving:Connect(function(player: Player)
	lastAskAt[player] = nil
end)

MarketplaceService.ProcessReceipt = function(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local item = Economy.findLimitedByProduct(Tuning.Limiteds, receipt.ProductId)
	if not item then
		warn(`RobuxShop: no limited sells product {receipt.ProductId}, receipt {receipt.PurchaseId} left pending`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Roblox sends pending receipts as the player joins, before their data loads.
	local data = PlayerData.waitFor(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not Purchases.seen(data.Purchases, receipt.PurchaseId) then
		data.Purchases = Purchases.record(data.Purchases, receipt.PurchaseId, Tuning.Save.KeepReceipts)
		if table.find(data.Economy.Limiteds, item.Id) then
			warn(`RobuxShop: {player.Name} bought {item.Id} again, already owned`)
		end
		Garage.giveLimited(player, item.Id)
	end
	if PlayerData.saveNow(player) or RunService:IsStudio() then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
