-- Levels, daily streak, season track and shop rules (pure).
local Progression = {}

function Progression.xpToNext(level: number, cfg): number
	return cfg.LevelBase + cfg.LevelStep * (level - 1)
end

-- Level and progress from total XP.
function Progression.levelFor(xp: number, cfg): (number, number, number)
	local level, left = 1, math.max(0, xp)
	while level < cfg.MaxLevel do
		local need = Progression.xpToNext(level, cfg)
		if left < need then
			return level, left, need
		end
		left -= need
		level += 1
	end
	return cfg.MaxLevel, 0, 0
end

-- Daily login: returns newStreak, granted (false when already claimed today).
function Progression.daily(lastDay: number, streak: number, today: number, cycle: number): (number, boolean)
	if lastDay == today then
		return streak, false
	end
	local s = if lastDay == today - 1 then streak + 1 else 1
	if s > cycle then
		s = 1
	end
	return s, true
end

-- Can `data` get cosmetic `c` by spending tokens / reaching a level? Returns ok, why.
function Progression.canBuy(c, data): (boolean, string?)
	if c == nil then
		return false, "unknown"
	end
	if data.Owned[c.id] or c.free then
		return false, "owned"
	end
	if c.tokens == nil then
		return false, "not for tokens"
	end
	if (data.GearTokens or 0) < c.tokens then
		return false, "tokens"
	end
	return true, nil
end

function Progression.owns(c, data, passes: { [string]: boolean }?): boolean
	if c == nil then
		return false
	end
	if c.free or data.Owned[c.id] then
		return true
	end
	if c.level and (data.Level or 1) >= c.level then
		return true
	end
	-- v1.3: premium track items need the season pass; the tier check below still applies
	if c.seasonPremium and not (data.Season and data.Season.Premium) then
		return false
	end
	if c.seasonTier and (data.Season and data.Season.Tier or 0) >= c.seasonTier
		and (c.season == nil or (data.Season and data.Season.Id) == c.season) then
		return true
	end
	if c.pass and passes and passes[c.pass] then
		return true
	end
	return false
end

-- Season track cosmetics reached at `tier` for season `seasonId` (premium-track ones only with
-- the pass). The server copies these into data.Owned so an earned or paid-for season cosmetic
-- is kept for good when the next season resets the track (v1.4 review fix).
function Progression.seasonRewards(items, seasonId: string, tier: number, premium: boolean): { string }
	local out = {}
	for _, c in items do
		if c.seasonTier and c.seasonTier <= tier and (c.season == nil or c.season == seasonId) then
			if premium or not c.seasonPremium then
				table.insert(out, c.id)
			end
		end
	end
	return out
end

-- Finale ring rate: guests inside, Phantoms inside.
function Progression.ringRate(guestsIn: number, phantomsIn: number, cfg): number
	if guestsIn <= 0 then
		return 0
	end
	local r = math.min(cfg.ringRateMax, 1 + cfg.ringRatePerExtraGuest * (guestsIn - 1))
	if phantomsIn > 0 then
		r *= cfg.phantomContest
	end
	return r
end

function Progression.ringNeed(cfg, nightsWon: number): number
	return math.max(10, cfg.ringSeconds - cfg.ringBonusPerNightWon * nightsWon)
end

return Progression
