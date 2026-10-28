return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Roles = t.load("Logic/Roles")
	local Match = t.load("Config/Match")
	describe("Roles", function()
		it("1 Phantom per 5 players: 1 at <= 6, 2 at 7-10", function()
			for n = 2, 6 do
				expect(Roles.phantomCount(n, Match.PhantomTable)).to.equal(1)
			end
			for n = 7, 10 do
				expect(Roles.phantomCount(n, Match.PhantomTable)).to.equal(2)
			end
			expect(Roles.phantomCount(1, Match.PhantomTable)).to.equal(0)
		end)
		it("assigns exactly `count` Phantoms, everyone else a Guest", function()
			local ids = { "a", "b", "c", "d", "e", "f", "g" }
			local roles = Roles.assign(ids, 2, math.random)
			local p, g = 0, 0
			for _, id in ids do
				if roles[id] == "Phantom" then
					p += 1
				elseif roles[id] == "Guest" then
					g += 1
				end
			end
			expect(p).to.equal(2)
			expect(g).to.equal(5)
		end)
		it("last round's Phantoms go to the back of the queue", function()
			local ids = { "a", "b", "c", "d", "e", "f" }
			for _ = 1, 50 do
				local roles = Roles.assign(ids, 1, math.random, { a = true, b = true, c = true, d = true, e = true })
				expect(roles.f).to.equal("Phantom")
			end
		end)
		it("bots fill to the minimum of 6 and never past the max", function()
			expect(Roles.botsNeeded(0, Match.MinPlayers, Match.MaxPlayers)).to.equal(6)
			expect(Roles.botsNeeded(1, 6, 10)).to.equal(5)
			expect(Roles.botsNeeded(6, 6, 10)).to.equal(0)
			expect(Roles.botsNeeded(9, 6, 10)).to.equal(0)
		end)
	end)
end
