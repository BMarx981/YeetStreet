--!strict
-- JetFlames (ModuleScript) -> StarterPlayerScripts.JetFlames
-- The flame, smoke trail, and glow out of the back of a car's thrusters,
-- sized and colored for the car's Jets look (Tuning.JetFlames). CarVisuals
-- puts them on every car's thrusters and lights them while its JetsBurning
-- attribute is true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local F = Tuning.JetFlames

local JetFlames = {}

-- What a thruster lights up while the jets burn.
export type Jet = {
	emitters: { ParticleEmitter },
	glow: PointLight?,
}

-- A flame, smoke, and glow out of the back of a thruster, sized for Jets look
-- step `step`. The thruster's axis is its X, which points toward the nose, so
-- its back end is at -X. The attachment is turned back to the car's own axes,
-- so the emitters' Back is out of the tail.
function JetFlames.add(thruster: BasePart, color: Color3, step: number): Jet
	local k = step + 1
	local attachment = Instance.new("Attachment")
	attachment.Name = "Flame"
	attachment.CFrame = CFrame.new(-thruster.Size.X / 2, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)
	attachment.Parent = thruster

	-- Locked to the thruster, so it stays a flame at any speed instead of
	-- being left behind as a streak of dots.
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "JetFlame"
	flame.Enabled = false
	flame.LockedToPart = true
	flame.EmissionDirection = Enum.NormalId.Back
	flame.Rate = F.FlameRate[k]
	flame.Lifetime = NumberRange.new(F.FlameLife * 0.8, F.FlameLife)
	local speed = F.FlameLength[k] / F.FlameLife
	flame.Speed = NumberRange.new(speed * 0.85, speed)
	flame.SpreadAngle = Vector2.new(4, 4)
	flame.LightEmission = 1
	flame.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.6), color)
	local width = F.FlameWidth[k] * thruster.Size.Y
	flame.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, width), NumberSequenceKeypoint.new(1, width * 0.2) })
	flame.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.8) })
	flame.Parent = attachment

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "JetSmoke"
	smoke.Enabled = false
	smoke.EmissionDirection = Enum.NormalId.Back
	smoke.Rate = F.SmokeRate[k]
	smoke.Lifetime = NumberRange.new(F.SmokeLife * 0.7, F.SmokeLife)
	smoke.Speed = NumberRange.new(2, 5)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Drag = 1
	smoke.Color = ColorSequence.new(F.SmokeColor)
	local puff = F.SmokeSize[k]
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, puff * 0.4), NumberSequenceKeypoint.new(1, puff) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-60, 60)
	smoke.Parent = attachment

	local glow: PointLight? = nil
	if F.GlowRange[k] > 0 then
		local light = Instance.new("PointLight")
		light.Enabled = false
		light.Color = color
		light.Range = F.GlowRange[k]
		light.Brightness = F.GlowBrightness
		light.Parent = attachment
		glow = light
	end
	return { emitters = { flame, smoke }, glow = glow }
end

-- Turns `jets` on or off.
function JetFlames.light(jets: { Jet }, on: boolean)
	for _, jet in jets do
		for _, emitter in jet.emitters do
			emitter.Enabled = on
		end
		if jet.glow then
			jet.glow.Enabled = on
		end
	end
end

return JetFlames
