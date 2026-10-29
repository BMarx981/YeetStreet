--!strict
-- CollisionGroups (ModuleScript) -> ServerScriptService.CollisionGroups
-- Registers every collision group the first time it is required, so scripts
-- that use them never depend on which one runs first.
--
--   Cars       car hulls
--   Wheels     car wheels: collide with what Cars do, and with Shoulders
--   Shoulders  invisible strips along obby roads that hold up wheels only,
--              so a hull can't hang on a road's edge (ObbyBuilder)
--   Drivers    seated characters: collide with nothing
--   Props    knockable props: hit the ground and each other, never a car or
--            driver, so they can never change where a car goes
--   Trunks   tree trunks: solid to cars, but props pass through them, so
--            coconuts shaken down fall clear of their tree

local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {
	Cars = "Cars",
	Wheels = "Wheels",
	Shoulders = "Shoulders",
	Drivers = "Drivers",
	Props = "Props",
	Trunks = "Trunks",
}

PhysicsService:RegisterCollisionGroup(CollisionGroups.Cars)
PhysicsService:RegisterCollisionGroup(CollisionGroups.Wheels)
PhysicsService:RegisterCollisionGroup(CollisionGroups.Shoulders)
PhysicsService:RegisterCollisionGroup(CollisionGroups.Drivers)
PhysicsService:RegisterCollisionGroup(CollisionGroups.Props)
PhysicsService:RegisterCollisionGroup(CollisionGroups.Trunks)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Drivers, "Default", false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Drivers, CollisionGroups.Cars, false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Drivers, CollisionGroups.Wheels, false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Drivers, CollisionGroups.Drivers, false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Props, CollisionGroups.Cars, false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Props, CollisionGroups.Wheels, false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Props, CollisionGroups.Drivers, false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Trunks, CollisionGroups.Props, false)
local G = CollisionGroups
for _, other in { "Default", G.Cars, G.Shoulders, G.Drivers, G.Props, G.Trunks } do
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Shoulders, other, false)
end

return CollisionGroups
