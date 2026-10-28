-- Manor geometry (pure): shared edges, door points, wall segments with door gaps, room lookup
-- and fewest-doors routes between rooms for bots. Rooms/doors come from Config/Manor.
local ManorLayout = {}

local function byId(rooms)
	local m = {}
	for _, r in rooms do
		m[r.id] = r
	end
	return m
end
ManorLayout.byId = byId

-- Shared edge of two rooms: axis "x" (a vertical wall at x = pos) or "z", the overlap range
-- along the edge and which side of each room it is on (N = z0, S = z1, W = x0, E = x1).
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

function ManorLayout.doorInfo(rooms, door)
	local m = byId(rooms)
	local a, b = m[door.a], m[door.b]
	assert(a and b, "door joins unknown room " .. tostring(door.a) .. "/" .. tostring(door.b))
	local e = ManorLayout.edge(a, b)
	assert(e, "rooms " .. door.a .. " and " .. door.b .. " do not share an edge")
	local x = if e.axis == "x" then e.pos else door.at
	local z = if e.axis == "x" then door.at else e.pos
	return {
		a = door.a, b = door.b, axis = e.axis, pos = e.pos, at = door.at, width = door.width,
		x = x, z = z, sideA = e.sideA, sideB = e.sideB, lo = e.lo, hi = e.hi,
		fits = door.at - door.width / 2 >= e.lo + 0.5 and door.at + door.width / 2 <= e.hi - 0.5,
	}
end

-- Wall segments: { room, side, cx, cz, sx, sz } (centre + footprint), walls sit inside each
-- room's rectangle (thickness t) with gaps where that side has doors.
function ManorLayout.walls(rooms, doors, t: number)
	local infos = {}
	for _, d in doors do
		table.insert(infos, ManorLayout.doorInfo(rooms, d))
	end
	local out = {}
	for _, r in rooms do
		for _, side in { "N", "S", "W", "E" } do
			local gaps = {}
			for _, d in infos do
				if (d.a == r.id and d.sideA == side) or (d.b == r.id and d.sideB == side) then
					table.insert(gaps, { d.at - d.width / 2, d.at + d.width / 2 })
				end
			end
			table.sort(gaps, function(p, q)
				return p[1] < q[1]
			end)
			local along0, along1
			if side == "N" or side == "S" then
				along0, along1 = r.x0, r.x1
			else
				along0, along1 = r.z0, r.z1
			end
			local cursor = along0
			local intervals = {}
			for _, g in gaps do
				if g[1] > cursor then
					table.insert(intervals, { cursor, math.min(g[1], along1) })
				end
				cursor = math.max(cursor, g[2])
			end
			if cursor < along1 then
				table.insert(intervals, { cursor, along1 })
			end
			for _, iv in intervals do
				local len = iv[2] - iv[1]
				if len > 0.05 then
					local mid = (iv[1] + iv[2]) / 2
					local seg = { room = r.id, side = side }
					if side == "N" then
						seg.cx, seg.cz, seg.sx, seg.sz = mid, r.z0 + t / 2, len, t
					elseif side == "S" then
						seg.cx, seg.cz, seg.sx, seg.sz = mid, r.z1 - t / 2, len, t
					elseif side == "W" then
						seg.cx, seg.cz, seg.sx, seg.sz = r.x0 + t / 2, mid, t, len
					else
						seg.cx, seg.cz, seg.sx, seg.sz = r.x1 - t / 2, mid, t, len
					end
					table.insert(out, seg)
				end
			end
		end
	end
	return out
end

function ManorLayout.roomAt(rooms, x: number, z: number): string?
	for _, r in rooms do
		if x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1 then
			return r.id
		end
	end
	return nil
end

function ManorLayout.centre(room)
	return (room.x0 + room.x1) / 2, (room.z0 + room.z1) / 2
end

-- Clamp a point inside a room (margin studs from its walls).
function ManorLayout.clampInto(room, x: number, z: number, margin: number)
	return math.clamp(x, room.x0 + margin, room.x1 - margin), math.clamp(z, room.z0 + margin, room.z1 - margin)
end

function ManorLayout.neighbours(rooms, doors, roomId: string)
	local out = {}
	for _, d in doors do
		if d.a == roomId then
			table.insert(out, d.b)
		elseif d.b == roomId then
			table.insert(out, d.a)
		end
	end
	return out
end

-- Waypoints {x, z} from room `from` to room `to` through door centres (BFS = fewest doors).
-- Each door contributes a point `step` studs either side of the opening so walkers pass
-- straight through. Returns {} when from == to, nil when unreachable.
function ManorLayout.route(rooms, doors, from: string, to: string, step: number?)
	if from == to then
		return {}
	end
	local s = step or 3
	local prev = { [from] = false }
	local queue = { from }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		if cur == to then
			break
		end
		for i, d in doors do
			local nxt = if d.a == cur then d.b elseif d.b == cur then d.a else nil
			if nxt and prev[nxt] == nil then
				prev[nxt] = { room = cur, door = i }
				table.insert(queue, nxt)
			end
		end
	end
	if prev[to] == nil then
		return nil
	end
	local chain = {}
	local cur = to
	while prev[cur] do
		table.insert(chain, 1, { from = prev[cur].room, to = cur, door = doors[prev[cur].door] })
		cur = prev[cur].room
	end
	local m = byId(rooms)
	local pts = {}
	for _, link in chain do
		local info = ManorLayout.doorInfo(rooms, link.door)
		local fromRoom = m[link.from]
		local cx, cz = ManorLayout.centre(fromRoom)
		if info.axis == "x" then
			local dir = if cx < info.pos then 1 else -1
			table.insert(pts, { x = info.pos - dir * s, z = info.at })
			table.insert(pts, { x = info.pos + dir * s, z = info.at })
		else
			local dir = if cz < info.pos then 1 else -1
			table.insert(pts, { x = info.at, z = info.pos - dir * s })
			table.insert(pts, { x = info.at, z = info.pos + dir * s })
		end
	end
	return pts
end

return ManorLayout
