-- Monetization (pure data) - COSMETIC ONLY, no pay-to-win.
-- UPGRADE (v1.1 business pass): expanded from 2 passes / 5 products to 4 passes / 9 products.
--   * Token economy fixed: the old TokenPouch (25 R$ / 150 tokens ≈ 3 matches of play) made the
--     249 R$ 2x pass worthless. New pouches cost more and grant less play-equivalent time, so
--     paying saves ~1-2 hours of grinding, not 20 minutes.
--   * Price ladder: Sterling Founder (599 R$) anchors the top; VIP (199 R$) now reads mid-tier.
--   * First-purchase hook: Guest's Starter Trunk (49 R$, one-time, flag StarterPackBought).
--   * Season 1: Winter Masquerade Pass (399 R$, premium track; see Config/Season).
--   * Private-server lane: Masquerade Host pass for party hosts.
-- Every id is still a PLACEHOLDER (0) until Gate 4/5: a 0 id shows "Coming soon" and never
-- opens a purchase prompt. Prices are DRAFT recommendations in Robux (see store/price-list.md).
local Monetization = {}

-- Game passes (one-time)
Monetization.Passes = {
	VIP = {
		id = 0, priceDraft = 199, name = "VIP Inventor",
		desc = "Golden Inventor mask + Golden Lantern + Inventor's Comet trail + gold name ribbon. Cosmetic only.",
		grants = { "mask_gold_vip", "lantern_gold_vip", "trail_vip" },
	},
	VIPPlus = {
		id = 0, priceDraft = 599, name = "Sterling Founder",
		desc = "Everything in VIP Inventor, plus the Founder Clockwork mask, Founder's Halo trail and Founder Salute emote. Cosmetic only.",
		grants = { "mask_gold_vip", "lantern_gold_vip", "trail_vip", "mask_founder", "trail_founder", "emote_founder" },
	},
	DoubleTokens = {
		id = 0, priceDraft = 249, name = "2x Gear Tokens",
		desc = "Earn double Gear Tokens. Tokens only buy cosmetics, never power.",
		tokenMultiplier = 2,
	},
	Host = {
		id = 0, priceDraft = 129, name = "Masquerade Host",
		desc = "For private-server hosts: Host Laurel mask + Party Whistle emote. Cosmetic only.",
		grants = { "mask_host_laurel", "emote_whistle" },
		privateServer = true, -- recommend pairing with a monthly private-server subscription
	},
}

-- Developer products (repeatable purchases; cosmetic packs grant once and then refund-proof
-- re-grant is a no-op, token pouches add tokens)
Monetization.Products = {
	-- first-purchase conversion hook (one per player; hidden once StarterPackBought)
	StarterPack = {
		id = 0, priceDraft = 49, name = "Guest's Starter Trunk",
		desc = "One-time welcome bundle: Guest's Welcome mask + Guest's Lamp + 100 Gear Tokens.",
		grants = { "mask_starter", "lantern_starter" }, tokens = 100, starter = true,
	},
	-- cosmetics
	MaskPackNeon = { id = 0, priceDraft = 79, name = "Neon Carnival Mask", grants = { "mask_neon_pack" } },
	LanternPackEmber = { id = 0, priceDraft = 79, name = "Ember Lantern", grants = { "lantern_ember" } },
	TrailPackRainbow = { id = 0, priceDraft = 99, name = "Rainbow Gears Trail", grants = { "trail_rainbow" } },
	EmotePackParty = { id = 0, priceDraft = 49, name = "Party Emotes (Confetti + Dance)", grants = { "emote_confetti", "emote_dance" } },
	-- soft currency: ~100 tokens ≈ 5-6 matches of play (old pouch was ~3 matches at 25 R$)
	TokenPouch = { id = 0, priceDraft = 49, name = "Pouch of 100 Gear Tokens", tokens = 100 },
	TokenChest = { id = 0, priceDraft = 99, name = "Chest of 240 Gear Tokens", tokens = 240 }, -- ~20% bonus over 2 pouches
	-- Season 1 premium track (Config/Season; 0 id = season inactive in the shop)
	SeasonWinter = { id = 0, priceDraft = 399, name = "Winter Masquerade Pass", season = "winter-masquerade" },
}

-- Order in the shop's Robux tab (starter first: highest conversion moment is the first session)
Monetization.ShopOrder = {
	"StarterPack", "SeasonWinter", "VIP", "VIPPlus", "DoubleTokens", "Host",
	"MaskPackNeon", "LanternPackEmber", "TrailPackRainbow", "EmotePackParty", "TokenPouch", "TokenChest",
}

function Monetization.productById(id: number)
	if id == 0 then
		return nil
	end
	for key, p in Monetization.Products do
		if p.id == id then
			return key, p
		end
	end
	return nil
end

function Monetization.passById(id: number)
	if id == 0 then
		return nil
	end
	for key, p in Monetization.Passes do
		if p.id == id then
			return key, p
		end
	end
	return nil
end

return Monetization
