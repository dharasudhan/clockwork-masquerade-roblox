return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Outcome = t.load("Logic/Outcome")
	local function s(o)
		local base = { phase = "Night", guestsTotal = 5, guestsAlive = 3, phantoms = 1, reboot = 40, timeLeft = 30 }
		for k, v in o do
			base[k] = v
		end
		return base
	end
	describe("Win check", function()
		it("no result mid-night", function()
			expect(Outcome.evaluate(s({}))).to.equal(nil)
			expect(Outcome.evaluate(s({ phase = "Lobby", guestsAlive = 0 }))).to.equal(nil)
		end)
		it("Phantoms win when every guest is tagged", function()
			expect(Outcome.evaluate(s({ guestsAlive = 0 })).winner).to.equal("Phantoms")
		end)
		it("Guests win at 100% reboot with a guest untagged", function()
			expect(Outcome.evaluate(s({ reboot = 100 })).winner).to.equal("Guests")
		end)
		it("all tagged beats a full reboot on the same tick", function()
			expect(Outcome.evaluate(s({ reboot = 100, guestsAlive = 0 })).winner).to.equal("Phantoms")
		end)
		it("timer out below 100% -> Phantoms; Phantoms leaving -> Guests", function()
			expect(Outcome.evaluate(s({ timeLeft = 0 })).winner).to.equal("Phantoms")
			expect(Outcome.evaluate(s({ phantoms = 0 })).winner).to.equal("Guests")
			expect(Outcome.evaluate(s({ phase = "Day", phantoms = 0 })).winner).to.equal("Guests")
			expect(Outcome.evaluate(s({ phase = "Day", timeLeft = 0 }))).to.equal(nil) -- day end -> night
		end)
	end)
end
