-- Manor events (pure data): once per Day and once per Night, at a random moment, the manor
-- itself throws a curveball. Keeps repeat matches from feeling identical. Eligibility is by
-- phase; the scheduler (server/EventService) picks one eligible event per phase instance and
-- fires it inside the Window fraction of the phase.
return {
	Order = { "PowerSurge", "DeepDark", "ClockworkRush", "LooseGears", "RumorMill" },
	Defs = {
		-- NIGHT: the grid jumps ahead - a loud, hopeful swing the Phantoms must answer
		PowerSurge = { phase = "Night", name = "Power Surge", amount = 0.08, toast = "POWER SURGE! The grid jumps forward!" },
		-- NIGHT: for a while the dark drinks the light - lanterns drain much faster
		DeepDark = { phase = "Night", name = "The Deep Dark", seconds = 25, drainFactor = 1.5,
			toast = "The Deep Dark falls - lanterns burn fast. Stick together!" },
		-- DAY: the manor winds up - everyone moves faster (loot + investigate!)
		ClockworkRush = { phase = "Day", name = "Clockwork Rush", seconds = 20, speedFactor = 1.15,
			toast = "CLOCKWORK RUSH! The manor's gears wind everyone up!" },
		-- DAY: spare parts everywhere - every guest gets a dry-cell (up to the item cap)
		LooseGears = { phase = "Day", name = "Loose Gears", dryCells = 1, toast = "LOOSE GEARS! Spare dry-cells for every guest!" },
		-- DAY: a servant's rumor reveals one clue for free (feeds the Expose economy)
		RumorMill = { phase = "Day", name = "Rumor Mill", toast = "RUMOR MILL! A servant shares what they saw..." },
	},
	-- when in the phase the event may fire (fraction of the phase length)
	Window = { min = 0.3, max = 0.7 },
}
