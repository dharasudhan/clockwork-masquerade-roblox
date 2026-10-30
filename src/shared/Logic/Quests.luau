-- Quest maths (pure, no requires - unit-tested under Lune).
-- A player's save holds Quests = { Day, Daily = {quest...}, Week, Weekly = {quest...} } where each
-- quest is { id, text, stat, goal, tokens, progress, done }. This module picks the active
-- quests deterministically per day/week and applies per-match gains.
local Quests = {}

-- Week id for a unix day (Thursday-aligned weeks are a Roblox convention; simple 7-day
-- buckets are fine for quests because nothing is displayed calendar-wise).
function Quests.weekOf(today: number): number
	return math.floor(today / 7)
end

-- Deterministic selection: rotate the pool by the seed (day or week number) and take the
-- first `count` entries. Same day -> same quests for everyone; no RNG, unit-testable.
function Quests.pick(pool, count: number, seed: number): { { [string]: any } }
	local n = #pool
	local out = {}
	for i = 1, math.min(count, n) do
		local def = pool[((seed + i - 1) % n) + 1]
		table.insert(out, {
			id = def.id,
			text = def.text,
			stat = def.stat,
			goal = def.goal,
			tokens = def.tokens,
			progress = 0,
			done = false,
		})
	end
	return out
end

-- Per-match gains keyed by the stat names used in Config/Quests pools.
function Quests.gains(stats, won: boolean, withFriend: boolean): { [string]: number }
	return {
		matches = 1,
		wins = if won then 1 else 0,
		chests = stats.chests or 0,
		repairs = stats.repairs or 0,
		tags = stats.tags or 0,
		exposes = stats.exposes or 0,
		nights = stats.nightsWon or 0,
		keys = stats.keys or 0,
		pages = stats.pages or 0,
		friendMatches = if withFriend then 1 else 0,
	}
end

-- Apply one match to a quest list; mutates progress/done. Returns events:
--   { completed = true, tokens } when a quest finished this match, else { progress, goal }.
function Quests.apply(list, gains: { [string]: number }): { { [string]: any } }
	local events = {}
	for _, q in list do
		if not q.done then
			local g = gains[q.stat]
			if type(g) == "number" and g > 0 then
				local before = q.progress
				q.progress = math.min(q.goal, q.progress + g)
				if q.progress >= q.goal then
					q.done = true
					table.insert(events, { id = q.id, text = q.text, completed = true, tokens = q.tokens })
				elseif q.progress ~= before then
					table.insert(events, { id = q.id, text = q.text, progress = q.progress, goal = q.goal })
				end
			end
		end
	end
	return events
end

-- Total token payout of a batch of events (completed quests only).
function Quests.tokensFrom(events: { { [string]: any } }): number
	local total = 0
	for _, e in events do
		if e.completed then
			total += e.tokens or 0
		end
	end
	return total
end

-- Flat summary for attributes / the client quest tab.
function Quests.summary(list): { string }
	local out = {}
	for _, q in list do
		table.insert(out, string.format("%s:%d/%d:%s", q.id, q.progress, q.goal, q.done and "1" or "0"))
	end
	return out
end

return Quests
