return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Loot = t.load("Logic/Loot")
	local N = t.load("Config/Nights")[1]
	local G = t.load("Config/Gadgets")
	local Manor = t.load("Config/Manor")
	describe("Loot + chests", function()
		it("rolls follow the weights", function()
			expect(Loot.roll(N.loot, 0)).to.equal("DryCell")
			expect(Loot.roll(N.loot, 0.49)).to.equal("DryCell")
			expect(Loot.roll(N.loot, 0.55)).to.equal("CopperWire")
			expect(Loot.roll(N.loot, 0.95)).to.equal("GlowStick")
			expect(Loot.roll(N.loot, 0.99999)).to.equal("GlowStick")
		end)
		it("stocks distinct chest spots", function()
			for _ = 1, 30 do
				local picks = Loot.pickSpots(#Manor.ChestSpots, N.chestCount, math.random)
				expect(#picks).to.equal(N.chestCount)
				local seen = {}
				for _, i in picks do
					expect(seen[i]).to.equal(nil)
					expect(i >= 1 and i <= #Manor.ChestSpots).to.equal(true)
					seen[i] = true
				end
			end
		end)
		it("carry caps hold", function()
			local inv = {}
			for _ = 1, 10 do
				Loot.add(inv, "DryCell", G.Inventory.caps)
			end
			expect(inv.DryCell).to.equal(G.Inventory.caps.DryCell)
			expect(Loot.add(inv, "Nope", G.Inventory.caps)).to.equal(false)
			expect(Loot.take(inv, "DryCell")).to.equal(true)
			expect(Loot.take(inv, "GlowStick")).to.equal(false)
		end)
	end)
end
