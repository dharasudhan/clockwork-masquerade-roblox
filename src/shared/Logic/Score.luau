-- v1.6.1 mid-match scoreboard (pure, unit-tested). The server encodes the current match
-- standings into ONE workspace attribute (CM_Score) so every client can draw the panel
-- without any per-player replication:
--   "name~ribbon~state~repairs~chests|name~ribbon~state~repairs~chests|..."
--   * sorted by contribution: repairs + chests desc, name asc as the tie-break
--   * capped at MaxEntries (a full server is 12)
--   * ROLE-SAFE BY CONSTRUCTION: the entry carries name, ribbon, alive state and the two
--     contribution counters - never the role, never the tag count.
--   * v1.6 review fix (Hark): only Guests can repair breakers (GridService), so a live repair
--     count would clear every repairing guest for the whole server and narrow the Expose vote.
--     Score.entriesFor() therefore sends repairs = 0 until the Results phase, and the public
--     state is only "In play" / "Wisp" (Phantoms and guests both read "In play"). Chests are
--     safe: Phantoms open chests by day too and get decoy loot (ChestService).
local Score = {}

Score.MaxEntries = 12
Score.Attribute = "CM_Score"

export type Entry = { name: string, ribbon: string, state: string, repairs: number, chests: number }

-- Strip the codec's separators from a free-text field (display names/ribbons are player input).
local function clean(s: any): string
	if type(s) ~= "string" then
		return "?"
	end
	s = string.gsub(s, "[~|]", "")
	if s == "" then
		return "?"
	end
	return s
end

-- Sort in place: contribution desc (repairs + chests), name asc tie-break.
function Score.sort(entries: { Entry })
	table.sort(entries, function(a, b)
		local sa, sb = a.repairs + a.chests, b.repairs + b.chests
		if sa ~= sb then
			return sa > sb
		end
		return a.name < b.name
	end)
end

-- Encode up to MaxEntries entries (input not mutated; sorts a copy).
function Score.encode(entries: { Entry }): string
	local copy = {}
	for _, e in entries or {} do
		table.insert(copy, e)
	end
	Score.sort(copy)
	local parts = {}
	for i = 1, math.min(Score.MaxEntries, #copy) do
		local e = copy[i]
		parts[i] = table.concat({
			clean(e.name),
			clean(e.ribbon),
			clean(e.state),
			tostring(math.floor(tonumber(e.repairs) or 0)),
			tostring(math.floor(tonumber(e.chests) or 0)),
		}, "~")
	end
	return table.concat(parts, "|")
end

-- Build scoreboard entries from match participants ({ name, ribbon, state, stats }).
-- reveal = true only in Results (every role is shown then anyway): repairs are sent.
function Score.entriesFor(participants: { any }, reveal: boolean?): { Entry }
	local out = {}
	for _, p in participants or {} do
		local st = p.state
		local stats = p.stats or {}
		table.insert(out, {
			name = tostring(p.name or "?"),
			ribbon = tostring(p.ribbon or "?"),
			state = if st == "Wisp" or st == "Bubble" then "Wisp" else "In play",
			repairs = if reveal then (tonumber(stats.repairs) or 0) else 0,
			chests = tonumber(stats.chests) or 0,
		})
	end
	return out
end

-- Decode an attribute string back into entries (already in sorted order). Tolerates junk.
function Score.decode(s: any): { Entry }
	local out = {}
	if type(s) ~= "string" or s == "" then
		return out
	end
	for _, part in string.split(s, "|") do
		if part == "" then
			continue
		end
		local f = string.split(part, "~")
		table.insert(out, {
			name = if f[1] and f[1] ~= "" then f[1] else "?",
			ribbon = f[2] or "?",
			state = f[3] or "?",
			repairs = tonumber(f[4]) or 0,
			chests = tonumber(f[5]) or 0,
		})
	end
	return out
end

return Score
