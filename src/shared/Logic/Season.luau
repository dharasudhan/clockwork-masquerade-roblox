-- Season maths (pure, no requires - unit-tested under Lune).
local Season = {}

function Season.active(cfg, today: number): boolean
	if cfg.StartsAt == 0 then
		return false
	end
	if today < cfg.StartsAt then
		return false
	end
	if cfg.EndsAt ~= 0 and today >= cfg.EndsAt then
		return false
	end
	return true
end

-- Tier 1 at 0 XP; each XpPerTier XP advances one tier, capped at TierCount. Date gating
-- (Season.active) decides whether XP accrues at all; the maths itself is date-free.
function Season.tierFor(xp: number, cfg): number
	return math.clamp(math.floor(math.max(0, xp) / cfg.XpPerTier) + 1, 1, cfg.TierCount)
end

-- (tier, xp into tier, xp needed for the next tier) like Progression.levelFor.
function Season.progress(xp: number, cfg): (number, number, number)
	local tier = Season.tierFor(xp, cfg)
	if tier >= cfg.TierCount then
		return tier, 0, 0
	end
	local need = cfg.XpPerTier
	return tier, math.max(0, xp) - (tier - 1) * need, need
end

return Season
