-- Lantern beam maths (pure). Vectors are anything with X, Y, Z fields (Vector3 or tables).
local Lantern = {}

local function sub(a, b)
	return a.X - b.X, a.Y - b.Y, a.Z - b.Z
end

-- Is `target` inside the beam cone from `origin` along `dir`? Returns (inside, distance).
function Lantern.inCone(origin, dir, target, range: number, halfAngleDeg: number): (boolean, number)
	local dx, dy, dz = sub(target, origin)
	local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
	if dist > range or dist < 0.05 then
		return false, dist
	end
	local dl = math.sqrt(dir.X * dir.X + dir.Y * dir.Y + dir.Z * dir.Z)
	if dl < 1e-6 then
		return false, dist
	end
	local cos = (dx * dir.X + dy * dir.Y + dz * dir.Z) / (dist * dl)
	return cos >= math.cos(math.rad(halfAngleDeg)), dist
end

-- Speed multiplier for a Phantom caught in `beams` lantern beams (stacking, capped).
function Lantern.speedFactor(beams: number, cfg): number
	return 1 - math.min(cfg.slowCap, math.max(0, beams) * cfg.slowPerBeam)
end

-- Battery after dt seconds; the lantern switches itself off at 0. Returns (battery, on).
function Lantern.drain(battery: number, dt: number, on: boolean, cfg): (number, boolean)
	if not on then
		return battery, false
	end
	local b = math.max(0, battery - dt * cfg.drainPerSecond)
	return b, b > 0
end

function Lantern.recharge(battery: number, cfg): number
	return math.min(cfg.batteryMax, battery + cfg.dryCellCharge)
end

-- Validates a client aim vector: finite, non-zero; returns a unit (x, y, z) or nil.
function Lantern.cleanAim(x: any, y: any, z: any): (number?, number?, number?)
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
		return nil, nil, nil
	end
	if x ~= x or y ~= y or z ~= z or math.abs(x) == math.huge or math.abs(y) == math.huge or math.abs(z) == math.huge then
		return nil, nil, nil
	end
	local l = math.sqrt(x * x + y * y + z * z)
	if l < 1e-3 then
		return nil, nil, nil
	end
	return x / l, y / l, z / l
end

return Lantern
