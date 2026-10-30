-- v1.6.1 Hall of Fame logic (Logic/Fame): sorting, clamping, board lines.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Fame = t.load("Logic/Fame")

	describe("Hall of Fame", function()
		it("sorts by wins desc, name asc as the tie-break, and caps at the limit", function()
			local top = Fame.sortTop({
				{ name = "Bob", wins = 3 },
				{ name = "Alice", wins = 7 },
				{ name = "Cleo", wins = 7 },
				{ name = "Dan", wins = 1 },
			}, 3)
			expect(#top).to.equal(3)
			expect(top[1].name).to.equal("Alice") -- 7 wins, Alice < Cleo
			expect(top[2].name).to.equal("Cleo")
			expect(top[3].name).to.equal("Bob")
		end)

		it("does not mutate the input and defaults to MaxRows", function()
			local entries = {}
			for i = 1, 15 do
				table.insert(entries, { name = "P" .. i, wins = 15 - i })
			end
			local before = entries[1].name
			local top = Fame.sortTop(entries)
			expect(#top).to.equal(Fame.MaxRows)
			expect(entries[1].name).to.equal(before)
			expect(#entries).to.equal(15)
		end)

		it("clampName ellipsizes long names and tolerates junk", function()
			expect(Fame.clampName("Short")).to.equal("Short")
			expect(utf8.len(Fame.clampName("AVeryLongDisplayName"))).to.equal(Fame.MaxName) -- "…" is 3 bytes
			expect(Fame.clampName("AVeryLongDisplayName")).to.equal(string.sub("AVeryLongDisplayName", 1, Fame.MaxName - 1) .. "…")
			expect(Fame.clampName(nil)).to.equal("?")
			expect(Fame.clampName("")).to.equal("?")
			expect(Fame.clampName(42)).to.equal("?")
		end)

		it("board lines are rank-padded and ellipsized", function()
			expect(Fame.line(1, "Alice", 12)).to.equal(" 1. Alice — 12")
			expect(Fame.line(10, "Bob", 0)).to.equal("10. Bob — 0")
		end)

		it("lines() numbers the top entries in order and handles empty input", function()
			local lines = Fame.lines({
				{ name = "Bob", wins = 3 },
				{ name = "Alice", wins = 7 },
			})
			expect(#lines).to.equal(2)
			expect(lines[1]).to.equal(" 1. Alice — 7")
			expect(lines[2]).to.equal(" 2. Bob — 3")
			expect(#Fame.lines({})).to.equal(0)
			expect(#Fame.lines(nil)).to.equal(0)
		end)
	end)
end
