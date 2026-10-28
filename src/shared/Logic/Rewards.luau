-- Gear Tokens for one match (pure). stats = { chests, repairs, tags }.
local Rewards = {}

function Rewards.tokens(stats, won: boolean, cfg): number
	local t = cfg.played
		+ (if won then cfg.win else 0)
		+ (stats.chests or 0) * cfg.perChest
		+ (stats.repairs or 0) * cfg.perRepair
		+ (stats.tags or 0) * cfg.perTag
	return math.clamp(math.floor(t), 0, cfg.cap)
end

return Rewards
