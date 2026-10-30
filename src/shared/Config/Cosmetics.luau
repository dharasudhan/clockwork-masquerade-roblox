-- Cosmetics (pure data). COSMETIC ONLY: nothing here changes speed, range, cooldowns or any
-- rule. Kinds: Mask (everyone wears a masquerade mask all match), Lantern (lantern body + beam
-- colour), Trail (sparkle trail while you are an Electro-Wisp), Emote (a short particle burst +
-- emoji above your head). How each is unlocked:
--   free = owned from the start · level = unlocks at that level · tokens = bought with Gear
--   Tokens (earned by playing) · daily = the 7-day login streak reward · seasonTier = the
--   season track (Config/Season; Logic/Season; `season` = the season id it belongs to, so a
--   later season never re-unlocks it) · seasonPremium = on the season track but ONLY
--   for pass holders (still needs the tier; Logic/Progression.owns) · product/pass = Robux
--   (Config/Monetization; placeholder ids until Gate 4/5).
local Cosmetics = {}

Cosmetics.Kinds = { "Mask", "Lantern", "Trail", "Emote" }

Cosmetics.Items = {
	-- masks
	{ id = "mask_brass", kind = "Mask", name = "Brass Masquerade", color = "Brass", free = true },
	{ id = "mask_teal", kind = "Mask", name = "Teal Domino", color = "TealNeon", level = 2 },
	{ id = "mask_rose", kind = "Mask", name = "Rose Filigree", color = "Rose", tokens = 150 },
	{ id = "mask_silver", kind = "Mask", name = "Silver Gearwork", color = "Silver", tokens = 300 },
	{ id = "mask_midnight", kind = "Mask", name = "Midnight Velvet", color = "Navy", level = 5 },
	{ id = "mask_emerald", kind = "Mask", name = "Emerald Clockface", color = "Emerald", tokens = 500 },
	{ id = "mask_aurora", kind = "Mask", name = "Aurora Prism", color = "Violet", daily = 7 },
	{ id = "mask_gold_vip", kind = "Mask", name = "Golden Inventor (VIP)", color = "Gold", pass = "VIP" },
	{ id = "mask_neon_pack", kind = "Mask", name = "Neon Carnival", color = "Pink", product = "MaskPackNeon" },
	-- v1.1: passes + starter + season
	{ id = "mask_founder", kind = "Mask", name = "Founder Clockwork (Sterling Founder)", color = "Gold", pass = "VIPPlus" },
	{ id = "mask_host_laurel", kind = "Mask", name = "Host Laurel (Masquerade Host)", color = "Emerald", pass = "Host" },
	{ id = "mask_starter", kind = "Mask", name = "Guest's Welcome Mask", color = "Copper", product = "StarterPack" },
	{ id = "mask_frost", kind = "Mask", name = "Frost Filigree (Winter Masquerade)", color = "SkyBlue", seasonTier = 2, season = "winter-masquerade" },
	-- v1.3: premium season track (pass holders only, still tier-gated)
	{ id = "mask_rime", kind = "Mask", name = "Rime Regent (Winter Masquerade)", color = "Silver", seasonTier = 1, season = "winter-masquerade", seasonPremium = true }, -- granted + auto-equipped at purchase
	{ id = "mask_winterking", kind = "Mask", name = "Winter King (Winter Masquerade)", color = "Gold", seasonTier = 10, season = "winter-masquerade", seasonPremium = true }, -- tier-10 flex prize
	-- lanterns
	{ id = "lantern_brass", kind = "Lantern", name = "Brass Lantern", color = "Brass", beam = "Warm", free = true },
	{ id = "lantern_copper", kind = "Lantern", name = "Copper Lantern", color = "Copper", beam = "Amber", level = 3 },
	{ id = "lantern_teal", kind = "Lantern", name = "Teal Arc Lamp", color = "TealDeep", beam = "TealNeon", tokens = 250 },
	{ id = "lantern_moon", kind = "Lantern", name = "Moonbeam", color = "Silver", beam = "SkyBlue", tokens = 450 },
	{ id = "lantern_gold_vip", kind = "Lantern", name = "Golden Lantern (VIP)", color = "Gold", beam = "Gold", pass = "VIP" },
	{ id = "lantern_ember", kind = "Lantern", name = "Ember Lantern", color = "Charcoal", beam = "Crimson", product = "LanternPackEmber" },
	{ id = "lantern_starter", kind = "Lantern", name = "Guest's Lamp", color = "Copper", beam = "Amber", product = "StarterPack" },
	{ id = "lantern_northern", kind = "Lantern", name = "Northern Lights (Winter Masquerade)", color = "TealDeep", beam = "TealNeon", seasonTier = 4, season = "winter-masquerade" },
	{ id = "lantern_solstice", kind = "Lantern", name = "Solstice (Winter Masquerade)", color = "Gold", beam = "Gold", seasonTier = 7, season = "winter-masquerade", seasonPremium = true },
	-- v1.6.3: in-match Robux specials (Config/Monetization `inMatch` products). COSMETIC ONLY,
	-- and Phantom-fantasy pieces are day/lobby looks on purpose: a per-player Phantom NIGHT form
	-- or tag effect would out its owner through the v1.4.1 uniform night shroud (even a
	-- Night-3-only form leaks into the Day-3 Expose vote), so none is sold. Deferred idea: a
	-- host-chosen UNIFORM Phantom form for private servers is leak-free (all Phantoms share it).
	{ id = "mask_reaper", kind = "Mask", name = "Phantom Regent", color = "MaskNeon", product = "MaskPackReaper" },
	{ id = "lantern_midnight", kind = "Lantern", name = "Midnight Lantern", color = "Navy", beam = "VioletNeon", product = "LanternPackMidnight" },
	{ id = "trail_phantom", kind = "Trail", name = "Phantom Shimmer", color = "MaskNeon", product = "TrailPackPhantom" },
	{ id = "emote_toast", kind = "Emote", name = "Teacup Toast", icon = "☕", color = "Brass", product = "EmotePackMasquerade" },
	{ id = "emote_applause", kind = "Emote", name = "Applause", icon = "👏", color = "TealNeon", product = "EmotePackMasquerade" },
	-- wisp trails
	{ id = "trail_spark", kind = "Trail", name = "Spark Trail", color = "Wisp", free = true },
	{ id = "trail_violet", kind = "Trail", name = "Violet Trail", color = "VioletNeon", level = 4 },
	{ id = "trail_gold", kind = "Trail", name = "Gold Dust", color = "Gold", tokens = 200 },
	{ id = "trail_rainbow", kind = "Trail", name = "Rainbow Gears", color = "Pink", product = "TrailPackRainbow" },
	{ id = "trail_vip", kind = "Trail", name = "Inventor's Comet (VIP)", color = "Amber", pass = "VIP" },
	{ id = "trail_founder", kind = "Trail", name = "Founder's Halo (Sterling Founder)", color = "Gold", pass = "VIPPlus" },
	{ id = "trail_snowfall", kind = "Trail", name = "Snowfall (Winter Masquerade)", color = "Silver", seasonTier = 6, season = "winter-masquerade" },
	{ id = "trail_aurora", kind = "Trail", name = "Aurora Borealis (Winter Masquerade)", color = "TealNeon", seasonTier = 3, season = "winter-masquerade", seasonPremium = true },
	-- emotes
	{ id = "emote_wave", kind = "Emote", name = "Wave", icon = "👋", color = "Cream2", free = true },
	{ id = "emote_bow", kind = "Emote", name = "Bow", icon = "🎩", color = "Brass", level = 2 },
	{ id = "emote_gears", kind = "Emote", name = "Gear Spin", icon = "⚙️", color = "Brass", tokens = 120 },
	{ id = "emote_sparkle", kind = "Emote", name = "Sparkle", icon = "✨", color = "Amber", level = 6 },
	{ id = "emote_confetti", kind = "Emote", name = "Confetti", icon = "🎉", color = "Pink", product = "EmotePackParty" },
	{ id = "emote_dance", kind = "Emote", name = "Clockwork Dance", icon = "🕺", color = "TealNeon", product = "EmotePackParty" },
	{ id = "emote_founder", kind = "Emote", name = "Founder Salute", icon = "⚜️", color = "Gold", pass = "VIPPlus" },
	{ id = "emote_whistle", kind = "Emote", name = "Party Whistle (Masquerade Host)", icon = "🎺", color = "Brass", pass = "Host" },
	{ id = "emote_gift", kind = "Emote", name = "Gift Box (Winter Masquerade)", icon = "🎁", color = "Rose", seasonTier = 8, season = "winter-masquerade" },
	{ id = "emote_ice", kind = "Emote", name = "Ice Sculpture (Winter Masquerade)", icon = "🧊", color = "SkyBlue", seasonTier = 5, season = "winter-masquerade", seasonPremium = true },
}

Cosmetics.Defaults = { Mask = "mask_brass", Lantern = "lantern_brass", Trail = "trail_spark", Emote = "emote_wave" }

function Cosmetics.byId(id: string)
	for _, c in Cosmetics.Items do
		if c.id == id then
			return c
		end
	end
	return nil
end

function Cosmetics.ofKind(kind: string)
	local out = {}
	for _, c in Cosmetics.Items do
		if c.kind == kind then
			table.insert(out, c)
		end
	end
	return out
end

return Cosmetics
