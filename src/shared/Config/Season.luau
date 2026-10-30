-- Season 1 (pure data): "Winter Masquerade" - the battle-pass-style track.
-- UPGRADE (v1.1 business pass): a seasonal progression engine is the re-engagement + revenue
-- cadence top Roblox games run on. Tier rewards are cosmetics gated by `seasonTier` in
-- Config/Cosmetics and checked by Logic/Progression.owns, so no extra grant code is needed:
-- reach the tier -> the cosmetic unlocks automatically.
-- INACTIVE while StartsAt == 0: no season XP accrues and the shop hides the pass. Set the
-- dates at Gate 4/5 (unix DAY numbers, i.e. math.floor(os.time() / 86400)).
-- UPGRADE (v1.3): pass holders earn season XP faster (PremiumXpFactor) and unlock the
-- seasonPremium cosmetics (Config/Cosmetics) - more rewards + a faster track, never power.
return {
	Id = "winter-masquerade",
	Name = "Winter Masquerade",
	StartsAt = 0, -- unix day the season begins (0 = not scheduled yet)
	EndsAt = 0, -- unix day the season ends (0 = no end date; XP accrues while active)
	XpPerTier = 250, -- a match earns ~10-90 XP (see Gadgets.Rewards) => tier 10 ≈ 10-25 matches
	TierCount = 10,
	PremiumXpFactor = 1.15, -- v1.3: season-pass XP boost (grind-shortening only)
	PremiumProduct = "SeasonWinter", -- key in Config/Monetization.Products (premium track)
	-- Free-track cosmetic tiers (unlocked by tier for everyone):
	--   tier 2 mask_frost, tier 4 lantern_northern, tier 6 trail_snowfall, tier 8 emote_gift
	-- Premium-track tiers (pass holders, still tier-gated):
	--   tier 1 mask_rime (instant at purchase), tier 3 trail_aurora, tier 5 emote_ice,
	--   tier 7 lantern_solstice, tier 10 mask_winterking
	-- (Config/Cosmetics items with seasonTier / seasonPremium set)
}
