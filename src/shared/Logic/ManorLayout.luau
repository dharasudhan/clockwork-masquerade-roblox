-- Manor geometry + navigation (pure; no requires). `M` is Config/Manor.
--   * levels: room spans, floor heights, room lookup by (x, y, z)
--   * geometry: wall pieces with door gaps per level band (walls butt-join at corners: N/S
--     walls run the full side, W/E walls stop at the N/S walls' inner faces), inset floor and
--     ceiling slabs, rails/crowns ON the wall faces, door frames and name plates; every piece is
--     an axis-aligned box, so Logic/Coplanar can prove no two visible faces share a plane
--   * navigation: a portal graph (doors, stair flights, the service lift) searched with Dijkstra
--     on walking distance; routes come back as {x, y, z, lift?} waypoints (y = root height)
local ManorLayout = {}

local EPS = 1e-6
ManorLayout.RootHeight = 3 -- a character's root above the floor
ManorLayout.StairBottomLanding = 8
ManorLayout.StairTopLanding = 10
ManorLayout.StairSteps = 20

local function byId(rooms)
	local m = {}
	for _, r in rooms do
		m[r.id] = r
	end
	return m
end
ManorLayout.byId = byId

local idCache = setmetatable({}, { __mode = "k" })
local function ids(M)
	local m = idCache[M]
	if not m then
		m = byId(M.Rooms)
		idCache[M] = m
	end
	return m
end
ManorLayout.ids = ids

-- ---- levels ------------------------------------------------------------------------------------
function ManorLayout.span(r): (number, number)
	return r.level, r.level + (r.span or 1) - 1
end

function ManorLayout.baseY(M, r): number
	return r.level * M.LevelHeight
end

function ManorLayout.height(M, r): number
	if r.height then
		return r.height
	end
	return ((r.span or 1) - 1) * M.LevelHeight + M.RoomHeight
end

function ManorLayout.topY(M, r): number
	return ManorLayout.baseY(M, r) + ManorLayout.height(M, r)
end

function ManorLayout.levelAt(M, y: number): number
	return math.floor((y + 8) / M.LevelHeight)
end

function ManorLayout.maxLevel(M): number
	local hi = -math.huge
	for _, l in M.Levels do
		hi = math.max(hi, l.level)
	end
	return hi
end

function ManorLayout.levelName(M, level: number): string
	for _, l in M.Levels do
		if l.level == level then
			return l.name
		end
	end
	return "Level " .. level
end

function ManorLayout.centre(room)
	return (room.x0 + room.x1) / 2, (room.z0 + room.z1) / 2
end

-- Room containing a point. y may be nil (then the ground-most room wins). Balconies beat the
-- tall room they sit in; one-level rooms beat tall ones; stairwells match their whole height.
function ManorLayout.roomAt(M, x: number, y: number?, z: number): string?
	local lvl = if y then ManorLayout.levelAt(M, y) else nil
	local best, bestScore = nil, -math.huge
	for _, r in M.Rooms do
		if x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1 then
			local lo, hi = ManorLayout.span(r)
			local ok, score = false, 0
			if lvl == nil then
				ok, score = true, -math.abs(r.level) - (if lo ~= hi then 0.5 else 0)
			elseif r.stair and y then
				local b = ManorLayout.baseY(M, r)
				ok = y >= b - 2 and y <= ManorLayout.topY(M, r) + 1
				score = 1
			elseif lvl >= lo and lvl <= hi then
				ok = true
				score = if r.balconyOf then 3 elseif lo == hi then 2 else 1
			end
			if ok and score > bestScore then
				best, bestScore = r.id, score
			end
		end
	end
	return best
end

-- Clamp a point inside a room (margin studs from its walls).
function ManorLayout.clampInto(room, x: number, z: number, margin: number)
	return math.clamp(x, room.x0 + margin, room.x1 - margin), math.clamp(z, room.z0 + margin, room.z1 - margin)
end

-- ---- doors -------------------------------------------------------------------------------------
-- Shared edge of two rooms (2D): axis "x" (a wall at x = pos) or "z", overlap range, sides.
function ManorLayout.edge(a, b)
	local function ov(a0, a1, b0, b1)
		return math.max(a0, b0), math.min(a1, b1)
	end
	if a.x1 == b.x0 or a.x0 == b.x1 then
		local lo, hi = ov(a.z0, a.z1, b.z0, b.z1)
		if hi - lo <= 0 then
			return nil
		end
		local east = a.x1 == b.x0
		return { axis = "x", pos = if east then a.x1 else a.x0, lo = lo, hi = hi, sideA = if east then "E" else "W", sideB = if east then "W" else "E" }
	elseif a.z1 == b.z0 or a.z0 == b.z1 then
		local lo, hi = ov(a.x0, a.x1, b.x0, b.x1)
		if hi - lo <= 0 then
			return nil
		end
		local south = a.z1 == b.z0
		return { axis = "z", pos = if south then a.z1 else a.z0, lo = lo, hi = hi, sideA = if south then "S" else "N", sideB = if south then "N" else "S" }
	end
	return nil
end

-- Edge of a balcony with a room outside its parent: the balcony's own edge on the parent's wall.
local function edgeOf(m, a, b)
	local e = ManorLayout.edge(a, b)
	if e then
		return e
	end
	return nil
end

function ManorLayout.doorLevel(m, door): number
	if door.level then
		return door.level
	end
	local a, b = m[door.a], m[door.b]
	local alo, ahi = ManorLayout.span(a)
	local blo, bhi = ManorLayout.span(b)
	if alo == ahi then
		return alo
	elseif blo == bhi then
		return blo
	end
	return math.max(alo, blo)
end

local infoCache = setmetatable({}, { __mode = "k" })
function ManorLayout.doorInfo(M, door)
	local cached = infoCache[door]
	if cached then
		return cached
	end
	local m = ids(M)
	local a, b = m[door.a], m[door.b]
	assert(a and b, "door joins unknown room " .. tostring(door.a) .. "/" .. tostring(door.b))
	local e = edgeOf(m, a, b)
	assert(e, "rooms " .. door.a .. " and " .. door.b .. " do not share an edge")
	local level = ManorLayout.doorLevel(m, door)
	local alo, ahi = ManorLayout.span(a)
	local blo, bhi = ManorLayout.span(b)
	local x = if e.axis == "x" then e.pos else door.at
	local z = if e.axis == "x" then door.at else e.pos
	local info = {
		a = door.a, b = door.b, axis = e.axis, pos = e.pos, at = door.at, width = door.width,
		x = x, z = z, level = level, y = level * M.LevelHeight, sideA = e.sideA, sideB = e.sideB, lo = e.lo, hi = e.hi,
		fits = door.at - door.width / 2 >= e.lo + 0.5 and door.at + door.width / 2 <= e.hi - 0.5
			and level >= alo and level <= ahi and level >= blo and level <= bhi,
	}
	infoCache[door] = info
	return info
end

function ManorLayout.neighbours(M, roomId: string)
	local out = {}
	for _, d in M.Doors do
		if d.a == roomId then
			table.insert(out, d.b)
		elseif d.b == roomId then
			table.insert(out, d.a)
		end
	end
	return out
end

-- ---- stairs ------------------------------------------------------------------------------------
-- A flight climbs `up` from the bottom wall: bottom landing, StairSteps steps, top landing.
-- u = distance from the bottom wall along the run; returns a world (x, z) for (u, across offset).
function ManorLayout.stairFrame(r)
	local up = r.stair.up
	local cx, cz = ManorLayout.centre(r)
	local len = if up == "N" or up == "S" then r.z1 - r.z0 else r.x1 - r.x0
	local function at(u: number, off: number?)
		local o = off or 0
		if up == "N" then
			return cx + o, r.z1 - u
		elseif up == "S" then
			return cx + o, r.z0 + u
		elseif up == "E" then
			return r.x0 + u, cz + o
		else
			return r.x1 - u, cz + o
		end
	end
	return { up = up, length = len, at = at, runAxis = if up == "N" or up == "S" then "z" else "x" }
end

-- Foot (bottom landing) and head (top landing) walking points of a stairwell.
function ManorLayout.stairPoints(M, r)
	local f = ManorLayout.stairFrame(r)
	local base = ManorLayout.baseY(M, r)
	local fx, fz = f.at(ManorLayout.StairBottomLanding - 2)
	local hx, hz = f.at(f.length - ManorLayout.StairTopLanding + 3)
	return { x = fx, y = base + ManorLayout.RootHeight, z = fz }, { x = hx, y = base + M.LevelHeight + ManorLayout.RootHeight, z = hz }
end

-- ---- geometry ----------------------------------------------------------------------------------
local function box(kind, room, x0, x1, y0, y1, z0, z1, extra)
	local b = { kind = kind, room = room, cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, cz = (z0 + z1) / 2, sx = x1 - x0, sy = y1 - y0, sz = z1 - z0 }
	if extra then
		for k, v in extra do
			b[k] = v
		end
	end
	return b
end
ManorLayout.box = box

-- Is the door's edge on room r's `side` boundary (r is one of the door's rooms, or the parent of a
-- balcony that is)?
local function doorOnSide(m, r, side, d, info)
	if d.a == r.id then
		return info.sideA == side
	elseif d.b == r.id then
		return info.sideB == side
	end
	for _, rid in { d.a, d.b } do
		local c = m[rid]
		if c.balconyOf == r.id then
			local plane = if side == "N" then r.z0 elseif side == "S" then r.z1 elseif side == "W" then r.x0 else r.x1
			local axis = if side == "N" or side == "S" then "z" else "x"
			return info.axis == axis and math.abs(info.pos - plane) < EPS
		end
	end
	return false
end

local function subtract(ranges, a, b)
	local out = {}
	for _, r in ranges do
		if b <= r[1] or a >= r[2] then
			table.insert(out, r)
		else
			if a > r[1] then
				table.insert(out, { r[1], a })
			end
			if b < r[2] then
				table.insert(out, { b, r[2] })
			end
		end
	end
	return out
end

-- Everything static the builder turns into parts. Returns a list of boxes:
--   { kind = Floor | Ceiling | Wainscot | Wall | Rail | Crown | DoorPost | Lintel | NamePlate |
--     Step | Landing | BalconyRail | Baluster | Guard, room, cx, cy, cz, sx, sy, sz, ... }
function ManorLayout.geometry(M, T: number)
	local m = ids(M)
	local out = {}
	local LH, DH = M.LevelHeight, M.DoorHeight
	local maxLevel = ManorLayout.maxLevel(M)
	local infos = {}
	for _, d in M.Doors do
		table.insert(infos, { d = d, info = ManorLayout.doorInfo(M, d) })
	end
	for _, r in M.Rooms do
		local base = ManorLayout.baseY(M, r)
		local top = ManorLayout.topY(M, r)
		local _, hiLevel = ManorLayout.span(r)
		if r.balconyOf then
			-- floor inset from the parent's walls on the shared sides, to the edge on the open side
			local p = m[r.balconyOf]
			local x0 = if math.abs(r.x0 - p.x0) < EPS then r.x0 + T else r.x0
			local x1 = if math.abs(r.x1 - p.x1) < EPS then r.x1 - T else r.x1
			local z0 = if math.abs(r.z0 - p.z0) < EPS then r.z0 + T else r.z0
			local z1 = if math.abs(r.z1 - p.z1) < EPS then r.z1 - T else r.z1
			table.insert(out, box("Floor", r.id, x0, x1, base - 1, base, z0, z1, { floor = r.floor }))
			-- railing along the open side: rail on balusters + an invisible guard
			local o = r.open
			local alongX = o == "N" or o == "S"
			local a0, a1 = if alongX then x0 else z0, if alongX then x1 else z1
			local edgeC = if o == "S" then z1 elseif o == "N" then z0 elseif o == "E" then x1 else x0
			local inward = if o == "S" or o == "E" then -1 else 1
			local c0, c1 = edgeC + inward * 0.05, edgeC + inward * 0.4
			local lo, hi = math.min(c0, c1), math.max(c0, c1)
			local function strip(kind, aa, ab, y0, y1, l, h)
				if alongX then
					table.insert(out, box(kind, r.id, aa, ab, y0, y1, l, h))
				else
					table.insert(out, box(kind, r.id, l, h, y0, y1, aa, ab))
				end
			end
			strip("BalconyRail", a0, a1, base + 3.3, base + 3.6, lo, hi)
			local n = math.max(2, math.floor((a1 - a0) / 3))
			for k = 1, n - 1 do
				local c = a0 + (a1 - a0) * k / n
				strip("Baluster", c - 0.15, c + 0.15, base, base + 3.3, lo + 0.03, hi - 0.03)
			end
			strip("Guard", a0, a1, base, base + 7, lo, hi)
			continue
		end
		-- floor + ceiling slabs, inset to the walls' inner faces
		table.insert(out, box("Floor", r.id, r.x0 + T, r.x1 - T, base - 1, base, r.z0 + T, r.z1 - T, { floor = r.floor }))
		table.insert(out, box("Ceiling", r.id, r.x0 + T, r.x1 - T, top, top + 1, r.z0 + T, r.z1 - T))
		local wallBottom = base - 1
		local wallTop = top + (if hiLevel < maxLevel then 3 else 1)
		for _, side in { "N", "S", "W", "E" } do
			local alongX = side == "N" or side == "S"
			local a0 = if alongX then r.x0 else r.z0 + T
			local a1 = if alongX then r.x1 else r.z1 - T
			local c0, c1 -- across range of the wall
			if side == "N" then
				c0, c1 = r.z0, r.z0 + T
			elseif side == "S" then
				c0, c1 = r.z1 - T, r.z1
			elseif side == "W" then
				c0, c1 = r.x0, r.x0 + T
			else
				c0, c1 = r.x1 - T, r.x1
			end
			local inner = if side == "N" or side == "W" then c1 else c0
			local inDir = if side == "N" or side == "W" then 1 else -1
			local gaps = {}
			for _, e in infos do
				if doorOnSide(m, r, side, e.d, e.info) then
					local g0, g1 = e.d.at - e.d.width / 2, e.d.at + e.d.width / 2
					table.insert(gaps, { g0 = g0, g1 = g1, y0 = e.info.y, y1 = e.info.y + DH })
				end
			end
			local cuts = { a0, a1 }
			for _, g in gaps do
				for _, v in { g.g0, g.g1 } do
					if v > a0 + EPS and v < a1 - EPS then
						table.insert(cuts, v)
					end
				end
			end
			table.sort(cuts)
			local function piece(kind, p, q, y0, y1, cc0, cc1, extra)
				if alongX then
					table.insert(out, box(kind, r.id, p, q, y0, y1, cc0, cc1, extra))
				else
					table.insert(out, box(kind, r.id, cc0, cc1, y0, y1, p, q, extra))
				end
			end
			local railRuns = {}
			for i = 1, #cuts - 1 do
				local p, q = cuts[i], cuts[i + 1]
				if q - p > 0.01 then
					local solid = { { wallBottom, wallTop } }
					local railOk = true
					for _, g in gaps do
						if g.g0 <= p + EPS and g.g1 >= q - EPS then
							solid = subtract(solid, g.y0, g.y1)
							if g.y0 < base + 4.2 and g.y1 > base + 3.8 then
								railOk = false
							end
						end
					end
					for _, s in solid do
						local y0, y1 = s[1], s[2]
						if y1 - y0 > 0.01 then
							local split = base + 4
							if y0 < split - EPS and y1 > split + EPS then
								piece("Wainscot", p, q, y0, split, c0, c1, { side = side })
								piece("Wall", p, q, split, y1, c0, c1, { side = side })
							elseif y1 <= split + EPS then
								piece("Wainscot", p, q, y0, y1, c0, c1, { side = side })
							else
								piece("Wall", p, q, y0, y1, c0, c1, { side = side })
							end
						end
					end
					if railOk then
						local last = railRuns[#railRuns]
						if last and math.abs(last[2] - p) < EPS then
							last[2] = q
						else
							table.insert(railRuns, { p, q })
						end
					end
				end
			end
			if not r.stair then
				-- brass dado rail ON the inner face (0.2 deep), clear of the perpendicular rails
				local lim0 = if alongX then r.x0 + T else r.z0 + T + 0.2
				local lim1 = if alongX then r.x1 - T else r.z1 - T - 0.2
				local rc0, rc1 = inner, inner + inDir * 0.2
				for _, run in railRuns do
					local p, q = math.max(run[1], lim0), math.min(run[2], lim1)
					if q - p > 0.3 then
						piece("Rail", p, q, base + 3.85, base + 4.15, math.min(rc0, rc1), math.max(rc0, rc1), { side = side })
					end
				end
				-- crown moulding under the ceiling (N/S walls, full inner span)
				if alongX then
					local cc0, cc1 = inner, inner + inDir * 0.3
					piece("Crown", r.x0 + T, r.x1 - T, top - 0.4, top, math.min(cc0, cc1), math.max(cc0, cc1), { side = side })
				end
			end
		end
		-- a stair flight: solid steps from the floor, then the top landing at the next level
		if r.stair then
			local f = ManorLayout.stairFrame(r)
			local nSteps = ManorLayout.StairSteps
			local runLen = (f.length - ManorLayout.StairBottomLanding - ManorLayout.StairTopLanding) / nSteps
			local rise = LH / nSteps
			local function slab(kind, u0, u1, h)
				local xa, za = f.at(u0)
				local xb, zb = f.at(u1)
				if f.runAxis == "z" then
					table.insert(out, box(kind, r.id, r.x0 + T, r.x1 - T, base, base + h, math.min(za, zb), math.max(za, zb)))
				else
					table.insert(out, box(kind, r.id, math.min(xa, xb), math.max(xa, xb), base, base + h, r.z0 + T, r.z1 - T))
				end
			end
			for i = 1, nSteps do
				local u0 = ManorLayout.StairBottomLanding + (i - 1) * runLen
				slab("Step", u0, u0 + runLen, rise * i)
			end
			slab("Landing", f.length - ManorLayout.StairTopLanding, f.length - T, LH)
		end
	end
	-- door frames + name plates (one plate per door, a SurfaceGui on each face)
	for _, e in infos do
		local d, info = e.d, e.info
		local g0, g1 = d.at - d.width / 2, d.at + d.width / 2
		local yb = info.y
		local function across(kind, p, q, y0, y1, half, extra)
			if info.axis == "z" then
				table.insert(out, box(kind, d.a .. "|" .. d.b, p, q, y0, y1, info.pos - half, info.pos + half, extra))
			else
				table.insert(out, box(kind, d.a .. "|" .. d.b, info.pos - half, info.pos + half, y0, y1, p, q, extra))
			end
		end
		across("DoorPost", g0, g0 + 0.6, yb, yb + DH, T + 0.1)
		across("DoorPost", g1 - 0.6, g1, yb, yb + DH, T + 0.1)
		across("Lintel", g0 + 0.6, g1 - 0.6, yb + DH - 0.5, yb + DH, T + 0.08)
		local pl = math.min(d.width - 2, 7)
		across("NamePlate", d.at - pl / 2, d.at + pl / 2, yb + DH + 0.7, yb + DH + 2.3, T + 0.15, { door = d, axis = info.axis, pos = info.pos })
	end
	return out
end

-- ---- chests + breakers -------------------------------------------------------------------------
-- Chest spots: corners (inset 5) of normal rooms; along the wall of narrow ones (corridors).
function ManorLayout.chestSpots(M)
	local spots = {}
	for _, r in M.Rooms do
		local n = r.chests or 0
		if n > 0 then
			local w, d = r.x1 - r.x0, r.z1 - r.z0
			local base = ManorLayout.baseY(M, r)
			local cands
			if math.min(w, d) <= 14 then
				cands = {}
				local long = w >= d
				for k = 1, n do
					local f = k / (n + 2)
					if long then
						table.insert(cands, { x = r.x0 + w * f, z = if r.open == "N" then r.z1 - 2.6 else r.z0 + 2.6 })
					else
						table.insert(cands, { x = r.x0 + 2.6, z = r.z0 + d * f })
					end
				end
			else
				cands = { { x = r.x0 + 5, z = r.z0 + 5 }, { x = r.x1 - 5, z = r.z1 - 5 }, { x = r.x1 - 5, z = r.z0 + 5 }, { x = r.x0 + 5, z = r.z1 - 5 } }
			end
			for k = 1, math.min(n, #cands) do
				local c = cands[k]
				table.insert(spots, { x = c.x, z = c.z, y = base, room = r.id, level = r.level })
			end
		end
	end
	return spots
end

local FaceOf = { N = "S", S = "N", W = "E", E = "W" }
function ManorLayout.breakers(M)
	local m = ids(M)
	local out = {}
	for _, b in M.Breakers do
		local r = m[b.room]
		local x, z
		if b.side == "N" then
			x, z = b.at, r.z0 + 2.5
		elseif b.side == "S" then
			x, z = b.at, r.z1 - 2.5
		elseif b.side == "W" then
			x, z = r.x0 + 2.5, b.at
		else
			x, z = r.x1 - 2.5, b.at
		end
		local face = FaceOf[b.side]
		local fx = if face == "E" then 2.5 elseif face == "W" then -2.5 else 0
		local fz = if face == "S" then 2.5 elseif face == "N" then -2.5 else 0
		table.insert(out, { id = b.id, room = b.room, x = x, z = z, y = ManorLayout.baseY(M, r), level = r.level, face = face, standX = x + fx, standZ = z + fz })
	end
	return out
end

-- ---- navigation ----------------------------------------------------------------------------------
local function dist3(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
ManorLayout.dist3 = dist3

-- Cost of walking from point a to point b inside room r (a stair flight when they are on
-- different levels of a stairwell).
local function inRoom(M, r, a, b)
	if r.stair and math.abs(a.y - b.y) > 6 then
		local foot, head = ManorLayout.stairPoints(M, r)
		local lowP, highP = if a.y < b.y then a else b, if a.y < b.y then b else a
		return dist3(lowP, foot) + dist3(foot, head) + dist3(head, highP)
	end
	return dist3(a, b)
end

local graphCache = setmetatable({}, { __mode = "k" })
function ManorLayout.graph(M)
	local g = graphCache[M]
	if g then
		return g
	end
	g = { nodes = {}, byRoom = {} }
	for _, r in M.Rooms do
		g.byRoom[r.id] = {}
	end
	for i, d in M.Doors do
		local info = ManorLayout.doorInfo(M, d)
		local n = { kind = "door", door = d, info = info, x = info.x, y = info.y + ManorLayout.RootHeight, z = info.z, rooms = { d.a, d.b }, i = i }
		table.insert(g.nodes, n)
		table.insert(g.byRoom[d.a], #g.nodes)
		table.insert(g.byRoom[d.b], #g.nodes)
	end
	local lifts = {}
	for _, r in M.Rooms do
		if r.lift then
			local cx, cz = ManorLayout.centre(r)
			local n = { kind = "lift", lift = r.lift, room = r.id, level = r.level, x = cx, y = ManorLayout.baseY(M, r) + ManorLayout.RootHeight, z = cz, rooms = { r.id } }
			table.insert(g.nodes, n)
			table.insert(g.byRoom[r.id], #g.nodes)
			lifts[r.lift] = lifts[r.lift] or {}
			table.insert(lifts[r.lift], #g.nodes)
		end
	end
	g.liftLinks = {}
	for _, list in lifts do
		for _, i in list do
			for _, j in list do
				if i ~= j and math.abs(g.nodes[i].level - g.nodes[j].level) == 1 then
					g.liftLinks[i] = g.liftLinks[i] or {}
					table.insert(g.liftLinks[i], j)
				end
			end
		end
	end
	g.LiftCost = 12
	graphCache[M] = g
	return g
end

local function otherRoom(n, room)
	if n.kind == "door" then
		return if n.rooms[1] == room then n.rooms[2] else n.rooms[1]
	end
	return nil
end

-- Waypoints from point `from` to point `to` (tables with x, y, z; y = root height). Returns
-- the list of intermediate waypoints (the caller adds `to` itself), {} when already in the
-- same room on the same level, nil when unreachable. A waypoint with `lift = level` means
-- "ride the lift there" before moving on.
function ManorLayout.route(M, from, to, step: number?)
	local s = step or 3
	local m = ids(M)
	local ra = ManorLayout.roomAt(M, from.x, from.y, from.z)
	local rb = ManorLayout.roomAt(M, to.x, to.y, to.z)
	if not ra or not rb then
		return nil
	end
	if ra == rb then
		local r = m[ra]
		if r.stair and math.abs(from.y - to.y) > 6 then
			local foot, head = ManorLayout.stairPoints(M, r)
			return if from.y < to.y then { foot, head } else { head, foot }
		end
		return {}
	end
	local g = ManorLayout.graph(M)
	-- Dijkstra over portals; state = node index, with the room it was reached FROM
	local dist, prev, via, done = {}, {}, {}, {}
	for _, i in g.byRoom[ra] do
		local c = inRoom(M, m[ra], from, g.nodes[i])
		if dist[i] == nil or c < dist[i] then
			dist[i], prev[i], via[i] = c, 0, ra
		end
	end
	local bestEnd, bestCost = nil, math.huge
	while true do
		local u, ud = nil, math.huge
		for i, dd in dist do
			if not done[i] and dd < ud then
				u, ud = i, dd
			end
		end
		if u == nil or ud >= bestCost then
			break
		end
		done[u] = true
		local n = g.nodes[u]
		-- the room we are in after passing node u
		local here = if n.kind == "door" then otherRoom(n, via[u]) else n.room
		if here == rb then
			local c = ud + inRoom(M, m[rb], n, to)
			if c < bestCost then
				bestEnd, bestCost = u, c
			end
		end
		local function relax(j, c, roomVia)
			if not done[j] and (dist[j] == nil or c < dist[j]) then
				dist[j], prev[j], via[j] = c, u, roomVia
			end
		end
		if n.kind == "lift" then
			for _, j in g.liftLinks[u] or {} do
				relax(j, ud + g.LiftCost, n.room) -- arrive at another stop; "via" = the stop left
			end
		end
		if here then
			for _, j in g.byRoom[here] do
				if j ~= u then
					relax(j, ud + inRoom(M, m[here], n, g.nodes[j]), here)
				end
			end
		end
	end
	if bestEnd == nil then
		return nil
	end
	local chain = {}
	local cur = bestEnd
	while cur and cur ~= 0 do
		table.insert(chain, 1, cur)
		cur = prev[cur]
	end
	-- expand to waypoints
	local pts = {}
	local curRoom, curPt = ra, from
	local function walkIn(roomId, a, b)
		local r = m[roomId]
		if r and r.stair and math.abs(a.y - b.y) > 6 then
			local foot, head = ManorLayout.stairPoints(M, r)
			if a.y < b.y then
				table.insert(pts, foot)
				table.insert(pts, head)
			else
				table.insert(pts, head)
				table.insert(pts, foot)
			end
		end
	end
	for k, i in chain do
		local n = g.nodes[i]
		if n.kind == "door" then
			local info = n.info
			local nextRoom = otherRoom(n, curRoom)
			local r = m[curRoom]
			walkIn(curRoom, curPt, n)
			local y = n.y
			if info.axis == "x" then
				local dir = if r.x1 <= info.pos + EPS then 1 else -1
				table.insert(pts, { x = info.pos - dir * s, y = y, z = info.at })
				table.insert(pts, { x = info.pos + dir * s, y = y, z = info.at })
			else
				local dir = if r.z1 <= info.pos + EPS then 1 else -1
				table.insert(pts, { x = info.at, y = y, z = info.pos - dir * s })
				table.insert(pts, { x = info.at, y = y, z = info.pos + dir * s })
			end
			curRoom, curPt = nextRoom, n
		else
			-- lift stop: walk to it; if the next node is another stop, ride there
			local nxt = chain[k + 1] and g.nodes[chain[k + 1]]
			if n.room == curRoom then
				walkIn(curRoom, curPt, n)
				if nxt and nxt.kind == "lift" then
					table.insert(pts, { x = n.x, y = n.y, z = n.z, lift = nxt.level })
				else
					table.insert(pts, { x = n.x, y = n.y, z = n.z })
				end
			else
				-- arrived by lift
				curRoom, curPt = n.room, n
				if nxt and nxt.kind == "lift" then
					table.insert(pts, { x = n.x, y = n.y, z = n.z, lift = nxt.level })
				end
			end
		end
	end
	walkIn(curRoom, curPt, to)
	return pts
end

-- Total walking length of a route (from -> waypoints -> to), for tests and bot costs.
function ManorLayout.routeLength(M, from, to): number?
	local pts = ManorLayout.route(M, from, to)
	if pts == nil then
		return nil
	end
	local total, prevP = 0, from
	for _, p in pts do
		total += dist3(prevP, p)
		prevP = p
	end
	return total + dist3(prevP, to)
end

return ManorLayout
