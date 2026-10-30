-- The three nights of a v1.0 match (pure data; GDD "3-night MVP"). Every number a night needs
-- lives here so a night is data, not code. A match plays Config/Match.NightOrder = { 1, 2, 3 }:
--   1 Main Breaker Tripped   (kind "grid")   Day -> Night: reboot the grid
--   2 Blueprint Archives     (kind "grid")   + blueprint pages, trapped cabinets, the projector
--                                              light barrier, Phantom Phase Glide
--   3 Dawn Reboot (finale)   (kind "finale") short Day -> Showdown (find 3 Master Override Keys,
--                                              bring them to the Exit Console) -> Overdrive (hold
--                                              the Console Activation Ring; Phantoms faster +
--                                              Shockwave Dash; the dynamo pulses)
-- Nights 1-2 can be won (dawn) or lost (dark) without ending the match; tagged guests wake up as
-- guests again at the next Day. Each night the guests win shortens the finale's ring time; each
-- night they lose makes the finale Phantoms faster. The match ends early only if every guest
-- is tagged (Phantoms) or every Phantom leaves (Guests); otherwise the finale decides.
local Nights = {}

local LOOT = {
	{ id = "DryCell", weight = 28 },
	{ id = "CopperWire", weight = 15 },
	{ id = "GlowStick", weight = 11 },
	{ id = "BrassWrench", weight = 8 },
	{ id = "SmokePellet", weight = 10 },
	{ id = "PocketWatch", weight = 6 },
	{ id = "TripwireBell", weight = 8 },
	{ id = "SpringBoots", weight = 8 },
	{ id = "ClockworkDecoy", weight = 6 },
}

Nights[1] = {
	id = "main_breaker",
	name = "Main Breaker Tripped",
	kind = "grid",
	daySeconds = 75,
	nightSeconds = 165,
	breakers = { "A", "B", "C", "D", "E" }, -- B1, G, 2F, G, 1F
	maxTampers = 2, -- across all Phantoms, per night
	tamperSeconds = 4, -- stationary channel by day
	tamperRange = 7,
	repairSeconds = 8, -- guest stationary channel at night (cooperative: rates add up)
	repairSecondsWithWire = 4,
	repairRange = 7,
	-- with every breaker online the grid reaches 100% in rebootFullSeconds of night; each offline
	-- breaker removes its 1/5 share. Downtime budget = (165 - 135) * 5 = 150 breaker-seconds.
	rebootFullSeconds = 135, -- balance pass 1 (was 125: guests won 9/9 nights)
	chestCount = 26, -- of the manor's chest spots, picked at random each Day
	chestOpenSeconds = 1,
	loot = LOOT,
	lighting = { day = "Day", night = "Night" },
	objective = {
		Day = {
			Guest = "Find chests! Look on every floor",
			Phantom = "Shh! Go to a breaker and TAMPER (stand still 4 s)",
		},
		Night = {
			Guest = "Fix the RED breakers! Shine your lantern at Phantoms",
			Phantom = "Tag the guests before the grid reboots!",
			Wisp = "You're a Wisp! Flicker lights, drop oil slicks",
			Bubble = "Energy Bubble! Becoming a Wisp...",
		},
	},
}

Nights[2] = {
	id = "blueprint_archives",
	name = "Blueprint Archives",
	kind = "grid",
	daySeconds = 70,
	nightSeconds = 165,
	breakers = { "A", "B", "D", "E", "F" }, -- F is up in the Observatory Tower
	maxTampers = 2,
	tamperSeconds = 4,
	tamperRange = 7,
	repairSeconds = 8,
	repairSecondsWithWire = 4,
	repairRange = 7,
	rebootFullSeconds = 135,
	chestCount = 22,
	chestOpenSeconds = 1,
	loot = LOOT,
	-- blueprint pages hide in `pages` of the 8 cabinets each Day; Phantoms can trap `traps`
	archives = {
		pages = 3,
		searchSeconds = 1.5,
		traps = 2, -- per Day, across all Phantoms
		trapSeconds = 2,
		inkSeconds = 3, -- a trapped cabinet splashes ink on the searcher's screen + rings an alarm
		slotSeconds = 1,
		barrierBase = 8, -- projector barrier radius (studs) with one page, +4 per extra page
		barrierPerPage = 4,
		rebootPerPage = 6, -- each slotted page jumps the reboot meter
		rebootAllPages = 8, -- extra when all 3 are in
	},
	phaseGlide = { distance = 10, cooldown = 25 }, -- Phantoms blink through a wall/door at night
	lighting = { day = "Day", night = "Night" },
	objective = {
		Day = {
			Guest = "Find the 3 blueprint pages in the cabinets!",
			Phantom = "Tamper a breaker or TRAP a cabinet",
		},
		Night = {
			Guest = "Bring pages to the Projector (Royal Library) + fix breakers",
			Phantom = "Tag guests! Use GLIDE to slip through walls",
			Wisp = "You're a Wisp! Flicker lights, drop oil slicks",
			Bubble = "Energy Bubble! Becoming a Wisp...",
		},
	},
}

Nights[3] = {
	id = "dawn_reboot",
	name = "Dawn Reboot",
	kind = "finale",
	daySeconds = 40,
	showdownSeconds = 120, -- find the 3 Master Override Keys and insert them at the Exit Console
	overdriveSeconds = 90, -- then hold the Console Activation Ring
	breakers = {},
	maxTampers = 0,
	tamperSeconds = 4,
	tamperRange = 7,
	repairSeconds = 8,
	repairSecondsWithWire = 4,
	repairRange = 7,
	rebootFullSeconds = 1,
	chestCount = 20,
	chestOpenSeconds = 1,
	loot = LOOT,
	finale = {
		takeSeconds = 2, -- hold to lift a key off its pedestal
		reviveOnKey = true, -- each inserted key wakes every Electro-Wisp up as a guest (comeback)
		insertSeconds = 1,
		carrySlow = 0.9, -- key carriers walk x0.9
		ringSeconds = 40, -- cumulative ring time needed (minus the bonus per night won)
		ringBonusPerNightWon = 8,
		ringRatePerExtraGuest = 0.25, -- 1 guest = 1 s/s, each extra +0.25 (max 1.75)
		ringRateMax = 1.75,
		phantomContest = 0.5, -- a Phantom inside the ring halves the rate
		phantomSpeed = 1.15, -- Overdrive: Phantoms x1.15 ...
		phantomSpeedPerNightLost = 0.05, -- ... +5% per night the guests lost
		dash = { distance = 14, windup = 0.8, cooldown = 12, hitRadius = 5, knockback = 10 },
		dynamo = { every = 15, radius = 4.5, push = 7 },
	},
	lighting = { day = "Day", night = "Night" },
	objective = {
		Day = {
			Guest = "Get ready! Find chests and vote at the Evidence Board",
			Phantom = "Blend in... the final night is coming",
		},
		Night = {
			Guest = "Find the 3 KEYS and bring them to the Exit Console!",
			Phantom = "No more hiding! Stop the guests from using the keys",
			Wisp = "You're a Wisp! Flicker lights, drop oil slicks",
			Bubble = "Energy Bubble! Becoming a Wisp...",
		},
		Overdrive = {
			Guest = "Stand in the glowing RING by the console!",
			Phantom = "Push them out of the ring! DASH!",
			Wisp = "Flicker the ballroom lights!",
			Bubble = "Energy Bubble! Becoming a Wisp...",
		},
	},
}

-- night length helper (the finale's Night is Showdown + Overdrive)
function Nights.nightLength(n): number
	if n.kind == "finale" then
		return n.showdownSeconds + n.overdriveSeconds
	end
	return n.nightSeconds
end

return Nights
