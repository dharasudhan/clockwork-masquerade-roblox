-- Night definitions (pure data). M1.1 ships Night 1 on the enormous 3-floor manor; Nights 2-3 are
-- added here in M2. Every number a night needs lives here so a new night is data, not code.
-- M1.1 timing (Murali's playtest Oct 28: "the time is too less"): Day 150 s, Night 240 s.
local Nights = {}

Nights[1] = {
	id = "main_breaker",
	name = "Main Breaker Tripped",
	daySeconds = 150,
	nightSeconds = 240,
	-- breakers / sabotage (5 terminals spread over all 3 floors)
	breakers = { "A", "B", "C", "D", "E" },
	maxTampers = 2, -- across all Phantoms, per night
	tamperSeconds = 4, -- stationary channel by day
	tamperRange = 7, -- studs from the terminal
	repairSeconds = 8, -- guest stationary channel at night (cooperative: rates add up)
	repairSecondsWithWire = 4, -- carrying copper wire (consumed on completion)
	repairRange = 7,
	-- reboot: with every breaker online the grid reaches 100% in rebootFullSeconds of night;
	-- each offline (tampered, unrepaired) breaker removes its 1/5 share of the rate. Downtime budget
	-- = (240 - 200) * 5 = 200 breaker-seconds: one trip must be fixed by 200 s, two by ~100 s each.
	rebootFullSeconds = 200,
	-- scavenging
	chestCount = 28, -- of the manor's chest spots (43), chosen at random each day
	chestOpenSeconds = 1, -- ProximityPrompt hold
	loot = {
		{ id = "DryCell", weight = 28 },
		{ id = "CopperWire", weight = 15 },
		{ id = "GlowStick", weight = 11 },
		{ id = "BrassWrench", weight = 8 },
		{ id = "SmokePellet", weight = 10 },
		{ id = "PocketWatch", weight = 6 },
		{ id = "TripwireBell", weight = 8 },
		{ id = "SpringBoots", weight = 8 },
		{ id = "ClockworkDecoy", weight = 6 },
	},
	lighting = { day = "Day", night = "Night" },
	objective = {
		Day = {
			Guest = "Search chests on all 3 floors - follow the compass",
			Phantom = "Blend in - stand still at a breaker 4 s to tamper (2 per night)",
		},
		Night = {
			Guest = "Repair tripped breakers - shine lanterns at Phantoms",
			Phantom = "Tag every guest before the grid reboots",
			Wisp = "You're a Wisp - flicker lights, drop oil slicks",
			Bubble = "Energy Bubble! Becoming a Wisp...",
		},
	},
}

return Nights
