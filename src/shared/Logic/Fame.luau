-- v1.6.1 Hall of Fame (pure, unit-tested). The all-time leaderboard on the lobby board:
-- total match WINS per player, top 10. The server keeps the scores in an OrderedDataStore
-- (FameService); this module is the sorting, clamping and formatting so the board painting
-- and the tests share one code path.
--   * sort: wins desc, name asc as the tie-break (stable, deterministic for tests)
--   * names clamp to 14 chars so long display names never break the board layout
local Fame = {}

Fame.MaxRows = 10 -- rows on the board
Fame.MaxName = 14 -- chars before the ellipsis

export type Entry = { name: string, wins: number }

-- Top `limit` entries: wins desc, then name asc. Does not mutate the input.
function Fame.sortTop(entries: { Entry }, limit: number?): { Entry }
	local out = {}
	for _, e in entries or {} do
		if type(e) == "table" and type(e.name) == "string" and type(e.wins) == "number" then
			table.insert(out, { name = e.name, wins = e.wins })
		end
	end
	table.sort(out, function(a, b)
		if a.wins ~= b.wins then
			return a.wins > b.wins
		end
		return a.name < b.name
	end)
	local n = math.min(limit or Fame.MaxRows, #out)
	local top = {}
	for i = 1, n do
		top[i] = out[i]
	end
	return top
end

-- Clamp a display name to MaxName chars, ellipsized. Tolerates nil / non-strings.
function Fame.clampName(name: any): string
	if type(name) ~= "string" or name == "" then
		return "?"
	end
	if #name <= Fame.MaxName then
		return name
	end
	return string.sub(name, 1, Fame.MaxName - 1) .. "…"
end

-- One board row: " 1. Name — 12".
function Fame.line(rank: number, name: any, wins: number): string
	return string.format("%2d. %s — %d", rank, Fame.clampName(name), wins)
end

-- All board rows for the top entries (Fame.line per row, rank from position).
function Fame.lines(entries: { Entry }, limit: number?): { string }
	local out = {}
	for i, e in Fame.sortTop(entries, limit) do
		out[i] = Fame.line(i, e.name, e.wins)
	end
	return out
end

return Fame
