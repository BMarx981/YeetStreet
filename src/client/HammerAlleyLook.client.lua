--!strict
-- HammerAlleyLook (LocalScript) -> StarterPlayerScripts.HammerAlleyLook
-- Draws Hammer Alley's hammers (HammerAlley, Hammers) and moves them every
-- frame from the server's clock, so every player sees them in the same
-- place. Each is a steel handle from its pivot and a red head. They are only
-- looks: CarController asks Hammers.push how one knocks its car.
--
-- Each whooshes and slams on its own head (HammerAlley.cues), and a hammer
-- reaching any car clangs there, as Hammers.push would knock it. During a
-- replay they move as they were at the moment being watched (ReplayWorld),
-- and only the ghost car clangs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HammerAlley = require(ReplicatedStorage.HammerAlley)
local Hammers = require(ReplicatedStorage.Hammers)
local MapLayout = require(ReplicatedStorage.MapLayout)
local Tuning = require(ReplicatedStorage.Tuning)
local OneShot = require(script.Parent.OneShot)
local ReplayWorld = require(script.Parent.ReplayWorld)

local A = Tuning.Scrapyard.Alley
local S = Tuning.Scrapyard.Sounds
local CONFIG: HammerAlley.Config = A :: any

local HANDLE = 3 -- how thick a handle is
-- Seconds; a longer jump in time between frames (a replay starting or
-- scrubbing) plays no sounds.
local CUE_GAP = 0.5

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
	whoosh: Sound,
	slam: Sound,
}

local looks: { Look } = {}
for _, hammer in A.Hammers :: { HammerAlley.Hammer } do
	local s = if hammer.Kind == "Swing" then A.Swing else A.Slam
	local handle = part("Handle", Vector3.new(s.Length, HANDLE, HANDLE), A.SteelColor, Enum.Material.Metal)
	handle.Shape = Enum.PartType.Cylinder
	local head = part("Head", Vector3.new(s.HeadSize, s.HeadSize, s.HeadLength), A.HeadColor, Enum.Material.Metal)
	table.insert(looks, {
		hammer = hammer,
		pivotX = if hammer.Kind == "Swing" then 0 else hammer.Side * (A.Width / 2 + A.Slam.PivotOut),
		pivotY = s.Height,
		handle = handle,
		head = head,
		whoosh = OneShot.make(S.Whoosh, S.HammerNear, S.HammerFar, head),
		slam = OneShot.make(S.HammerSlam, S.HammerNear, S.HammerFar, head),
	})
end

-- When each car, or "ghost" for the replay's, last clanged, in os.clock.
local clangedAt: { [any]: number } = {}

local function clang(key: any, position: Vector3, time: number)
	local now = os.clock()
	if now - (clangedAt[key] or -math.huge) < A.Cooldown or not Hammers.inLane(position) then
		return
	end
	if Hammers.push(position, Vector3.zero, time) then
		clangedAt[key] = now
		OneShot.at(S.Clang, position, S.Near, S.Far)
	end
end

local lastTime = 0

RunService.RenderStepped:Connect(function()
	local time = ReplayWorld.serverTime()
	local step = time - lastTime
	lastTime = time
	if step > 0 and step <= CUE_GAP then
		for _, look in looks do
			for _, cue in HammerAlley.cues(CONFIG, look.hammer, time - step, time) do
				if cue == "slam" then
					OneShot.play(look.slam, S.HammerSlam)
				else
					OneShot.play(look.whoosh, S.Whoosh)
				end
			end
		end
		local ghost = ReplayWorld.ghost()
		if ghost then
			clang("ghost", ghost.Position, time)
		else
			local cars = workspace:FindFirstChild("Cars")
			for _, car in if cars then cars:GetChildren() else {} do
				local hull = car:IsA("Model") and car.PrimaryPart
				if hull then
					clang(car, hull.Position, time)
				end
			end
		end
	end
	for key in clangedAt do
		if typeof(key) == "Instance" and not key.Parent then
			clangedAt[key] = nil
		end
	end
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
