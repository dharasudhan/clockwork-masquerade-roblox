-- Escalation maths (pure, no requires - unit-tested under Lune).
local Escalation = {}

-- Modifiers for match-night `orderIdx` (clamped into the table; repeats the last night).
function Escalation.forNight(cfg, orderIdx: number)
	local t = cfg.Nights[math.clamp(orderIdx, 1, #cfg.Nights)]
	return t or { drainFactor = 1, phantomSpeedBonus = 0, rebootBoost = 1 }
end

-- Last Stand lantern factor for `alive` surviving guests (1 = no effect).
function Escalation.lastStandDrain(cfg, alive: number?): number
	local ls = cfg.LastStand
	local a = alive or math.huge
	if a >= ls.minAlive and a <= ls.aliveAtOrBelow then
		return ls.drainFactor
	end
	return 1
end

-- Last Stand movement bonus (studs/s) for `alive` surviving guests (0 = no effect).
function Escalation.lastStandSpeed(cfg, alive: number?): number
	local ls = cfg.LastStand
	local a = alive or math.huge
	if a >= ls.minAlive and a <= ls.aliveAtOrBelow then
		return ls.speedBonus
	end
	return 0
end

-- Dawn Rush reboot multiplier at reboot fraction `reboot` (1 = no surge yet).
function Escalation.rushBoost(cfg, reboot: number?): number
	if reboot ~= nil and reboot >= cfg.Rush.rebootAt then
		return cfg.Rush.boost
	end
	return 1
end

return Escalation
