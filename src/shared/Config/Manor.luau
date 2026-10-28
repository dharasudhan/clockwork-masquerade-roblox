-- Sterling Manor (pure data), M1.1 "enormous" layout: 3 levels (Basement -1, Ground 0, Upper 1),
-- ~3.6x the M1 floor area, 35 named rooms + 3 stairwells + a 3-stop service lift.
-- Rooms are axis-aligned rectangles in studs (x0 < x1, z0 < z1; +x east, +z south). A room's
-- floor top is at level * LevelHeight; `span` = how many levels it is tall (ballroom and
-- stairwells are 2). Doors join two rooms sharing an edge at one `level` (default: the level both
-- rooms are on); `at` is the door centre along that edge, `width` its opening.
-- Logic/ManorLayout turns this into wall pieces with door gaps per level, door points, a
-- distance-weighted portal graph (doors + stairs + lift) and waypoint routes for bots.
local Manor = {}

Manor.LevelHeight = 20 -- floor-to-floor
Manor.RoomHeight = 16 -- floor-to-ceiling of a one-level room
Manor.DoorHeight = 12
Manor.Levels = {
	{ level = -1, name = "Basement", short = "B" },
	{ level = 0, name = "Ground Floor", short = "G" },
	{ level = 1, name = "Upper Floor", short = "U" },
}

-- floor: Parquet | Walnut | Iron | Marble | Tile | Stone; chests = chest spots in the room
-- (corners, inset); lights = chandeliers; decor = a dressing kit in ManorBuilder.
Manor.Rooms = {
	-- ---- Ground floor (level 0) ------------------------------------------------------------
	{ id = "ballroom", name = "Grand Ballroom", level = 0, span = 2, x0 = -30, x1 = 30, z0 = -30, z1 = 30, floor = "Parquet", lights = 4, chests = 2, decor = "ballroom" },
	{ id = "foyer", name = "Foyer", level = 0, x0 = -30, x1 = 30, z0 = 30, z1 = 60, floor = "Marble", lights = 2, chests = 2, decor = "foyer" },
	{ id = "northHall", name = "North Corridor", level = 0, x0 = -30, x1 = 30, z0 = -42, z1 = -30, floor = "Walnut", lights = 2, decor = "pipes" },
	{ id = "westHall", name = "West Corridor", level = 0, x0 = -42, x1 = -30, z0 = -42, z1 = 60, floor = "Walnut", lights = 4, chests = 1, decor = "pipes" },
	{ id = "eastHall", name = "East Corridor", level = 0, x0 = 30, x1 = 42, z0 = -42, z1 = 60, floor = "Walnut", lights = 4, chests = 1, decor = "pipes" },
	{ id = "library", name = "Library", level = 0, x0 = -90, x1 = -42, z0 = -42, z1 = -6, floor = "Walnut", lights = 2, chests = 2, decor = "shelves" },
	{ id = "billiard", name = "Billiard Room", level = 0, x0 = -90, x1 = -60, z0 = -6, z1 = 34, floor = "Parquet", lights = 1, chests = 1, decor = "billiard" },
	{ id = "musicRoom", name = "Music Room", level = 0, x0 = -90, x1 = -42, z0 = 34, z1 = 66, floor = "Parquet", lights = 2, chests = 1, decor = "music" },
	{ id = "laboratory", name = "Inventor's Laboratory", level = 0, x0 = 42, x1 = 90, z0 = -42, z1 = -6, floor = "Tile", lights = 2, chests = 1, breaker = "D", decor = "lab" },
	{ id = "diningHall", name = "Dining Hall", level = 0, x0 = 60, x1 = 90, z0 = -6, z1 = 34, floor = "Parquet", lights = 2, chests = 1, decor = "dining" },
	{ id = "kitchen", name = "Kitchen", level = 0, x0 = 42, x1 = 90, z0 = 34, z1 = 66, floor = "Tile", lights = 2, chests = 2, decor = "kitchen" },
	{ id = "mapRoom", name = "Map Room", level = 0, x0 = -42, x1 = -12, z0 = -72, z1 = -42, floor = "Walnut", lights = 1, chests = 1, decor = "maps" },
	{ id = "clockWorkshop", name = "Clock Workshop", level = 0, x0 = -12, x1 = 12, z0 = -72, z1 = -42, floor = "Iron", lights = 1, chests = 1, breaker = "B", decor = "clocks" },
	{ id = "conservatory", name = "Conservatory", level = 0, x0 = 12, x1 = 72, z0 = -82, z1 = -42, floor = "Stone", lights = 2, chests = 2, decor = "plants" },
	{ id = "greenhouse", name = "Greenhouse", level = 0, x0 = -90, x1 = -42, z0 = -78, z1 = -42, floor = "Stone", lights = 1, chests = 1, decor = "plants" },
	-- stairwells (2 levels tall, `stair.up` = the direction the flight climbs)
	{ id = "westStair", name = "West Grand Stair", level = 0, span = 2, x0 = -60, x1 = -42, z0 = -6, z1 = 34, floor = "Marble", lights = 1, stair = { up = "N" } },
	{ id = "eastStair", name = "East Grand Stair", level = 0, span = 2, x0 = 42, x1 = 60, z0 = -6, z1 = 34, floor = "Marble", lights = 1, stair = { up = "N" } },
	{ id = "serviceStair", name = "Service Stair", level = -1, span = 2, x0 = 72, x1 = 90, z0 = -82, z1 = -42, floor = "Iron", lights = 1, stair = { up = "N" } },
	-- service lift: one shaft, a stop on every level (ProximityPrompts ride it)
	{ id = "liftB", name = "Service Lift", level = -1, x0 = 42, x1 = 54, z0 = 66, z1 = 78, floor = "Iron", lights = 1, lift = "service" },
	{ id = "liftG", name = "Service Lift", level = 0, x0 = 42, x1 = 54, z0 = 66, z1 = 78, floor = "Iron", lights = 1, lift = "service" },
	{ id = "liftU", name = "Service Lift", level = 1, x0 = 42, x1 = 54, z0 = 66, z1 = 78, floor = "Iron", lights = 1, lift = "service" },
	-- ---- Upper floor (level 1) -------------------------------------------------------------
	-- the Gallery balcony sits inside the ballroom's upper half (railing along its open side)
	{ id = "gallery", name = "Gallery Balcony", level = 1, x0 = -30, x1 = 30, z0 = -30, z1 = -18, floor = "Walnut", lights = 0, chests = 1, balconyOf = "ballroom", open = "S" },
	{ id = "portraitHall", name = "Portrait Hall", level = 1, x0 = -30, x1 = 30, z0 = -42, z1 = -30, floor = "Walnut", lights = 2, decor = "portraits" },
	{ id = "westLanding", name = "West Landing", level = 1, x0 = -42, x1 = -30, z0 = -42, z1 = 34, floor = "Walnut", lights = 3, chests = 1, decor = "portraits" },
	{ id = "eastLanding", name = "East Landing", level = 1, x0 = 30, x1 = 42, z0 = -42, z1 = 34, floor = "Walnut", lights = 3, chests = 1, decor = "portraits" },
	{ id = "observatory", name = "Observatory Dome", level = 1, x0 = -12, x1 = 12, z0 = -72, z1 = -42, height = 24, floor = "Iron", lights = 1, chests = 1, breaker = "C", decor = "telescope" },
	{ id = "telegraph", name = "Telegraph Room", level = 1, x0 = -42, x1 = -12, z0 = -72, z1 = -42, floor = "Walnut", lights = 1, chests = 1, breaker = "E", decor = "telegraph" },
	{ id = "loft", name = "Clocktower Loft", level = 1, x0 = 12, x1 = 42, z0 = -72, z1 = -42, floor = "Iron", lights = 1, chests = 1, decor = "clocks" },
	{ id = "guestWest", name = "West Guest Suite", level = 1, x0 = -90, x1 = -42, z0 = -42, z1 = -6, floor = "Parquet", lights = 2, chests = 2, decor = "beds" },
	{ id = "guestEast", name = "East Guest Suite", level = 1, x0 = 42, x1 = 90, z0 = -42, z1 = -6, floor = "Parquet", lights = 2, chests = 2, decor = "beds" },
	{ id = "drafting", name = "Drafting Room", level = 1, x0 = -90, x1 = -60, z0 = -6, z1 = 34, floor = "Walnut", lights = 1, chests = 1, decor = "drafting" },
	{ id = "trophy", name = "Trophy Room", level = 1, x0 = 60, x1 = 90, z0 = -6, z1 = 34, floor = "Walnut", lights = 1, chests = 1, decor = "trophies" },
	{ id = "teaSalon", name = "Tea Salon", level = 1, x0 = -90, x1 = -30, z0 = 34, z1 = 66, floor = "Parquet", lights = 2, chests = 2, decor = "tea" },
	{ id = "mezzanine", name = "Clock Mezzanine", level = 1, x0 = -30, x1 = 30, z0 = 30, z1 = 60, floor = "Marble", lights = 2, chests = 1, decor = "clocks" },
	{ id = "linen", name = "Linen Room", level = 1, x0 = 30, x1 = 90, z0 = 34, z1 = 66, floor = "Walnut", lights = 2, chests = 1, decor = "linen" },
	-- ---- Basement (level -1) ---------------------------------------------------------------
	{ id = "steamHall", name = "Steam Corridor", level = -1, x0 = -42, x1 = 90, z0 = -42, z1 = -30, floor = "Iron", lights = 4, chests = 1, decor = "pipes" },
	{ id = "wineCellar", name = "Wine Cellar", level = -1, x0 = -42, x1 = 0, z0 = -30, z1 = 30, floor = "Stone", lights = 2, chests = 2, decor = "barrels" },
	{ id = "boiler", name = "Boiler Room", level = -1, x0 = 0, x1 = 42, z0 = -30, z1 = 30, floor = "Iron", lights = 2, chests = 1, decor = "boiler" },
	{ id = "generator", name = "Generator Vault", level = -1, x0 = 42, x1 = 90, z0 = -30, z1 = 30, floor = "Iron", lights = 2, chests = 1, breaker = "A", decor = "generator" },
	{ id = "coalStore", name = "Coal Store", level = -1, x0 = -42, x1 = 42, z0 = 30, z1 = 54, floor = "Stone", lights = 2, chests = 2, decor = "barrels" },
	{ id = "laundry", name = "Laundry", level = -1, x0 = 42, x1 = 90, z0 = 30, z1 = 66, floor = "Tile", lights = 2, chests = 1, decor = "linen" },
}

Manor.Doors = {
	-- ground
	{ a = "ballroom", b = "foyer", at = 0, width = 14, level = 0 },
	{ a = "ballroom", b = "northHall", at = 0, width = 12, level = 0 },
	{ a = "ballroom", b = "westHall", at = 0, width = 12, level = 0 },
	{ a = "ballroom", b = "eastHall", at = 0, width = 12, level = 0 },
	{ a = "foyer", b = "westHall", at = 45, width = 8 },
	{ a = "foyer", b = "eastHall", at = 45, width = 8 },
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
	-- upper
	{ a = "gallery", b = "westLanding", at = -24, width = 8 },
	{ a = "gallery", b = "eastLanding", at = -24, width = 8 },
	{ a = "gallery", b = "portraitHall", at = 0, width = 10 },
	{ a = "portraitHall", b = "westLanding", at = -36, width = 8 },
	{ a = "portraitHall", b = "eastLanding", at = -36, width = 8 },
	{ a = "portraitHall", b = "observatory", at = 0, width = 8 },
	{ a = "portraitHall", b = "telegraph", at = -21, width = 8 },
	{ a = "portraitHall", b = "loft", at = 21, width = 8 },
	{ a = "westLanding", b = "telegraph", at = -36, width = 8 },
	{ a = "eastLanding", b = "loft", at = 36, width = 8 },
	{ a = "westLanding", b = "guestWest", at = -24, width = 8 },
	{ a = "eastLanding", b = "guestEast", at = -24, width = 8 },
	{ a = "westStair", b = "westLanding", at = 0, width = 8, level = 1 },
	{ a = "eastStair", b = "eastLanding", at = 0, width = 8, level = 1 },
	{ a = "guestWest", b = "drafting", at = -75, width = 8 },
	{ a = "guestEast", b = "trophy", at = 75, width = 8 },
	{ a = "drafting", b = "teaSalon", at = -75, width = 8 },
	{ a = "trophy", b = "linen", at = 75, width = 8 },
	{ a = "westLanding", b = "teaSalon", at = -36, width = 8 },
	{ a = "eastLanding", b = "linen", at = 36, width = 8 },
	{ a = "teaSalon", b = "mezzanine", at = 47, width = 8 },
	{ a = "mezzanine", b = "linen", at = 47, width = 8 },
	{ a = "linen", b = "liftU", at = 48, width = 8 },
	-- basement
	{ a = "serviceStair", b = "steamHall", at = 81, width = 8, level = -1 },
	{ a = "steamHall", b = "wineCellar", at = -21, width = 8 },
	{ a = "steamHall", b = "boiler", at = 21, width = 8 },
	{ a = "steamHall", b = "generator", at = 66, width = 8 },
	{ a = "wineCellar", b = "boiler", at = 0, width = 10 },
	{ a = "boiler", b = "generator", at = 0, width = 10 },
	{ a = "wineCellar", b = "coalStore", at = -21, width = 8 },
	{ a = "boiler", b = "coalStore", at = 21, width = 8 },
	{ a = "coalStore", b = "laundry", at = 42, width = 8 },
	{ a = "generator", b = "laundry", at = 66, width = 8 },
	{ a = "laundry", b = "liftB", at = 48, width = 8 },
}

-- Breaker terminals (5, on all three floors): the cabinet stands against `side` of its room
-- ("N" | "S" | "W" | "E"), centred `at` along that wall, facing into the room.
Manor.Breakers = {
	{ id = "A", room = "generator", side = "E", at = 0 },
	{ id = "B", room = "clockWorkshop", side = "N", at = 0 },
	{ id = "C", room = "observatory", side = "N", at = 0 },
	{ id = "D", room = "laboratory", side = "E", at = -24 },
	{ id = "E", room = "telegraph", side = "W", at = -57 },
}

-- Round spawn ring (ballroom centre) and the lobby terrace (south of the manor, outside).
Manor.Spawn = { x = 0, z = 0, radius = 12, level = 0 }
Manor.Lobby = { x0 = -26, x1 = 26, z0 = 110, z1 = 154, spawn = { x = 0, z = 132 } }
Manor.FrontDoorZ = 60 -- foyer south wall (facade, front path)

return Manor
