-- Match flow (pure data). Lobby -> Night 1 (Day, Night) -> Results -> Lobby, forever.
-- Later milestones only add nights to `Nights` order; nothing here is Night-1 specific.
return {
	LobbySeconds = 30,
	ResultsSeconds = 10,
	MinPlayers = 6, -- bots fill up to this many participants
	MaxPlayers = 10, -- server size (set Max Players = 10 in Game Settings)
	-- 1 Phantom per 5 players: 1 at <= 6 participants, 2 at 7-10
	PhantomTable = {
		{ upTo = 6, count = 1 },
		{ upTo = 10, count = 2 },
	},
	NightOrder = { 1 }, -- M1: Night 1 only
	TickSeconds = 0.1, -- server simulation step (10 Hz)
	RoleRevealSeconds = 4,
	-- an untagged guest is "alive"; phantoms win when every guest is tagged
}
