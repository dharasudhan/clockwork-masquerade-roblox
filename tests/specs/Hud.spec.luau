return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local HudLayout = t.load("Logic/HudLayout")
	describe("Phone-first HUD layout", function()
		for _, vp in HudLayout.TestViewports do
			it(vp.name .. ": nothing overlaps, off screen, on the jump button or thumbstick", function()
				local L = HudLayout.compute(vp.w, vp.h, vp.touch)
				local problems = HudLayout.validate(L, vp.w, vp.h)
				if #problems > 0 then
					error(table.concat(problems, "; "))
				end
			end)
		end
		it("timer pill is top centre and small on phones", function()
			local L = HudLayout.compute(780, 360, true)
			local r = L.el.Timer
			expect(r.x + r.w / 2).to.be.near(390)
			expect(r.y < 10).to.equal(true)
			expect(r.h <= 24).to.equal(true)
			expect(L.small).to.equal(true)
		end)
		it("touch buttons are at least 60 px", function()
			for _, vp in HudLayout.TestViewports do
				if vp.touch then
					expect(HudLayout.compute(vp.w, vp.h, true).button >= 60).to.equal(true)
				end
			end
		end)
	end)
end
