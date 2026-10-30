-- v1.6 review specs (Hark): role-safe scoreboard entries, Grotto Baths pool safety for the Dawn
-- Scatter / chests / doors, and every Robux id still 0 (draft, no purchase prompts).
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Score = t.load("Logic/Score")
	local Scatter = t.load("Logic/Scatter")
	local M = t.load("Config/Manor")
	local L = t.load("Logic/ManorLayout")
	local Mon = t.load("Config/Monetization")
	local C = t.load("Config/Cosmetics")
	local Match = t.load("Config/Match")

	describe("v1.6.1 scoreboard entries (role-safe)", function()
		local parts = {
			{ name = "Ann", ribbon = "Crimson", role = "Phantom", state = "Guest", stats = { repairs = 0, chests = 2, tags = 5 } },
			{ name = "Ben", ribbon = "Azure", role = "Guest", state = "Guest", stats = { repairs = 3, chests = 1, tags = 0 } },
			{ name = "Cy", ribbon = "Amber", role = "Guest", state = "Wisp", stats = { repairs = 1, chests = 0, tags = 0 } },
			{ name = "Di", ribbon = "Onyx", role = "Guest", state = "Bubble", stats = {} },
		}
		it("during the match: repairs hidden (only guests repair), state only In play / Wisp", function()
			local e = Score.entriesFor(parts, false)
			expect(#e).to.equal(4)
			for _, x in e do
				expect(x.repairs).to.equal(0)
				expect(x.state == "In play" or x.state == "Wisp").to.equal(true)
			end
			expect(e[1].state).to.equal("In play") -- the Phantom reads exactly like a guest
			expect(e[2].state).to.equal("In play")
			expect(e[3].state).to.equal("Wisp")
			expect(e[4].state).to.equal("Wisp")
			local wire = Score.encode(e)
			expect(string.find(wire, "Phantom", 1, true)).to.equal(nil)
			expect(string.find(wire, "Guest", 1, true)).to.equal(nil)
			-- sorted by chests only while repairs are hidden: Ann (2) first
			expect(Score.decode(wire)[1].name).to.equal("Ann")
		end)
		it("at Results: repairs revealed", function()
			local d = Score.decode(Score.encode(Score.entriesFor(parts, true)))
			expect(d[1].name).to.equal("Ben") -- 3 repairs + 1 chest
			expect(d[1].repairs).to.equal(3)
		end)
		it("tolerates empty / junk participants", function()
			expect(#Score.entriesFor({}, false)).to.equal(0)
			expect(#Score.entriesFor(nil :: any, false)).to.equal(0)
			local e = Score.entriesFor({ {} }, false)
			expect(e[1].name).to.equal("?")
			expect(e[1].chests).to.equal(0)
		end)
	end)

	describe("v1.6.2 Grotto Baths + pool", function()
		local byId = L.byId(M.Rooms)
		local function inBasin(x, z, pool, margin)
			return math.abs(x - pool.x) <= pool.hx + margin and math.abs(z - pool.z) <= pool.hz + margin
		end
		it("the grotto is a B1 room with a pool config that fits inside it", function()
			local g = byId.grotto
			expect(g ~= nil).to.equal(true)
			expect(g.level).to.equal(-1)
			expect(#M.Pools).to.equal(1)
			for _, pool in M.Pools do
				local r = byId[pool.room]
				expect(r ~= nil).to.equal(true)
				-- basin + 0.6 rim stays at least 3 studs off every wall (walkway all round)
				expect(pool.x - pool.hx - 0.6 >= r.x0 + 1 + 3).to.equal(true)
				expect(pool.x + pool.hx + 0.6 <= r.x1 - 1 - 3).to.equal(true)
				expect(pool.z - pool.hz - 0.6 >= r.z0 + 1 + 3).to.equal(true)
				expect(pool.z + pool.hz + 0.6 <= r.z1 - 1 - 3).to.equal(true)
				-- the avoid radius covers the whole basin + rim
				expect(math.sqrt((pool.hx + 0.6) ^ 2 + (pool.hz + 0.6) ^ 2) < pool.r).to.equal(true)
			end
		end)
		it("two doorways in (no dead end), neither opening onto the pool", function()
			local pool = M.Pools[1]
			local n = 0
			for _, d in M.Doors do
				if d.a == "grotto" or d.b == "grotto" then
					n += 1
					local info = L.doorInfo(M, d)
					-- the doorway centre and 4 studs inside the room are dry
					expect(inBasin(info.x, info.z, pool, 0.6)).to.equal(false)
					expect(inBasin(info.x, info.z + 4, pool, 0.6)).to.equal(false)
				end
			end
			expect(n >= 2).to.equal(true)
		end)
		it("Dawn Scatter: the grotto is a valid landing room and no spot is in or near the water", function()
			local found = false
			for _, c in Scatter.candidates(M, L) do
				for _, s in c.spots do
					for _, pool in M.Pools do
						local r = byId[pool.room]
						if c.level == r.level then
							expect((s.x - pool.x) ^ 2 + (s.z - pool.z) ^ 2 >= pool.r * pool.r).to.equal(true)
							expect(inBasin(s.x, s.z, pool, 2)).to.equal(false)
						end
					end
				end
				if c.id == "grotto" then
					found = #c.spots > 0
				end
			end
			expect(found).to.equal(true)
		end)
		it("no chest spot, breaker, key or prop sits in the pool", function()
			local pool = M.Pools[1]
			local lvl = byId[pool.room].level
			for _, s in L.chestSpots(M) do
				if s.level == lvl then
					expect(inBasin(s.x, s.z, pool, 2)).to.equal(false)
				end
			end
			for _, b in L.breakers(M) do
				if b.level == lvl then
					expect(inBasin(b.standX, b.standZ, pool, 2)).to.equal(false)
				end
			end
			for _, list in { M.Keys or {}, { M.Projector }, { M.Console } } do
				for _, k in list do
					expect(k.room ~= pool.room).to.equal(true)
				end
			end
		end)
	end)

	describe("v1.6.3 Robux products stay draft (id 0)", function()
		it("every pass, product and badge id is 0", function()
			for _, p in Mon.Passes do
				expect(p.id).to.equal(0)
			end
			for _, p in Mon.Products do
				expect(p.id).to.equal(0)
			end
			local P = t.load("Config/Progression")
			for _, b in P.Badges or {} do
				expect(b.id or 0).to.equal(0)
			end
		end)
		it("id 0 never resolves to a product (a receipt for it stays unprocessed)", function()
			expect(Mon.productById(0)).to.equal(nil)
		end)
		it("in-match specials are cosmetic only: no tokens, no passes, no gameplay fields", function()
			for _, key in Mon.inMatchProducts() do
				local p = Mon.Products[key]
				expect(p.tokens).to.equal(nil)
				expect(p.season).to.equal(nil)
				expect(p.starter).to.equal(nil)
				for _, g in p.grants or {} do
					local c = C.byId(g)
					expect(c.kind == "Mask" or c.kind == "Lantern" or c.kind == "Trail" or c.kind == "Emote").to.equal(true)
					expect(c.product).to.equal(key)
				end
				expect(type(p.priceDraft)).to.equal("number")
			end
		end)
		it("build label is v1.6.x and the intro phase has a hard cap", function()
			expect(string.sub(Match.Version, 1, 4)).to.equal("v1.6")
			expect(Match.IntroSeconds > 0 and Match.IntroSeconds <= 60).to.equal(true)
		end)
	end)
end
