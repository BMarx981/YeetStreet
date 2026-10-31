--!strict
local Check = require("./Check")
local ParkLooks = require("../src/shared/ParkLooks")

local PARKS = { "Skate", "Corkscrew", "City", "Dino", "Silo" }

Check.test("every park has its own color, icon, and stripe", function()
	local seen: { [string]: string } = {}
	for _, id in PARKS do
		local look = ParkLooks.of(id)
		Check.eq(look == ParkLooks.of("NoSuchPark"), false, `{id} has a look`)
		for _, key in { look.color, look.icon, look.sign.stripe } do
			Check.eq(seen[key], nil, `{id} repeats {key}`)
			seen[key] = id
		end
	end
end)

Check.test("every other teleport stop has its own card", function()
	for _, id in { "Garage", "Hub", "Obby" } do
		Check.eq(ParkLooks.of(id) == ParkLooks.of("NoSuchPark"), false, id)
	end
end)

Check.test("a place with no look gets a plain card with no tagline", function()
	Check.eq(ParkLooks.of("NoSuchPark").tagline, "")
end)

Check.finish("ParkLooks")
