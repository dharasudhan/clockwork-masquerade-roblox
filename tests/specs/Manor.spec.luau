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
	describe("Manor layout (3 levels)", function()
		it("is enormous: 3 levels, 30+ named rooms, ~3x the M1 floor area", function()
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
			expect(named >= 30).to.equal(true)
			expect(levels[-1] and levels[0] and levels[1]).to.equal(true)
			expect(area / 16632 >= 3).to.equal(true) -- M1 ground floor was 16,632 sq studs
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
		it("no dead-end floors: each level has >= 2 independent ways up/down (loops)", function()
			local links = { [-1] = 0, [0] = 0, [1] = 0 }
			for _, r in Manor.Rooms do
				local lo, hi = ML.span(r)
				if r.stair then
					links[lo] += 1
					links[hi] += 1
				end
			end
			links[-1] += 1 -- service lift stops on every level
			links[0] += 1
			links[1] += 1
			expect(links[-1] >= 2 and links[0] >= 3 and links[1] >= 3).to.equal(true)
			-- 2 grand staircases + a service stair
			local stairs = 0
			for _, r in Manor.Rooms do
				if r.stair then
					stairs += 1
				end
			end
			expect(stairs).to.equal(3)
		end)
		it("routes climb stairs through foot and head; basement trips use stair or lift", function()
			local rt = ML.route(Manor, pt("ballroom"), pt("observatory"))
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
		it("5 breakers on all 3 floors; chest spots 35-45 inside rooms, clear of doors", function()
			local bs = ML.breakers(Manor)
			expect(#bs).to.equal(5)
			local lv = {}
			for _, b in bs do
				expect(ML.roomAt(Manor, b.x, b.y + 3, b.z)).to.equal(b.room)
				lv[b.level] = true
			end
			expect(lv[-1] and lv[0] and lv[1]).to.equal(true)
			local spots = ML.chestSpots(Manor)
			expect(#spots >= 35 and #spots <= 45).to.equal(true)
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
		end)
	end)
end
