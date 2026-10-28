-- Carried items (pure data, data-driven: ItemService reads `use`, HUD reads `short`/`color`, bots
-- read `bot`). Everyone can loot every item - a Phantom keeps decoy loot so item counters never
-- give it away - and anyone who LOOKS like a guest (any Guest, or a Phantom by day) may use the
-- items allowed in that phase. Server-validated: phase, state, count, per-item cooldown.
--   cap      carry limit           phases   when it can be used ({} = passive)
--   consume  used up on use        cooldown seconds between uses (server rate limit)
local Items = {}

Items.Order = { "DryCell", "GlowStick", "SmokePellet", "SpringBoots", "ClockworkDecoy", "TripwireBell", "PocketWatch", "CopperWire", "BrassWrench" }

Items.Defs = {
	DryCell = { name = "Dry-cell", short = "CELL", color = "Warm", cap = 3, consume = true, phases = { "Night" }, cooldown = 1, use = "cell",
		hint = "Recharges your lantern +45 s" },
	CopperWire = { name = "Copper wire", short = "WIRE", color = "Copper", cap = 2, consume = false, phases = {}, use = nil,
		hint = "Passive: halves repair time (used up when a repair finishes)" },
	GlowStick = { name = "Glow-stick", short = "GLOW", color = "Glow", cap = 3, consume = true, phases = { "Night" }, cooldown = 2, use = "glow",
		hint = "Drop it: Phantoms nearby glow through walls" },
	BrassWrench = { name = "Brass wrench", short = "WRCH", color = "Brass", cap = 1, consume = false, phases = {}, use = nil,
		hint = "Passive: repairs 40% faster" },
	SmokePellet = { name = "Smoke pellet", short = "SMOK", color = "Smoke", cap = 2, consume = true, phases = { "Night" }, cooldown = 6, use = "smoke",
		hint = "Blink forward in a puff of smoke - can't be tagged for a moment" },
	PocketWatch = { name = "Pocket watch", short = "WTCH", color = "Cream", cap = 1, consume = false, phases = { "Day", "Night" }, cooldown = 30, use = "watch",
		hint = "Day: how many breakers were tampered. Night: dawn ETA + breaker status" },
	TripwireBell = { name = "Tripwire bell", short = "BELL", color = "Bell", cap = 2, consume = true, phases = { "Day", "Night" }, cooldown = 3, use = "bell",
		hint = "Set a bell: it rings for everyone when a Phantom passes at night" },
	SpringBoots = { name = "Spring boots", short = "BOOT", color = "Spring", cap = 2, consume = true, phases = { "Day", "Night" }, cooldown = 4, use = "boots",
		hint = "Short speed burst" },
	ClockworkDecoy = { name = "Clockwork decoy", short = "DCOY", color = "Decoy", cap = 1, consume = true, phases = { "Night" }, cooldown = 5, use = "decoy",
		hint = "Wind up a ticking decoy that lures Phantoms" },
}

-- effect tuning
Items.Wrench = { repairFactor = 0.6 } -- repair time x0.6 (stacks with copper wire)
Items.Smoke = { blink = 12, immuneSeconds = 1.5, cloudSeconds = 4, cloudRadius = 7 }
Items.Watch = { showSeconds = 6 }
Items.Bell = { radius = 7, lifetime = 150, maxAlive = 1, rearmSeconds = 6 }
Items.Boots = { factor = 1.5, seconds = 3 }
Items.Decoy = { lifetime = 10, lureRadius = 45 }

function Items.usableIn(id: string, phase: string): boolean
	local d = Items.Defs[id]
	if not d then
		return false
	end
	for _, p in d.phases do
		if p == phase then
			return true
		end
	end
	return false
end

function Items.caps()
	local c = {}
	for id, d in Items.Defs do
		c[id] = d.cap
	end
	return c
end

function Items.emptyInventory()
	local inv = {}
	for _, id in Items.Order do
		inv[id] = 0
	end
	return inv
end

return Items
