-- Chest stocking + loot rolls + carried items (pure). rng() returns [0, 1).
local Loot = {}

function Loot.roll(table_: { { id: string, weight: number } }, r: number): string
	local total = 0
	for _, e in table_ do
		total += e.weight
	end
	local x = r * total
	for _, e in table_ do
		x -= e.weight
		if x < 0 then
			return e.id
		end
	end
	return table_[#table_].id
end

-- Picks `count` distinct spot indexes out of 1..n (partial Fisher-Yates).
function Loot.pickSpots(n: number, count: number, rng: () -> number): { number }
	local idx = {}
	for i = 1, n do
		idx[i] = i
	end
	local out = {}
	for i = 1, math.min(count, n) do
		local j = i + math.floor(rng() * (n - i + 1))
		j = math.clamp(j, i, n)
		idx[i], idx[j] = idx[j], idx[i]
		table.insert(out, idx[i])
	end
	return out
end

-- Adds one item if under its cap. Returns true when added.
function Loot.add(inv: { [string]: number }, item: string, caps: { [string]: number }): boolean
	local cap = caps[item]
	if cap == nil then
		return false
	end
	local have = inv[item] or 0
	if have >= cap then
		return false
	end
	inv[item] = have + 1
	return true
end

function Loot.take(inv: { [string]: number }, item: string): boolean
	if (inv[item] or 0) <= 0 then
		return false
	end
	inv[item] -= 1
	return true
end

return Loot
