--!strict
-- OneShot (ModuleScript) -> StarterPlayerScripts.OneShot
-- Short sounds out in the world, heard at full volume within `near` studs
-- and fading out by `far`. `make` puts one on a part to play again and again
-- (`play`), so it has loaded by the first time; `at` plays one once where
-- something happened and cleans up after. A spec is { Id, Pitch, Volume },
-- plus Start if its file opens with silence.

local Debris = game:GetService("Debris")

local LIFE = 10 -- seconds a sound played `at` a place is kept

local OneShot = {}

export type Spec = { Id: string, Pitch: number, Volume: number, Start: number? }

function OneShot.make(spec: Spec, near: number, far: number, parent: Instance): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = spec.Id
	sound.PlaybackSpeed = spec.Pitch
	sound.Volume = spec.Volume
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = near
	sound.RollOffMaxDistance = far
	sound.Parent = parent
	return sound
end

-- Plays a sound made by `make` from its start.
function OneShot.play(sound: Sound, spec: Spec)
	sound.TimePosition = spec.Start or 0
	sound:Play()
end

function OneShot.at(spec: Spec, position: Vector3, near: number, far: number)
	local part = Instance.new("Part")
	part.Name = "OneShot"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.new(position)
	local sound = OneShot.make(spec, near, far, part)
	part.Parent = workspace
	OneShot.play(sound, spec)
	Debris:AddItem(part, LIFE)
end

return OneShot
