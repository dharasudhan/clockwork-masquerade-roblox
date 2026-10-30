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
	{ id = "coalStore", name = "Coal Store", level = -1, x0 = -42, x1 = 12, z0 = 30, z1 = 54, lights = 2, chests = 2, theme = "coal" },
	{ id = "pumpRoom", name = "Pump Room", level = -1, x0 = 30, x1 = 42, z0 = 30, z1 = 54, lights = 1, chests = 1, theme = "pump" },
	{ id = "laundry", name = "Laundry", level = -1, x0 = 42, x1 = 90, z0 = 30, z1 = 66, lights = 2, chests = 1, theme = "laundry" },
	-- v1.6.2 Grotto Baths: the castle's swimming pool, under the east lawn (the grass slabs
	-- above already seal it invisibly; two archways in from the Coal Store, no dead-end).
	{ id = "grotto", name = "Grotto Baths", level = -1, x0 = -42, x1 = 12, z0 = 54, z1 = 78, lights = 2, chests = 1, theme = "grotto" },
}

-- v1.6.2: water hazards - Dawn Scatter spots must never land in the pool (Logic/Scatter reads
-- these as avoid points; radius from the pool centre covers the whole basin + rim).
Manor.Pools = {
	{ room = "grotto", x = -21, z = 66, r = 16 },
}

Manor.Doors = {
	-- ground
	{ a = "ballroom", b = "foyer", at = -2, width = 14, level = 0 },
	{ a = "ballroom", b = "northHall", at = 0, width = 12, level = 0 },
	{ a = "ballroom", b = "westHall", at = 0, width = 12, level = 0 },
	{ a = "ballroom", b = "eastHall", at = 0, width = 12, level = 0 },
	{ a = "foyer", b = "westHall", at = 45, width = 8 },
	{ a = "foyer", b = "cellarStair", at = 54.5, width = 8, level = 0 },
	{ a = "eastHall", b = "cellarStair", at = 54.5, width = 8, level = 0 },
	{ a = "northHall", b = "westHall", at = -36, width = 8 },
	{ a = "northHall", b = "eastHall", at = -36, width = 8 },
	{ a = "westHall", b = "library", at = -24, width = 8 },
	{ a = "westHall", b = "westStair", at = 29.5, width = 7, level = 0 },
	{ a = "westHall", b = "musicRoom", at = 50, width = 8 },
	{ a = "library", b = "billiard", at = -75, width = 8 },
	{ a = "billiard", b = "musicRoom", at = -75, width = 8 },
	{ a = "library", b = "greenhouse", at = -66, width = 8 },
	{ a = "greenhouse", b = "mapRoom", at = -60, width = 8 },
	{ a = "westHall", b = "mapRoom", at = -36, width = 8 },
	{ a = "northHall", b = "mapRoom", at = -21, width = 8 },
	{ a = "northHall", b = "clockWorkshop", at = 0, width = 8 },
	{ a = "northHall", b = "conservatory", at = 21, width = 8 },
	{ a = "eastHall", b = "conservatory", at = 36, width = 8 },
	{ a = "mapRoom", b = "clockWorkshop", at = -57, width = 8 },
	{ a = "clockWorkshop", b = "conservatory", at = -57, width = 8 },
	{ a = "eastHall", b = "laboratory", at = -24, width = 8 },
	{ a = "eastHall", b = "eastStair", at = 29.5, width = 7, level = 0 },
	{ a = "eastHall", b = "kitchen", at = 50, width = 8 },
	{ a = "laboratory", b = "diningHall", at = 75, width = 8 },
	{ a = "diningHall", b = "kitchen", at = 75, width = 8 },
	{ a = "conservatory", b = "laboratory", at = 57, width = 8 },
	{ a = "conservatory", b = "serviceStair", at = -76, width = 8, level = 0 },
	{ a = "kitchen", b = "liftG", at = 48, width = 8 },
	-- 1st floor
	{ a = "gallery", b = "westLanding", at = -24, width = 8 },
	{ a = "gallery", b = "eastLanding", at = -24, width = 8 },
	{ a = "gallery", b = "portraitHall", at = 0, width = 10 },
	{ a = "portraitHall", b = "westLanding", at = -36, width = 8 },
	{ a = "portraitHall", b = "eastLanding", at = -36, width = 8 },
	{ a = "portraitHall", b = "study", at = 0, width = 8 },
	{ a = "portraitHall", b = "telegraph", at = -21, width = 8 },
	{ a = "portraitHall", b = "loft", at = 21, width = 8 },
	{ a = "westLanding", b = "telegraph", at = -36, width = 8 },
	{ a = "eastLanding", b = "loft", at = 36, width = 8 },
	{ a = "westLanding", b = "guestWest", at = -24, width = 8 },
	{ a = "eastLanding", b = "guestEast", at = -24, width = 8 },
	{ a = "westStair", b = "westLanding", at = 0, width = 8, level = 1 },
	{ a = "eastStair", b = "eastLanding", at = 0, width = 8, level = 1 },
	{ a = "guestEast", b = "trophy", at = 75, width = 8 },
	{ a = "teaSalon", b = "atticStair", at = -75, width = 8, level = 1 },
	{ a = "trophy", b = "linen", at = 75, width = 8 },
	{ a = "westLanding", b = "teaSalon", at = -36, width = 8 },
	{ a = "eastLanding", b = "linen", at = 36, width = 8 },
	{ a = "teaSalon", b = "mezzanine", at = 47, width = 8 },
	{ a = "mezzanine", b = "linen", at = 47, width = 8 },
	{ a = "linen", b = "liftU", at = 48, width = 8 },
	-- 2nd floor / attic
	{ a = "atticStair", b = "draftingLoft", at = -75, width = 8, level = 2 },
	{ a = "draftingLoft", b = "atticHall", at = -36, width = 8 },
	{ a = "atticHall", b = "atticStore", at = -21, width = 8 },
	{ a = "atticHall", b = "automata", at = 21, width = 8 },
	{ a = "atticStore", b = "automata", at = -5, width = 10 },
	{ a = "atticHall", b = "atticWorkshop", at = -27, width = 8 },
	{ a = "atticHall", b = "towerStair", at = 0, width = 8, level = 2 },
	{ a = "atticHall", b = "greatClock", at = 27, width = 8 },
	{ a = "automata", b = "servants", at = 0, width = 8 },
	{ a = "servants", b = "trunkRoom", at = 66, width = 8 },
	{ a = "trunkRoom", b = "liftA", at = 48, width = 8 },
	-- tower
	{ a = "towerStair", b = "observatory", at = -67, width = 7, level = 3 },
	{ a = "towerStair", b = "lookout", at = -67, width = 7, level = 3 },
	-- B1 boiler level
	{ a = "serviceStair", b = "steamHall", at = 81, width = 8, level = -1 },
	{ a = "steamHall", b = "wineCellar", at = -21, width = 8 },
	{ a = "steamHall", b = "boiler", at = 21, width = 8 },
	{ a = "steamHall", b = "generator", at = 66, width = 8 },
	{ a = "wineCellar", b = "boiler", at = 0, width = 10 },
	{ a = "boiler", b = "generator", at = 0, width = 10 },
	{ a = "wineCellar", b = "coalStore", at = -21, width = 8 },
	{ a = "boiler", b = "coalStore", at = 6, width = 8 },
	{ a = "coalStore", b = "cellarStair", at = 34.5, width = 6, level = -1 },
	{ a = "pumpRoom", b = "cellarStair", at = 34.5, width = 6, level = -1 },
	{ a = "boiler", b = "pumpRoom", at = 36, width = 8 },
	{ a = "pumpRoom", b = "laundry", at = 42, width = 8 },
	{ a = "generator", b = "laundry", at = 66, width = 8 },
	{ a = "laundry", b = "liftB", at = 48, width = 8 },
	-- v1.6.2: two 8-stud archways into the Grotto Baths (two escape points, no dead-end - the
	-- Tower scatter lesson). A cellarStair door was tried and dropped: its posts landed
	-- coplanar with the stairwell's top-landing fill and the doorway opened into solid fill.
	{ a = "coalStore", b = "grotto", at = -30, width = 8 },
	{ a = "coalStore", b = "grotto", at = 0, width = 8 },
}

-- Breaker terminals (6, spread over B1 / G / 1F / 2F / Tower; each night uses 5 of them): the
-- cabinet stands against `side` of its room ("N" | "S" | "W" | "E"), centred `at` along that wall.
Manor.Breakers = {
	{ id = "A", room = "generator", side = "E", at = 0 },
	{ id = "B", room = "clockWorkshop", side = "N", at = 0 },
	{ id = "C", room = "atticWorkshop", side = "N", at = -27 },
	{ id = "D", room = "laboratory", side = "E", at = -24 },
	{ id = "E", room = "telegraph", side = "W", at = -57 },
	{ id = "F", room = "observatory", side = "N", at = 27 },
}

-- Night 2: blueprint page cabinets (pages hide in 3 of these each Day) and the projector.
Manor.Cabinets = {
	{ id = "cab1", room = "library", side = "W", at = -14 },
	{ id = "cab2", room = "draftingLoft", side = "W", at = -14 },
	{ id = "cab3", room = "mapRoom", side = "W", at = -57 },
	{ id = "cab4", room = "study", side = "E", at = -57 },
	{ id = "cab5", room = "wineCellar", side = "W", at = 12 },
	{ id = "cab6", room = "trophy", side = "E", at = 22 },
	{ id = "cab7", room = "atticStore", side = "W", at = 8 },
	{ id = "cab8", room = "lookout", side = "W", at = -57 },
}
Manor.Projector = { room = "library", x = -50, z = -30 }

-- Night 3 finale: the three Master Override Keys and the Exit Console (ballroom dais).
Manor.Keys = {
	{ id = "engine", name = "Clockwork Engine Key", room = "generator", x = 60, z = 0 },
	{ id = "attic", name = "Attic Key", room = "atticStore", x = -21, z = 8 },
	{ id = "greenhouse", name = "Greenhouse Key", room = "greenhouse", x = -56, z = -72 },
}
Manor.Console = { room = "ballroom", x = 0, z = 0, ringRadius = 11 }

-- Expose: the Evidence Board (Foyer, west wall) where guests vote by day.
Manor.EvidenceBoard = { room = "foyer", side = "W", at = 38 }

-- Round spawn ring (ballroom centre) and the lobby terrace (south of the manor, outside).
Manor.Spawn = { x = 0, z = 0, radius = 14, level = 0 }
Manor.Lobby = { x0 = -26, x1 = 26, z0 = 110, z1 = 154, spawn = { x = 0, z = 132 } }
Manor.FrontDoorZ = 60 -- foyer south wall (facade, front path)

return Manor
