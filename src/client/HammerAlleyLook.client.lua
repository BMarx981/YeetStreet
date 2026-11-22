--!strict
-- HammerAlleyLook (LocalScript) -> StarterPlayerScripts.HammerAlleyLook
-- Draws Hammer Alley's hammers (HammerAlley, Hammers) and moves them every
-- frame from the server's clock, so every player sees them in the same
-- place. Each is a steel handle from its pivot and a red head. They are only
-- looks: CarController asks Hammers.push how one knocks its car.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HammerAlley = require(ReplicatedStorage.HammerAlley)
local Hammers = require(ReplicatedStorage.Hammers)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)

local A = Tuning.Scrapyard.Alley
local CONFIG: HammerAlley.Config = A :: any

local HANDLE = 3 -- how thick a handle is

if not MapLayout.find(Tuning.Map.Areas :: any, "Scrapyard") then
	return
end

local folder = Instance.new("Folder")
folder.Name = "HammerAlleyLook"
folder.Parent = workspace

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.Color = color
	p.Material = material
	p.Parent = folder
	return p
end

type Look = {
	hammer: HammerAlley.Hammer,
	pivotX: number,
	pivotY: number,
	handle: Part,
	head: Part,
}

local looks: { Look } = {}
for _, hammer in A.Hammers :: { HammerAlley.Hammer } do
	local s = if hammer.Kind == "Swing" then A.Swing else A.Slam
	local handle = part("Handle", Vector3.new(s.Length, HANDLE, HANDLE), A.SteelColor, Enum.Material.Metal)
	handle.Shape = Enum.PartType.Cylinder
	table.insert(looks, {
		hammer = hammer,
		pivotX = if hammer.Kind == "Swing" then 0 else hammer.Side * (A.Width / 2 + A.Slam.PivotOut),
		pivotY = s.Height,
		handle = handle,
		head = part("Head", Vector3.new(s.HeadSize, s.HeadSize, s.HeadLength), A.HeadColor, Enum.Material.Metal),
	})
end

RunService.RenderStepped:Connect(function()
	local time = workspace:GetServerTimeNow()
	for _, look in looks do
		local x, y = HammerAlley.head(CONFIG, look.hammer, time)
		local dx, dy = x - look.pivotX, y - look.pivotY
		-- Rolled about the lane so each part's X runs from the pivot to the head.
		local roll = CFrame.Angles(0, 0, math.atan2(dy, dx))
		local at = look.hammer.At
		look.handle.CFrame = Hammers.frame * CFrame.new((look.pivotX + x) / 2, (look.pivotY + y) / 2, -at) * roll
		look.head.CFrame = Hammers.frame * CFrame.new(x, y, -at) * roll
	end
end)
