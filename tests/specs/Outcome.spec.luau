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
		it("3-night match: grid nights 1-2 decide the night only (final = false), the finale ends the match", function()
			local r = Outcome.evaluate(s({ reboot = 100, last = false }))
			expect(r.winner).to.equal("Guests")
			expect(r.final).to.equal(false)
			expect(Outcome.evaluate(s({ timeLeft = 0, last = false })).final).to.equal(false)
			expect(Outcome.evaluate(s({ guestsAlive = 0, last = false })).final).to.equal(false) -- a wipe loses the night
			expect(Outcome.evaluate(s({ phantoms = 0, last = false })).final).to.equal(true) -- Phantoms fled: over
			local f = { kind = "finale", stage = "Showdown", last = true }
			expect(Outcome.evaluate(s(f))).to.equal(nil)
			expect(Outcome.evaluate(s({ kind = "finale", stage = "Showdown", timeLeft = 0 })).winner).to.equal("Phantoms")
			expect(Outcome.evaluate(s({ kind = "finale", stage = "Overdrive", ring = 20, ringNeed = 24 }))).to.equal(nil)
			local win = Outcome.evaluate(s({ kind = "finale", stage = "Overdrive", ring = 24, ringNeed = 24 }))
			expect(win.winner).to.equal("Guests")
			expect(win.final).to.equal(true)
			expect(Outcome.evaluate(s({ kind = "finale", stage = "Overdrive", ring = 5, ringNeed = 24, timeLeft = 0 })).winner).to.equal("Phantoms")
			expect(Outcome.evaluate(s({ kind = "finale", guestsAlive = 0 })).final).to.equal(true)
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
