-- Sterling Manor, ground floor (pure data). Rooms are axis-aligned rectangles in studs
-- (x0 < x1, z0 < z1; +x east, +z south, floor at y = 0). Doors join two rooms that share an
-- edge: `at` is the door centre along that edge, `width` its opening. Logic/ManorLayout turns
-- this into wall segments, door points and a room graph for bot routes.
local Manor = {}

Manor.Rooms = {
	{ id = "ballroom", name = "Ballroom", x0 = -30, x1 = 30, z0 = -30, z1 = 30, floor = "Parquet", lights = 4 },
	{ id = "foyer", name = "Foyer", x0 = -30, x1 = 30, z0 = 30, z1 = 60, floor = "Walnut", lights = 2 },
	{ id = "westHall", name = "West Corridor", x0 = -42, x1 = -30, z0 = -42, z1 = 50, floor = "Walnut", lights = 4 },
	{ id = "eastHall", name = "East Corridor", x0 = 30, x1 = 42, z0 = -42, z1 = 50, floor = "Walnut", lights = 4 },
	{ id = "northHall", name = "North Corridor", x0 = -30, x1 = 30, z0 = -42, z1 = -30, floor = "Walnut", lights = 3 },
	{ id = "boiler", name = "Boiler Room", x0 = -66, x1 = -42, z0 = -30, z1 = -6, floor = "Iron", lights = 1, breaker = "A" },
	{ id = "workshop", name = "Clock Workshop", x0 = 42, x1 = 66, z0 = -30, z1 = -6, floor = "Iron", lights = 1, breaker = "B" },
	{ id = "observatory", name = "Observatory", x0 = -12, x1 = 12, z0 = -66, z1 = -42, floor = "Iron", lights = 1, breaker = "C" },
	{ id = "luggage", name = "Luggage Room", x0 = -66, x1 = -42, z0 = 10, z1 = 40, floor = "Walnut", lights = 1 },
	{ id = "parlour", name = "Tea Parlour", x0 = 42, x1 = 66, z0 = 10, z1 = 40, floor = "Parquet", lights = 1 },
}

Manor.Doors = {
	{ a = "ballroom", b = "foyer", at = 0, width = 14 },
	{ a = "ballroom", b = "northHall", at = 0, width = 12 },
	{ a = "ballroom", b = "westHall", at = 0, width = 12 },
	{ a = "ballroom", b = "eastHall", at = 0, width = 12 },
	{ a = "foyer", b = "westHall", at = 42, width = 8 },
	{ a = "foyer", b = "eastHall", at = 42, width = 8 },
	{ a = "northHall", b = "westHall", at = -36, width = 8 },
	{ a = "northHall", b = "eastHall", at = -36, width = 8 },
	{ a = "westHall", b = "boiler", at = -18, width = 8 },
	{ a = "eastHall", b = "workshop", at = -18, width = 8 },
	{ a = "northHall", b = "observatory", at = 0, width = 8 },
	{ a = "westHall", b = "luggage", at = 25, width = 8 },
	{ a = "eastHall", b = "parlour", at = 25, width = 8 },
}

-- Breaker terminals: x, z of the box; `face` = direction the front faces (towards the room).
Manor.Breakers = {
	{ id = "A", room = "boiler", x = -63.5, z = -18, face = "E" },
	{ id = "B", room = "workshop", x = 63.5, z = -18, face = "W" },
	{ id = "C", room = "observatory", x = 0, z = -63.5, face = "S" },
}

-- Chest spots (12 of them are stocked each Day, chosen at random).
Manor.ChestSpots = {
	{ x = -24, z = -24 }, { x = 24, z = -24 }, { x = -24, z = 24 }, { x = 24, z = 24 },
	{ x = -25, z = 55 }, { x = 25, z = 55 },
	{ x = -36, z = -12 }, { x = 36, z = 12 },
	{ x = -60, z = 15 }, { x = -48, z = 35 }, { x = -61, z = 35 },
	{ x = 60, z = 15 }, { x = 48, z = 35 },
	{ x = -61, z = -27 }, { x = 61, z = -27 }, { x = -8, z = -62 },
}

-- Round spawn ring (ballroom centre) and the lobby terrace (south of the manor, outside).
Manor.Spawn = { x = 0, z = 0, radius = 12 }
Manor.Lobby = { x0 = -26, x1 = 26, z0 = 96, z1 = 140, spawn = { x = 0, z = 122 } }

return Manor
