-- Monetization (pure data) - COSMETIC ONLY, no pay-to-win. DRAFT: nothing here is live.
-- Every id is a PLACEHOLDER (0). Creating products, setting prices and listing them is Gate 4/5
-- and needs Murali's explicit yes; then he pastes the real ids here.
-- While an id is 0 the shop shows the item as "Coming soon" and never opens a purchase prompt.
-- Prices are the DRAFT recommendation in Robux (see store/price-list.md).
local Monetization = {}

-- Game passes (one-time)
Monetization.Passes = {
	VIP = {
		id = 0, priceDraft = 199, name = "VIP Inventor",
		desc = "Golden Inventor mask + Golden Lantern + Inventor's Comet trail + gold name ribbon. Cosmetic only.",
		grants = { "mask_gold_vip", "lantern_gold_vip", "trail_vip" },
	},
	DoubleTokens = {
		id = 0, priceDraft = 249, name = "2x Gear Tokens",
		desc = "Earn double Gear Tokens. Tokens only buy cosmetics, never power.",
		tokenMultiplier = 2,
	},
}

-- Developer products (repeatable purchases; cosmetic packs grant once and then refund-proof
-- re-grant is a no-op, token pouches add tokens)
Monetization.Products = {
	MaskPackNeon = { id = 0, priceDraft = 79, name = "Neon Carnival Mask", grants = { "mask_neon_pack" } },
	LanternPackEmber = { id = 0, priceDraft = 79, name = "Ember Lantern", grants = { "lantern_ember" } },
	TrailPackRainbow = { id = 0, priceDraft = 99, name = "Rainbow Gears Trail", grants = { "trail_rainbow" } },
	EmotePackParty = { id = 0, priceDraft = 49, name = "Party Emotes (Confetti + Dance)", grants = { "emote_confetti", "emote_dance" } },
	TokenPouch = { id = 0, priceDraft = 25, name = "Pouch of 150 Gear Tokens", tokens = 150 },
}

-- Order in the shop's Robux tab
Monetization.ShopOrder = { "VIP", "DoubleTokens", "MaskPackNeon", "LanternPackEmber", "TrailPackRainbow", "EmotePackParty", "TokenPouch" }

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
