-- Manor event selection (pure, no requires - unit-tested under Lune). Deterministic in `roll`
-- so the server (seeded RNG) and the tests agree.
local Events = {}

-- Ids eligible in `phase` ("Day" / "Night"), in Config/Events.Order order.
function Events.eligible(cfg, phase: string): { string }
	local out = {}
	for _, id in cfg.Order do
		if cfg.Defs[id].phase == phase then
			table.insert(out, id)
		end
	end
	return out
end

-- Pick one eligible event for `roll` in [0, 1). Returns nil when nothing fits the phase.
function Events.pick(cfg, phase: string, roll: number): string?
	local list = Events.eligible(cfg, phase)
	if #list == 0 then
		return nil
	end
	local i = math.clamp(math.floor((roll or 0) * #list) + 1, 1, #list)
	return list[i]
end

-- Fire moment as a fraction of the phase length, for `roll` in [0, 1).
function Events.scheduleAt(cfg, roll: number): number
	local w = cfg.Window
	return w.min + (w.max - w.min) * math.clamp(roll or 0, 0, 1)
end

return Events
