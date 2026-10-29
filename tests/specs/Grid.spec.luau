return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Grid = t.load("Logic/Grid")
	local N = t.load("Config/Nights")[1]
	describe("Breakers + reboot", function()
		it("only maxTampers (2) breakers can be tampered per night", function()
			local s = Grid.new(N.breakers)
			expect(Grid.tamper(s, "A", N.maxTampers)).to.equal(true)
			expect(Grid.tamper(s, "A", N.maxTampers)).to.equal(false)
			expect(Grid.tamper(s, "B", N.maxTampers)).to.equal(true)
			expect(Grid.tamper(s, "C", N.maxTampers)).to.equal(false)
			expect((Grid.online(s))).to.equal(#N.breakers - 2)
		end)
		it("cooperative repair: fractions add up and bring the breaker back online", function()
			local s = Grid.new(N.breakers)
			Grid.tamper(s, "B", 1)
			expect(Grid.addRepair(s, "B", 0.5)).to.equal(false)
			expect(Grid.addRepair(s, "B", 0.5)).to.equal(true)
			expect((Grid.online(s))).to.equal(#N.breakers)
			expect(Grid.addRepair(s, "C", 1)).to.equal(false) -- not tampered
		end)
		it("all online reaches 100% after rebootFullSeconds, a tampered one slows it", function()
			local s = Grid.new(N.breakers)
			for _ = 1, N.rebootFullSeconds * 10 do
				Grid.stepReboot(s, 0.1, N.rebootFullSeconds)
			end
			expect(s.reboot).to.be.near(100, 0.01)
			local s2 = Grid.new(N.breakers)
			Grid.tamper(s2, "A", 1)
			for _ = 1, N.nightSeconds * 10 do
				Grid.stepReboot(s2, 0.1, N.rebootFullSeconds)
			end
			expect(s2.reboot < 100).to.equal(true) -- never repaired -> the night is lost
		end)
		it("repairing before the deadline still makes dawn; after it does not", function()
			local deadline = Grid.repairDeadline(#N.breakers, N.nightSeconds, N.rebootFullSeconds)
			expect(deadline).to.be.near((N.nightSeconds - N.rebootFullSeconds) * #N.breakers) -- (165 - 135) * 5 = 150
			local function run(repairAt)
				local s = Grid.new(N.breakers)
				Grid.tamper(s, "A", 1)
				for i = 1, N.nightSeconds * 10 do
					if math.abs(i / 10 - repairAt) < 0.05 then
						Grid.addRepair(s, "A", 1)
					end
					Grid.stepReboot(s, 0.1, N.rebootFullSeconds)
				end
				return s.reboot
			end
			expect(run(deadline - 4) >= 100).to.equal(true)
			expect(run(deadline + 6) < 100).to.equal(true)
		end)
		it("two trips: both fixed by ~70 s still makes dawn; both left to 80 s does not", function()
			local function run(at)
				local s = Grid.new(N.breakers)
				Grid.tamper(s, "A", 2)
				Grid.tamper(s, "B", 2)
				for i = 1, N.nightSeconds * 10 do
					if math.abs(i / 10 - at) < 0.05 then
						Grid.addRepair(s, "A", 1)
						Grid.addRepair(s, "B", 1)
					end
					Grid.stepReboot(s, 0.1, N.rebootFullSeconds)
				end
				return s.reboot
			end
			-- budget 150 breaker-seconds over 2 trips = 75 s each
			expect(run(70) >= 100).to.equal(true)
			expect(run(80) < 100).to.equal(true)
		end)
	end)
end
