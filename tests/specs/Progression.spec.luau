return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Progression = t.load("Logic/Progression")
	local Cosmetics = t.load("Config/Cosmetics")

	-- one premium-track cosmetic and one free-track cosmetic (both tier-gated)
	local premItem, freeItem
	for _, kind in { "Mask", "Lantern", "Trail", "Emote" } do
		for _, c in Cosmetics.ofKind(kind) do
			if c.seasonTier then
				if c.seasonPremium and not premItem then
					premItem = c
				elseif not c.seasonPremium and not freeItem then
					freeItem = c
				end
			end
		end
	end
	-- the highest-tier premium cosmetic (for the tier-still-matters case)
	local topPrem
	for _, kind in { "Mask", "Lantern", "Trail", "Emote" } do
		for _, c in Cosmetics.ofKind(kind) do
			if c.seasonPremium and (not topPrem or c.seasonTier > topPrem.seasonTier) then
				topPrem = c
			end
		end
	end

	describe("Progression season premium gate", function()
		it("defines both a free-track and a premium-track season cosmetic", function()
			expect(premItem ~= nil).to.equal(true)
			expect(freeItem ~= nil).to.equal(true)
			expect(premItem.seasonPremium).to.equal(true)
			expect(freeItem.seasonPremium == nil or freeItem.seasonPremium == false).to.equal(true)
		end)
		it("premium items need the pass even at max tier; free items need none", function()
			local noPass = { Owned = {}, Level = 1, Season = { Id = "winter-masquerade", Tier = 10, Premium = false } }
			expect(Progression.owns(premItem, noPass)).to.equal(false)
			local withPass = { Owned = {}, Level = 1, Season = { Id = "winter-masquerade", Tier = premItem.seasonTier, Premium = true } }
			expect(Progression.owns(premItem, withPass)).to.equal(true)
			local freeHolder = { Owned = {}, Level = 1, Season = { Id = "winter-masquerade", Tier = freeItem.seasonTier, Premium = false } }
			expect(Progression.owns(freeItem, freeHolder)).to.equal(true)
		end)
		it("the pass alone is not enough: premium items still need their tier", function()
			local lowTier = { Owned = {}, Level = 1, Season = { Id = "winter-masquerade", Tier = 1, Premium = true } }
			expect(Progression.owns(topPrem, lowTier)).to.equal(false)
			local highTier = { Owned = {}, Level = 1, Season = { Id = "winter-masquerade", Tier = topPrem.seasonTier, Premium = true } }
			expect(Progression.owns(topPrem, highTier)).to.equal(true)
		end)
	end)
end
