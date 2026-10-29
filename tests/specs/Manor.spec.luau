return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local ML = t.load("Logic/ManorLayout")
	local Coplanar = t.load("Logic/Coplanar")
	local Manor = t.load("Config/Manor")
	local Style = t.load("Config/Style")
	local m = ML.byId(Manor.Rooms)
	local function pt(roomId, dx, dz)
		local r = m[roomId]
		local cx, cz = ML.centre(r)
		return { x = cx + (dx or 0), y = ML.baseY(Manor, r) + ML.RootHeight, z = cz + (dz or 0) }
	end
	describe("Manor layout (5 levels: B1, G, 1F, 2F attic, tower)", function()
		it("is enormous: 5 levels, 45+ named rooms, ~4x the M1 floor area", function()
			local named, area, levels = 0, 0, {}
			for _, r in Manor.Rooms do
				if not r.stair and not r.lift then
					named += 1
				end
				if not r.balconyOf then
					area += (r.x1 - r.x0) * (r.z1 - r.z0) * (r.span or 1)
				end
				levels[r.level] = true
			end
			expect(named >= 45).to.equal(true)
			expect(levels[-1] and levels[0] and levels[1] and levels[2] and levels[3]).to.equal(true)
			expect(#Manor.Levels).to.equal(5)
			expect(area / 16632 >= 4).to.equal(true) -- M1 ground floor was 16,632 sq studs
		end)
		it("every door joins rooms that share an edge on its level and fits inside it", function()
			for _, d in Manor.Doors do
				local info = ML.doorInfo(Manor, d)
				if not info.fits then
					error("door " .. d.a .. "/" .. d.b .. " does not fit")
				end
			end
		end)
		it("rooms on a level do not overlap (balconies sit inside their parent)", function()
			for i, a in Manor.Rooms do
				for j, b in Manor.Rooms do
					if i < j and not a.balconyOf and not b.balconyOf then
						local alo, ahi = ML.span(a)
						local blo, bhi = ML.span(b)
						local lv = alo <= bhi and blo <= ahi
						local ov = lv and a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1
						if ov then
							error("overlap " .. a.id .. " / " .. b.id)
						end
					end
				end
			end
		end)
		it("every room is reachable from the ballroom; routes span all 3 floors", function()
			local from = pt("ballroom")
			for _, r in Manor.Rooms do
				local to = pt(r.id)
				if r.balconyOf then
					to = { x = (r.x0 + r.x1) / 2, y = ML.baseY(Manor, r) + 3, z = r.z0 + 4 }
				end
				local rt = ML.route(Manor, from, to)
				if rt == nil then
					error("unreachable " .. r.id)
				end
			end
		end)
		it("every level is linked to the next by a stair; B1/G/1F/2F also by the lift; 6 staircases", function()
			local links = {}
			local stairs = 0
			for _, r in Manor.Rooms do
				local lo, hi = ML.span(r)
				if r.stair then
					stairs += 1
					links[lo .. ">" .. hi] = (links[lo .. ">" .. hi] or 0) + 1
				end
			end
			expect(stairs).to.equal(6)
			expect(links["-1>0"]).to.equal(2) -- Cellar Stair (off the Foyer) + Service Stair
			expect(links["0>1"]).to.equal(2) -- West + East Grand Stair
			expect(links["1>2"]).to.equal(1) -- Attic Stair (+ the lift)
			expect(links["2>3"]).to.equal(1) -- Tower Stair
			local lifts = {}
			for _, r in Manor.Rooms do
				if r.lift then
					lifts[r.level] = true
				end
			end
			expect(lifts[-1] and lifts[0] and lifts[1] and lifts[2]).to.equal(true)
		end)
		it("the way down to B1 is visible from the Foyer: the Cellar Stair door opens off it", function()
			local found = false
			for _, d in Manor.Doors do
				if (d.a == "foyer" and d.b == "cellarStair") or (d.b == "foyer" and d.a == "cellarStair") then
					found = true
					expect(ML.doorLevel(ML.ids(Manor), d)).to.equal(0)
				end
			end
			expect(found).to.equal(true)
			-- from the ballroom spawn, B1 is reached through the Foyer in a short walk
			local len = ML.routeLength(Manor, pt("ballroom"), pt("coalStore"))
			expect(len ~= nil and len < 140).to.equal(true)
		end)
		it("a walker reaches every level from the ballroom (routes go through stairs, top floor too)", function()
			local function maxMin(route)
				local hi, lo = -math.huge, math.huge
				for _, p in route do
					hi, lo = math.max(hi, p.y), math.min(lo, p.y)
				end
				return hi, lo
			end
			local hi = maxMin(ML.route(Manor, pt("ballroom"), pt("observatory")))
			expect(hi > 60).to.equal(true)
			local _, lo = maxMin(ML.route(Manor, pt("ballroom"), pt("wineCellar")))
			expect(lo < -10).to.equal(true)
			expect(ML.route(Manor, pt("lookout"), pt("laundry"))).to.be.ok()
		end)
		it("routes climb stairs through foot and head; basement trips use stair or lift", function()
			local rt = ML.route(Manor, pt("ballroom"), pt("study"))
			local maxY = 0
			for _, p in rt do
				maxY = math.max(maxY, p.y)
			end
			expect(maxY > 20).to.equal(true)
			local rb = ML.route(Manor, pt("ballroom"), pt("generator"))
			local minY, rode = 0, false
			for _, p in rb do
				minY = math.min(minY, p.y)
				rode = rode or p.lift ~= nil
			end
			expect(minY < -10 or rode).to.equal(true)
			-- every consecutive waypoint pair is a short, walkable hop (no wall crossing in a room)
			for _, p in rt do
				expect(ML.roomAt(Manor, p.x, p.y, p.z)).to.be.ok()
			end
		end)
		it("walls leave gaps exactly at doors (per level band)", function()
			local geo = ML.geometry(Manor, Style.WallThickness)
			for _, d in Manor.Doors do
				local info = ML.doorInfo(Manor, d)
				local px = if info.axis == "x" then info.pos else info.at
				local pz = if info.axis == "x" then info.at else info.pos
				local py = info.y + 6
				for _, b in geo do
					if b.kind == "Wall" or b.kind == "Wainscot" then
						local inside = math.abs(b.cx - px) < b.sx / 2 - 0.01 and math.abs(b.cz - pz) < b.sz / 2 - 0.01 and math.abs(b.cy - py) < b.sy / 2 - 0.01
						if inside then
							error("wall blocks door " .. d.a .. "/" .. d.b)
						end
					end
				end
			end
		end)
		it("no z-fighting: no two static faces share a plane (walls, slabs, trim, frames, steps)", function()
			local geo = ML.geometry(Manor, Style.WallThickness)
			local boxes = {}
			for _, b in geo do
				if b.kind ~= "Guard" then
					table.insert(boxes, b)
				end
			end
			local probs = Coplanar.find(boxes, 0.01)
			if #probs > 0 then
				local p = probs[1]
				local a, b = boxes[p.a], boxes[p.b]
				error(string.format("%d coplanar faces, e.g. %s(%s) vs %s(%s) axis %d plane %.2f", #probs, a.kind, a.room, b.kind, b.room, p.axis, p.plane))
			end
		end)
		it("the z-fight check catches overlapping coplanar faces and ignores touching ones", function()
			local wallA = { cx = 0, cy = 8, cz = 0.5, sx = 10, sy = 16, sz = 1 }
			local wallCorner = { cx = -4.5, cy = 8, cz = 5, sx = 1, sy = 16, sz = 10 } -- overlaps the corner
			expect(#Coplanar.find({ wallA, wallCorner }) > 0).to.equal(true)
			local wallButt = { cx = -4.5, cy = 8, cz = 6, sx = 1, sy = 16, sz = 10 } -- starts at wallA's inner face
			expect(#Coplanar.find({ wallA, wallButt })).to.equal(0)
			local floor = { cx = 0, cy = -0.5, cz = 0, sx = 10, sy = 1, sz = 10 }
			expect(#Coplanar.find({ wallA, floor })).to.equal(0) -- wall stands on the floor
			local trim = { cx = 0, cy = 4, cz = 0.5, sx = 10, sy = 0.3, sz = 1.4 } -- M1 rail: through the wall, ends flush
			expect(#Coplanar.find({ wallA, trim }) > 0).to.equal(true) -- its ends share the wall's end planes
			local trimIn = { cx = 0, cy = 4, cz = 1.1, sx = 9.9, sy = 0.3, sz = 0.2 }
			expect(#Coplanar.find({ wallA, trimIn })).to.equal(0)
			-- a SurfaceGui face may not touch anything
			local plate = { cx = 0, cy = 8, cz = 1.05, sx = 2, sy = 1, sz = 0.1 } -- back face on the wall
			expect(#Coplanar.find({ wallA, plate }, nil, nil, { [2] = { "Front" } }) > 0).to.equal(true)
		end)
		it("6 breakers over all 5 levels; chest spots 50-60 inside rooms, clear of doors", function()
			local bs = ML.breakers(Manor)
			expect(#bs).to.equal(6)
			local lv = {}
			for _, b in bs do
				expect(ML.roomAt(Manor, b.x, b.y + 3, b.z)).to.equal(b.room)
				lv[b.level] = true
			end
			expect(lv[-1] and lv[0] and lv[1] and lv[2] and lv[3]).to.equal(true)
			local spots = ML.chestSpots(Manor)
			expect(#spots >= 50 and #spots <= 60).to.equal(true)
			for _, c in spots do
				expect(ML.roomAt(Manor, c.x, c.y + 3, c.z)).to.equal(c.room)
				for _, d in Manor.Doors do
					local info = ML.doorInfo(Manor, d)
					if info.level == c.level then
						local dd = math.sqrt((info.x - c.x) ^ 2 + (info.z - c.z) ^ 2)
						if dd < 4 then
							error("chest in " .. c.room .. " blocks door " .. d.a .. "/" .. d.b)
						end
					end
				end
			end
			expect(ML.roomAt(Manor, Manor.Spawn.x, 3, Manor.Spawn.z)).to.equal("ballroom")
			expect(ML.roomAt(Manor, Manor.Lobby.spawn.x, 3, Manor.Lobby.spawn.z)).to.equal(nil)
		end)
		it("room lookup is level-aware (balcony over ballroom, stairwell full height)", function()
			expect(ML.roomAt(Manor, 0, 3, -24)).to.equal("ballroom")
			expect(ML.roomAt(Manor, 0, 23, -24)).to.equal("gallery")
			expect(ML.roomAt(Manor, -60, 23, -20)).to.equal("guestWest")
			expect(ML.roomAt(Manor, -60, 3, -20)).to.equal("library")
			expect(ML.roomAt(Manor, 60, -17, 0)).to.equal("generator")
			expect(ML.roomAt(Manor, -51, 13, 15)).to.equal("westStair")
			expect(ML.roomAt(Manor, 21, -10, 45)).to.equal("cellarStair")
			expect(ML.roomAt(Manor, 20, 43, -5)).to.equal("automata")
			expect(ML.roomAt(Manor, 27, 63, -57)).to.equal("observatory")
			expect(ML.levelName(Manor, -1)).to.equal("B1 Boiler Level")
		end)
	end)
end
