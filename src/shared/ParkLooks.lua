--!strict
-- ParkLooks (ModuleScript) -> ReplicatedStorage.ParkLooks
-- How each place looks, by area Id: its card in the teleport menu, and for a
-- park its sign (ParkBuilder, ParkSigns). Colors are hex for Color3.fromHex
-- and postMaterial names an Enum.Material. Pure, see InputAxes.

local ParkLooks = {}

export type Sign = {
	stripe: string,
	stripeBack: string,
	post: string,
	postMaterial: string,
}

export type Look = {
	color: string,
	icon: string,
	tagline: string,
	sign: Sign,
}

local HAZARD: Sign = { stripe = "#FFC400", stripeBack = "#16161A", post = "#5C626C", postMaterial = "DiamondPlate" }

local LOOKS: { [string]: Look } = {
	Garage = { color = "#E69614", icon = "🔧", tagline = "Upgrades and new cars", sign = HAZARD },
	Hub = { color = "#3C6EBE", icon = "⭐", tagline = "The big launcher in the middle", sign = HAZARD },
	Skate = {
		color = "#B43CAA",
		icon = "🛹",
		tagline = "Bowls, ramps, and rails",
		sign = { stripe = "#3CE6F0", stripeBack = "#16161A", post = "#3CE6F0", postMaterial = "SmoothPlastic" },
	},
	Corkscrew = {
		color = "#14968C",
		icon = "🌀",
		tagline = "Tubes, the Gravitron, and the Globe",
		sign = { stripe = "#FF9A2E", stripeBack = "#0B3F3B", post = "#14968C", postMaterial = "Metal" },
	},
	City = {
		color = "#C84632",
		icon = "🏙️",
		tagline = "Trains, cranes, and a kaiju",
		sign = { stripe = "#F5F5F0", stripeBack = "#16161A", post = "#2A2C32", postMaterial = "Metal" },
	},
	Dino = {
		color = "#469632",
		icon = "🦖",
		tagline = "Volcano, T-Rex, and raptors",
		sign = { stripe = "#D2B478", stripeBack = "#4A3220", post = "#6B4A2C", postMaterial = "Wood" },
	},
	Silo = {
		color = "#39424E",
		icon = "🚀",
		tagline = "Buttons, klaxons, and a missile",
		sign = HAZARD,
	},
	Obby = { color = "#785ADC", icon = "🏁", tagline = "Sky course with checkpoints", sign = HAZARD },
}

local DEFAULT: Look = { color = "#606670", icon = "🏁", tagline = "", sign = HAZARD }

function ParkLooks.of(id: string): Look
	return LOOKS[id] or DEFAULT
end

return ParkLooks
