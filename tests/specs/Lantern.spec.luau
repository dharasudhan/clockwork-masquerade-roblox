return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Lantern = t.load("Logic/Lantern")
	local G = t.load("Config/Gadgets").Lantern
	local function v(x, y, z)
		return { X = x, Y = y, Z = z }
	end
	describe("Lantern beam", function()
		it("hits inside the cone and range, misses outside", function()
			local o, dir = v(0, 3, 0), v(0, 0, -1)
			expect((Lantern.inCone(o, dir, v(0, 3, -20), G.range, G.halfAngle))).to.equal(true)
			expect((Lantern.inCone(o, dir, v(5, 3, -20), G.range, G.halfAngle))).to.equal(true) -- ~14 deg
			expect((Lantern.inCone(o, dir, v(12, 3, -20), G.range, G.halfAngle))).to.equal(false) -- ~31 deg
			expect((Lantern.inCone(o, dir, v(0, 3, -31), G.range, G.halfAngle))).to.equal(false)
			expect((Lantern.inCone(o, dir, v(0, 3, 10), G.range, G.halfAngle))).to.equal(false)
		end)
		it("slow stacks per beam and is capped", function()
			expect(Lantern.speedFactor(0, G)).to.equal(1)
			expect(Lantern.speedFactor(1, G)).to.be.near(1 - G.slowPerBeam)
			expect(Lantern.speedFactor(2, G)).to.be.near(1 - 2 * G.slowPerBeam)
			expect(Lantern.speedFactor(5, G)).to.be.near(1 - G.slowCap)
		end)
		it("a fully slowed Phantom is slower than a guest; an unslowed one is faster", function()
			local P = t.load("Config/Gadgets").Phantom
			local guest = t.load("Config/Gadgets").Guest.walkSpeed
			expect(P.nightSpeed > guest).to.equal(true)
			expect(P.nightSpeed * Lantern.speedFactor(1, G) < guest).to.equal(true) -- one focused beam lets a guest kite
		end)
		it("battery drains while on, switches off empty, dry-cells recharge to the cap", function()
			local b, on = Lantern.drain(2, 1, true, G)
			expect(b).to.be.near(2 - G.drainPerSecond)
			expect(on).to.equal(true)
			b, on = Lantern.drain(b, 5 / G.drainPerSecond, true, G)
			expect(b).to.equal(0)
			expect(on).to.equal(false)
			expect(Lantern.drain(5, 3, false, G)).to.equal(5)
			expect(Lantern.recharge(0, G)).to.equal(G.dryCellCharge)
			expect(Lantern.recharge(G.batteryMax - 1, G)).to.equal(G.batteryMax)
		end)
		it("rejects bad client aim (NaN, inf, zero, non-numbers)", function()
			expect(Lantern.cleanAim(0 / 0, 0, 1)).to.equal(nil)
			expect(Lantern.cleanAim(math.huge, 0, 1)).to.equal(nil)
			expect(Lantern.cleanAim(0, 0, 0)).to.equal(nil)
			expect(Lantern.cleanAim("1", 0, 0)).to.equal(nil)
			local x, y, z = Lantern.cleanAim(3, 0, 4)
			expect(x).to.be.near(0.6)
			expect(z).to.be.near(0.8)
			expect(y).to.equal(0)
		end)
	end)
end
