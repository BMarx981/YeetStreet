--!strict
-- GunService (Script) -> ServerScriptService.GunService
-- Shoots a PlaneCar's guns. The driver's game asks on
-- ReplicatedStorage.FireGuns, naming the gun, as often as Guns allows; the
-- server takes a shot only from a player whose car is a PlaneCar, and no
-- faster than Tuning.Guns.Rate. It traces the shot from the car as the
-- server sees it (ShotPath), and a car it hits is ScoreService's to damage
-- (ServerStorage.CarShot). Every other player's game draws the shot from
-- ReplicatedStorage.GunShot; the shooter's drew it already.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Guns = require(ReplicatedStorage.Guns)
local ShotPath = require(ReplicatedStorage.ShotPath)
local Tuning = require(ReplicatedStorage.Tuning)

local G = Tuning.Guns

local fireGuns = Instance.new("RemoteEvent")
fireGuns.Name = "FireGuns"
fireGuns.Parent = ReplicatedStorage

local gunShot = Instance.new("RemoteEvent")
gunShot.Name = "GunShot"
gunShot.Parent = ReplicatedStorage

local carsFolder = workspace:WaitForChild("Cars")
local carShot = ServerStorage:WaitForChild("CarShot") :: BindableEvent

local lastShotAt: { [Player]: number } = {}

local function carOf(player: Player): Model?
	for _, car in carsFolder:GetChildren() do
		if car:IsA("Model") and car:GetAttribute("OwnerUserId") == player.UserId then
			return car
		end
	end
	return nil
end

fireGuns.OnServerEvent:Connect(function(player: Player, gun: any)
	if gun ~= 1 and gun ~= 2 then
		return
	end
	local car = carOf(player)
	local hull = car and car:FindFirstChild("Hull")
	if not (car and hull and hull:IsA("BasePart") and car:GetAttribute("PlaneCar") == true) then
		return
	end
	local now = os.clock()
	if not Guns.allowed(lastShotAt[player] or -math.huge, now, G.Rate, G.Slack) then
		return
	end
	lastShotAt[player] = now

	local from, to, victim = ShotPath.trace(car, hull, gun)
	if victim then
		carShot:Fire(victim, player, (to - from).Unit)
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			gunShot:FireClient(other, from, to, victim ~= nil)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastShotAt[player] = nil
end)
