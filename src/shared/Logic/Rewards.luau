-- Gear Tokens for one match (pure). stats = { chests, repairs, tags, nightsWon, keys, pages,
-- exposes }. `multiplier` = 2 with the 2x Gear Tokens pass, `coPlay` = the Social.CoPlayTokenFactor
-- from Config/Quests when the match had at least CoPlayMinHumans humans (both applied after the
-- cap; tokens only buy cosmetics). XP = the uncapped base amount (before both multipliers).
local Rewards = {}

function Rewards.tokens(stats, won: boolean, cfg, multiplier: number?, coPlay: number?): (number, number)
	local t = cfg.played
		+ (if won then cfg.win else 0)
		+ (stats.chests or 0) * cfg.perChest
		+ (stats.repairs or 0) * cfg.perRepair
		+ (stats.tags or 0) * cfg.perTag
		+ (stats.nightsWon or 0) * (cfg.nightWon or 0)
		+ (stats.keys or 0) * (cfg.key or 0)
		+ (stats.pages or 0) * (cfg.page or 0)
		+ (stats.exposes or 0) * (cfg.expose or 0)
	local base = math.clamp(math.floor(t), 0, cfg.cap)
	return base * (multiplier or 1) * (coPlay or 1), base
end

return Rewards
