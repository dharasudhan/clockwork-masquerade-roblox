-- v1.4.1 Dawn Scatter (pure, unit-tested). At the end of every dawn interlude the clock strikes:
-- every screen goes black for ~2 s, Phantoms lose their shroud and EVERY living participant is
-- moved to a random safe spot in a different room, spread over the floors (B1-2F, not the Tower), so nobody can name
-- the Phantom from where they last saw it at night.
--   * candidates: real rooms only - no stairwells, lift cars, balconies (open railing side) or
--     narrow corridors/landings (< 14 studs: doorways and traffic); spots are inset >= 25% from
--     the walls (doors sit in walls) and keep clear of props, chests and breakers
--   * one person per room while rooms last, never the room they stood in, levels round-robin
--   * deterministic for a seed (own LCG; no math.random, no Random) so tests can pin it
local Scatter = {}

Scatter.MinRoomWidth = 14
-- Floors the scatter uses: B1, Ground, 1st, 2nd/Attic. NOT the Tower: two dead-end rooms up a
-- long stair - stranding a guest there before the finale cost the guests ~20 points of match
-- wins in the 30-match bot sim (43% without the Tower vs 20-30% with it, Oct 30 2026).
Scatter.Levels = { -1, 0, 1, 2 }
Scatter.AvoidRadius = 5 -- studs from a prop / chest / breaker stand point

-- Blackout timing (seconds from the clock strike). The server swaps appearance + positions at
-- SwapAt, well inside the fully-black window [FadeIn, Total - FadeOut] on every client (the
-- teleport replicates after the "blackout" notify, so latency shifts both equally).
Scatter.Timing = { Total = 2.0, FadeIn = 0.45, FadeOut = 0.45, SwapAt = 0.8 }

-- Screen blackness 0..1 at t seconds after the strike (client fade; pure so it is testable).
function Scatter.alpha(t: number, cfg): number
	cfg = cfg or Scatter.Timing
	if t < 0 or t >= cfg.Total then
		return 0
	end
	if t < cfg.FadeIn then
		return t / cfg.FadeIn
	end
	if t > cfg.Total - cfg.FadeOut then
		return math.max(0, (cfg.Total - t) / cfg.FadeOut)
	end
	return 1
end

-- true when the swap happens while the screen is fully black
function Scatter.swapIsHidden(cfg): boolean
	cfg = cfg or Scatter.Timing
	return Scatter.alpha(cfg.SwapAt, cfg) >= 1
end

local function eligible(r): boolean
	if r.stair or r.lift or r.balconyOf then
		return false
	end
	return math.min(r.x1 - r.x0, r.z1 - r.z0) >= Scatter.MinRoomWidth
end
Scatter.eligible = eligible

-- Points to keep clear of: { x, z, level, r }.
function Scatter.avoidPoints(M, Layout)
	local out = {}
	local byId = {}
	for _, r in M.Rooms do
		byId[r.id] = r
	end
	local function add(x, z, level, r)
		table.insert(out, { x = x, z = z, level = level, r = r or Scatter.AvoidRadius })
	end
	for _, s in Layout.chestSpots(M) do
		add(s.x, s.z, s.level)
	end
	for _, b in Layout.breakers(M) do
		add(b.standX, b.standZ, b.level)
	end
	-- v1.6.2: pools - nobody materialises in the water at dawn
	for _, pool in M.Pools or {} do
		local r = byId[pool.room]
		if r then
			add(pool.x, pool.z, r.level, pool.r)
		end
	end
	for _, list in { M.Keys or {}, { M.Projector }, { M.Console } } do
		for _, k in list do
			local r = byId[k.room]
			if r and k.x then
				add(k.x, k.z, r.level, if k.ringRadius then 6 else nil)
			end
		end
	end
	return out
end

-- Candidate rooms with their safe spots: { id, level, y (floor), spots = { {x, z} } }.
-- levels: allow-list of floor levels (default Scatter.Levels; pass false for every floor)
function Scatter.candidates(M, Layout, levels: any?)
	local avoid = Scatter.avoidPoints(M, Layout)
	local allow = nil
	if levels == nil then
		levels = Scatter.Levels
	end
	if levels then
		allow = {}
		for _, l in levels do
			allow[l] = true
		end
	end
	local out = {}
	for _, r in M.Rooms do
		if eligible(r) and (allow == nil or allow[r.level]) then
			local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
			local qx, qz = (r.x1 - r.x0) / 4, (r.z1 - r.z0) / 4
			local spots = {}
			for _, o in { { 0, 0 }, { -qx, -qz }, { qx, qz }, { qx, -qz }, { -qx, qz } } do
				local x, z = cx + o[1], cz + o[2]
				local clear = true
				for _, a in avoid do
					if a.level == r.level and (x - a.x) ^ 2 + (z - a.z) ^ 2 < a.r * a.r then
						clear = false
						break
					end
				end
				if clear then
					table.insert(spots, { x = x, z = z })
				end
			end
			if #spots > 0 then
				table.insert(out, { id = r.id, level = r.level, y = Layout.baseY(M, r), spots = spots })
			end
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

-- Park-Miller LCG -> 0..1 (deterministic per seed)
function Scatter.rng(seed: number)
	local s = math.floor(math.abs(seed)) % 2147483646 + 1
	return function(): number
		s = (s * 16807) % 2147483647
		return (s - 1) / 2147483646
	end
end

-- people: { { id = string, room = string? (where they are now) } }
-- Returns { [id] = { room, level, x, y (floor), z } }.
function Scatter.assign(cands, people, seed: number)
	local rnd = Scatter.rng(seed)
	-- shuffle rooms, then interleave levels so consecutive picks change floor
	local rooms = table.clone(cands)
	for i = #rooms, 2, -1 do
		local j = math.floor(rnd() * i) + 1
		rooms[i], rooms[j] = rooms[j], rooms[i]
	end
	local byLevel, levels = {}, {}
	for _, r in rooms do
		if not byLevel[r.level] then
			byLevel[r.level] = {}
			table.insert(levels, r.level)
		end
		table.insert(byLevel[r.level], r)
	end
	table.sort(levels)
	-- rotate the level order by the seed too
	local rot = math.floor(rnd() * #levels)
	local order = {}
	local k = 1
	while #order < #rooms do
		for li = 1, #levels do
			local lv = levels[((li - 1 + rot) % #levels) + 1]
			local list = byLevel[lv]
			if list[k] then
				table.insert(order, list[k])
			end
		end
		k += 1
	end
	local sorted = table.clone(people)
	table.sort(sorted, function(a, b)
		return tostring(a.id) < tostring(b.id)
	end)
	-- shuffle people too (the id order must not decide who lands where)
	for i = #sorted, 2, -1 do
		local j = math.floor(rnd() * i) + 1
		sorted[i], sorted[j] = sorted[j], sorted[i]
	end
	local used, spotUse, spotBase = {}, {}, {}
	local out = {}
	for _, p in sorted do
		local pick
		for _, r in order do
			if not used[r.id] and r.id ~= p.room then
				pick = r
				break
			end
		end
		if not pick then
			-- more people than rooms: share rooms (still never their own)
			for _, r in order do
				if r.id ~= p.room then
					pick = r
					break
				end
			end
			table.insert(order, table.remove(order, table.find(order, pick) or 1)) -- spread reuse
		end
		if pick then
			used[pick.id] = true
			spotUse[pick.id] = (spotUse[pick.id] or 0) + 1
			local n = #pick.spots
			spotBase[pick.id] = spotBase[pick.id] or math.floor(rnd() * n)
			local s = pick.spots[((spotBase[pick.id] + spotUse[pick.id] - 1) % n) + 1]
			out[p.id] = { room = pick.id, level = pick.level, x = s.x, y = pick.y, z = s.z }
		end
	end
	return out
end

return Scatter
