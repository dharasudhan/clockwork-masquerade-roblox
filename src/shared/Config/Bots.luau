-- Bots (pure data). Server NPCs that fill a match to Match.MinPlayers. Never saved.
return {
	Names = {
		"Ada Gearwright", "Cogsworth", "Penny Sprocket", "Barnaby Brass", "Ivy Voltaire",
		"Otto Pistonby", "Clara Copperfield", "Felix Flywheel", "Mabel Mainspring", "Rupert Rivet",
	},
	TickSeconds = 0.25, -- brain rate
	ArriveDistance = 3.5,
	UnstickSeconds = 2.5, -- no progress for this long -> hop to the next waypoint
	FleeRadius = 26, -- guest bots react to a Phantom this close (night)
	PanicRadius = 13, -- ... and run instead of shining when closer than this
	GroupRadius = 14,
	IsolationWeight = 22, -- phantom cost per neighbour guest near a target
	OpenRange = 6,
	StandRange = 4, -- within this of a breaker's stand point (2.5 studs in front) to tamper/repair (> ArriveDistance)
	BoldSeconds = 25, -- ... unless the Day has less than this left
	WatchRadius = 8, -- a Phantom bot only tampers when no guest is this close to the breaker
	Looks = {
		{ { 234, 196, 160 }, { 30, 90, 96 }, { 196, 152, 64 }, { 60, 40, 30 } },
		{ { 200, 150, 110 }, { 120, 26, 46 }, { 184, 108, 56 }, { 40, 40, 48 } },
		{ { 240, 210, 180 }, { 70, 60, 110 }, { 236, 222, 190 }, { 52, 52, 58 } },
		{ { 150, 100, 70 }, { 40, 110, 70 }, { 196, 152, 64 }, { 92, 58, 36 } },
		{ { 230, 180, 150 }, { 160, 110, 40 }, { 26, 78, 82 }, { 30, 30, 36 } },
	},
}
