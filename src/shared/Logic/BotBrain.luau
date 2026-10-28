-- Bot decisions (pure). The server builds a small world view; the brain returns one decision:
--   { action = "move" | "open" | "tamper" | "repair" | "tag" | "slick" | "flicker" | "idle",
--     x, z (move target), id (chest / breaker / guest), lantern (bool), aimX, aimZ, useCell }
-- me = { id, x, z, state, battery, inv = {DryCell, CopperWire, GlowStick}, slickReady, flickerReady }
-- w  = { phase, guests = {{id,x,z}}, phantoms = {{id,x,z}}, chests = {{id,x,z}},
--        breakers = {{id,x,z,tampered}}, tampersLeft, fleeSpots = {{x,z}}, guestsInRoom }
local BotBrain = {}

local function d(ax, az, bx, bz)
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end
BotBrain.dist = d

local function nearest(me, list, filter)
	local best, bd = nil, math.huge
	for _, e in list do
		if filter == nil or filter(e) then
			local dd = d(me.x, me.z, e.x, e.z)
			if dd < bd then
				best, bd = e, dd
			end
		end
	end
	return best, bd
end
BotBrain.nearest = nearest

local function count(list, x, z, r, exceptId)
	local n = 0
	for _, e in list do
		if e.id ~= exceptId and d(x, z, e.x, e.z) <= r then
			n += 1
		end
	end
	return n
end

-- Where to run from a Phantom: straight away (clamped into the current room, w.room) or a
-- neighbouring room, never back past the Phantom, preferring company (other guests' beams).
function BotBrain.fleeTarget(me, threat, w, cfg)
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
	table.insert(cands, { x = ax, z = az })
	for _, s in w.fleeSpots or {} do
		table.insert(cands, s)
	end
	-- closest the straight run from me to c passes by the Phantom
	local function pass(c)
		local vx, vz = c.x - me.x, c.z - me.z
		local len2 = vx * vx + vz * vz
		if len2 < 1e-6 then
			return d(me.x, me.z, threat.x, threat.z)
		end
		local t = math.clamp(((threat.x - me.x) * vx + (threat.z - me.z) * vz) / len2, 0, 1)
		return d(me.x + vx * t, me.z + vz * t, threat.x, threat.z)
	end
	local function pick(allowToward)
		local best, bs = nil, -math.huge
		for _, c in cands do
			local vx, vz = c.x - me.x, c.z - me.z
			local toward = vx * (threat.x - me.x) + vz * (threat.z - me.z) > 0
			local gain = d(c.x, c.z, threat.x, threat.z) - d(me.x, me.z, threat.x, threat.z)
			local score = gain + 4 * count(w.guests, c.x, c.z, cfg.GroupRadius, me.id)
			if toward then
				score -= if allowToward then 0 else 40
			end
			if allowToward and pass(c) < 5 then
				score -= 60 -- would run into its arms
			end
			if d(c.x, c.z, me.x, me.z) < 2 then
				score -= 25 -- already here
			end
			if score > bs then
				best, bs = c, score
			end
		end
		return best, bs
	end
	local best = pick(false)
	-- cornered (dead-end room, the away point gains nothing): dodge past it to another room
	if best == nil or d(best.x, best.z, threat.x, threat.z) - d(me.x, me.z, threat.x, threat.z) < 5 then
		local dodge = pick(true)
		if dodge then
			best = dodge
		end
	end
	return best
end

function BotBrain.guest(me, w, cfg, gadgets, night)
	local out = { action = "idle", lantern = false }
	if me.battery < 8 and (me.inv.DryCell or 0) > 0 then
		out.useCell = true
	end
	if w.phase == "Day" then
		local chest, cd = nearest(me, w.chests)
		if chest then
			if cd <= cfg.OpenRange - 1 then
				out.action, out.id = "open", chest.id
			else
				out.action, out.x, out.z = "move", chest.x, chest.z
			end
			return out
		end
		local b = nearest(me, w.breakers)
		if b then
			out.action, out.x, out.z = "move", b.x, b.z
		end
		return out
	end
	-- Night
	local threat, td = nearest(me, w.phantoms)
	if threat and td <= cfg.FleeRadius then
		out.lantern = me.battery > 0
		out.aimX, out.aimZ = threat.x, threat.z
		if td <= cfg.PanicRadius or me.battery <= 0 then
			local best = BotBrain.fleeTarget(me, threat, w, cfg)
			if best then
				out.action, out.x, out.z = "move", best.x, best.z
			end
		end
		return out
	end
	local broken, bd = nearest(me, w.breakers, function(b)
		return b.tampered
	end)
	if broken then
		if bd <= cfg.StandRange then
			out.action, out.id = "repair", broken.id
		else
			out.action, out.x, out.z, out.exact = "move", broken.x, broken.z, true
		end
		return out
	end
	-- nothing to fix: stick with the group
	local mate, md = nearest(me, w.guests, function(g)
		return g.id ~= me.id
	end)
	if mate and md > cfg.GroupRadius * 0.6 then
		out.action, out.x, out.z = "move", mate.x, mate.z
	end
	return out
end

function BotBrain.phantom(me, w, cfg, gadgets, night)
	local out = { action = "idle", lantern = false }
	if w.phase == "Day" then
		if (w.tampersLeft or 0) > 0 then
			-- careful while there is time; bold in the last BoldSeconds of the day
			local bold = (w.timeLeft or math.huge) <= cfg.BoldSeconds
			local b, bd = nearest(me, w.breakers, function(b)
				return not b.tampered and (bold or count(w.guests, b.x, b.z, cfg.WatchRadius, nil) == 0)
			end)
			if b then
				if bd <= cfg.StandRange then
					out.action, out.id = "tamper", b.id
				else
					out.action, out.x, out.z, out.exact = "move", b.x, b.z, true
				end
				return out
			end
		end
		-- blend in: search chests like a guest (decoy loot)
		local chest, cd = nearest(me, w.chests)
		if chest then
			if cd <= cfg.OpenRange - 1 then
				out.action, out.id = "open", chest.id
			else
				out.action, out.x, out.z = "move", chest.x, chest.z
			end
		end
		return out
	end
	-- Night: hunt the most isolated reachable guest
	local best, bc, bdist = nil, math.huge, math.huge
	for _, g in w.guests do
		local dd = d(me.x, me.z, g.x, g.z)
		local cost = dd + cfg.IsolationWeight * count(w.guests, g.x, g.z, cfg.GroupRadius, g.id)
		if cost < bc then
			best, bc, bdist = g, cost, dd
		end
	end
	if best then
		if bdist <= gadgets.Phantom.tagRange - 0.5 then
			out.action, out.id = "tag", best.id
		else
			out.action, out.x, out.z = "move", best.x, best.z
		end
	end
	return out
end

function BotBrain.wisp(me, w, cfg, gadgets)
	local out = { action = "idle", lantern = false }
	local g, gd = nearest(me, w.guests)
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
	out.action, out.x, out.z = "move", g.x, g.z
	return out
end

return BotBrain
