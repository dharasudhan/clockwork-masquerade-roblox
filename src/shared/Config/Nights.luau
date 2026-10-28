-- Night definitions (pure data). M1 ships Night 1; Nights 2-3 are added here in M2.
-- Every number a night needs lives here so a new night is data, not code.
local Nights = {}

Nights[1] = {
	id = "main_breaker",
	name = "Main Breaker Tripped",
	daySeconds = 60,
	nightSeconds = 90,
	-- breakers / sabotage
	breakers = { "A", "B", "C" },
	maxTampers = 1, -- across all Phantoms, per night
	tamperSeconds = 4, -- stationary channel by day
	tamperRange = 7, -- studs from the terminal
	repairSeconds = 6, -- guest stationary channel at night (cooperative: rates add up)
	repairSecondsWithWire = 3, -- carrying copper wire (consumed on completion)
	repairRange = 7,
	-- reboot: with every breaker online the grid reaches 100% in fullSeconds of night;
	-- each offline (tampered, unrepaired) breaker removes its share of the rate.
	rebootFullSeconds = 72,
	-- scavenging
	chestCount = 12, -- of Config/Manor chest spots, chosen at random each day
	chestOpenSeconds = 1, -- ProximityPrompt hold
	loot = {
		{ id = "DryCell", weight = 50 },
		{ id = "CopperWire", weight = 30 },
		{ id = "GlowStick", weight = 20 },
	},
	lighting = { day = "Day", night = "Night" },
	objective = {
		Day = {
			Guest = "Search chests: dry-cells, copper wire, glow-sticks",
			Phantom = "Blend in - stand still at a breaker 4 s to tamper",
		},
		Night = {
			Guest = "Repair the tripped breaker - shine lanterns at Phantoms",
			Phantom = "Tag every guest before the grid reboots",
			Wisp = "You're a Wisp - flicker lights, drop oil slicks",
			Bubble = "Energy Bubble! Becoming a Wisp...",
		},
	},
}

return Nights
