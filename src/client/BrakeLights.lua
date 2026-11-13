--!strict
-- BrakeLights (ModuleScript) -> StarterPlayerScripts.BrakeLights
-- A car's brake lights, which glow red while it brakes. CarVisuals lights
-- them while the car's Braking attribute is true.

local BrakeLights = {}

local GLOW = Color3.fromRGB(255, 25, 25)

-- A brake light and how it looks unlit.
export type Brake = {
	part: BasePart,
	color: Color3,
	material: Enum.Material,
}

function BrakeLights.add(brakes: { Brake }, part: BasePart)
	table.insert(brakes, { part = part, color = part.Color, material = part.Material })
end

-- Turns `brakes` on or off.
function BrakeLights.light(brakes: { Brake }, on: boolean)
	for _, brake in brakes do
		brake.part.Color = if on then GLOW else brake.color
		brake.part.Material = if on then Enum.Material.Neon else brake.material
	end
end

return BrakeLights
