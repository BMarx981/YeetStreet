--!strict
-- CarNameplate (ModuleScript) -> StarterPlayerScripts.CarNameplate
-- A nameplate over every other player's car on this client (CarVisuals): the
-- driver's display name, and once they have been reborn, their rebirth count
-- in the color of their rebirth trail (CarTrail.rebirthColor). The count
-- follows the player's Rebirths attribute (Garage). Your own car has none, as
-- Roblox hides your own name tag. While seated, the driver's own Roblox name
-- tag is hidden (CarService), so the name shows once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rebirth = require(ReplicatedStorage.Rebirth)
local Tuning = require(ReplicatedStorage.Tuning)
local CarTrail = require(script.Parent.CarTrail)
local UiStyle = require(script.Parent.UiStyle)

local N = Tuning.Nameplate

local CarNameplate = {}

-- Puts the owner's nameplate over `car`'s `hull`, unless the car is this
-- player's own or has no owner in the game.
function CarNameplate.add(car: Model, hull: BasePart)
	local ownerId = car:GetAttribute("OwnerUserId")
	local owner = if typeof(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
	if not owner or owner == Players.LocalPlayer or hull:FindFirstChild("Nameplate") then
		return
	end

	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Adornee = hull
	plate.Size = UDim2.fromOffset(N.Width, N.NameSize + N.RebirthSize + 8)
	plate.StudsOffsetWorldSpace = Vector3.new(0, N.Lift, 0)
	plate.MaxDistance = N.MaxDistance
	plate.LightInfluence = 0
	plate.ResetOnSpawn = false

	local name = UiStyle.text("Name", plate, N.NameSize, true)
	name.Size = UDim2.new(1, 0, 0, N.NameSize + 4)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Text = owner.DisplayName

	local count = UiStyle.text("Rebirths", plate, N.RebirthSize, true)
	count.Position = UDim2.fromOffset(0, N.NameSize + 4)
	count.Size = UDim2.new(1, 0, 0, N.RebirthSize + 4)
	count.TextXAlignment = Enum.TextXAlignment.Center

	local function showRebirths()
		local rebirths = Rebirth.count(owner:GetAttribute("Rebirths"))
		count.Visible = rebirths > 0
		count.Text = `REBIRTH {rebirths}`
		count.TextColor3 = CarTrail.rebirthColor(rebirths) or UiStyle.Yellow
	end
	local changed = owner:GetAttributeChangedSignal("Rebirths"):Connect(showRebirths)
	showRebirths()
	plate.Destroying:Connect(function()
		changed:Disconnect()
	end)
	plate.Parent = hull
end

return CarNameplate
