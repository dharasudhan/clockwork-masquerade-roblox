return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Quests = t.load("Logic/Quests")
	local Cfg = t.load("Config/Quests")

	describe("Quests", function()
		it("weekOf buckets 7-day weeks", function()
			expect(Quests.weekOf(0)).to.equal(0)
			expect(Quests.weekOf(6)).to.equal(0)
			expect(Quests.weekOf(7)).to.equal(1)
			expect(Quests.weekOf(69)).to.equal(9)
		end)
		it("pick is deterministic per seed and covers the pool", function()
			local a = Quests.pick(Cfg.DailyPool, Cfg.DailyCount, 42)
			local b = Quests.pick(Cfg.DailyPool, Cfg.DailyCount, 42)
			expect(#a).to.equal(Cfg.DailyCount)
			expect(a[1].id).to.equal(b[1].id)
			expect(a[2].id).to.equal(b[2].id)
			expect(a[3].id).to.equal(b[3].id)
			expect(a[1].progress).to.equal(0)
			expect(a[1].done).to.equal(false)
			local seen = {}
			for day = 0, 20 do
				for _, q in Quests.pick(Cfg.DailyPool, Cfg.DailyCount, day) do
					seen[q.id] = true
				end
			end
			for _, def in Cfg.DailyPool do
				expect(seen[def.id]).to.equal(true)
			end
			-- a different day picks a different set (rotating 3-of-6 cycles)
			local c = Quests.pick(Cfg.DailyPool, Cfg.DailyCount, 43)
			local same = 0
			for i = 1, Cfg.DailyCount do
				if c[i].id == a[i].id then
					same += 1
				end
			end
			expect(same < Cfg.DailyCount).to.equal(true)
		end)
		it("apply progresses and completes exactly once", function()
			local list = Quests.pick(Cfg.DailyPool, Cfg.DailyCount, 0)
			local repair
			for _, q in list do
				if q.stat == "repairs" then
					repair = q
				end
			end
			expect(repair).to.be.ok()
			local gains = { repairs = 1 }
			local e1 = Quests.apply(list, gains)
			expect(repair.progress).to.equal(1)
			expect(repair.done).to.equal(false)
			expect(#e1).to.equal(1)
			expect(e1[1].completed).to.equal(nil)
			local e2 = Quests.apply(list, gains) -- goal 2: completes
			expect(repair.progress).to.equal(2)
			expect(repair.done).to.equal(true)
			expect(e2[1].completed).to.equal(true)
			expect(e2[1].tokens).to.equal(repair.tokens)
			local e3 = Quests.apply(list, gains) -- already done: no event
			expect(#e3).to.equal(0)
			expect(Quests.tokensFrom(e2)).to.equal(repair.tokens)
			expect(Quests.tokensFrom(e1)).to.equal(0)
		end)
		it("apply ignores stats no active quest uses", function()
			local list = Quests.pick(Cfg.DailyPool, Cfg.DailyCount, 0)
			local events = Quests.apply(list, { tags = 99, keys = 99 })
			for _, e in events do
				expect(e.id).never.to.equal("daily_tag") -- only if picked and done; tags goal is 1
			end
		end)
		it("gains maps a match for each role", function()
			local g = Quests.gains({ chests = 3, repairs = 2, tags = 0, exposes = 1, nightsWon = 2, keys = 1, pages = 1 }, true, true)
			expect(g.matches).to.equal(1)
			expect(g.wins).to.equal(1)
			expect(g.chests).to.equal(3)
			expect(g.nights).to.equal(2)
			expect(g.friendMatches).to.equal(1)
			local p = Quests.gains({ chests = 0, repairs = 0, tags = 2, exposes = 0, nightsWon = 1 }, false, false)
			expect(p.wins).to.equal(0)
			expect(p.tags).to.equal(2)
			expect(p.friendMatches).to.equal(0)
		end)
		it("summary encodes progress for the client mirror", function()
			local list = Quests.pick(Cfg.WeeklyPool, Cfg.WeeklyCount, 5)
			list[1].progress = 3
			list[1].done = true
			local s = Quests.summary(list)
			expect(#s).to.equal(Cfg.WeeklyCount)
			expect(string.match(s[1], "^" .. list[1].id .. ":3/%d+:1$")).to.be.ok()
		end)
	end)
end
