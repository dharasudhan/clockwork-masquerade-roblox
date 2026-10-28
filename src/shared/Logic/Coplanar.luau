-- Z-fighting detector (pure). Two visible faces that point the same way and lie in the same
-- plane (within `tol`, default 0.01 studs) while overlapping in area flicker on screen. Opposite
-- faces touching (a wall on a floor, two walls back to back) are hidden and fine.
-- Input: boxes { name, cx, cy, cz, sx, sy, sz } (axis-aligned, world space), optional
-- `guiFaces` = { [boxIndex] = { "Front" | "Back" | "Left" | "Right" | "Top" | "Bottom" } }: a face
-- carrying a SurfaceGui/Decal may not touch ANY other face (either direction).
-- Returns a list of problems { a, b, axis, plane, area } (box indexes into the input).
local Coplanar = {}

-- face index: axis 1..3 (x, y, z), sign +1/-1
local NormalOf = {
	Right = { 1, 1 }, Left = { 1, -1 }, Top = { 2, 1 }, Bottom = { 2, -1 }, Back = { 3, 1 }, Front = { 3, -1 },
}
Coplanar.NormalOf = NormalOf

local function faces(b)
	local c = { b.cx, b.cy, b.cz }
	local h = { b.sx / 2, b.sy / 2, b.sz / 2 }
	local out = {}
	for axis = 1, 3 do
		local u, v = if axis == 1 then 2 else 1, if axis == 3 then 2 else 3
		for _, sign in { 1, -1 } do
			table.insert(out, {
				axis = axis, sign = sign, plane = c[axis] + sign * h[axis],
				u0 = c[u] - h[u], u1 = c[u] + h[u], v0 = c[v] - h[v], v1 = c[v] + h[v],
			})
		end
	end
	return out
end
Coplanar.faces = faces

function Coplanar.find(boxes, tol: number?, minOverlap: number?, guiFaces)
	local t = tol or 0.01
	local mo = minOverlap or 0.02
	local buckets = {}
	local function key(axis, sign, q)
		return axis * 10 + (sign + 1) .. ":" .. q
	end
	local all = {}
	for i, b in boxes do
		for _, f in faces(b) do
			f.box = i
			local gf = guiFaces and guiFaces[i]
			if gf then
				for _, name in gf do
					local n = NormalOf[name]
					if n and n[1] == f.axis and n[2] == f.sign then
						f.gui = true
					end
				end
			end
			local q = math.floor(f.plane / t + 0.5)
			local k = key(f.axis, f.sign, q)
			buckets[k] = buckets[k] or {}
			table.insert(buckets[k], f)
			table.insert(all, f)
		end
	end
	local problems = {}
	local seen = {}
	local function check(f, g, gui)
		if f.box == g.box or math.abs(f.plane - g.plane) > t then
			return
		end
		local du = math.min(f.u1, g.u1) - math.max(f.u0, g.u0)
		local dv = math.min(f.v1, g.v1) - math.max(f.v0, g.v0)
		if du > mo and dv > mo then
			local a, b = math.min(f.box, g.box), math.max(f.box, g.box)
			local id = a .. "/" .. b .. "/" .. f.axis .. (if gui then "g" else "")
			if not seen[id] then
				seen[id] = true
				table.insert(problems, { a = a, b = b, axis = f.axis, plane = f.plane, area = du * dv, gui = gui })
			end
		end
	end
	for _, f in all do
		local q = math.floor(f.plane / t + 0.5)
		for dq = -1, 1 do
			local list = buckets[key(f.axis, f.sign, q + dq)]
			if list then
				for _, g in list do
					if g.box > f.box then
						check(f, g, false)
					end
				end
			end
			if f.gui then
				-- a face carrying a GUI must not touch an opposite face either
				local opp = buckets[key(f.axis, -f.sign, q + dq)]
				if opp then
					for _, g in opp do
						check(f, g, true)
					end
				end
			end
		end
	end
	return problems
end

-- Axis-aligned world box of a rotated box given by its centre, size and rotation matrix
-- columns (right, up, back vectors as {x, y, z}). Returns nil when not axis-aligned.
function Coplanar.alignedBox(name, cx, cy, cz, sx, sy, sz, R, U, B)
	local cols = { R, U, B }
	local size = { sx, sy, sz }
	local world = { 0, 0, 0 }
	for i = 1, 3 do
		local c = cols[i]
		local comps = { math.abs(c[1]), math.abs(c[2]), math.abs(c[3]) }
		local hit = nil
		for k = 1, 3 do
			if comps[k] > 0.9999 then
				hit = k
			elseif comps[k] > 1e-4 then
				return nil
			end
		end
		if hit == nil then
			return nil
		end
		world[hit] = size[i]
	end
	return { name = name, cx = cx, cy = cy, cz = cz, sx = world[1], sy = world[2], sz = world[3] }
end

-- Which world face (NormalId name) a part's local NormalId maps to (axis-aligned parts).
function Coplanar.worldFace(localFace: string, R, U, B): string?
	local n = NormalOf[localFace]
	if not n then
		return nil
	end
	local col = ({ R, U, B })[n[1]]
	for k = 1, 3 do
		if math.abs(col[k]) > 0.9999 then
			local s = (if col[k] > 0 then 1 else -1) * n[2]
			for name, v in NormalOf do
				if v[1] == k and v[2] == s then
					return name
				end
			end
		end
	end
	return nil
end

return Coplanar
