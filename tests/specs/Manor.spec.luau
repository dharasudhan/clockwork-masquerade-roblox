return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local ML = t.load("Logic/ManorLayout")
	local Manor = t.load("Config/Manor")
	local Style = t.load("Config/Style")
	describe("Manor layout", function()
		it("every door joins rooms that share an edge and fits inside it", function()
			for _, d in Manor.Doors do
				local info = ML.doorInfo(Manor.Rooms, d)
				expect(info.fits).to.equal(true)
			end
		end)
		it("rooms do not overlap", function()
			for i, a in Manor.Rooms do
				for j, b in Manor.Rooms do
					if i < j then
						local ov = a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1
						expect(ov).to.equal(false)
					end
				end
			end
		end)
		it("every room is reachable from the ballroom", function()
			for _, r in Manor.Rooms do
				expect(ML.route(Manor.Rooms, Manor.Doors, "ballroom", r.id)).to.be.ok()
			end
		end)
		it("walls leave gaps exactly at doors", function()
			local walls = ML.walls(Manor.Rooms, Manor.Doors, Style.WallThickness)
			expect(#walls > 40).to.equal(true)
			for _, d in Manor.Doors do
				local info = ML.doorInfo(Manor.Rooms, d)
				for _, w in walls do
					-- no wall segment covers a door centre
					local inside = math.abs(w.cx - info.x) <= w.sx / 2 - 0.01 and math.abs(w.cz - info.z) <= w.sz / 2 + 1.01
					if info.axis == "z" then
						inside = math.abs(w.cx - info.x) <= w.sx / 2 - 0.01 and math.abs(w.cz - info.z) <= 1.01
					else
						inside = math.abs(w.cz - info.z) <= w.sz / 2 - 0.01 and math.abs(w.cx - info.x) <= 1.01
					end
					expect(inside).to.equal(false)
				end
			end
		end)
		it("breakers, chest spots and spawn are inside rooms; 3 breaker rooms", function()
			expect(#Manor.Breakers).to.equal(3)
			for _, b in Manor.Breakers do
				expect(ML.roomAt(Manor.Rooms, b.x, b.z)).to.equal(b.room)
			end
			for _, c in Manor.ChestSpots do
				expect(ML.roomAt(Manor.Rooms, c.x, c.z)).to.be.ok()
			end
			expect(ML.roomAt(Manor.Rooms, Manor.Spawn.x, Manor.Spawn.z)).to.equal("ballroom")
			expect(ML.roomAt(Manor.Rooms, Manor.Lobby.spawn.x, Manor.Lobby.spawn.z)).to.equal(nil)
		end)
		it("routes pass through doors in order", function()
			local pts = ML.route(Manor.Rooms, Manor.Doors, "ballroom", "boiler")
			expect(#pts).to.equal(4) -- ballroom -> westHall -> boiler
			expect(pts[1].x > pts[2].x).to.equal(true) -- heading west
			expect(ML.route(Manor.Rooms, Manor.Doors, "foyer", "foyer")).to.deepEqual({})
		end)
	end)
end
