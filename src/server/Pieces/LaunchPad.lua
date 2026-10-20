--!strict
-- LaunchPad (ModuleScript) -> ServerScriptService.Pieces.LaunchPad
-- Launch pads for building parks. A pad is a part with a LaunchSpeed
-- attribute: a car on it heading along the part's LookVector
-- (Tuning.Launch.MinHeading) is pushed that way up to that speed
-- (CarController), and arms a run (RunTracker). Its
-- RespawnCFrame
-- attribute is where a reset or wreck puts a car that last launched there
-- (ScoreService). An optional PayScale attribute scales the cash a run from
-- it pays, so the biggest launchers can pay less per point.

local LaunchPad = {}

local COLOR = Color3.fromRGB(255, 200, 40)

-- Makes `part` a launch pad.
function LaunchPad.make(part: BasePart, launchSpeed: number, respawn: CFrame, payScale: number?)
	part.Name = "LaunchPad"
	part.Color = COLOR
	part.Material = Enum.Material.Neon
	part:SetAttribute("LaunchSpeed", launchSpeed)
	part:SetAttribute("RespawnCFrame", respawn)
	part:SetAttribute("PayScale", payScale)
end

-- A flat pad whose top face is centered on `top`, pushing along its LookVector.
function LaunchPad.flat(
	parent: Instance,
	top: CFrame,
	width: number,
	length: number,
	launchSpeed: number,
	respawn: CFrame,
	payScale: number?
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = Vector3.new(width, 0.4, length)
	part.CFrame = top * CFrame.new(0, -0.2, 0)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	LaunchPad.make(part, launchSpeed, respawn, payScale)
	return part
end

-- The planks of a curved piece (CurvedWall), highest first.
local function planksByHeight(piece: Model): { BasePart }
	local planks: { BasePart } = {}
	for _, part in piece:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "Plank" then
			table.insert(planks, part)
		end
	end
	table.sort(planks, function(a: BasePart, b: BasePart): boolean
		return a.Position.Y > b.Position.Y
	end)
	return planks
end

-- Turns the top `count` planks of a curved piece into pads, pushing up the
-- curve. For a ring, count every slice: rings of 2 planks on 48 slices is 96.
function LaunchPad.top(piece: Model, count: number, launchSpeed: number, respawn: CFrame, payScale: number?)
	local planks = planksByHeight(piece)
	for i = 1, math.min(count, #planks) do
		LaunchPad.make(planks[i], launchSpeed, respawn, payScale)
	end
end

-- Turns the bottom `count` planks of a curved piece into pads, the same way.
function LaunchPad.bottom(piece: Model, count: number, launchSpeed: number, respawn: CFrame)
	local planks = planksByHeight(piece)
	for i = #planks, math.max(#planks - count + 1, 1), -1 do
		LaunchPad.make(planks[i], launchSpeed, respawn)
	end
end

return LaunchPad
