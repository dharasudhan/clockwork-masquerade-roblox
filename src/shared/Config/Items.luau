-- Carried items (pure data, data-driven: ItemService reads `use`, HUD reads `short`/`color`, bots
-- read `bot`). Everyone can loot every item - a Phantom keeps decoy loot so item counters never
-- give it away - and anyone who LOOKS like a guest (any Guest, or a Phantom by day) may use the
-- items allowed in that phase. Server-validated: phase, state, count, per-item cooldown.
--   cap      carry limit           phases   when it can be used ({} = passive)
--   consume  used up on use        cooldown seconds between uses (server rate limit)
local Items = {}

Items.Order = { "DryCell", "GlowStick", "SmokePellet", "SpringBoots", "ClockworkDecoy", "TripwireBell", "PocketWatch", "CopperWire", "BrassWrench" }

-- icon = a big emoji glyph shown on item chips, the pick-up card and the hotbar (readable by young
-- players); kid = the one-line, very short pick-up description; tip = the inventory tooltip;
-- sfx = the use sound (Config/Audio.Sfx); model = the held/world model (Logic/ItemModels).
Items.Defs = {
	DryCell = { name = "Dry-cell", short = "CELL", icon = "🔋", color = "Warm", cap = 3, consume = true, phases = { "Night" }, cooldown = 1, use = "cell",
		hint = "Recharges your lantern +45 s", kid = "Power for your lantern!", tip = "Night: tap USE to fill your lantern (+45 s of light).", sfx = "Charge", model = "cell" },
	CopperWire = { name = "Copper wire", short = "WIRE", icon = "🧵", color = "Copper", cap = 2, consume = false, phases = {}, use = nil,
		hint = "Passive: halves repair time (used up when a repair finishes)", kid = "Fix breakers twice as fast!", tip = "Just carry it: repairs take half the time. Used up after one repair.", model = "wire" },
	GlowStick = { name = "Glow-stick", short = "GLOW", icon = "🟢", color = "Glow", cap = 3, consume = true, phases = { "Night" }, cooldown = 2, use = "glow",
		hint = "Drop it: Phantoms nearby glow through walls", kid = "Makes hidden Phantoms glow!", tip = "Night: drop it. Phantoms close to it glow through walls for 45 s.", sfx = "Glow", model = "glow" },
	BrassWrench = { name = "Brass wrench", short = "WRCH", icon = "🔧", color = "Brass", cap = 1, consume = false, phases = {}, use = nil,
		hint = "Passive: repairs 40% faster", kid = "Fix things faster!", tip = "Just carry it: every repair is 40% faster. Never used up.", model = "wrench" },
	SmokePellet = { name = "Smoke pellet", short = "SMOK", icon = "💨", color = "Smoke", cap = 2, consume = true, phases = { "Night" }, cooldown = 6, use = "smoke",
		hint = "Blink forward in a puff of smoke - can't be tagged for a moment", kid = "Poof! Zip away from a Phantom!", tip = "Night: jump forward in smoke. Phantoms can't tag you for a moment.", sfx = "Smoke", model = "smoke" },
	PocketWatch = { name = "Pocket watch", short = "WTCH", icon = "⌚", color = "Cream", cap = 1, consume = false, phases = { "Day", "Night" }, cooldown = 30, use = "watch",
		hint = "Day: how many breakers were tampered. Night: dawn ETA + breaker status", kid = "Tells you secret clues!", tip = "Day: how many breakers were broken. Night: when dawn comes and which breakers are down.", sfx = "Tick", model = "watch" },
	TripwireBell = { name = "Tripwire bell", short = "BELL", icon = "🔔", color = "Bell", cap = 2, consume = true, phases = { "Day", "Night" }, cooldown = 3, use = "bell",
		hint = "Set a bell: it rings for everyone when a Phantom passes at night", kid = "Rings when a Phantom sneaks by!", tip = "Set it down. At night it rings and shows on the map when a Phantom walks past.", sfx = "Bell", model = "bell" },
	SpringBoots = { name = "Spring boots", short = "BOOT", icon = "👢", color = "Spring", cap = 2, consume = true, phases = { "Day", "Night" }, cooldown = 4, use = "boots",
		hint = "Short speed burst", kid = "Run super fast!", tip = "Tap USE: run 1.5x faster for 3 s.", sfx = "Boing", model = "boots" },
	ClockworkDecoy = { name = "Clockwork decoy", short = "DCOY", icon = "🧸", color = "Decoy", cap = 1, consume = true, phases = { "Night" }, cooldown = 5, use = "decoy",
		hint = "Wind up a ticking decoy that lures Phantoms", kid = "A ticking toy that tricks Phantoms!", tip = "Night: drop a ticking toy. Phantoms chase it and waste their tag.", sfx = "Tick", model = "decoy" },
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
