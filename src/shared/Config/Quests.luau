-- Quests (pure data): daily + weekly objectives that pay Gear Tokens (cosmetic currency).
-- UPGRADE (v1.1 business pass): gives players a reason to start a session (daily) and to come
-- back mid-week (weekly), beyond the login streak. All goals use match stats the server
-- already tracks (p.stats) or match-level facts (played/won/friend), so there is no new
-- gameplay surface to balance.
--   stat: the key in the `gains` table built by Logic/Quests.gains per finished match.
return {
	DailyCount = 3,
	DailyPool = {
		{ id = "daily_play", text = "Attend the masquerade (play a match)", stat = "matches", goal = 1, tokens = 15 },
		{ id = "daily_chests", text = "Open 4 chests", stat = "chests", goal = 4, tokens = 20 },
		{ id = "daily_repair", text = "Repair 2 breakers", stat = "repairs", goal = 2, tokens = 25 },
		{ id = "daily_expose", text = "Cast an Expose vote", stat = "exposes", goal = 1, tokens = 15 },
		{ id = "daily_tag", text = "Tag a guest as a Phantom", stat = "tags", goal = 1, tokens = 25 },
		{ id = "daily_night", text = "Help your side win a night", stat = "nights", goal = 1, tokens = 20 },
	},
	WeeklyCount = 2,
	WeeklyPool = {
		{ id = "weekly_matches", text = "Play 6 matches", stat = "matches", goal = 6, tokens = 80 },
		{ id = "weekly_repair", text = "Repair 10 breakers", stat = "repairs", goal = 10, tokens = 100 },
		{ id = "weekly_win", text = "Win 2 matches", stat = "wins", goal = 2, tokens = 120 },
		{ id = "weekly_friend", text = "Play 3 matches with a Roblox friend", stat = "friendMatches", goal = 3, tokens = 100 },
		{ id = "weekly_nights", text = "Win 6 nights", stat = "nights", goal = 6, tokens = 90 },
	},
	-- Co-play bonus: playing a match with at least CoPlayMinHumans humans in the server
	-- multiplies the match's Gear Tokens by CoPlayTokenFactor (applied after the cap, like
	-- the 2x pass). Drives social sessions without requiring friendship checks.
	Social = {
		CoPlayMinHumans = 2,
		CoPlayTokenFactor = 1.1, -- +10% for every human in a co-played match
	},
}
