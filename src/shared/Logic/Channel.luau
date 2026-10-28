-- Stationary channels (tamper by day, repair by night). Pure: the server feeds positions.
-- A channel is cancelled when its actor drifts more than `tolerance` studs from where it
-- started or leaves `range` of the target.
local Channel = {}

function Channel.new(actor: string, target: string, x: number, z: number, now: number)
	return { actor = actor, target = target, x = x, z = z, startedAt = now, elapsed = 0 }
end

local function dist2(ax, az, bx, bz)
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

-- Returns "running" | "cancelled". pos = actor x, z now; tx, tz = target position.
function Channel.check(ch, x: number, z: number, tx: number, tz: number, tolerance: number, range: number): string
	if dist2(x, z, ch.x, ch.z) > tolerance then
		return "cancelled"
	end
	if dist2(x, z, tx, tz) > range then
		return "cancelled"
	end
	return "running"
end

function Channel.advance(ch, dt: number, duration: number): boolean
	ch.elapsed += dt
	return ch.elapsed >= duration - 1e-6
end

return Channel
