-- Sterling Manor - now "Castle Sterling" (pure data), v1.0 layout: 5 levels a player obviously walks between:
--   B1 Boiler Level (-1)  ·  Ground (0)  ·  1st Floor (1)  ·  2nd Floor / Attic (2)  ·  Tower (3)
-- connected by two grand stairs (G<->1F), the Cellar Stair (G<->B1, opens off the Foyer right by
-- the front door), the Service Stair (G<->B1), the Attic Stair (1F<->2F), the Tower Stair
-- (2F<->Tower) and a 4-stop service lift (B1/G/1F/2F).
-- Rooms are axis-aligned rectangles in studs (x0 < x1, z0 < z1; +x east, +z south). A room's
-- floor top is at level * LevelHeight; `span` = how many levels it is tall (ballroom and
-- stairwells are 2). Doors join two rooms sharing an edge at one `level` (default: the level both
-- rooms are on); `at` is the door centre along that edge, `width` its opening.
-- `theme` names a look in Config/Decor (walls, floor, ceiling, light colour, trim, furniture kit,
-- wall-art set) so every room has its own identity.
local Manor = {}

Manor.LevelHeight = 20 -- floor-to-floor
Manor.RoomHeight = 16 -- floor-to-ceiling of a one-level room
Manor.DoorHeight = 12
-- `hud` is the floor name on the HUD floor badge and the minimap
Manor.Levels = {
	{ level = -1, name = "B1 Boiler Level", short = "B1", hud = "B1  BOILER LEVEL" },
	{ level = 0, name = "Ground Floor", short = "G", hud = "GROUND FLOOR" },
	{ level = 1, name = "1st Floor", short = "1F", hud = "1ST FLOOR" },
	{ level = 2, name = "2nd Floor / Attic", short = "2F", hud = "2ND FLOOR  ATTIC" },
	{ level = 3, name = "Tower", short = "T", hud = "3RD FLOOR  TOWER" },
}

-- chests = chest spots (corners, inset); lights = chandeliers / lamps
Manor.Rooms = {
	-- ---- Ground floor (level 0) ------------------------------------------------------------
	{ id = "ballroom", name = "Grand Ballroom", level = 0, span = 2, x0 = -30, x1 = 30, z0 = -30, z1 = 30, lights = 4, chests = 2, theme = "ballroom" },
	{ id = "foyer", name = "Foyer", level = 0, x0 = -30, x1 = 12, z0 = 30, z1 = 60, lights = 2, chests = 2, theme = "foyer" },
	{ id = "northHall", name = "North Corridor", level = 0, x0 = -30, x1 = 30, z0 = -42, z1 = -30, lights = 2, theme = "corridor" },
	{ id = "westHall", name = "West Corridor", level = 0, x0 = -42, x1 = -30, z0 = -42, z1 = 60, lights = 4, chests = 1, theme = "corridor" },
	{ id = "eastHall", name = "East Corridor", level = 0, x0 = 30, x1 = 42, z0 = -42, z1 = 60, lights = 4, chests = 1, theme = "corridor" },
	{ id = "library", name = "Royal Library", level = 0, x0 = -90, x1 = -42, z0 = -42, z1 = -6, lights = 2, chests = 2, theme = "library" },
	{ id = "billiard", name = "Billiard Room", level = 0, x0 = -90, x1 = -60, z0 = -6, z1 = 34, lights = 1, chests = 1, theme = "billiard" },
	{ id = "musicRoom", name = "Minstrel Hall", level = 0, x0 = -90, x1 = -42, z0 = 34, z1 = 66, lights = 2, chests = 1, theme = "music" },
	{ id = "laboratory", name = "Inventor's Laboratory", level = 0, x0 = 42, x1 = 90, z0 = -42, z1 = -6, lights = 2, chests = 1, theme = "lab" },
	{ id = "diningHall", name = "Banquet Hall", level = 0, x0 = 60, x1 = 90, z0 = -6, z1 = 34, lights = 2, chests = 1, theme = "dining" },
	{ id = "kitchen", name = "Kitchen", level = 0, x0 = 42, x1 = 90, z0 = 34, z1 = 66, lights = 2, chests = 2, theme = "kitchen" },
	{ id = "mapRoom", name = "Map Room", level = 0, x0 = -42, x1 = -12, z0 = -72, z1 = -42, lights = 1, chests = 1, theme = "maps" },
	{ id = "clockWorkshop", name = "Clock Workshop", level = 0, x0 = -12, x1 = 12, z0 = -72, z1 = -42, lights = 1, chests = 1, theme = "clockShop" },
	{ id = "conservatory", name = "Conservatory", level = 0, x0 = 12, x1 = 72, z0 = -82, z1 = -42, lights = 2, chests = 2, theme = "conservatory" },
	{ id = "greenhouse", name = "Greenhouse", level = 0, x0 = -90, x1 = -42, z0 = -78, z1 = -42, lights = 1, chests = 1, theme = "greenhouse" },
	-- stairwells (2 levels tall, `stair.up` = the direction the flight climbs)
	{ id = "westStair", name = "West Grand Stair", level = 0, span = 2, x0 = -60, x1 = -42, z0 = -6, z1 = 34, lights = 1, stair = { up = "N" }, theme = "grandStair" },
	{ id = "eastStair", name = "East Grand Stair", level = 0, span = 2, x0 = 42, x1 = 60, z0 = -6, z1 = 34, lights = 1, stair = { up = "N" }, theme = "grandStair" },
	{ id = "serviceStair", name = "Service Stair", level = -1, span = 2, x0 = 72, x1 = 90, z0 = -82, z1 = -42, lights = 1, stair = { up = "N" }, theme = "serviceStair" },
	-- the Cellar Stair opens off the Foyer (east wall, next to the front door) and the East
	-- Corridor: the obvious way down to B1
	{ id = "cellarStair", name = "Cellar Stair", level = -1, span = 2, x0 = 12, x1 = 30, z0 = 30, z1 = 60, lights = 2, stair = { up = "S" }, theme = "cellarStair" },
	-- service lift: one shaft, a stop on B1, G, 1F and 2F (ProximityPrompts ride it)
	{ id = "liftB", name = "Service Lift", level = -1, x0 = 42, x1 = 54, z0 = 66, z1 = 78, lights = 1, lift = "service", theme = "lift" },
	{ id = "liftG", name = "Service Lift", level = 0, x0 = 42, x1 = 54, z0 = 66, z1 = 78, lights = 1, lift = "service", theme = "lift" },
	{ id = "liftU", name = "Service Lift", level = 1, x0 = 42, x1 = 54, z0 = 66, z1 = 78, lights = 1, lift = "service", theme = "lift" },
	{ id = "liftA", name = "Service Lift", level = 2, x0 = 42, x1 = 54, z0 = 66, z1 = 78, lights = 1, lift = "service", theme = "lift" },
	-- ---- 1st floor (level 1) ---------------------------------------------------------------
	-- the Gallery balcony sits inside the ballroom's upper half (railing along its open side)
	{ id = "gallery", name = "Gallery Balcony", level = 1, x0 = -30, x1 = 30, z0 = -30, z1 = -18, lights = 0, chests = 1, balconyOf = "ballroom", open = "S", theme = "galleryBalcony" },
	{ id = "portraitHall", name = "Portrait Gallery", level = 1, x0 = -30, x1 = 30, z0 = -42, z1 = -30, lights = 2, theme = "portraitHall" },
	{ id = "westLanding", name = "West Landing", level = 1, x0 = -42, x1 = -30, z0 = -42, z1 = 34, lights = 3, chests = 1, theme = "landingWest" },
	{ id = "eastLanding", name = "East Landing", level = 1, x0 = 30, x1 = 42, z0 = -42, z1 = 34, lights = 3, chests = 1, theme = "landingEast" },
	{ id = "study", name = "Sterling's Study", level = 1, x0 = -12, x1 = 12, z0 = -72, z1 = -42, lights = 1, chests = 1, theme = "study" },
	{ id = "telegraph", name = "Telegraph Room", level = 1, x0 = -42, x1 = -12, z0 = -72, z1 = -42, lights = 1, chests = 1, theme = "telegraph" },
	{ id = "loft", name = "Clocktower Loft", level = 1, x0 = 12, x1 = 42, z0 = -72, z1 = -42, lights = 1, chests = 1, theme = "loft" },
	{ id = "guestWest", name = "Rose Guest Suite", level = 1, x0 = -90, x1 = -42, z0 = -42, z1 = -6, lights = 2, chests = 2, theme = "suiteRose" },
	{ id = "guestEast", name = "Azure Guest Suite", level = 1, x0 = 42, x1 = 90, z0 = -42, z1 = -6, lights = 2, chests = 2, theme = "suiteAzure" },
	{ id = "atticStair", name = "Attic Stair", level = 1, span = 2, x0 = -90, x1 = -60, z0 = -6, z1 = 34, lights = 1, stair = { up = "N" }, theme = "atticStair" },
	{ id = "trophy", name = "Armory", level = 1, x0 = 60, x1 = 90, z0 = -6, z1 = 34, lights = 1, chests = 1, theme = "trophy" },
	{ id = "teaSalon", name = "Tea Salon", level = 1, x0 = -90, x1 = -30, z0 = 34, z1 = 66, lights = 2, chests = 2, theme = "tea" },
	{ id = "mezzanine", name = "Clock Mezzanine", level = 1, x0 = -30, x1 = 30, z0 = 30, z1 = 60, lights = 2, chests = 1, theme = "mezzanine" },
	{ id = "linen", name = "Linen Room", level = 1, x0 = 30, x1 = 90, z0 = 34, z1 = 66, lights = 2, chests = 1, theme = "linen" },
	-- ---- 2nd floor / attic (level 2) -------------------------------------------------------
	{ id = "draftingLoft", name = "Drafting Loft", level = 2, x0 = -90, x1 = -42, z0 = -42, z1 = -6, lights = 2, chests = 2, theme = "drafting" },
	{ id = "atticHall", name = "Attic Corridor", level = 2, x0 = -42, x1 = 42, z0 = -42, z1 = -30, lights = 3, chests = 1, theme = "atticHall" },
	{ id = "atticStore", name = "Attic Storeroom", level = 2, x0 = -42, x1 = 0, z0 = -30, z1 = 20, lights = 2, chests = 2, theme = "atticStore" },
	{ id = "automata", name = "Automaton Nursery", level = 2, x0 = 0, x1 = 42, z0 = -30, z1 = 20, lights = 2, chests = 2, theme = "automata" },
	{ id = "atticWorkshop", name = "Attic Workshop", level = 2, x0 = -42, x1 = -12, z0 = -72, z1 = -42, lights = 1, chests = 1, theme = "atticWorkshop" },
	{ id = "towerStair", name = "Tower Stair", level = 2, span = 2, x0 = -12, x1 = 12, z0 = -72, z1 = -42, lights = 1, stair = { up = "N" }, theme = "towerStair" },
	{ id = "greatClock", name = "Great Clock Room", level = 2, x0 = 12, x1 = 42, z0 = -72, z1 = -42, lights = 1, chests = 1, theme = "greatClock" },
	{ id = "servants", name = "Servants' Quarters", level = 2, x0 = 42, x1 = 90, z0 = -30, z1 = 18, lights = 2, chests = 2, theme = "servants" },
	{ id = "trunkRoom", name = "Trunk Room", level = 2, x0 = 42, x1 = 90, z0 = 18, z1 = 66, lights = 2, chests = 1, theme = "trunks" },
	-- ---- Tower (level 3) -------------------------------------------------------------------
	{ id = "observatory", name = "Observatory Dome", level = 3, x0 = 12, x1 = 42, z0 = -72, z1 = -42, height = 26, lights = 1, chests = 1, theme = "observatory" },
	{ id = "lookout", name = "Tower Lookout", level = 3, x0 = -42, x1 = -12, z0 = -72, z1 = -42, lights = 1, chests = 1, theme = "lookout" },
	-- ---- B1 Boiler Level (level -1) --------------------------------------------------------
	{ id = "steamHall", name = "Steam Corridor", level = -1, x0 = -42, x1 = 90, z0 = -42, z1 = -30, lights = 4, chests = 1, theme = "steamHall" },
	{ id = "wineCellar", name = "Wine Cellar", level = -1, x0 = -42, x1 = 0, z0 = -30, z1 = 30, lights = 2, chests = 2, theme = "wineCellar" },
	{ id = "boiler", name = "Boiler Room", level = -1, x0 = 0, x1 = 42, z0 = -30, z1 = 30, lights = 2, chests = 1, theme = "boiler" },
	{ id = "generator", name = "Generator Vault", level = -1, x0 = 42, x1 = 90, z0 = -30, z1 = 30, lights = 2, chests = 1, theme = "generator" },
	{ id = "coalStore", name = "Coal Store", level = -1, x0 = -90, x1 = -42, z0 = -30, z1 = 30, lights = 1, chests = 1, theme = "coal" },
	{ id = "darkCellar", name = "Dark Cellar", level = -1, x0 = -90, x1 = -42, z0 = 30, z1 = 66, lights = 1, chests = 1, theme = "dark" },
}

-- doors (between rooms sharing an edge; at = centre of the opening along that edge, width = opening)
Manor.Doors = {
	{ a = "ballroom", b = "foyer", level = 0, at = 0, width = 16 },
	{ a = "ballroom", b = "northHall", level = 0, at = 0, width = 16 },
	{ a = "ballroom", b = "westHall", level = 0, at = -12, width = 14 },
	{ a = "ballroom", b = "eastHall", level = 0, at = 12, width = 14 },
	{ a = "foyer", b = "westHall", level = 0, at = 42, width = 12 },
	{ a = "foyer", b = "eastHall", level = 0, at = 42, width = 12 },
	{ a = "westHall", b = "library", level = 0, at = -24, width = 14 },
	{ a = "westHall", b = "billiard", level = 0, at = 14, width = 10 },
	{ a = "westHall", b = "musicRoom", level = 0, at = 50, width = 12 },
	{ a = "eastHall", b = "laboratory", level = 0, at = -24, width = 14 },
	{ a = "eastHall", b = "diningHall", level = 0, at = 14, width = 10 },
	{ a = "eastHall", b = "kitchen", level = 0, at = 50, width = 12 },
	{ a = "northHall", b = "mapRoom", level = 0, at = -24, width = 10 },
	{ a = "northHall", b = "clockWorkshop", level = 0, at = 0, width = 10 },
	{ a = "northHall", b = "conservatory", level = 0, at = 30, width = 14 },
	{ a = "library", b = "greenhouse", level = 0, at = -60, width = 10 },
	{ a = "diningHall", b = "kitchen", level = 0, at = 14, width = 12 },
	{ a = "billiard", b = "musicRoom", level = 0, at = 14, width = 12 },
	{ a = "ballroom", b = "gallery", level = 1, at = 0, width = 16 }, -- the mezzanine
	{ a = "northHall", b = "portraitHall", level = 1, at = 0, width = 16 },
	{ a = "portraitHall", b = "westLanding", level = 1, at = -12, width = 12 },
	{ a = "portraitHall", b = "eastLanding", level = 1, at = 12, width = 12 },
	{ a = "portraitHall", b = "study", level = 1, at = 0, width = 10 },
	{ a = "portraitHall", b = "telegraph", level = 1, at = -24, width = 10 },
	{ a = "portraitHall", b = "loft", level = 1, at = 24, width = 10 },
	{ a = "westLanding", b = "guestWest", level = 1, at = -24, width = 14 },
	{ a = "eastLanding", b = "guestEast", level = 1, at = -24, width = 14 },
	{ a = "westLanding", b = "atticStair", level = 1, at = 12, width = 12 },
	{ a = "eastLanding", b = "trophy", level = 1, at = 12, width = 12 },
	{ a = "westLanding", b = "teaSalon", level = 1, at = 50, width = 12 },
	{ a = "eastLanding", b = "linen", level = 1, at = 50, width = 12 },
	{ a = "mezzanine", b = "gallery", level = 1, at = 0, width = 16 },
	{ a = "westStair", b = "westLanding", level = 1, at = 14, width = 12 },
	{ a = "eastStair", b = "eastLanding", level = 1, at = 14, width = 12 },
	{ a = "cellarStair", b = "westHall", level = 0, at = 42, width = 10 },
	{ a = "cellarStair", b = "eastHall", level = 0, at = 42, width = 10 },
	{ a = "atticStair", b = "draftingLoft", level = 2, at = -24, width = 12 },
	{ a = "atticHall", b = "atticStore", level = 2, at = -12, width = 14 },
	{ a = "atticHall", b = "automata", level = 2, at = 12, width = 14 },
	{ a = "atticHall", b = "atticWorkshop", level = 2, at = -24, width = 10 },
	{ a = "atticHall", b = "towerStair", level = 2, at = 0, width = 12 },
	{ a = "atticHall", b = "greatClock", level = 2, at = 24, width = 10 },
	{ a = "steamHall", b = "wineCellar", level = -1, at = -24, width = 12 },
	{ a = "steamHall", b = "boiler", level = -1, at = 12, width = 12 },
	{ a = "steamHall", b = "generator", level = -1, at = 48, width = 12 },
	{ a = "boiler", b = "coalStore", level = -1, at = -24, width = 12 },
	{ a = "wineCellar", b = "darkCellar", level = -1, at = 48, width = 12 },
	{ a = "servants", b = "trunkRoom", level = 2, at = 36, width = 12 },
	{ a = "towerStair", b = "observatory", level = 3, at = 24, width = 12 },
	{ a = "towerStair", b = "lookout", level = 3, at = -24, width = 12 },
}

-- lockable shortcuts: sealed doors the Phantom can spend shroud to open / guests to barricade
Manor.Shortcuts = {
	{ a = "ballroom", b = "conservatory", level = 0, at = 30, width = 10, lock = 3 },
	{ a = "billiard", b = "guestWest", level = 1, at = 14, width = 10, lock = 2 },
	{ a = "diningHall", b = "servants", level = 2, at = 12, width = 10, lock = 2 },
	{ a = "musicRoom", b = "teaSalon", level = 1, at = 50, width = 12, lock = 3 },
	{ a = "laboratory", b = "loft", level = 1, at = 24, width = 10, lock = 2 },
	{ a = "greenhouse", b = "guestWest", level = 1, at = -60, width = 10, lock = 3 },
}

-- the front door (Foyer -> terrace); the lobby span sits south of it (Config/Match Lobby*)
Manor.FrontDoor = { at = 8, width = 10, z = 60 }
-- ghost-gates (how the Phantom enters each night; all sit on the ground floor's outer walls)
Manor.GhostGates = {
	{ room = "ballroom", at = 0, face = "N", width = 12 },
	{ room = "library", at = -60, face = "W", width = 10 },
	{ room = "laboratory", at = -24, face = "E", width = 10 },
	{ room = "conservatory", at = 30, face = "N", width = 10 },
	{ room = "diningHall", at = 14, face = "E", width = 10 },
	{ room = "musicRoom", at = 50, face = "S", width = 10 },
	{ room = "kitchen", at = 14, face = "S", width = 10 },
	{ room = "billiard", at = -24, face = "S", width = 10 },
}
-- where the guests first gather (terrace centre)
Manor.Spawn = { x = 0, y = 132, z = 132 }

return Manor
