return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Loot = t.load("Logic/Loot")
	local N = t.load("Config/Nights")[1]
	local Items = t.load("Config/Items")
	local Manor = t.load("Config/Manor")
	local ML = t.load("Logic/ManorLayout")
	local spots = ML.chestSpots(Manor)
	describe("Loot + chests", function()
		it("rolls follow the weights (9 items, every loot id defined)", function()
			local total = 0
			for _, e in N.loot do
				total += e.weight
				expect(Items.Defs[e.id]).to.be.ok()
			end
			expect(#N.loot).to.equal(9)
			expect(Loot.roll(N.loot, 0)).to.equal("DryCell")
			expect(Loot.roll(N.loot, (N.loot[1].weight - 0.5) / total)).to.equal("DryCell")
			expect(Loot.roll(N.loot, (N.loot[1].weight + 0.5) / total)).to.equal("CopperWire")
			expect(Loot.roll(N.loot, 0.99999)).to.equal(N.loot[#N.loot].id)
			local seen = {}
			for i = 0, 999 do
				seen[Loot.roll(N.loot, i / 1000)] = true
			end
			for _, e in N.loot do
				expect(seen[e.id]).to.equal(true)
			end
		end)
		it("stocks distinct chest spots", function()
			for _ = 1, 30 do
				local picks = Loot.pickSpots(#spots, N.chestCount, math.random)
				expect(#picks).to.equal(N.chestCount)
				local seen = {}
				for _, i in picks do
					expect(seen[i]).to.equal(nil)
					expect(i >= 1 and i <= #spots).to.equal(true)
					seen[i] = true
				end
			end
		end)
		it("carry caps hold", function()
			local inv = {}
			for _ = 1, 10 do
				Loot.add(inv, "DryCell", Items.caps())
			end
			expect(inv.DryCell).to.equal(Items.Defs.DryCell.cap)
			expect(Loot.add(inv, "Nope", Items.caps())).to.equal(false)
			expect(Loot.take(inv, "DryCell")).to.equal(true)
			expect(Loot.take(inv, "GlowStick")).to.equal(false)
		end)
	end)
end
