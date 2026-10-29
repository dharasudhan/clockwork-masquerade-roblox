-- Room dressing for Sterling Manor v1.0: every room gets its own identity from Config/Decor
-- (floor pattern, glass roof / star dome, chandelier colour) plus a furniture kit (library
-- bookcases + ladders, dining table + chairs + candelabra, kitchen stove + counters + copper pots,
-- greenhouse planters under a glass roof, billiard table + cue rack, piano + gramophone, Tesla
-- coils + workbenches, telescope under a star dome, beds + wardrobes, barrels + wine racks,
-- furnace + pipes, ...) and wall art (ArtGui: portraits, landscapes, blueprints, clocks, mirrors,
-- banners, sconces) on door-free stretches, rugs and potted plants.
-- Everything here is non-colliding (walkers and bots never snag) and axis-aligned where it can
-- be, so Logic/Coplanar can prove there is no z-fighting. Wall art is ONE part per piece (the
-- frame is drawn by its SurfaceGui), patterns are a SurfaceGui on an invisible sheet 0.04 above
-- the floor: the part budget stays phone-friendly.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Manor = require(Shared.Config.Manor)
local Decor = require(Shared.Config.Decor)
local Style = require(Shared.Config.Style)
local ManorLayout = require(Shared.Logic.ManorLayout)
local ArtGui = require(Shared.ArtGui)
local Build = require(script.Parent.Build)

local ManorDecor = {}

local T = Style.WallThickness
local LH = Manor.LevelHeight
local M = Enum.Material

local function color(c)
	return ArtGui.rgb(c)
end

local function deco(parent: Instance, name: string, x0, x1, y0, y1, z0, z1, c, material, opts)
	local o = opts or {}
	return Build.part({
		name = name, parent = parent, size = Vector3.new(x1 - x0, y1 - y0, z1 - z0), pos = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		color = color(c), material = material or M.Wood, collide = false, shadow = o.shadow, transparency = o.t,
	})
end
ManorDecor.deco = deco

local function cyl(parent: Instance, name: string, x, y, z, h, d, c, material, vertical: boolean?)
	local cf = if vertical == false then CFrame.new(x, y, z) else CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
	return Build.part({ name = name, parent = parent, shape = Enum.PartType.Cylinder, size = Vector3.new(h, d, d), cf = cf, color = color(c), material = material or M.Metal, collide = false })
end

local function ball(parent: Instance, name: string, x, y, z, d, c, material)
	return Build.part({ name = name, parent = parent, shape = Enum.PartType.Ball, size = Vector3.new(d, d, d), pos = Vector3.new(x, y, z), color = color(c), material = material or M.SmoothPlastic, collide = false, shadow = false })
end

local function neonLight(part: BasePart, c, brightness: number, range: number)
	return Build.light(part, "PointLight", color(c), brightness, range)
end

-- ---- wall bookkeeping -----------------------------------------------------------------------
local reserved: { [string]: { any } } = {}
local function key(r, side)
	return r.id .. ":" .. side
end
local function reserve(r, side, a0, a1)
	local k = key(r, side)
	reserved[k] = reserved[k] or {}
	table.insert(reserved[k], { a0, a1 })
end
ManorDecor.reserve = reserve

local function blocked(r, side)
	local out = {}
	for _, d in Manor.Doors do
		local info = ManorLayout.doorInfo(Manor, d)
		if (d.a == r.id and info.sideA == side) or (d.b == r.id and info.sideB == side) then
			table.insert(out, { d.at - d.width / 2 - 1, d.at + d.width / 2 + 1 })
		end
	end
	local function add(list)
		for _, x in list or {} do
			if x.room == r.id and x.side == side then
				table.insert(out, { x.at - 4, x.at + 4 })
			end
		end
	end
	add(Manor.Breakers)
	add(Manor.Cabinets)
	add({ Manor.EvidenceBoard })
	if r.lift and side == "S" then
		table.insert(out, { r.x0, r.x1 })
	end
	for _, g in reserved[key(r, side)] or {} do
		table.insert(out, g)
	end
	return out
end

local function spanFree(r, side, a0, a1): boolean
	local alongX = side == "N" or side == "S"
	local lo, hi = if alongX then r.x0 + T + 0.5 else r.z0 + T + 0.5, if alongX then r.x1 - T - 0.5 else r.z1 - T - 0.5
	if a0 < lo or a1 > hi then
		return false
	end
	for _, g in blocked(r, side) do
		if a0 < g[2] and a1 > g[1] then
			return false
		end
	end
	return true
end
ManorDecor.spanFree = spanFree

-- axis-aligned box against a wall: `at` along the wall, `w` wide, from `off` to `off + d` into
-- the room, y0..y1 (absolute)
local function wallBox(r, side, at, w, off, d)
	if side == "N" then
		return at - w / 2, at + w / 2, r.z0 + T + off, r.z0 + T + off + d
	elseif side == "S" then
		return at - w / 2, at + w / 2, r.z1 - T - off - d, r.z1 - T - off
	elseif side == "W" then
		return r.x0 + T + off, r.x0 + T + off + d, at - w / 2, at + w / 2
	end
	return r.x1 - T - off - d, r.x1 - T - off, at - w / 2, at + w / 2
end
ManorDecor.wallBox = wallBox

local IntoRoom = { N = Enum.NormalId.Back, S = Enum.NormalId.Front, W = Enum.NormalId.Right, E = Enum.NormalId.Left }
ManorDecor.IntoRoom = IntoRoom

local function wallThing(f, r, side, at, w, off, d, y0, y1, name, c, material)
	local x0, x1, z0, z1 = wallBox(r, side, at, w, off, d)
	return deco(f, name, x0, x1, y0, y1, z0, z1, c, material)
end

-- first free stretch of `len` on a side, trying the middle first; nil when none
local function findSpot(r, side, len)
	local alongX = side == "N" or side == "S"
	local a0, a1 = if alongX then r.x0 else r.z0, if alongX then r.x1 else r.z1
	local mid = (a0 + a1) / 2
	for _, shift in { 0, -6, 6, -12, 12, -18, 18, -24, 24, -30, 30 } do
		local c = mid + shift
		if spanFree(r, side, c - len / 2, c + len / 2) then
			return c
		end
	end
	return nil
end
ManorDecor.findSpot = findSpot

local function longSides(r)
	if (r.x1 - r.x0) >= (r.z1 - r.z0) then
		return { "N", "S", "W", "E" }
	end
	return { "W", "E", "N", "S" }
end

-- ---- wall art ---------------------------------------------------------------------------------
local artSerial = 0
local function artPiece(f, r, side, at, kind, yCentre)
	local s = Decor.ArtSize[kind] or Decor.ArtSize.landscape
	local w, h = s[1], s[2]
	local yc = yCentre or (ManorLayout.baseY(Manor, r) + s[3])
	local x0, x1, z0, z1 = wallBox(r, side, at, w, 0.05, 0.2)
	local p = deco(f, "Art_" .. kind, x0, x1, yc - h / 2, yc + h / 2, z0, z1, if kind == "mirror" then "Silver" else "WalnutDark", if kind == "mirror" then M.Glass else M.Wood)
	p.CastShadow = false
	artSerial += 1
	ArtGui.paint(p, IntoRoom[side], kind, artSerial * 7 + #r.id)
	if kind == "sconce" then
		local bulb = deco(f, "SconceBulb", x0, x1, yc + h / 2 + 0.1, yc + h / 2 + 0.5, z0, z1, "Amber", M.Neon)
		bulb.Transparency = 1
		neonLight(bulb, "Warm", 0.6, 9)
	end
	return p
end

local function dressWalls(f, r, theme)
	local kinds = theme.art or {}
	local count = theme.artCount or 0
	if #kinds == 0 or count == 0 then
		return 0
	end
	local placed = 0
	local base = ManorLayout.baseY(Manor, r)
	local sides = longSides(r)
	local yBase = nil
	if r.stair then
		-- stairwells: only the bottom and top end walls (the side walls are behind the steps)
		local up = r.stair.up
		local bottom = ({ N = "S", S = "N", E = "W", W = "E" })[up]
		sides = { bottom, up }
	end
	local k = 0
	for pass = 1, 3 do
		for _, side in sides do
			if placed >= count then
				return placed
			end
			local alongX = side == "N" or side == "S"
			local a0, a1 = if alongX then r.x0 else r.z0, if alongX then r.x1 else r.z1
			local n = math.max(1, math.floor((a1 - a0) / 11))
			local slot = ((pass - 1) * 3 + placed) % n
			for j = 0, n - 1 do
				local idx = (slot + j) % n
				local at = a0 + (a1 - a0) * (idx + 1) / (n + 1)
				k += 1
				local kind = kinds[(k % #kinds) + 1]
				local s = Decor.ArtSize[kind]
				if spanFree(r, side, at - s[1] / 2 - 0.6, at + s[1] / 2 + 0.6) then
					yBase = nil
					if r.stair and side == r.stair.up then
						yBase = base + LH + s[3]
					end
					artPiece(f, r, side, at, kind, yBase)
					reserve(r, side, at - s[1] / 2 - 0.6, at + s[1] / 2 + 0.6)
					placed += 1
					break
				end
			end
		end
	end
	return placed
end

-- ---- floor patterns, rugs, plants, ceilings -----------------------------------------------------
local function patternSheet(f, r, theme)
	local p = theme.p
	if not p or r.stair or r.balconyOf then
		return
	end
	local b = ManorLayout.baseY(Manor, r)
	local sheet = deco(f, "FloorPattern", r.x0 + T, r.x1 - T, b + 0.03, b + 0.05, r.z0 + T, r.z1 - T, "Ivory", M.SmoothPlastic)
	sheet.Transparency = 1
	sheet.CastShadow = false
	sheet.CanQuery = false
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Pattern"
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 6
	sg.LightInfluence = 1
	sg.MaxDistance = 120
	sg.Parent = sheet
	local w, d = r.x1 - r.x0 - 2 * T, r.z1 - r.z0 - 2 * T
	local function fr(name, x, y, sw, sh, c, t)
		local q = Instance.new("Frame")
		q.Name = name
		q.BorderSizePixel = 0
		q.Position = UDim2.fromScale(x, y)
		q.Size = UDim2.fromScale(sw, sh)
		q.BackgroundColor3 = color(c)
		q.BackgroundTransparency = t or 0
		q.Parent = sg
		return q
	end
	local cell = p.cell or 4
	if p.kind == "checker" then
		local nx, nz = math.min(14, math.max(2, math.floor(w / cell))), math.min(12, math.max(2, math.floor(d / cell)))
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				fr("Cell", i / nx, j / nz, 1 / nx, 1 / nz, if (i + j) % 2 == 0 then p.a else p.b)
			end
		end
	elseif p.kind == "tiles" or p.kind == "grating" then
		fr("Base", 0, 0, 1, 1, p.a, if p.kind == "grating" then 0.35 else 0.15)
		local nx, nz = math.min(30, math.floor(w / cell)), math.min(30, math.floor(d / cell))
		local lw = if p.kind == "grating" then 0.12 else 0.08
		for i = 1, nx - 1 do
			fr("LineX", i / nx, 0, lw / w, 1, p.b)
		end
		for j = 1, nz - 1 do
			fr("LineZ", 0, j / nz, 1, lw / d, p.b)
		end
	elseif p.kind == "carpet" then
		local inset = math.min(1.5, math.min(w, d) * 0.12)
		fr("Border", inset / w, inset / d, 1 - 2 * inset / w, 1 - 2 * inset / d, p.b)
		fr("Field", (inset + 0.6) / w, (inset + 0.6) / d, 1 - 2 * (inset + 0.6) / w, 1 - 2 * (inset + 0.6) / d, p.a)
		local long = w >= d
		if long then
			fr("Stripe", 0.05, 0.5 - 0.15 / d, 0.9, 0.3 / d, p.b, 0.3)
		else
			fr("Stripe", 0.5 - 0.15 / w, 0.05, 0.3 / w, 0.9, p.b, 0.3)
		end
	elseif p.kind == "planks" then
		local long = w >= d
		local n = math.min(40, math.floor((if long then d else w) / cell))
		for i = 0, n - 1 do
			if i % 2 == 1 then
				if long then
					fr("Plank", 0, i / n, 1, 1 / n, p.b, 0.55)
				else
					fr("Plank", i / n, 0, 1 / n, 1, p.b, 0.55)
				end
			end
		end
	end
end

local function rug(f, r, theme, cx, cz, w, d)
	if not theme.rug then
		return
	end
	local b = ManorLayout.baseY(Manor, r)
	local p = deco(f, "Rug", cx - w / 2, cx + w / 2, b + 0.06, b + 0.13, cz - d / 2, cz + d / 2, theme.rug, M.Fabric)
	p.CastShadow = false
	local sg = Instance.new("SurfaceGui")
	sg.Name = "RugPattern"
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 10
	sg.MaxDistance = 80
	sg.Parent = p
	local border = Instance.new("Frame")
	border.Name = "Border"
	border.BackgroundTransparency = 1
	border.Position = UDim2.fromScale(0.06, 0.08)
	border.Size = UDim2.fromScale(0.88, 0.84)
	border.Parent = sg
	local s = Instance.new("UIStroke")
	s.Color = color("Gold")
	s.Thickness = 4
	s.Parent = border
	local medallion = Instance.new("Frame")
	medallion.Name = "Medallion"
	medallion.BorderSizePixel = 0
	medallion.BackgroundColor3 = color("Gold")
	medallion.BackgroundTransparency = 0.3
	medallion.Position = UDim2.fromScale(0.4, 0.35)
	medallion.Size = UDim2.fromScale(0.2, 0.3)
	medallion.Parent = sg
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = medallion
end

local function plant(f, x, z, b, big: boolean?)
	local s = if big then 1.4 else 1
	cyl(f, "PlantPot", x, b + 0.9 * s, z, 1.8 * s, 1.9 * s, "Copper", M.Metal, true)
	ball(f, "Foliage", x, b + 2.9 * s, z, 3.1 * s, "Leaf", M.Grass)
end

local function plants(f, r, theme)
	local n = theme.plants or 0
	if n <= 0 then
		return
	end
	local b = ManorLayout.baseY(Manor, r)
	-- corners 3 and 4 (chest spots use corners 1 and 2), then mid-walls
	local spots = {
		{ r.x1 - T - 2.2, r.z0 + T + 2.2 }, { r.x0 + T + 2.2, r.z1 - T - 2.2 },
		{ r.x0 + T + 2.2, r.z0 + T + 2.2 }, { r.x1 - T - 2.2, r.z1 - T - 2.2 },
	}
	if (r.chests or 0) >= 1 then
		spots[3] = nil
	end
	if (r.chests or 0) >= 2 then
		spots[4] = nil
	end
	local k = 0
	for i = 1, 4 do
		local s = spots[i]
		if s and k < n then
			k += 1
			plant(f, s[1], s[2], b, false)
		end
	end
	return k
end

local function ceilingDress(f, r, theme)
	local top = ManorLayout.topY(Manor, r)
	if theme.glassRoof then
		local n = math.max(1, math.floor((r.x1 - r.x0) / 12))
		for i = 1, n do
			local x = r.x0 + (r.x1 - r.x0) * i / (n + 1)
			deco(f, "Mullion", x - 0.2, x + 0.2, top - 0.45, top - 0.05, r.z0 + T + 0.3, r.z1 - T - 0.3, "Iron", M.Metal)
		end
	end
	if theme.stars then
		local cx, cz = ManorLayout.centre(r)
		for k = 1, 9 do
			local a = k * 0.7
			local star = ball(f, "Star", cx + math.cos(a) * (3 + k), top - 0.5 - (k % 3) * 0.25, cz + math.sin(a) * (2 + k * 0.9), 0.45, "Cream2", M.Neon)
			star.CastShadow = false
		end
	end
end

-- ---- kits ---------------------------------------------------------------------------------
local Kits = {}

local function chair(f, x, z, b, face: string, c)
	-- seat + back (back on the side away from `face`)
	deco(f, "ChairSeat", x - 0.9, x + 0.9, b + 1.5, b + 1.8, z - 0.9, z + 0.9, c or "Mahogany")
	deco(f, "ChairLeg", x - 0.15, x + 0.15, b, b + 1.5, z - 0.15, z + 0.15, "WalnutDark")
	local bx0, bx1, bz0, bz1 = x - 0.9, x + 0.9, z - 0.9, z + 0.9
	if face == "E" then
		bx0, bx1 = x - 0.9, x - 0.65
	elseif face == "W" then
		bx0, bx1 = x + 0.65, x + 0.9
	elseif face == "S" then
		bz0, bz1 = z - 0.9, z - 0.65
	else
		bz0, bz1 = z + 0.65, z + 0.9
	end
	deco(f, "ChairBack", bx0, bx1, b + 1.8, b + 4, bz0, bz1, c or "Mahogany")
end

local function tableAt(f, x, z, b, w, d, top, legs, h)
	local ht = h or 2.8
	deco(f, "TableTop", x - w / 2, x + w / 2, b + ht, b + ht + 0.35, z - d / 2, z + d / 2, top or "Walnut")
	deco(f, "TableBase", x - w / 2 + 0.6, x + w / 2 - 0.6, b, b + ht, z - d / 2 + 0.55, z + d / 2 - 0.55, legs or "WalnutDark")
end

local function bookcase(f, r, side, at, w, b, h)
	local x0, x1, z0, z1 = wallBox(r, side, at, w, 0.1, 1.3)
	deco(f, "Bookcase", x0, x1, b, b + h, z0, z1, "Mahogany")
	local sx0, sx1, sz0, sz1 = wallBox(r, side, at, w - 0.7, 1.45, 0.08)
	local sp = deco(f, "BookSpines", sx0, sx1, b + 0.6, b + h - 0.7, sz0, sz1, "WalnutDark")
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Spines"
	sg.Face = IntoRoom[side]
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 14
	sg.MaxDistance = 70
	sg.Parent = sp
	local cols = { "Burgundy", "Forest", "Navy", "Ochre", "Plum", "TealDeep", "Mahogany", "Cream2" }
	local rows = math.max(2, math.floor((h - 1.3) / 2.2))
	for row = 0, rows - 1 do
		local shelf = Instance.new("Frame")
		shelf.Name = "Shelf"
		shelf.BorderSizePixel = 0
		shelf.BackgroundColor3 = color("Mahogany")
		shelf.Position = UDim2.fromScale(0, (row + 1) / rows - 0.04)
		shelf.Size = UDim2.fromScale(1, 0.04)
		shelf.Parent = sg
		local n = 12
		for k = 0, n - 1 do
			local bk = Instance.new("Frame")
			bk.Name = "Book"
			bk.BorderSizePixel = 0
			bk.BackgroundColor3 = color(cols[((k * 3 + row * 5) % #cols) + 1])
			local hh = 0.7 + ((k * 7 + row) % 4) * 0.06
			bk.Position = UDim2.fromScale(k / n + 0.005, (row + 1) / rows - 0.04 - hh / rows)
			bk.Size = UDim2.fromScale(1 / n - 0.012, hh / rows)
			bk.Parent = sg
		end
	end
	reserve(r, side, at - w / 2 - 0.6, at + w / 2 + 0.6)
end

local function wallUnit(f, r, side, len, fn)
	local at = findSpot(r, side, len + 1.2)
	if at then
		fn(at)
		reserve(r, side, at - len / 2 - 0.6, at + len / 2 + 0.6)
	end
	return at
end

local function chandelierRing(f, x, z, y, c)
	cyl(f, "Candelabra", x, y, z, 0.25, 2.4, c or "Gold", M.Metal, true)
end

function Kits.ballroom(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	-- the Exit Console dais (Night 3) sits at the centre: a stepped brass dais with a neon inlay
	cyl(f, "Dais", cx, b + 0.3, cz, 0.6, 10, "BrassDark", M.Metal, true)
	cyl(f, "DaisInlay", cx, b + 0.33, cz, 0.62, 6, "TealNeon", M.Neon, true)
	-- marble columns along E/W walls with gold capitals
	for _, z in { -20, -6, 8, 22 } do
		for _, side in { "W", "E" } do
			local x = if side == "W" then r.x0 + T + 1.6 else r.x1 - T - 1.6
			cyl(f, "Column", x, b + 9, cz + z, 18, 2.2, "Ivory", M.Marble, true)
			cyl(f, "Capital", x, b + 18.2, cz + z, 0.6, 2.9, "Gold", M.Metal, true)
			reserve(r, side, cz + z - 2, cz + z + 2)
		end
	end
	-- high banners above the gallery line
	for i, z in { -2, 16 } do
		artPiece(f, r, "W", cz + z, "banner", b + 27)
		artPiece(f, r, "E", cz + z + (i - 1) * 0.0, "banner", b + 27)
	end
	-- buffet tables + punch bowl
	tableAt(f, cx - 18, cz + 22, b, 8, 3, "Ivory", "Mahogany", 2.9)
	ball(f, "PunchBowl", cx - 18, b + 3.9, cz + 22, 1.6, "Crimson", M.Glass)
	tableAt(f, cx + 18, cz + 22, b, 8, 3, "Ivory", "Mahogany", 2.9)
	for k = -1, 1 do
		cyl(f, "Cake", cx + 18 + k * 2.2, b + 3.75 + (k + 1) * 0.15, cz + 22, 0.5 + (k + 1) * 0.3, 1.5 - (k + 1) * 0.3, "Cream2", M.SmoothPlastic, true)
	end
	-- gramophone on the dais edge
	cyl(f, "GramophoneBox", cx + 6.2, b + 1.4, cz - 4, 1.4, 1.6, "WalnutDark", M.Wood, true)
	for k = 0, 2 do
		cyl(f, "Horn", cx + 6.2 + k * 0.6, b + 2.6 + k * 0.6, cz - 4, 0.8, 0.8 + k * 0.9, "Brass", M.Metal, false)
	end
end

function Kits.foyer(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	-- grandfather clock on the west wall
	wallUnit(f, r, "W", 3, function(at)
		wallThing(f, r, "W", at, 2.4, 0.1, 2, b, b + 9, "ClockCase", "Walnut")
		local x0, x1, z0, z1 = wallBox(r, "W", at, 1.8, 2.15, 0.12)
		local face = deco(f, "ClockFace", x0, x1, b + 6.3, b + 8.1, z0, z1, "Cream2", M.SmoothPlastic)
		ArtGui.paint(face, Enum.NormalId.Right, "clock", 3)
	end)
	-- round table with a vase of flowers under the chandelier
	cyl(f, "HallTable", cx - 4, b + 2.8, cz, 0.3, 4.4, "Mahogany", M.Wood, true)
	cyl(f, "HallTableLeg", cx - 4, b + 1.4, cz, 2.8, 0.7, "Gold", M.Metal, true)
	cyl(f, "Vase", cx - 4, b + 3.95, cz, 2, 1.2, "TealDeep", M.Glass, true)
	ball(f, "Flowers", cx - 4, b + 5.4, cz, 1.9, "Rose", M.Fabric)
	-- coat stand + umbrella pot by the front door
	cyl(f, "CoatStand", r.x0 + T + 7, b + 3.5, r.z1 - T - 2.5, 7, 0.4, "WalnutDark", M.Wood, true)
	ball(f, "CoatHat", r.x0 + T + 7, b + 7.2, r.z1 - T - 2.5, 1.2, "Coal", M.Fabric)
	-- the way down to B1: a neon sign + chevrons on the floor pointing at the Cellar Stair door
	local door = nil
	for _, d in Manor.Doors do
		if (d.a == "foyer" and d.b == "cellarStair") or (d.b == "foyer" and d.a == "cellarStair") then
			door = d
		end
	end
	if door then
		local sx0, sx1, sz0, sz1 = wallBox(r, "E", door.at - 9.5, 7.5, 0.05, 0.25)
		local sign = deco(f, "BasementSign", sx0, sx1, b + 6.2, b + 10.2, sz0, sz1, "Coal", M.SmoothPlastic)
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Sign"
		sg.Face = Enum.NormalId.Left
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 30
		sg.LightInfluence = 0
		sg.MaxDistance = 120
		sg.Parent = sign
		local t1 = Instance.new("TextLabel")
		t1.Name = "Line1"
		t1.BackgroundTransparency = 1
		t1.Size = UDim2.fromScale(1, 0.55)
		t1.Font = Enum.Font.Sarpanch
		t1.TextScaled = true
		t1.TextColor3 = color("Amber")
		t1.Text = "BASEMENT  >>"
		t1.Parent = sg
		local t2 = t1:Clone()
		t2.Name = "Line2"
		t2.Position = UDim2.fromScale(0, 0.55)
		t2.Size = UDim2.fromScale(1, 0.42)
		t2.TextColor3 = color("TealNeon")
		t2.Text = "B1 BOILER LEVEL - STAIRS DOWN"
		t2.Parent = sg
		neonLight(sign, "Amber", 0.8, 12)
		reserve(r, "E", door.at - 14, door.at - 5)
		-- chevrons leading from the ballroom door to the cellar door
		for k = 0, 3 do
			local x = -6 + k * 4.2
			local z = 34 + k * 5
			local ch = deco(f, "FloorArrow", x - 0.9, x + 0.9, b + 0.06, b + 0.11, z - 0.9, z + 0.9, "Amber", M.Neon)
			ch.CastShadow = false
		end
	end
end

function Kits.corridor(f, r, b)
	-- side tables with vases + benches on the long walls
	local long = if (r.x1 - r.x0) >= (r.z1 - r.z0) then { "N", "S" } else { "W", "E" }
	for i, side in long do
		wallUnit(f, r, side, 4, function(at)
			local x0, x1, z0, z1 = wallBox(r, side, at, 4, 0.1, 1.6)
			deco(f, "SideTable", x0, x1, b + 2.6, b + 2.9, z0, z1, "Mahogany")
			local lx0, lx1, lz0, lz1 = wallBox(r, side, at, 3.2, 0.4, 1)
			deco(f, "SideTableBase", lx0, lx1, b, b + 2.6, lz0, lz1, "WalnutDark")
			local vx, vz = (x0 + x1) / 2, (z0 + z1) / 2
			cyl(f, "Vase", vx, b + 3.9, vz, 2, if i == 1 then 1 else 0.8, if i == 1 then "TealDeep" else "Burgundy", M.Glass, true)
		end)
	end
end

function Kits.library(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for _, side in { "W", "N", "S" } do
		for _ = 1, 2 do
			wallUnit(f, r, side, 10, function(at)
				bookcase(f, r, side, at, 10, b, 11)
				-- a rolling library ladder leaning on the case (slanted rails)
				local lx0, lx1, lz0, lz1 = wallBox(r, side, at + 3, 1.6, 1.6, 0.2)
				local rail = deco(f, "LadderRail", lx0, lx1, b, b + 10, lz0, lz1, "Oak")
				rail.CFrame = rail.CFrame * CFrame.Angles(if side == "W" or side == "E" then 0 else math.rad(-12), 0, if side == "W" then math.rad(12) elseif side == "E" then math.rad(-12) else 0)
			end)
		end
	end
	tableAt(f, cx + 4, cz, b, 8, 4, "Walnut", "WalnutDark")
	chair(f, cx + 4, cz - 3.6, b, "N", "Burgundy")
	chair(f, cx + 4, cz + 3.6, b, "S", "Burgundy")
	cyl(f, "ReadingLamp", cx + 6.5, b + 3.9, cz, 1.8, 0.5, "Brass", M.Metal, true)
	local shade = ball(f, "LampShade", cx + 6.5, b + 5, cz, 1.3, "Emerald", M.Glass)
	neonLight(shade, "Warm", 0.5, 8)
	cyl(f, "GlobeStand", cx - 8, b + 1.6, cz + 4, 3.2, 0.8, "Brass", M.Metal, true)
	ball(f, "Globe", cx - 8, b + 4.6, cz + 4, 3.2, "Teal", M.SmoothPlastic)
	rug(f, r, Decor.Themes.library, cx + 4, cz, 14.13, 10.07)
end

function Kits.billiard(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	deco(f, "BilliardBase", cx - 3, cx + 3, b, b + 2.5, cz - 5.5, cz + 5.5, "Mahogany")
	deco(f, "BilliardFelt", cx - 3.6, cx + 3.6, b + 2.5, b + 2.9, cz - 6.1, cz + 6.1, "Felt", M.Fabric)
	deco(f, "BilliardRailN", cx - 3.9, cx + 3.9, b + 2.5, b + 3.2, cz - 6.4, cz - 6.1, "Mahogany")
	deco(f, "BilliardRailS", cx - 3.9, cx + 3.9, b + 2.5, b + 3.2, cz + 6.1, cz + 6.4, "Mahogany")
	deco(f, "BilliardRailW", cx - 3.9, cx - 3.6, b + 2.5, b + 3.2, cz - 6.1, cz + 6.1, "Mahogany")
	deco(f, "BilliardRailE", cx + 3.6, cx + 3.9, b + 2.5, b + 3.2, cz - 6.1, cz + 6.1, "Mahogany")
	for k, c in { "Cream2", "Crimson", "Amber", "Azure", "Coal" } do
		ball(f, "Ball", cx - 1.2 + (k % 3) * 0.6, b + 3.15, cz - 2 + k * 0.5, 0.5, c, M.SmoothPlastic)
	end
	local lamp = deco(f, "TableLamp", cx - 3, cx + 3, b + 9, b + 9.6, cz - 1, cz + 1, "Emerald", M.Glass)
	neonLight(lamp, "Warm", 0.8, 14)
	-- cue rack on a wall
	wallUnit(f, r, "W", 4, function(at)
		wallThing(f, r, "W", at, 3.6, 0.05, 0.4, b + 2, b + 8.5, "CueRack", "Mahogany")
		for k = -1, 1 do
			local x0, x1, z0, z1 = wallBox(r, "W", at + k * 1.1, 0.18, 0.5, 0.18)
			deco(f, "Cue", x0, x1, b + 1.5, b + 9, z0, z1, "Oak")
		end
	end)
	chair(f, cx + 8, cz + 10, b, "W", "Forest")
	chair(f, cx + 8, cz - 10, b, "W", "Forest")
end

function Kits.music(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	-- grand piano (body + lid + keys + bench)
	deco(f, "PianoBody", cx - 3.4, cx + 3.4, b + 2.4, b + 4, cz - 3, cz + 2.4, "Coal")
	local lid = deco(f, "PianoLid", cx - 3.3, cx + 3.3, b + 4.1, b + 4.3, cz - 2.9, cz + 2.3, "Coal")
	lid.CFrame = lid.CFrame * CFrame.Angles(math.rad(-25), 0, 0)
	deco(f, "PianoKeys", cx - 3, cx + 3, b + 2.6, b + 3.6, cz + 2.4, cz + 3.1, "Cream2", M.SmoothPlastic)
	for _, dx in { -2.8, 2.8 } do
		deco(f, "PianoLeg", cx + dx - 0.25, cx + dx + 0.25, b, b + 2.4, cz - 0.25, cz + 0.25, "Gold", M.Metal)
	end
	deco(f, "PianoBench", cx - 1.6, cx + 1.6, b + 1.6, b + 2, cz + 4.4, cz + 5.4, "Coal")
	deco(f, "PianoBenchBase", cx - 1.2, cx + 1.2, b, b + 1.6, cz + 4.6, cz + 5.2, "Gold", M.Metal)
	-- gramophone on a stand
	local gx, gz = cx + 11, cz - 6
	deco(f, "GramoStand", gx - 1.2, gx + 1.2, b, b + 3, gz - 1.2, gz + 1.2, "Mahogany")
	deco(f, "GramoBox", gx - 1, gx + 1, b + 3, b + 4, gz - 1, gz + 1, "WalnutDark")
	for k = 0, 3 do
		cyl(f, "GramoHorn", gx - 0.6 - k * 0.7, b + 4.5 + k * 0.6, gz, 0.9, 0.7 + k * 0.85, "Brass", M.Metal, false)
	end
	-- harp-ish music stands + cello case
	for _, dx in { -10, -6 } do
		cyl(f, "MusicStand", cx + dx, b + 2.2, cz + 6, 4.4, 0.25, "Iron", M.Metal, true)
		deco(f, "SheetMusic", cx + dx - 0.9, cx + dx + 0.9, b + 4.4, b + 5.6, cz + 6.2, cz + 6.35, "Cream2", M.SmoothPlastic)
	end
	rug(f, r, Decor.Themes.music, cx, cz, 16.07, 12.11)
end

function Kits.lab(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for _, dz in { -6, 6 } do
		deco(f, "Workbench", cx - 6, cx + 6, b + 3, b + 3.4, cz + dz - 1.6, cz + dz + 1.6, "Steel", M.Metal)
		deco(f, "WorkbenchBase", cx - 5.4, cx + 5.4, b, b + 3, cz + dz - 1.2, cz + dz + 1.2, "WalnutDark")
		for k = -2, 2 do
			local c = ({ "Emerald", "Azure", "Violet", "Amber", "Crimson" })[k + 3]
			local flask = ball(f, "Flask", cx + k * 2, b + 4, cz + dz, 1, c, M.Glass)
			flask.Transparency = 0.2
		end
	end
	-- two Tesla coils with glowing tops
	for _, dx in { -15, 15 } do
		cyl(f, "CoilBase", cx + dx, b + 1.5, cz, 3, 3.4, "Copper", M.Metal, true)
		cyl(f, "Coil", cx + dx, b + 6, cz, 6, 1.4, "Brass", M.Metal, true)
		for k = 0, 3 do
			cyl(f, "CoilRing", cx + dx, b + 3.8 + k * 1.3, cz, 0.25, 2, "Copper", M.Metal, true)
		end
		local top = ball(f, "CoilTop", cx + dx, b + 9.8, cz, 2.6, "TealNeon", M.Neon)
		neonLight(top, "TealNeon", 1, 14)
	end
	wallUnit(f, r, "N", 8, function(at)
		wallThing(f, r, "N", at, 7.6, 0.1, 1.4, b, b + 7, "InstrumentRack", "Steel", M.Metal)
	end)
end

function Kits.dining(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	tableAt(f, cx, cz, b, 6, 24, "Mahogany", "WalnutDark")
	deco(f, "TableRunner", cx - 1, cx + 1, b + 3.15, b + 3.2, cz - 11.5, cz + 11.5, "Ivory", M.Fabric)
	for _, z in { -9, -4.5, 0, 4.5, 9 } do
		chair(f, cx - 4, cz + z, b, "E", "Burgundy")
		chair(f, cx + 4, cz + z, b, "W", "Burgundy")
	end
	for _, z in { -6, 6 } do
		cyl(f, "CandelabraStem", cx, b + 4.2, cz + z, 1.9, 0.3, "Gold", M.Metal, true)
		chandelierRing(f, cx, cz + z, b + 5.2, "Gold")
		for _, dx in { -0.9, 0, 0.9 } do
			cyl(f, "Candle", cx + dx, b + 5.85, cz + z, 1, 0.25, "Cream2", M.SmoothPlastic, true)
			local flame = ball(f, "Flame", cx + dx, b + 6.6, cz + z, 0.35, "Amber", M.Neon)
			flame.CastShadow = false
		end
	end
	wallUnit(f, r, "E", 8, function(at)
		wallThing(f, r, "E", at, 8, 0.1, 1.8, b, b + 3.2, "Sideboard", "Mahogany")
		local x0, x1, z0, z1 = wallBox(r, "E", at, 7.4, 0.4, 1.2)
		deco(f, "SideboardTop", x0, x1, b + 3.2, b + 3.4, z0, z1, "Ivory", M.Marble)
	end)
end

function Kits.kitchen(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	-- cast-iron range with copper pots
	wallUnit(f, r, "S", 10, function(at)
		wallThing(f, r, "S", at, 10, 0.1, 3, b, b + 3.4, "Range", "Coal", M.Metal)
		local x0, x1, z0, z1 = wallBox(r, "S", at, 10.4, 0.05, 3.2)
		deco(f, "RangeTop", x0, x1, b + 3.4, b + 3.7, z0, z1, "Copper", M.Metal)
		local hx0, hx1, hz0, hz1 = wallBox(r, "S", at, 6, 0.1, 2.4)
		deco(f, "Hood", hx0, hx1, b + 8, b + 10, hz0, hz1, "Copper", M.Metal)
		for k = -1, 1 do
			local px, _, pz = (x0 + x1) / 2 + (if x1 - x0 > 5 then k * 3 else 0), 0, (z0 + z1) / 2 + (if z1 - z0 > 5 then k * 3 else 0)
			cyl(f, "CopperPot", px, b + 4.6, pz, 1.6, 2, "Copper", M.Metal, true)
		end
	end)
	-- counters along the north wall + an island
	wallUnit(f, r, "N", 14, function(at)
		wallThing(f, r, "N", at, 14, 0.1, 2.6, b, b + 3.1, "Counter", "Ivory", M.Wood)
		local x0, x1, z0, z1 = wallBox(r, "N", at, 14.4, 0.05, 2.8)
		deco(f, "CounterTop", x0, x1, b + 3.1, b + 3.4, z0, z1, "Charcoal", M.Marble)
	end)
	tableAt(f, cx, cz, b, 10, 4, "Oak", "Ivory", 3)
	-- hanging pot rack over the island
	deco(f, "PotRack", cx - 5, cx + 5, b + 11, b + 11.3, cz - 0.4, cz + 0.4, "Iron", M.Metal)
	for k = -2, 2 do
		cyl(f, "HangingPot", cx + k * 2, b + 9.9, cz, 1.3, 1.4 + (k % 2) * 0.3, "Copper", M.Metal, true)
	end
	cyl(f, "Barrel", r.x1 - T - 2, b + 2, r.z0 + T + 9, 4, 3, "Oak", M.Wood, true)
end

function Kits.maps(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	tableAt(f, cx, cz, b, 9, 6, "Walnut", "WalnutDark")
	local map = deco(f, "MapSheet", cx - 4, cx + 4, b + 3.15, b + 3.2, cz - 2.6, cz + 2.6, "Cream2", M.Fabric)
	ArtGui.paint(map, Enum.NormalId.Top, "landscape", 11)
	cyl(f, "GlobeStand", cx + 8, b + 1.6, cz - 6, 3.2, 0.8, "Brass", M.Metal, true)
	ball(f, "Globe", cx + 8, b + 4.6, cz - 6, 3.4, "SkyBlue", M.SmoothPlastic)
	for k = 0, 2 do
		cyl(f, "MapScroll", cx - 9, b + 0.5 + k * 0.9, cz + 6, 4, 0.8, "Cream2", M.Fabric, false)
	end
end

function Kits.clockShop(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	tableAt(f, cx, cz, b, 10, 4, "Oak", "Iron", 2.9)
	for k = -2, 2 do
		cyl(f, "PocketWatch", cx + k * 1.8, b + 3.35, cz, 0.15, 1.1, "Gold", M.Metal, true)
	end
	-- a big gear assembly on a free wall
	local side = "N"
	local at = findSpot(r, side, 12) or findSpot(r, "S", 12)
	if at then
		if not findSpot(r, "N", 12) then
			side = "S"
		end
		for k, rad in { 3, 2, 1.4 } do
			local x0, x1, z0, z1 = wallBox(r, side, at - 4 + (k - 1) * 4, 0.01, 0.2 + k * 0.05, 0.3)
			local px, pz = (x0 + x1) / 2, (z0 + z1) / 2
			local g = Build.part({ name = "WallGear", parent = f, shape = Enum.PartType.Cylinder, size = Vector3.new(0.3, rad * 2, rad * 2), cf = CFrame.new(px, b + 9 - k, pz) * CFrame.Angles(0, math.rad(90), 0), color = color(if k == 2 then "Copper" else "Brass"), material = M.Metal, collide = false })
			g.CastShadow = false
		end
		reserve(r, side, at - 8, at + 8)
	end
	-- grandfather clocks in a row
	wallUnit(f, r, "W", 8, function(at2)
		for k = -1, 1 do
			wallThing(f, r, "W", at2 + k * 2.6, 2, 0.1, 1.6, b, b + 8 + k * 0.6, "ClockTower", if k == 0 then "Mahogany" else "Walnut")
		end
	end)
end

local function greenery(f, r, b, rows)
	local cx, cz = ManorLayout.centre(r)
	local w = r.x1 - r.x0
	for k = -rows, rows do
		local x = cx + k * math.min(10, (w - 10) / (2 * rows + 1))
		deco(f, "Planter", x - 2.1, x + 2.1, b, b + 1.6, cz - 4.1, cz + 4.1, "Stone", M.Slate)
		ball(f, "Shrub", x, b + 3.3, cz - 1.8, 3.6, "Leaf", M.Grass)
		ball(f, "Fern", x, b + 2.8, cz + 2, 2.6, "Emerald", M.Grass)
		local bloom = ball(f, "Bloom", x + 0.9, b + 4.8, cz - 1.4, 1, ({ "Rose", "Amber", "Violet" })[(k % 3) + 1], M.SmoothPlastic)
		bloom.CastShadow = false
	end
end

function Kits.conservatory(f, r, b)
	greenery(f, r, b, 2)
	local cx, cz = ManorLayout.centre(r)
	-- wicker chairs + a fountain
	cyl(f, "FountainBasin", cx + 20, b + 0.8, cz + 10, 1.6, 6, "Ivory", M.Marble, true)
	cyl(f, "FountainWater", cx + 20, b + 1.3, cz + 10, 0.4, 5.2, "SkyBlue", M.Glass, true)
	cyl(f, "FountainSpout", cx + 20, b + 2.8, cz + 10, 3, 0.6, "Ivory", M.Marble, true)
	chair(f, cx - 20, cz + 12, b, "N", "Ochre")
	chair(f, cx - 16, cz + 12, b, "N", "Ochre")
end

function Kits.greenhouse(f, r, b)
	greenery(f, r, b, 1)
	local cx, cz = ManorLayout.centre(r)
	-- potting bench + watering can
	wallUnit(f, r, "W", 8, function(at)
		wallThing(f, r, "W", at, 8, 0.1, 2.4, b + 2.8, b + 3.2, "PottingBench", "Oak")
		wallThing(f, r, "W", at, 7.2, 0.4, 1.8, b, b + 2.8, "PottingBenchBase", "WalnutDark")
		for k = -1, 1 do
			local x0, x1, z0, z1 = wallBox(r, "W", at + k * 2.4, 0.01, 1.3, 0.01)
			plant(f, (x0 + x1) / 2, (z0 + z1) / 2, b + 3.2, false)
		end
	end)
	cyl(f, "WateringCan", cx + 10, b + 0.9, cz + 10, 1.8, 1.4, "Copper", M.Metal, true)
end

function Kits.cellarSign(f, r, b)
	-- lanterns on the landing walls (the sign itself hangs in the Foyer)
	local cx = ManorLayout.centre(r)
	local lamp = ball(f, "LandingLamp", cx, b + LH + 10, r.z1 - T - 2, 1.2, "Amber", M.Neon)
	neonLight(lamp, "Warm", 1, 18)
	local lamp2 = ball(f, "BottomLamp", cx, b + 10, r.z0 + T + 2, 1.2, "Amber", M.Neon)
	neonLight(lamp2, "Warm", 1, 18)
end

function Kits.gallery(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for _, dx in { -14, 0, 14 } do
		deco(f, "Bench", cx + dx - 2.5, cx + dx + 2.5, b + 1.6, b + 2, cz - 0.8, cz + 0.8, "Burgundy", M.Fabric)
		deco(f, "BenchBase", cx + dx - 2.1, cx + dx + 2.1, b, b + 1.6, cz - 0.5, cz + 0.5, "Gold", M.Metal)
	end
	for _, dx in { -21, 7, 21 } do
		cyl(f, "Pedestal", cx + dx, b + 1.75, cz, 3.5, 1.6, "Ivory", M.Marble, true)
		cyl(f, "Vase", cx + dx, b + 4.5, cz, 2, 1.2, ({ "TealDeep", "Burgundy", "Navy" })[(dx % 3) + 1], M.Glass, true)
	end
end

function Kits.study(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	tableAt(f, cx, cz + 2, b, 9, 4.5, "Mahogany", "Mahogany")
	chair(f, cx, cz - 1.5, b, "S", "Burgundy")
	local plan = deco(f, "Blueprints", cx - 3.5, cx + 3.5, b + 3.15, b + 3.2, cz + 0.4, cz + 3.6, "Blueprint", M.SmoothPlastic)
	ArtGui.paint(plan, Enum.NormalId.Top, "blueprint", 5)
	cyl(f, "DeskLamp", cx + 3.6, b + 3.9, cz + 3.5, 1.6, 0.4, "Brass", M.Metal, true)
	local shade = ball(f, "LampShade", cx + 3.6, b + 4.9, cz + 3.5, 1.1, "Emerald", M.Glass)
	neonLight(shade, "Warm", 0.5, 8)
	wallUnit(f, r, "W", 8, function(at)
		bookcase(f, r, "W", at, 8, b, 10)
	end)
	cyl(f, "Armchair", cx - 7, b + 1.4, cz - 6, 2.8, 3, "Burgundy", M.Fabric, true)
end

function Kits.telegraph(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for _, dx in { -5, 5 } do
		tableAt(f, cx + dx, cz, b, 6, 3, "Walnut", "WalnutDark")
		cyl(f, "Sounder", cx + dx - 1.4, b + 3.7, cz, 1, 1.2, "Brass", M.Metal, true)
		cyl(f, "Key", cx + dx + 1.4, b + 3.45, cz, 0.5, 0.8, "Copper", M.Metal, true)
		chair(f, cx + dx, cz + 2.6, b, "N", "Ochre")
	end
	-- a tape reel cabinet
	wallUnit(f, r, "S", 6, function(at)
		wallThing(f, r, "S", at, 6, 0.1, 1.8, b, b + 6, "ReelCabinet", "Walnut")
	end)
end

function Kits.suite(f, r, b, theme)
	local cx, cz = ManorLayout.centre(r)
	for _, dx in { -10, 10 } do
		deco(f, "BedFrame", cx + dx - 3, cx + dx + 3, b, b + 1.6, cz - 4.5, cz + 4.5, "Mahogany")
		deco(f, "Headboard", cx + dx - 3, cx + dx + 3, b + 1.6, b + 5, cz - 4.5, cz - 4.1, "Mahogany")
		deco(f, "Mattress", cx + dx - 2.7, cx + dx + 2.7, b + 1.6, b + 2.6, cz - 4.1, cz + 4.2, "Cream2", M.Fabric)
		deco(f, "Quilt", cx + dx - 2.85, cx + dx + 2.85, b + 2.6, b + 2.85, cz - 1, cz + 4.35, theme.quilt or "Burgundy", M.Fabric)
		deco(f, "Pillow", cx + dx - 2, cx + dx + 2, b + 2.6, b + 3.2, cz - 3.9, cz - 2.6, "Ivory", M.Fabric)
		deco(f, "Nightstand", cx + dx + 3.3, cx + dx + 5.1, b, b + 2.4, cz - 4.4, cz - 2.6, "Walnut")
		local lamp = ball(f, "BedsideLamp", cx + dx + 4.2, b + 3.1, cz - 3.5, 1, "Amber", M.Neon)
		neonLight(lamp, "Warm", 0.4, 8)
	end
	-- wardrobes on a free wall
	for _ = 1, 2 do
		wallUnit(f, r, "S", 5, function(at)
			wallThing(f, r, "S", at, 5, 0.1, 2.4, b, b + 9, "Wardrobe", "Walnut")
			local x0, x1, z0, z1 = wallBox(r, "S", at, 0.3, 2.5, 0.2)
			deco(f, "WardrobeHandle", x0, x1, b + 4, b + 5.2, z0, z1, "Gold", M.Metal)
		end)
	end
	rug(f, r, theme, cx, cz + 7, 12.07, 5.03)
end

function Kits.trophy(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for k = -1, 1 do
		local z = cz + k * 9
		cyl(f, "Pedestal", cx, b + 1.75, z, 3.5, 2, "Ivory", M.Marble, true)
		cyl(f, "TrophyCup", cx, b + 4.4, z, 1.8, 1.4, "Gold", M.Metal, true)
		ball(f, "TrophyTop", cx, b + 5.6, z, 1, "Gold", M.Metal)
	end
	wallUnit(f, r, "E", 10, function(at)
		wallThing(f, r, "E", at, 10, 0.1, 1.6, b, b + 7, "DisplayCase", "Mahogany")
		local x0, x1, z0, z1 = wallBox(r, "E", at, 9.2, 1.75, 0.1)
		local glass = deco(f, "CaseGlass", x0, x1, b + 1, b + 6.4, z0, z1, "SkyBlue", M.Glass)
		glass.Transparency = 0.6
	end)
end

function Kits.tea(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for _, dx in { -14, 0, 14 } do
		cyl(f, "TeaTable", cx + dx, b + 2.6, cz, 0.4, 4.2, "Ivory", M.Marble, true)
		cyl(f, "TeaLeg", cx + dx, b + 1.2, cz, 2.4, 0.5, "Gold", M.Metal, true)
		cyl(f, "Teapot", cx + dx, b + 3.3, cz, 1, 1.1, "Cream2", M.SmoothPlastic, true)
		for _, dz in { -3, 3 } do
			chair(f, cx + dx, cz + dz, b, if dz < 0 then "S" else "N", "Rose")
		end
	end
	cyl(f, "CakeStand", cx + 7, b + 3.6, cz + 9, 3.2, 0.3, "Gold", M.Metal, true)
	for k = 0, 2 do
		cyl(f, "CakeTier", cx + 7, b + 2.4 + k * 1.1, cz + 9, 0.12, 2.4 - k * 0.6, "Cream2", M.SmoothPlastic, true)
	end
end

function Kits.mezzanine(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	-- a giant floor-standing astronomical clock
	cyl(f, "ClockPlinth", cx, b + 1.5, cz, 3, 6, "Mahogany", M.Wood, true)
	deco(f, "ClockBody", cx - 2, cx + 2, b + 3, b + 12, cz - 2, cz + 2, "Walnut")
	for _, side in { { Enum.NormalId.Front, -2.06 }, { Enum.NormalId.Back, 2.06 } } do
		local face = deco(f, "ClockDial", cx - 1.8, cx + 1.8, b + 8, b + 11.6, cz + side[2] - (if side[2] < 0 then 0.1 else 0), cz + side[2] + (if side[2] > 0 then 0.1 else 0), "Cream2", M.SmoothPlastic)
		ArtGui.paint(face, side[1], "clock", 9)
	end
	for _, dx in { -18, 18 } do
		deco(f, "Settee", cx + dx - 3, cx + dx + 3, b + 1.4, b + 2, cz + 9, cz + 11, "TealDeep", M.Fabric)
		deco(f, "SetteeBack", cx + dx - 3, cx + dx + 3, b + 2, b + 4, cz + 10.6, cz + 11, "TealDeep", M.Fabric)
		deco(f, "SetteeBase", cx + dx - 2.6, cx + dx + 2.6, b, b + 1.4, cz + 9.3, cz + 10.7, "Gold", M.Metal)
	end
end

function Kits.linen(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	deco(f, "Press", cx - 5, cx + 5, b, b + 3, cz - 2, cz + 2, "Steel", M.Metal)
	for k = 0, 2 do
		deco(f, "Linen", cx - 4 + k * 3, cx - 2 + k * 3, b + 3, b + 3.6 + k * 0.4, cz - 1.4, cz + 1.4, "Cream2", M.Fabric)
	end
	for _ = 1, 2 do
		wallUnit(f, r, "N", 8, function(at)
			wallThing(f, r, "N", at, 8, 0.1, 2.2, b, b + 8, "LinenShelf", "Ivory")
		end)
	end
	-- laundry lines
	deco(f, "Line", r.x0 + T + 4, r.x1 - T - 4, b + 9, b + 9.1, cz + 8, cz + 8.1, "Cream2", M.Fabric)
	for k = 0, 4 do
		local x = cx - 12 + k * 6
		deco(f, "Sheet", x - 1.5, x + 1.5, b + 5.5, b + 9, cz + 7.95, cz + 8.0, ({ "Cream2", "SkyBlue", "Rose" })[(k % 3) + 1], M.Fabric)
	end
end

function Kits.drafting(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for _, dx in { -10, 0, 10 } do
		local board = deco(f, "DraftBoard", cx + dx - 3, cx + dx + 3, b + 3.2, b + 3.5, cz - 2, cz + 2, "Cream2", M.SmoothPlastic)
		board.CFrame = board.CFrame * CFrame.Angles(math.rad(20), 0, 0)
		deco(f, "DraftLeg", cx + dx - 0.3, cx + dx + 0.3, b, b + 3.1, cz - 0.3, cz + 0.3, "Iron", M.Metal)
		chair(f, cx + dx, cz + 3.6, b, "N", "Oak")
	end
	for k = 0, 3 do
		cyl(f, "PlanTube", cx - 14 + k * 0.9, b + 2, cz - 8, 4, 0.7, "Cream2", M.Fabric, true)
	end
	-- a model airship hanging from the ceiling
	local top = ManorLayout.topY(Manor, r)
	cyl(f, "ModelAirship", cx, top - 3.5, cz - 6, 6, 2.2, "Crimson", M.Fabric, false)
	deco(f, "AirshipString", cx - 0.05, cx + 0.05, top - 2.5, top - 0.02, cz - 6.05, cz - 5.95, "Cream2", M.Fabric)
end

function Kits.atticBeams(f, r, b)
	local top = ManorLayout.topY(Manor, r)
	local w = r.x1 - r.x0
	local n = math.floor(w / 10)
	for i = 1, n do
		local x = r.x0 + w * i / (n + 1)
		deco(f, "RoofBeam", x - 0.6, x + 0.6, top - 1.2, top - 0.02, r.z0 + T + 0.1, r.z1 - T - 0.1, "WalnutDark")
	end
	local cx, cz = ManorLayout.centre(r)
	for k = -1, 1, 2 do
		cyl(f, "Trunk", cx + k * 20, b + 1.2, cz, 4, 2.4, "Ochre", M.Wood, false)
	end
end

function Kits.attic(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	-- trunks, crates, a dress form and a rocking horse (secular attic clutter)
	for k = 0, 5 do
		local x = cx - 12 + (k % 3) * 12
		local z = cz - 8 + math.floor(k / 3) * 16
		deco(f, "Crate", x - 1.8, x + 1.8, b, b + 3.6, z - 1.8, z + 1.8, if k % 2 == 0 then "Oak" else "Walnut")
		deco(f, "CrateLid", x - 1.9, x + 1.9, b + 3.6, b + 3.9, z - 1.9, z + 1.9, "WalnutDark")
	end
	cyl(f, "TrunkBody", cx + 4, b + 1.3, cz + 6, 4.2, 2.6, "Burgundy", M.Wood, false)
	cyl(f, "DressForm", cx - 6, b + 3, cz + 1, 3, 1.6, "Cream2", M.Fabric, true)
	ball(f, "DressFormTop", cx - 6, b + 5, cz + 1, 1.4, "Cream2", M.Fabric)
	-- dust sheets over furniture
	deco(f, "DustSheet", cx + 8, cx + 13, b, b + 3.4, cz - 4, cz + 0.6, "Ivory", M.Fabric)
end

function Kits.automata(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	-- little friendly clockwork robots, a rocking horse, alphabet blocks
	for k = 0, 3 do
		local x = cx - 9 + k * 6
		local z = cz + (k % 2) * 4 - 2
		cyl(f, "BotBody", x, b + 1.8, z, 2.4, 1.8, ({ "Brass", "Copper", "Silver", "Gold" })[k + 1], M.Metal, true)
		ball(f, "BotHead", x, b + 3.6, z, 1.4, "Brass", M.Metal)
		local eye = ball(f, "BotEye", x, b + 3.7, z - 0.6, 0.45, "TealNeon", M.Neon)
		eye.CastShadow = false
	end
	for k = 0, 5 do
		local x = cx + 10 + (k % 3) * 1.25
		local y = b + math.floor(k / 3) * 1.15
		deco(f, "Block", x - 0.55, x + 0.55, y + 0.02, y + 1.12, cz + 8 - 0.55, cz + 8 + 0.55, ({ "Crimson", "Azure", "Amber", "Emerald", "Violet", "Pink" })[k + 1], M.SmoothPlastic)
	end
	deco(f, "HorseBody", cx - 12, cx - 8, b + 2.2, b + 3.6, cz + 8, cz + 9.4, "Cream2", M.Wood)
	ball(f, "HorseHead", cx - 7.5, b + 4.2, cz + 8.7, 1.4, "Cream2", M.Wood)
	deco(f, "Rocker", cx - 12.5, cx - 7.5, b, b + 0.6, cz + 7.9, cz + 9.5, "Crimson", M.Wood)
	deco(f, "HorseLeg", cx - 11, cx - 9, b + 0.6, b + 2.2, cz + 8.4, cz + 9, "Cream2", M.Wood)
end

function Kits.workshop(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	tableAt(f, cx, cz + 4, b, 10, 3.5, "Steel", "WalnutDark", 3)
	cyl(f, "Vice", cx - 3, b + 3.8, cz + 4, 1.2, 1, "Iron", M.Metal, true)
	cyl(f, "Lathe", cx + 2, b + 3.9, cz + 4, 4, 1, "Copper", M.Metal, false)
	wallUnit(f, r, "W", 6, function(at)
		wallThing(f, r, "W", at, 6, 0.05, 0.3, b + 3, b + 9, "Pegboard", "Oak")
		for k = -1, 1 do
			local x0, x1, z0, z1 = wallBox(r, "W", at + k * 1.8, 0.3, 0.4, 0.3)
			deco(f, "HangingTool", x0, x1, b + 5, b + 7.5, z0, z1, "Steel", M.Metal)
		end
	end)
end

function Kits.greatClock(f, r, b)
	-- the back of the tower's great clock face fills the north wall
	local cx = ManorLayout.centre(r)
	local face = deco(f, "GreatClockFace", cx - 6, cx + 6, b + 2, b + 14, r.z0 + T + 0.05, r.z0 + T + 0.3, "Cream2", M.SmoothPlastic)
	ArtGui.paint(face, Enum.NormalId.Back, "clock", 12)
	reserve(r, "N", cx - 7, cx + 7)
	for k, rad in { 2.4, 1.6 } do
		local g = Build.part({ name = "ClockGear", parent = f, shape = Enum.PartType.Cylinder, size = Vector3.new(0.4, rad * 2, rad * 2), cf = CFrame.new(cx + 9 + k * 2, b + 6 + k * 2, r.z0 + T + 0.8 + k * 0.2) * CFrame.Angles(0, math.rad(90), 0), color = color("Brass"), material = M.Metal, collide = false })
		g.CastShadow = false
	end
	local _, cz = ManorLayout.centre(r)
	cyl(f, "Pendulum", cx, b + 4, cz + 4, 0.3, 2.6, "Gold", M.Metal, false)
	deco(f, "PendulumRod", cx - 0.1, cx + 0.1, b + 4, b + 15.98, cz + 3.95, cz + 4.05, "Brass", M.Metal)
end

function Kits.servants(f, r, b, theme)
	local cx, cz = ManorLayout.centre(r)
	for k = -1, 1 do
		local x = cx + k * 13
		deco(f, "Cot", x - 2, x + 2, b, b + 1.8, cz - 4, cz + 4, "Oak")
		deco(f, "CotBlanket", x - 2.1, x + 2.1, b + 1.8, b + 2.1, cz - 1, cz + 4.1, theme.quilt or "Sage", M.Fabric)
		deco(f, "Footlocker", x - 1.5, x + 1.5, b, b + 1.6, cz + 4.6, cz + 6.2, "Walnut")
	end
	for _ = 1, 2 do
		wallUnit(f, r, "E", 5, function(at)
			wallThing(f, r, "E", at, 5, 0.1, 2.2, b, b + 8.5, "Wardrobe", "Oak")
		end)
	end
	rug(f, r, theme, cx, cz - 9, 10.07, 4.03)
end

function Kits.observatory(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	cyl(f, "TelescopeMount", cx, b + 2, cz + 2, 4, 2.4, "Iron", M.Metal, true)
	local tube = cyl(f, "Telescope", cx, b + 7, cz, 14, 1.8, "Brass", M.Metal)
	tube.CFrame = CFrame.new(cx, b + 8, cz) * CFrame.Angles(math.rad(50), math.rad(90), 0)
	cyl(f, "Eyepiece", cx, b + 3.8, cz + 5, 1, 0.6, "Copper", M.Metal, false)
	-- an orrery (planets on rings)
	local ox, oz = cx - 9, cz + 8
	cyl(f, "OrreryBase", ox, b + 1.5, oz, 3, 1.4, "Mahogany", M.Wood, true)
	ball(f, "Sun", ox, b + 4, oz, 1.4, "Amber", M.Neon)
	for k, c in { "Azure", "Crimson", "Emerald" } do
		ball(f, "Planet", ox + k * 1.4, b + 4, oz, 0.6, c, M.SmoothPlastic)
	end
	-- the dome ring
	local top = ManorLayout.topY(Manor, r)
	deco(f, "DomeRibN", r.x0 + T + 0.2, r.x1 - T - 0.2, top - 0.6, top - 0.02, cz - 0.3, cz + 0.3, "Brass", M.Metal)
	deco(f, "DomeRibE", cx - 0.25, cx + 0.25, top - 0.55, top - 0.12, r.z0 + T + 0.2, r.z1 - T - 0.2, "Brass", M.Metal)
end

function Kits.lookout(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for _, dx in { -6, 6 } do
		cyl(f, "Spyglass", cx + dx, b + 3.6, cz - 8, 4, 0.7, "Brass", M.Metal, false)
		cyl(f, "SpyglassStand", cx + dx, b + 1.6, cz - 8, 3.2, 0.4, "Iron", M.Metal, true)
	end
	tableAt(f, cx, cz + 4, b, 8, 5, "Oak", "WalnutDark")
	local map = deco(f, "SeaChart", cx - 3.5, cx + 3.5, b + 3.15, b + 3.2, cz + 2, cz + 6, "Cream2", M.Fabric)
	ArtGui.paint(map, Enum.NormalId.Top, "starchart", 4)
end

function Kits.pipes(f, r, b)
	local long = (r.x1 - r.x0) >= (r.z1 - r.z0)
	local top = ManorLayout.topY(Manor, r)
	for k, y in { top - 1.6, top - 3.2 } do
		if long then
			cyl(f, "Pipe", (r.x0 + r.x1) / 2, y, r.z0 + T + 0.45 + k * 0.9, r.x1 - r.x0 - 2 * T - 0.4 - k * 0.2, 0.7, if k == 1 then "Copper" else "Steel", M.Metal, false)
		else
			local part = cyl(f, "Pipe", r.x0 + T + 0.45 + k * 0.9, y, (r.z0 + r.z1) / 2, r.z1 - r.z0 - 2 * T - 0.4 - k * 0.2, 0.7, if k == 1 then "Copper" else "Steel", M.Metal, false)
			part.CFrame = CFrame.new(part.CFrame.Position) * CFrame.Angles(0, math.rad(90), 0)
		end
	end
	if long then
		local cx = ManorLayout.centre(r)
		for k = -2, 2 do
			local x = cx + k * 20
			local valve = cyl(f, "Valve", x, top - 2.4, r.z0 + T + 1.8, 0.3, 1.4, "Crimson", M.Metal, true)
			valve.CastShadow = false
		end
	end
end

function Kits.wine(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for k = 0, 5 do
		local x = cx - 12 + (k % 3) * 12
		local z = cz - 6 + math.floor(k / 3) * 12
		cyl(f, "Barrel", x, b + 2.1, z, 4, 3.4, if k % 2 == 0 then "Oak" else "Walnut", M.Wood, false)
		cyl(f, "BarrelHoop", x, b + 2.1, z, 0.3, 3.6, "Iron", M.Metal, false)
	end
	-- wine racks (honeycomb drawn on the face) on the long walls
	for _, side in { "N", "S" } do
		for _ = 1, 2 do
			wallUnit(f, r, side, 8, function(at)
				local rack = wallThing(f, r, side, at, 8, 0.1, 1.6, b, b + 8, "WineRack", "Mahogany")
				local sg = Instance.new("SurfaceGui")
				sg.Name = "Bottles"
				sg.Face = IntoRoom[side]
				sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				sg.PixelsPerStud = 12
				sg.MaxDistance = 60
				sg.Parent = rack
				for i = 0, 5 do
					for j = 0, 5 do
						local bt = Instance.new("Frame")
						bt.Name = "Bottle"
						bt.BorderSizePixel = 0
						bt.BackgroundColor3 = color(if (i + j) % 3 == 0 then "Emerald" else "Burgundy")
						bt.Position = UDim2.fromScale(0.04 + i * 0.16, 0.04 + j * 0.16)
						bt.Size = UDim2.fromScale(0.11, 0.11)
						bt.Parent = sg
						local c = Instance.new("UICorner")
						c.CornerRadius = UDim.new(0.5, 0)
						c.Parent = bt
					end
				end
			end)
		end
	end
	tableAt(f, cx + 16, cz + 20, b, 4, 4, "Oak", "WalnutDark")
	for _, dx in { -0.8, 0.8 } do
		cyl(f, "WineBottle", cx + 16 + dx, b + 3.95, cz + 20, 1.6, 0.5, "Emerald", M.Glass, true)
	end
end

function Kits.boiler(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	cyl(f, "Boiler", cx, b + 5.5, cz, 11, 8, "Copper", M.Metal, true)
	for k = 0, 2 do
		cyl(f, "BoilerBand", cx, b + 2 + k * 3.5, cz, 0.4, 8.3, "Iron", M.Metal, true)
	end
	-- furnace mouth with glowing coals
	deco(f, "Furnace", cx - 3, cx + 3, b, b + 4.6, cz + 4.2, cz + 7, "Coal", M.Metal)
	local fire = deco(f, "FurnaceFire", cx - 2, cx + 2, b + 0.8, b + 3.2, cz + 7.02, cz + 7.12, "Amber", M.Neon)
	neonLight(fire, { 255, 110, 40 }, 1.6, 18)
	for _, dx in { -6, 6 } do
		cyl(f, "Flue", cx + dx, b + 8, cz, 16 - 0.1, 1.2, "Iron", M.Metal, true)
	end
	local top = ManorLayout.topY(Manor, r)
	for k = -1, 1 do
		cyl(f, "SteamPipe", cx, top - 1.5 - k * 0.0, cz + k * 8, r.x1 - r.x0 - 2 * T - 0.6, 0.8, "Copper", M.Metal, false)
	end
	cyl(f, "PressureGauge", cx + 4.3, b + 7, cz - 1, 0.3, 1.6, "Cream2", M.SmoothPlastic, false)
	for k = 0, 3 do
		deco(f, "CoalHeap", cx - 12 + k * 1.37, cx - 9 + k * 1.31, b + 0.03 * k, b + 1 + k * 0.3, cz + 10 + 0.07 * k, cz + 13 - 0.05 * k, "Coal", M.Slate)
	end
end

function Kits.generator(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for _, dz in { -10, 10 } do
		cyl(f, "Dynamo", cx - 6, b + 3, cz + dz, 7, 5, "Steel", M.Metal, false)
		cyl(f, "DynamoCoil", cx - 6, b + 3, cz + dz, 7.3, 2.4, "TealNeon", M.Neon, false)
		deco(f, "DynamoBase", cx - 10, cx - 2, b, b + 0.5, cz + dz - 2.6, cz + dz + 2.6, "Coal", M.Metal)
	end
	-- a giant flywheel
	local wheel = Build.part({ name = "Flywheel", parent = f, shape = Enum.PartType.Cylinder, size = Vector3.new(1, 10, 10), cf = CFrame.new(cx + 6, b + 5.2, cz), color = color("Iron"), material = M.Metal, collide = false })
	wheel.CastShadow = false
	cyl(f, "FlywheelHub", cx + 6, b + 5.2, cz, 1.3, 2, "Brass", M.Metal, false)
	-- control panel with dials
	wallUnit(f, r, "W", 8, function(at)
		local panel = wallThing(f, r, "W", at, 8, 0.1, 1, b + 2, b + 8, "ControlPanel", "Steel", M.Metal)
		ArtGui.paint(panel, Enum.NormalId.Right, "blueprint", 21)
	end)
end

function Kits.coal(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for k = 0, 4 do
		local x = cx - 16 + k * 8
		deco(f, "CoalPile", x - 3 + k * 0.03, x + 3, b, b + 1.5 + (k % 2), cz - 4 - k * 0.07, cz + 4, "Coal", M.Slate)
	end
	for _, dx in { -10, 10 } do
		cyl(f, "Shovel", cx + dx, b + 2.5, cz + 7, 5, 0.25, "Oak", M.Wood, true)
		cyl(f, "Cart", cx + dx + 3, b + 1.4, cz + 7, 3.2, 2.2, "Iron", M.Metal, false)
	end
end

function Kits.pump(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	cyl(f, "PumpTank", cx, b + 3.5, cz + 4, 7, 4, "Copper", M.Metal, true)
	cyl(f, "PumpPipe", cx, b + 10, cz + 4, 6, 1, "Steel", M.Metal, true)
	cyl(f, "PumpWheel", cx + 2.4, b + 4, cz - 3, 0.4, 3, "Crimson", M.Metal, false)
end

function Kits.laundry(f, r, b)
	local cx, cz = ManorLayout.centre(r)
	for k = -1, 1 do
		cyl(f, "WashTub", cx + k * 9, b + 1.5, cz - 6, 3, 4, "Steel", M.Metal, true)
		local water = cyl(f, "Suds", cx + k * 9, b + 3.05, cz - 6, 0.1, 3.4, "Cream2", M.SmoothPlastic, true)
		water.CastShadow = false
	end
	deco(f, "Mangle", cx - 2, cx + 2, b, b + 4, cz + 6, cz + 9, "Iron", M.Metal)
	cyl(f, "MangleRoller", cx, b + 4.6, cz + 7.5, 4.6, 1, "Oak", M.Wood, false)
	deco(f, "Line", r.x0 + T + 4, r.x1 - T - 4, b + 10, b + 10.1, cz + 12, cz + 12.1, "Cream2", M.Fabric)
	for k = 0, 4 do
		local x = cx - 14 + k * 7
		deco(f, "Sheet", x - 1.8, x + 1.8, b + 6.5, b + 10, cz + 11.95, cz + 12, ({ "Cream2", "SkyBlue", "Rose" })[(k % 3) + 1], M.Fabric)
	end
end
ManorDecor.Kits = Kits

-- Dress one room. Returns a summary { art = n, plants = n }.
function ManorDecor.dress(parent: Instance, r)
	local theme = Decor.Themes[r.theme or ""] or Decor.Themes.corridor
	local f = Instance.new("Model")
	f.Name = "Decor_" .. r.id
	local b = ManorLayout.baseY(Manor, r)
	patternSheet(f, r, theme)
	ceilingDress(f, r, theme)
	local kit = theme.kit and Kits[theme.kit]
	if kit then
		kit(f, r, b, theme)
	end
	local nPlants = plants(f, r, theme) or 0
	local nArt = dressWalls(f, r, theme)
	if theme.rug and theme.kit ~= "library" and theme.kit ~= "music" and theme.kit ~= "suite" and theme.kit ~= "servants" then
		local cx, cz = ManorLayout.centre(r)
		local w, d = r.x1 - r.x0, r.z1 - r.z0
		rug(f, r, theme, cx, cz, math.min(16, w * 0.5) + 0.07, math.min(12, d * 0.5) + 0.03)
	end
	f.Parent = parent
	return { art = nArt, plants = nPlants }
end

function ManorDecor.themeOf(r)
	return Decor.Themes[r.theme or ""] or Decor.Themes.corridor
end

function ManorDecor.resetReservations()
	table.clear(reserved)
end

return ManorDecor
