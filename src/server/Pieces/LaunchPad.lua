--!strict
-- LaunchPad (ModuleScript) -> ServerScriptService.Pieces.LaunchPad
-- Launch pads for building parks. A pad is a part with a LaunchSpeed
-- attribute: a car on it is pushed along the part's LookVector up to that
-- speed (CarController) and arms a run (RunTracker). Its RespawnCFrame
-- attribute is where a reset or wreck puts a car that last launched there
-- (ScoreService).

local LaunchPad = {}

local COLOR = Color3.fromRGB(255, 200, 40)

-- Makes `part` a launch pad.
function LaunchPad.make(part: BasePart, launchSpeed: number, respawn: CFrame)
	part.Name = "LaunchPad"
	part.Color = COLOR
	part.Material = Enum.Material.Neon
	part:SetAttribute("LaunchSpeed", launchSpeed)
	part:SetAttribute("RespawnCFrame", respawn)
end

-- A flat pad whose top face is centered on `top`, pushing along its LookVector.
function LaunchPad.flat(
	parent: Instance,
	top: CFrame,
	width: number,
	length: number,
	launchSpeed: number,
	respawn: CFrame
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = Vector3.new(width, 0.4, length)
	part.CFrame = top * CFrame.new(0, -0.2, 0)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	LaunchPad.make(part, launchSpeed, respawn)
	return part
end

-- Turns the top `count` planks of a curved piece (CurvedWall) into pads,
-- pushing up the curve.
function LaunchPad.top(piece: Model, count: number, launchSpeed: number, respawn: CFrame)
	local planks: { BasePart } = {}
	for _, part in piece:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "Plank" then
			table.insert(planks, part)
		end
	end
	table.sort(planks, function(a: BasePart, b: BasePart): boolean
		return a.Position.Y > b.Position.Y
	end)
	for i = 1, math.min(count, #planks) do
		LaunchPad.make(planks[i], launchSpeed, respawn)
	end
end

return LaunchPad
