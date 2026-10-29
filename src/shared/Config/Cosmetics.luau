-- Cosmetics (pure data). COSMETIC ONLY: nothing here changes speed, range, cooldowns or any
-- rule. Kinds: Mask (everyone wears a masquerade mask all match), Lantern (lantern body + beam
-- colour), Trail (sparkle trail while you are an Electro-Wisp), Emote (a short particle burst +
-- emoji above your head). How each is unlocked:
--   free = owned from the start · level = unlocks at that level · tokens = bought with Gear
--   Tokens (earned by playing) · daily = the 7-day login streak reward · product/pass = Robux
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
	-- lanterns
	{ id = "lantern_brass", kind = "Lantern", name = "Brass Lantern", color = "Brass", beam = "Warm", free = true },
	{ id = "lantern_copper", kind = "Lantern", name = "Copper Lantern", color = "Copper", beam = "Amber", level = 3 },
	{ id = "lantern_teal", kind = "Lantern", name = "Teal Arc Lamp", color = "TealDeep", beam = "TealNeon", tokens = 250 },
	{ id = "lantern_moon", kind = "Lantern", name = "Moonbeam", color = "Silver", beam = "SkyBlue", tokens = 450 },
	{ id = "lantern_gold_vip", kind = "Lantern", name = "Golden Lantern (VIP)", color = "Gold", beam = "Gold", pass = "VIP" },
	{ id = "lantern_ember", kind = "Lantern", name = "Ember Lantern", color = "Charcoal", beam = "Crimson", product = "LanternPackEmber" },
	-- wisp trails
	{ id = "trail_spark", kind = "Trail", name = "Spark Trail", color = "Wisp", free = true },
	{ id = "trail_violet", kind = "Trail", name = "Violet Trail", color = "VioletNeon", level = 4 },
	{ id = "trail_gold", kind = "Trail", name = "Gold Dust", color = "Gold", tokens = 200 },
	{ id = "trail_rainbow", kind = "Trail", name = "Rainbow Gears", color = "Pink", product = "TrailPackRainbow" },
	{ id = "trail_vip", kind = "Trail", name = "Inventor's Comet (VIP)", color = "Amber", pass = "VIP" },
	-- emotes
	{ id = "emote_wave", kind = "Emote", name = "Wave", icon = "👋", color = "Cream2", free = true },
	{ id = "emote_bow", kind = "Emote", name = "Bow", icon = "🎩", color = "Brass", level = 2 },
	{ id = "emote_gears", kind = "Emote", name = "Gear Spin", icon = "⚙️", color = "Brass", tokens = 120 },
	{ id = "emote_sparkle", kind = "Emote", name = "Sparkle", icon = "✨", color = "Amber", level = 6 },
	{ id = "emote_confetti", kind = "Emote", name = "Confetti", icon = "🎉", color = "Pink", product = "EmotePackParty" },
	{ id = "emote_dance", kind = "Emote", name = "Clockwork Dance", icon = "🕺", color = "TealNeon", product = "EmotePackParty" },
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
