-- Gadgets and role tuning (pure data). Speeds in studs/s, times in seconds.
-- M1.1: rescaled for the 150 s Day / 240 s Night rounds on the 3-floor manor.
return {
	Guest = {
		walkSpeed = 16,
	},
	Lantern = {
		batteryMax = 120, -- seconds of beam (night 240 s; pass 2: was 100)
		startBattery = 60, -- (pass 2: was 45)
		drainPerSecond = 0.75, -- (pass 2: was 1)
		dryCellCharge = 45, -- one dry-cell = +45 s
		range = 30,
		halfAngle = 20, -- degrees
		slowPerBeam = 0.25, -- each beam on a Phantom: -25% speed (one beam: 21 -> 15.75 < guest 16) ...
		slowCap = 0.6, -- ... stacking up to -60%
		aimStaleSeconds = 1.2, -- older client aim -> use the body's facing
		aimRate = 15, -- max aim updates per second accepted
	},
	Phantom = {
		daySpeed = 16, -- looks and moves like a guest by day
		nightSpeed = 18.5, -- M1.1 balance (was 21; pass 1: 19, pass 3: 18.5): the bigger manor gave Phantoms the edge
		transformSeconds = 1.5, -- frozen while the mask lights up at night start
		tagRange = 6,
		tagCooldown = 8, -- (was 3; pass 1: 5, pass 3: 8)
		recoilSeconds = 4, -- after a tag the Phantom staggers ... (was 1.5; pass 1: 3, pass 3: 4)
		recoilFactor = 0.5, -- ... at half speed (no chain-tagging a huddle)
	},
	Bubble = {
		seconds = 3, -- Energy Bubble, then Electro-Wisp
	},
	Wisp = {
		walkSpeed = 18,
		hover = 2.5, -- orb height above the root
		flickerCooldown = 30,
		flickerSeconds = 5,
		slickCooldown = 45,
		slickMaxAlive = 2, -- per Wisp
		slickLifetime = 100, -- > 2 x cooldown, so the max-2-alive cap binds
		slickRadius = 4,
		slickSlow = 0.8, -- guests walking through: x0.8 speed (pass 2: was 0.7) ...
		slickSlowSeconds = 2, -- ... for 2 s after leaving it (Phantoms unaffected)
	},
	GlowStick = {
		lifetime = 45,
		radius = 16, -- Phantoms inside are outlined for everyone
		maxAlive = 2,
	},
	Rewards = {
		played = 8, -- rounds are ~2.5x longer since M1.1
		win = 10,
		perChest = 1,
		perRepair = 3,
		perTag = 2,
		cap = 60,
	},
}
