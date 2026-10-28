-- Breakers, cooperative repair and the reboot meter (pure).
local Grid = {}

function Grid.new(ids: { string })
	local s = { breakers = {}, order = {}, tampers = 0, reboot = 0 }
	for _, id in ids do
		s.breakers[id] = { id = id, tampered = false, repair = 0 }
		table.insert(s.order, id)
	end
	return s
end

function Grid.canTamper(s, id: string, maxTampers: number): boolean
	local b = s.breakers[id]
	return b ~= nil and not b.tampered and s.tampers < maxTampers
end

function Grid.tamper(s, id: string, maxTampers: number): boolean
	if not Grid.canTamper(s, id, maxTampers) then
		return false
	end
	local b = s.breakers[id]
	b.tampered = true
	b.repair = 0
	s.tampers += 1
	return true
end

-- Adds repair progress (fraction of a full repair). Returns true when this call finished it.
function Grid.addRepair(s, id: string, fraction: number): boolean
	local b = s.breakers[id]
	if b == nil or not b.tampered then
		return false
	end
	b.repair = math.min(1, b.repair + math.max(0, fraction))
	if b.repair >= 1 then
		b.tampered = false
		b.repair = 0
		return true
	end
	return false
end

function Grid.online(s): (number, number)
	local on, total = 0, 0
	for _, id in s.order do
		total += 1
		if not s.breakers[id].tampered then
			on += 1
		end
	end
	return on, total
end

-- Reboot % per second of night: 100 / fullSeconds with every breaker online.
function Grid.rebootRate(online: number, total: number, fullSeconds: number): number
	if total <= 0 then
		return 0
	end
	return (online / total) * 100 / fullSeconds
end

function Grid.stepReboot(s, dt: number, fullSeconds: number): number
	local on, total = Grid.online(s)
	s.reboot = math.min(100, s.reboot + dt * Grid.rebootRate(on, total, fullSeconds))
	return s.reboot
end

-- Latest second of the night a single tampered breaker can be repaired and still reach 100%.
function Grid.repairDeadline(total: number, nightSeconds: number, fullSeconds: number): number
	-- (total-1)/total * t + (night - t) >= full  ->  t <= (night - full) * total
	return math.min(nightSeconds, (nightSeconds - fullSeconds) * total)
end

return Grid
