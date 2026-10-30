-- Match flow (pure data). Lobby -> Night 1 (Day, Night) -> Dawn -> Night 2 -> Dawn -> Night 3
-- (Day, Showdown, Overdrive) -> Results -> Lobby, forever. See Config/Nights.
return {
	Version = "v1.2", -- build label (workspace attribute CM_Version)
	LobbySeconds = 30,
	ResultsSeconds = 12,
	DawnSeconds = 8, -- interlude between nights (night result, Wisps wake up)
	MinPlayers = 6, -- bots fill up to this many participants
	MaxPlayers = 10, -- server size (set Max Players = 10 in Game Settings)
	-- 1 Phantom per 5 players: 1 at <= 6 participants, 2 at 7-10
	PhantomTable = {
		{ upTo = 6, count = 1 },
		{ upTo = 10, count = 2 },
	},
	NightOrder = { 1, 2, 3 },
	TickSeconds = 0.1, -- server simulation step (10 Hz)
	RoleRevealSeconds = 4,
	-- ribbon colours: everyone wears one (Expose clues name ribbon colours)
	Ribbons = { "Crimson", "Azure", "Emerald", "Amber", "Violet", "Pink", "Cream2", "TealNeon", "Onyx", "Copper" },
	RibbonNames = { Crimson = "Red", Azure = "Blue", Emerald = "Green", Amber = "Yellow", Violet = "Purple", Pink = "Pink", Cream2 = "White", TealNeon = "Teal", Onyx = "Black", Copper = "Orange" },
	Expose = {
		stunSeconds = 5, -- a correctly exposed Phantom is frozen at night start ...
		revealSeconds = 30, -- ... and outlined through walls for everyone
		shakenSeconds = 20, -- a wrong vote: every voter walks x0.85 at night start
		shakenFactor = 0.85,
		minVotes = 2,
		minShare = 0.4, -- of the voters who are alive
		clueDecoyChance = 1, -- clue names the tamperer's ribbon + one other (shuffled)
		inspectRange = 8,
	},
}
