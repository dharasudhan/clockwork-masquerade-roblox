return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Items = t.load("Config/Items")
	local Style = t.load("Config/Style")
	local N = t.load("Config/Nights")[1]
	describe("Items (data-driven)", function()
		it("9 items: the 3 M1 items + 6 new ones, every one ordered, iconed, capped", function()
			local n = 0
			for id, d in Items.Defs do
				n += 1
				expect(table.find(Items.Order, id)).to.be.ok()
				expect(#d.short <= 4).to.equal(true)
				expect(Style.Palette[d.color]).to.be.ok()
				expect(d.cap >= 1).to.equal(true)
				expect(type(d.hint)).to.equal("string")
				for _, p in d.phases do
					expect(p == "Day" or p == "Night").to.equal(true)
				end
				if #d.phases > 0 then
					expect(type(d.use)).to.equal("string")
					expect(d.cooldown and d.cooldown > 0).to.equal(true) -- every usable item is rate limited
				end
			end
			expect(n).to.equal(9)
			expect(#Items.Order).to.equal(9)
			for _, id in { "BrassWrench", "SmokePellet", "PocketWatch", "TripwireBell", "SpringBoots", "ClockworkDecoy" } do
				expect(Items.Defs[id]).to.be.ok()
			end
		end)
		it("phase rules: night-only escape items, day+night utility items, passives never usable", function()
			expect(Items.usableIn("SmokePellet", "Night")).to.equal(true)
			expect(Items.usableIn("SmokePellet", "Day")).to.equal(false)
			expect(Items.usableIn("SpringBoots", "Day")).to.equal(true)
			expect(Items.usableIn("BrassWrench", "Night")).to.equal(false)
			expect(Items.usableIn("CopperWire", "Night")).to.equal(false)
			expect(Items.usableIn("Nope", "Night")).to.equal(false)
		end)
		it("every item can drop from chests; the wrench speeds repairs", function()
			for id in Items.Defs do
				local found = false
				for _, e in N.loot do
					found = found or e.id == id
				end
				expect(found).to.equal(true)
			end
			expect(Items.Wrench.repairFactor < 1).to.equal(true)
			expect(Items.Boots.factor > 1).to.equal(true)
			local inv = Items.emptyInventory()
			expect(inv.ClockworkDecoy).to.equal(0)
		end)
	end)
end
