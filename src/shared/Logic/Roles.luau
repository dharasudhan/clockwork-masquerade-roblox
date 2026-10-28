-- Role assignment (pure, no requires). Phantoms per participant count come from
-- Config/Match.PhantomTable (1 at <= 6, 2 at 7-10). Anyone who was a Phantom last round goes
-- to the back of the queue, so the same person is not picked twice in a row when avoidable.
local Roles = {}

function Roles.phantomCount(n: number, tbl: { { upTo: number, count: number } }): number
	if n <= 1 then
		return 0
	end
	for _, row in tbl do
		if n <= row.upTo then
			return math.min(row.count, n - 1)
		end
	end
	return math.min(tbl[#tbl].count, n - 1)
end

-- ids: array of participant ids; recent: set of ids that were Phantom last round;
-- rng(): number in [0, 1). Returns { [id] = "Phantom" | "Guest" }.
function Roles.assign(ids: { string }, count: number, rng: () -> number, recent: { [string]: boolean }?)
	local order = {}
	for _, id in ids do
		table.insert(order, { id = id, key = (if recent and recent[id] then 1 else 0) + rng() * 0.999 })
	end
	table.sort(order, function(a, b)
		return a.key < b.key
	end)
	local roles = {}
	for i, e in order do
		roles[e.id] = if i <= count then "Phantom" else "Guest"
	end
	return roles
end

-- How many bots join so the match has at least `min` participants (never above `max`).
function Roles.botsNeeded(humans: number, min: number, max: number): number
	return math.max(0, math.min(max, min) - humans)
end

return Roles
