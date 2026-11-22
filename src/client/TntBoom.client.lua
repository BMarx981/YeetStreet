--!strict
-- TntBoom (LocalScript) -> StarterPlayerScripts.TntBoom
-- Shows a Scrapyard TNT barrel blowing up (Parks.ScrapyardTnt fires
-- ReplicatedStorage.TntBoom with where it stood): Roblox's own explosion,
-- sized to the blast, which pushes nothing and breaks no one's joints, since
-- the server throws the cars and nobody is ever hurt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Tuning)

local B = Tuning.Scrapyard.Tnt

local remote = ReplicatedStorage:WaitForChild("TntBoom")
if not remote:IsA("RemoteEvent") then
	warn("TntBoom: ReplicatedStorage.TntBoom is not a RemoteEvent; barrels blow up unseen")
	return
end

remote.OnClientEvent:Connect(function(at: any)
	if typeof(at) ~= "Vector3" then
		return
	end
	local explosion = Instance.new("Explosion")
	explosion.Position = at + Vector3.new(0, B.Height / 2, 0)
	explosion.BlastRadius = B.BlastRadius
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = workspace
end)
