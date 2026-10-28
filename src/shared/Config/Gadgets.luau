-- Gadgets and role tuning (pure data). Speeds in studs/s, times in seconds.
return {
	Guest = {
		walkSpeed = 16,
	},
	Lantern = {
		batteryMax = 40, -- seconds of beam
		startBattery = 20,
		drainPerSecond = 1,
		dryCellCharge = 20, -- one dry-cell = +20 s
		range = 30,
		halfAngle = 20, -- degrees
		slowPerBeam = 0.25, -- each beam on a Phantom: -25% speed (one beam: 21 -> 15.75 < guest 16) ...
		slowCap = 0.6, -- ... stacking up to -60%
		aimStaleSeconds = 1.2, -- older client aim -> use the body's facing
		aimRate = 15, -- max aim updates per second accepted
	},
	Phantom = {
		daySpeed = 16, -- looks and moves like a guest by day
		nightSpeed = 21,
		transformSeconds = 1.5, -- frozen while the mask lights up at night start
		tagRange = 6,
		tagCooldown = 3,
		recoilSeconds = 1.5, -- after a tag the Phantom staggers ...
		recoilFactor = 0.5, -- ... at half speed (no chain-tagging a huddle)
	},
	Bubble = {
		seconds = 3, -- Energy Bubble, then Electro-Wisp
	},
	Wisp = {
		walkSpeed = 18,
		hover = 2.5, -- orb height above the root
		flickerCooldown = 20,
		flickerSeconds = 4,
		slickCooldown = 30,
		slickMaxAlive = 2, -- per Wisp
		slickLifetime = 45, -- > cooldown, so the max-2-alive cap matters
		slickRadius = 4,
		slickSlow = 0.7, -- guests walking through: x0.7 speed ...
		slickSlowSeconds = 2, -- ... for 2 s after leaving it (Phantoms unaffected)
	},
	GlowStick = {
		lifetime = 30,
		radius = 16, -- Phantoms inside are outlined for everyone
		maxAlive = 2,
	},
	Inventory = {
		caps = { DryCell = 3, CopperWire = 2, GlowStick = 3 },
	},
	Rewards = {
		played = 5,
		win = 10,
		perChest = 1,
		perRepair = 3,
		perTag = 2,
		cap = 40,
	},
}
