-- Progression (pure data): XP (= Gear Tokens earned in a match, before any 2x pass), levels,
-- the 7-day daily login streak and the badges. Logic/Progression does the maths.
return {
	-- XP needed to go from level L to L+1 = base + step * (L - 1)
	LevelBase = 40,
	LevelStep = 20,
	MaxLevel = 50,
	-- Daily login: day 1..7 of a streak (a missed day restarts at 1; day 7 loops to 1)
	Daily = {
		{ tokens = 15 }, { tokens = 20 }, { tokens = 25 }, { tokens = 30 },
		{ tokens = 40 }, { tokens = 50 }, { tokens = 75, item = "mask_aurora" },
	},
	-- Badges: ids are created in Creator Hub (badge creation can cost Robux = Gate 4); 0 = not yet
	-- created, the badge is still recorded in the save and awarded once its id is filled in.
	Badges = {
		Welcome = { id = 0, name = "Welcome to Sterling Manor", desc = "Play your first masquerade" },
		FirstDawn = { id = 0, name = "First Dawn", desc = "Win a match as a guest" },
		PhantomWin = { id = 0, name = "Masked Menace", desc = "Win a match as a Phantom" },
		ChiefEngineer = { id = 0, name = "Chief Engineer", desc = "Repair 10 breakers (total)" },
		OverdriveMaster = { id = 0, name = "Overdrive Master", desc = "Stand in the ring when the Dawn Reboot completes" },
		Detective = { id = 0, name = "Detective", desc = "Expose a Phantom at the Evidence Board" },
		KeyKeeper = { id = 0, name = "Key Keeper", desc = "Insert a Master Override Key" },
		Archivist = { id = 0, name = "Archivist", desc = "Slot a blueprint page into the projector" },
		WeekStreak = { id = 0, name = "Regular Guest", desc = "Log in 7 days in a row" },
	},
	ChiefEngineerRepairs = 10,
}
