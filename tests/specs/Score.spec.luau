-- v1.6.1 mid-match scoreboard codec (Logic/Score): sort, encode/decode round-trip, role safety.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Score = t.load("Logic/Score")

	describe("mid-match scoreboard", function()
		it("sorts by repairs+chests desc, name asc tie-break (encode is sorted)", function()
			local s = Score.encode({
				{ name = "Bob", ribbon = "Azure", state = "Guest", repairs = 1, chests = 0 },
				{ name = "Alice", ribbon = "Crimson", state = "Guest", repairs = 2, chests = 1 },
				{ name = "Cleo", ribbon = "Amber", state = "Guest", repairs = 3, chests = 0 },
			})
			local d = Score.decode(s)
			expect(d[1].name).to.equal("Alice") -- 3 points, Alice < Cleo
			expect(d[2].name).to.equal("Cleo")
			expect(d[3].name).to.equal("Bob")
		end)

		it("encode/decode round-trips every field", function()
			local d = Score.decode(Score.encode({
				{ name = "Alice", ribbon = "Crimson", state = "Guest", repairs = 4, chests = 2 },
			}))
			expect(#d).to.equal(1)
			expect(d[1].name).to.equal("Alice")
			expect(d[1].ribbon).to.equal("Crimson")
			expect(d[1].state).to.equal("Guest")
			expect(d[1].repairs).to.equal(4)
			expect(d[1].chests).to.equal(2)
		end)

		it("strips codec separators from names/ribbons and survives empty parts", function()
			local s = Score.encode({
				{ name = "Al|ice~X", ribbon = "Pink", state = "Guest", repairs = 0, chests = 0 },
			})
			local d = Score.decode(s)
			expect(d[1].name).to.equal("AliceX")
			-- trailing/leading empty parts (the gmatch empty-match trap) decode to nothing
			expect(#Score.decode(s .. "|")).to.equal(1)
			expect(#Score.decode("|" .. s)).to.equal(1)
		end)

		it("caps at MaxEntries and tolerates junk input", function()
			local many = {}
			for i = 1, 20 do
				table.insert(many, { name = "P" .. i, ribbon = "Onyx", state = "Guest", repairs = i, chests = 0 })
			end
			expect(#Score.decode(Score.encode(many))).to.equal(Score.MaxEntries)
			expect(#Score.decode(nil)).to.equal(0)
			expect(#Score.decode("")).to.equal(0)
			expect(#Score.decode("|||")).to.equal(0)
			local junk = Score.decode("a~b")
			expect(junk[1].name).to.equal("a")
			expect(junk[1].repairs).to.equal(0)
		end)

		it("role-safe by construction: no role, no tags anywhere in the wire format", function()
			local s = Score.encode({
				{ name = "Alice", ribbon = "Crimson", state = "Guest", repairs = 1, chests = 1, role = "Phantom", tags = 9 } :: any,
			})
			expect(string.find(s, "Phantom", 1, true)).to.equal(nil)
			expect(string.find(s, "9", 1, true)).to.equal(nil)
			-- exactly 5 fields per entry
			local fields = string.split((string.split(s, "|"))[1], "~")
			expect(#fields).to.equal(5)
		end)
	end)
end