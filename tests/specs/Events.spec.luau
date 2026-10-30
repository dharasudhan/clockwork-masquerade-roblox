return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Events = t.load("Logic/Events")
	local Cfg = t.load("Config/Events")

	describe("Manor events", function()
		it("eligibility splits by phase", function()
			local day = Events.eligible(Cfg, "Day")
			local night = Events.eligible(Cfg, "Night")
			expect(#day > 0).to.equal(true)
			expect(#night > 0).to.equal(true)
			for _, id in day do
				expect(Cfg.Defs[id].phase).to.equal("Day")
			end
			for _, id in night do
				expect(Cfg.Defs[id].phase).to.equal("Night")
			end
			expect(#Events.eligible(Cfg, "Lobby")).to.equal(0)
		end)
		it("pick is deterministic in roll and covers the eligible pool", function()
			local seenDay, seenNight = {}, {}
			for i = 0, 50 do
				local d = Events.pick(Cfg, "Day", i / 51)
				local n = Events.pick(Cfg, "Night", i / 51)
				expect(d).to.be.ok()
				expect(n).to.be.ok()
				seenDay[d] = true
				seenNight[n] = true
			end
			for _, id in Events.eligible(Cfg, "Day") do
				expect(seenDay[id]).to.equal(true)
			end
			for _, id in Events.eligible(Cfg, "Night") do
				expect(seenNight[id]).to.equal(true)
			end
			expect(Events.pick(Cfg, "Day", 0)).to.equal(Events.pick(Cfg, "Day", 0.0001))
			expect(Events.pick(Cfg, "Lobby", 0.5)).to.equal(nil)
		end)
		it("scheduleAt stays inside the window", function()
			expect(Events.scheduleAt(Cfg, 0)).to.equal(Cfg.Window.min)
			expect(Events.scheduleAt(Cfg, 1)).to.equal(Cfg.Window.max)
			local mid = Events.scheduleAt(Cfg, 0.5)
			expect(mid > Cfg.Window.min and mid < Cfg.Window.max).to.equal(true)
			expect(Events.scheduleAt(Cfg, -3)).to.equal(Cfg.Window.min)
		end)
	end)
end
