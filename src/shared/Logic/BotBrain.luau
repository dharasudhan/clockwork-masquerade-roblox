-- Bot decisions (pure). The server builds a small world view; the brain returns one decision:
--   { action = "move" | "open" | "tamper" | "repair" | "tag" | "slick" | "flicker" | "idle",
--     x, y, z (move target), id (chest / breaker / guest / decoy), lantern (bool), aimX, aimZ,
--     item (an item id to use this tick), itemDir {x, z} (smoke blink direction) }
-- me = { id, x, y, z, state, battery, inv = { [itemId] = n }, slickReady, flickerReady, itemReady }
-- w  = { phase, timeLeft, guests = {{id,x,y,z}}, phantoms = {{id,x,y,z}}, decoys = {{id,x,y,z}},
--        chests = {{id,x,y,z}}, breakers = {{id,x,y,z,tampered}}, tampersLeft, room,
--        fleeSpots = {{x,y,z}}, guestsInRoom }
-- Distances are level-aware: flat distance + cfg.FloorCost per stud of height difference (a
-- guest one floor up is "far" even when it is right overhead).
local BotBrain = {}

local function d3(a, b, floorCost: number?)
	local dx, dz = a.x - b.x, a.z - b.z
	local dy = math.abs((a.y or 0) - (b.y or 0))
	return math.sqrt(dx * dx + dz * dz) + dy * (floorCost or 2.5)
end
BotBrain.dist = d3

local function nearest(me, list, filter, fc)
	local best, bd = nil, math.huge
	for _, e in list do
		if filter == nil or filter(e) then
			local dd = d3(me, e, fc)
			if dd < bd then
				best, bd = e, dd
			end
		end
	end
	return best, bd
end
BotBrain.nearest = nearest

local function count(list, p, r, exceptId, fc)
	local n = 0
	for _, e in list do
		if e.id ~= exceptId and d3(p, e, fc) <= r then
			n += 1
		end
	end
	return n
end

local function has(me, id): boolean
	return (me.inv and (me.inv[id] or 0) > 0) and (me.itemReady == nil or me.itemReady[id] ~= false)
end
BotBrain.has = has

-- Where to run from a Phantom: straight away (clamped into the current room, w.room) or a
-- neighbouring room, never back past the Phantom, preferring company (other guests' beams).
function BotBrain.fleeTarget(me, threat, w, cfg)
	local fc = cfg.FloorCost
	local dx, dz = me.x - threat.x, me.z - threat.z
	local l = math.sqrt(dx * dx + dz * dz)
	if l < 0.01 then
		dx, dz, l = 1, 0, 1
	end
	dx, dz = dx / l, dz / l
	local cands = {}
	local ax, az = me.x + dx * 18, me.z + dz * 18
	if w.room then
		ax = math.clamp(ax, w.room.x0 + 3, w.room.x1 - 3)
		az = math.clamp(az, w.room.z0 + 3, w.room.z1 - 3)
	end
	table.insert(cands, { x = ax, y = me.y, z = az })
	for _, s in w.fleeSpots or {} do
		table.insert(cands, s)
	end
	local function pass(c)
		local vx, vz = c.x - me.x, c.z - me.z
		local len2 = vx * vx + vz * vz
		if len2 < 1e-6 then
			return d3(me, threat, fc)
		end
		local t = math.clamp(((threat.x - me.x) * vx + (threat.z - me.z) * vz) / len2, 0, 1)
		return d3({ x = me.x + vx * t, y = me.y, z = me.z + vz * t }, threat, fc)
	end
	local function pick(allowToward)
		local best, bs = nil, -math.huge
		for _, c in cands do
			local vx, vz = c.x - me.x, c.z - me.z
			local toward = vx * (threat.x - me.x) + vz * (threat.z - me.z) > 0
			local gain = d3(c, threat, fc) - d3(me, threat, fc)
			local score = gain + 4 * count(w.guests, c, cfg.GroupRadius, me.id, fc)
			if toward then
				score -= if allowToward then 0 else 40
			end
			if allowToward and pass(c) < 5 then
				score -= 60 -- would run into its arms
			end
			if d3(c, me, fc) < 2 then
				score -= 25 -- already here
			end
			if score > bs then
				best, bs = c, score
			end
		end
		return best, bs
	end
	local best = pick(false)
	if best == nil or d3(best, threat, fc) - d3(me, threat, fc) < 5 then
		local dodge = pick(true)
		if dodge then
			best = dodge
		end
	end
	return best
end

local function moveTo(out, t, exact)
	out.action, out.x, out.y, out.z, out.exact = "move", t.x, t.y, t.z, exact
	return out
end

-- day helpers shared by guests and disguised Phantoms (items that blend in)
local function dayItems(me, w, out, cfg, target, td)
	if has(me, "SpringBoots") and target and td > cfg.BootsDistance then
		out.item = "SpringBoots"
	elseif has(me, "PocketWatch") and (w.timeLeft or math.huge) < cfg.WatchDaySeconds then
		out.item = "PocketWatch"
	end
end

function BotBrain.guest(me, w, cfg, gadgets, night)
	local fc = cfg.FloorCost
	local out = { action = "idle", lantern = false }
	if me.battery < 8 and has(me, "DryCell") and w.phase == "Night" then
		out.item = "DryCell"
	end
	if w.phase == "Day" then
		local chest, cd = nearest(me, w.chests, nil, fc)
		if chest then
			dayItems(me, w, out, cfg, chest, cd)
			if cd <= cfg.OpenRange - 1 and math.abs((chest.y or 0) - (me.y or 0)) < 6 then
				out.action, out.id = "open", chest.id
			else
				moveTo(out, chest)
			end
			return out
		end
		-- no chests left: wait by a breaker (guards it), set a tripwire bell there
		local b, bd = nearest(me, w.breakers, nil, fc)
		if b then
			if bd <= cfg.StandRange + 2 and has(me, "TripwireBell") and not out.item then
				out.item = "TripwireBell"
			end
			moveTo(out, b)
		end
		return out
	end
	-- Night
	local threat, td = nearest(me, w.phantoms, nil, fc)
	if threat and td <= cfg.FleeRadius then
		out.lantern = me.battery > 0
		out.aimX, out.aimZ = threat.x, threat.z
		if td <= cfg.PanicRadius or me.battery <= 0 then
			if not out.item then
				if has(me, "SmokePellet") and td <= cfg.SmokeRadius then
					local dx, dz = me.x - threat.x, me.z - threat.z
					out.item, out.itemDir = "SmokePellet", { x = dx, z = dz }
				elseif has(me, "ClockworkDecoy") then
					out.item = "ClockworkDecoy"
				elseif has(me, "SpringBoots") then
					out.item = "SpringBoots"
				end
			end
			local best = BotBrain.fleeTarget(me, threat, w, cfg)
			if best then
				moveTo(out, best)
			end
		end
		return out
	end
	if not out.item and has(me, "PocketWatch") then
		out.item = "PocketWatch"
	end
	local broken, bd = nearest(me, w.breakers, function(b)
		return b.tampered
	end, fc)
	if broken then
		if bd <= cfg.StandRange then
			out.action, out.id = "repair", broken.id
			if not out.item and has(me, "TripwireBell") then
				out.item = "TripwireBell"
			end
		else
			moveTo(out, broken, true)
			if not out.item and has(me, "SpringBoots") and bd > cfg.BootsDistance then
				out.item = "SpringBoots"
			end
		end
		return out
	end
	-- nothing to fix: stick with the group
	local mate, md = nearest(me, w.guests, function(g)
		return g.id ~= me.id
	end, fc)
	if mate and md > cfg.GroupRadius * 0.6 then
		moveTo(out, mate)
	end
	return out
end

function BotBrain.phantom(me, w, cfg, gadgets, night)
	local fc = cfg.FloorCost
	local out = { action = "idle", lantern = false }
	if w.phase == "Day" then
		if (w.tampersLeft or 0) > 0 then
			-- careful while there is time; bold in the last BoldSeconds of the day
			local bold = (w.timeLeft or math.huge) <= cfg.BoldSeconds
			local b, bd = nearest(me, w.breakers, function(b)
				return not b.tampered and (bold or count(w.guests, b, cfg.WatchRadius, nil, fc) == 0)
			end, fc)
			if b then
				dayItems(me, w, out, cfg, b, bd)
				if bd <= cfg.StandRange then
					out.action, out.id = "tamper", b.id
					out.item = nil
				else
					moveTo(out, b, true)
				end
				return out
			end
		end
		-- blend in: search chests like a guest (decoy loot)
		local chest, cd = nearest(me, w.chests, nil, fc)
		if chest then
			dayItems(me, w, out, cfg, chest, cd)
			if cd <= cfg.OpenRange - 1 and math.abs((chest.y or 0) - (me.y or 0)) < 6 then
				out.action, out.id = "open", chest.id
			else
				moveTo(out, chest)
			end
		end
		return out
	end
	-- Night: hunt the most isolated reachable guest; a ticking decoy nearby is irresistible
	local best, bc, bdist = nil, math.huge, math.huge
	for _, g in w.guests do
		local dd = d3(me, g, fc)
		local cost = dd + cfg.IsolationWeight * count(w.guests, g, cfg.GroupRadius, g.id, fc)
		if cost < bc then
			best, bc, bdist = g, cost, dd
		end
	end
	for _, dc in w.decoys or {} do
		local dd = d3(me, dc, fc)
		if dd <= cfg.DecoyLure then
			local cost = dd - cfg.DecoyBonus
			if cost < bc then
				best, bc, bdist = dc, cost, dd
			end
		end
	end
	if best then
		if bdist <= gadgets.Phantom.tagRange - 0.5 then
			out.action, out.id = "tag", best.id
		else
			moveTo(out, best)
		end
	end
	return out
end

function BotBrain.wisp(me, w, cfg, gadgets)
	local fc = cfg.FloorCost
	local out = { action = "idle", lantern = false }
	local g, gd = nearest(me, w.guests, nil, fc)
	if not g then
		return out
	end
	if me.slickReady and gd <= 8 then
		out.action = "slick"
		return out
	end
	if me.flickerReady and (w.guestsInRoom or 0) > 0 then
		out.action = "flicker"
		return out
	end
	return moveTo(out, g)
end

return BotBrain
