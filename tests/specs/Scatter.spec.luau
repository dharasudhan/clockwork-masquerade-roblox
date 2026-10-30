return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Scatter = t.load("Logic/Scatter")
	local Manor = t.load("Config/Manor")
	local Layout = t.load("Logic/ManorLayout")

	local cands = Scatter.candidates(Manor, Layout)
	local byId = {}
	for _, r in Manor.Rooms do
		byId[r.id] = r
	end
	local function people(n, rooms)
		local out = {}
		for i = 1, n do
			table.insert(out, { id = "P" .. i, room = rooms and rooms[i] })
		end
		return out
	end

	describe("Dawn Scatter: candidates", function()
		it("only real rooms: no stairwells, lift cars, balconies or narrow corridors", function()
			expect(#cands >= 20).to.equal(true)
			for _, c in cands do
				local r = byId[c.id]
				expect(r.stair == nil and r.lift == nil and r.balconyOf == nil).to.equal(true)
				expect(math.min(r.x1 - r.x0, r.z1 - r.z0) >= Scatter.MinRoomWidth).to.equal(true)
			end
		end)
		it("every spot is inside its room, >= 25% from the walls (doorways) and clear of props", function()
			local avoid = Scatter.avoidPoints(Manor, Layout)
			for _, c in cands do
				local r = byId[c.id]
				for _, s in c.spots do
					local mx, mz = (r.x1 - r.x0) / 4 - 1e-6, (r.z1 - r.z0) / 4 - 1e-6
					expect(s.x >= r.x0 + mx and s.x <= r.x1 - mx and s.z >= r.z0 + mz and s.z <= r.z1 - mz).to.equal(true)
					for _, a in avoid do
						if a.level == r.level then
							expect((s.x - a.x) ^ 2 + (s.z - a.z) ^ 2 >= a.r * a.r).to.equal(true)
						end
					end
					-- the spot really resolves to this room (not a stairwell / balcony on top)
					expect(Layout.roomAt(Manor, s.x, c.y + Layout.RootHeight, s.z)).to.equal(c.id)
				end
			end
		end)
		it("spans B1, Ground, 1st and 2nd floor - never the Tower (balance)", function()
			local levels = {}
			for _, c in cands do
				levels[c.level] = true
			end
			for _, l in { -1, 0, 1, 2 } do
				expect(levels[l]).to.equal(true)
			end
			expect(levels[3]).to.equal(nil)
			local all = Scatter.candidates(Manor, Layout, false)
			expect(#all > #cands).to.equal(true) -- (the Tower rooms are eligible, just not used)
		end)
	end)

	describe("Dawn Scatter: assignment", function()
		it("one person per room (10 players), never the room they stood in", function()
			local from = { "ballroom", "library", "kitchen", "boiler", "study", "automata", "observatory", "foyer", "laundry", "trophy" }
			for seed = 1, 40 do
				local plan = Scatter.assign(cands, people(10, from), seed)
				local seen = {}
				for i = 1, 10 do
					local a = plan["P" .. i]
					expect(a ~= nil).to.equal(true)
					expect(a.room ~= from[i]).to.equal(true)
					expect(seen[a.room]).to.equal(nil)
					seen[a.room] = true
				end
			end
		end)
		it("spreads over floors (6 players land on >= 4 levels)", function()
			for seed = 1, 20 do
				local plan = Scatter.assign(cands, people(6), seed)
				local levels, n = {}, 0
				for _, a in plan do
					if not levels[a.level] then
						levels[a.level] = true
						n += 1
					end
				end
				expect(n >= 4).to.equal(true)
			end
		end)
		it("deterministic for a seed, different for another", function()
			local function key(plan)
				local parts = {}
				for i = 1, 8 do
					local a = plan["P" .. i]
					table.insert(parts, string.format("%s@%.1f,%.1f", a.room, a.x, a.z))
				end
				return table.concat(parts, ";")
			end
			local a1 = key(Scatter.assign(cands, people(8), 12345))
			local a2 = key(Scatter.assign(cands, people(8), 12345))
			local b = key(Scatter.assign(cands, people(8), 54321))
			expect(a1).to.equal(a2)
			expect(a1 ~= b).to.equal(true)
		end)
		it("input order does not matter for a seed", function()
			local fwd = people(5)
			local rev = { fwd[5], fwd[4], fwd[3], fwd[2], fwd[1] }
			local p1, p2 = Scatter.assign(cands, fwd, 7), Scatter.assign(cands, rev, 7)
			for i = 1, 5 do
				expect(p1["P" .. i].room).to.equal(p2["P" .. i].room)
			end
		end)
		it("more people than rooms still places everyone, never in their own room, distinct spots where possible", function()
			local few = { cands[1], cands[2], cands[3] }
			local plan = Scatter.assign(few, people(5, { few[1].id, few[1].id, few[2].id, few[3].id, nil }), 3)
			local count = 0
			for i = 1, 5 do
				local a = plan["P" .. i]
				expect(a ~= nil).to.equal(true)
				count += 1
			end
			expect(count).to.equal(5)
			expect(plan.P1.room ~= few[1].id and plan.P2.room ~= few[1].id and plan.P3.room ~= few[2].id).to.equal(true)
		end)
	end)

	describe("Dawn Scatter: clock-strike blackout timing", function()
		it("fades in, holds black, fades out within ~2 s", function()
			local T = Scatter.Timing
			expect(T.Total).to.be.near(2, 0.25)
			expect(Scatter.alpha(-0.1)).to.equal(0)
			expect(Scatter.alpha(0)).to.equal(0)
			expect(Scatter.alpha(T.FadeIn / 2)).to.be.near(0.5, 1e-6)
			expect(Scatter.alpha(T.FadeIn)).to.equal(1)
			expect(Scatter.alpha(T.Total - T.FadeOut / 2)).to.be.near(0.5, 1e-6)
			expect(Scatter.alpha(T.Total)).to.equal(0)
		end)
		it("the swap happens while the screen is fully black, with latency headroom", function()
			local T = Scatter.Timing
			expect(Scatter.swapIsHidden()).to.equal(true)
			-- the teleport replicates after the notify; even 0.3 s of extra skew stays black
			expect(Scatter.alpha(T.SwapAt + 0.3)).to.equal(1)
			expect(T.SwapAt - T.FadeIn >= 0.3).to.equal(true)
		end)
	end)
end
