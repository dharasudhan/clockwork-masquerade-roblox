-- Saved player data (ProfileStore template, v3 - v1.1 business pass). Safe defaults: every
-- key has one. Dictionaries keyed by ids (Owned, Badges, Purchases) start empty; SaveData.sanitize
-- keeps unknown keys and fills missing ones, so v2 saves migrate cleanly (Quests/Season/
-- StarterPackBought are added by the sanitiser on first load).
return {
	Version = 3,
	GearTokens = 0,
	XP = 0,
	Level = 1,
	Wins = { Guest = 0, Phantom = 0 },
	Played = 0,
	Settings = { Music = true, Sfx = true, Hints = true },
	IntroSeen = false,
	TutorialDone = false,
	Class = "Mechanist",
	Daily = { LastDay = 0, Streak = 0 },
	Owned = {},
	Equipped = { Mask = "mask_brass", Lantern = "lantern_brass", Trail = "trail_spark", Emote = "emote_wave" },
	Badges = {},
	Stats = { Repairs = 0, Exposes = 0, Keys = 0, Pages = 0, Tags = 0 },
	Purchases = {}, -- receipt PurchaseId -> os.time() (idempotent ProcessReceipt)
	-- v1.1: daily/weekly quests (Day/Week = unix day / week id the lists belong to)
	Quests = { Day = 0, Daily = {}, Week = 0, Weekly = {} },
	-- v1.1: season track (Id = Config/Season id while a season is active, "" otherwise)
	Season = { Id = "", XP = 0, Tier = 1, Premium = false },
	-- v1.1: one-time Guest's Starter Trunk already bought
	StarterPackBought = false,
}
