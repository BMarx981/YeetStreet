--!strict
-- CollisionGroups (ModuleScript) -> ServerScriptService.CollisionGroups
-- Registers every collision group the first time it is required, so scripts
-- that use them never depend on which one runs first.
--
--   Cars     car hulls and wheels
--   Drivers  seated characters: collide with nothing
--   Props    knockable props: hit the ground and each other, never a car or
--            driver, so they can never change where a car goes
--   Trunks   tree trunks: solid to cars, but props pass through them, so
--            coconuts shaken down fall clear of their tree

local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {
	Cars = "Cars",
	Drivers = "Drivers",
	Props = "Props",
	Trunks = "Trunks",
}

PhysicsService:RegisterCollisionGroup(CollisionGroups.Cars)
PhysicsService:RegisterCollisionGroup(CollisionGroups.Drivers)
PhysicsService:RegisterCollisionGroup(CollisionGroups.Props)
PhysicsService:RegisterCollisionGroup(CollisionGroups.Trunks)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Drivers, "Default", false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Drivers, CollisionGroups.Cars, false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Drivers, CollisionGroups.Drivers, false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Props, CollisionGroups.Cars, false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Props, CollisionGroups.Drivers, false)
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Trunks, CollisionGroups.Props, false)

return CollisionGroups
