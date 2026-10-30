-- Round / lobby pacing config: ready-up, countdowns, night length.
-- MatchService runs Lobby -> Countdown -> Night(s) -> Dawn phases (one match = many nights).
local Match = {}

Match.Version = "v1.5.1", -- build label (workspace attribute CM_Version)
Match.MaxPlayers = 12
Match.LobbySeconds = 45
Match.CountdownSeconds = 6
Match.NightSeconds = 480 -- 8 minutes per night
Match.DawnSeconds = 45
Match.PhantomSeconds = 45 -- solo-phantom pick phase
Match.SoloPhantomOffAfter = 3

-- lobby terrace (south of the manor; the spawn lawn)
Match.Lobby = { x0 = -26, x1 = 26, z0 = 110, z1 = 154, y = 0 }
-- x/z extent of the whole lot (drives DoormanController's fenced perimeter + foyer wall bounds)
Match.Lot = { x0 = -120, x1 = 120, z0 = -90, z1 = 160 }
Match.SpawnY = 0.4 -- terrace tiles' top
Match.TitleBoard = { x = 0, z = 148 } -- "Clockwork Masquerade" board on the terrace's north edge
Match.FrontDoorZ = 60 -- the manor's front door (lobby span is south of it)

-- hunter bot balance
Match.Bots = {
	Phantom = { count = 1, think = 1.0, cooldown = 4 },
	Hunter = { count = 2, think = 1.2, cooldown = 5 },
}

-- night shroud (phase 1.2): phantom's deployable darkness; "shroud" == the deployable field itself
Match.Shroud = {
	maxCharges = 3, -- stored charges (refilled by haunting furniture)
	chargeSeconds = 25, -- each charge takes this long to build (a phantom actively haunting)
	deploySeconds = 30, -- a deployed field lasts this long
	radius = 26,
	movePenalty = 0.45, -- guest speed multiplier inside a field
}

-- dawn scatter (phase 1.2): loot pins scattered at dawn to re-seed the night's economy
Match.DawnScatter = {
	enabled = true,
	radius = 70, -- scatter around the manor heart
	smallPct = 50, mediumPct = 30, largePct = 20, -- weighting of scatter sizes
}

-- one bot round sim = 3 in-game days
Match.BotDays = 3
Match.MinHumansForBotFill = 0 -- keep 0 for bot-filled test games
Match.BotHumans = 0 -- bots fill up to this many total "players"
Match.BotFillPct = 0.6 -- fill remaining seats with bots to 60%

return Match
