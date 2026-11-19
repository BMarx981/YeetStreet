--!strict
-- Purchases (ModuleScript) -> ReplicatedStorage.Purchases
-- The Robux receipts a player's data has already granted. Pure, see
-- InputAxes.
--
-- Roblox can send the same receipt more than once, until the game says it
-- was granted. The receipt id is saved together with what it granted, so a
-- repeat never grants twice. Only the newest few are kept
-- (Tuning.Save.KeepReceipts), since Roblox only retries recent ones.

local Purchases = {}

export type State = {
	Receipts: { string }, -- receipt (PurchaseId) ids, oldest first
}

function Purchases.new(): State
	return { Receipts = {} }
end

-- A valid state from whatever was saved; nil for saves from before receipts.
function Purchases.reconcile(saved: any): State
	local state = Purchases.new()
	if typeof(saved) == "table" and typeof(saved.Receipts) == "table" then
		for _, id in saved.Receipts do
			if typeof(id) == "string" and id ~= "" and not table.find(state.Receipts, id) then
				table.insert(state.Receipts, id)
			end
		end
	end
	return state
end

function Purchases.seen(state: State, receiptId: string): boolean
	return table.find(state.Receipts, receiptId) ~= nil
end

-- A new state that has seen `receiptId`, keeping only the newest `keep`.
function Purchases.record(state: State, receiptId: string, keep: number): State
	local receipts = table.clone(state.Receipts)
	if not table.find(receipts, receiptId) then
		table.insert(receipts, receiptId)
	end
	while #receipts > keep do
		table.remove(receipts, 1)
	end
	return { Receipts = receipts }
end

return Purchases
