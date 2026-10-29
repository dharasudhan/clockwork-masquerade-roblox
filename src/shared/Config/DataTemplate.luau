-- Saved player data (ProfileStore template, v2). Safe defaults: every key has one. Dictionaries
-- keyed by ids (Owned, Badges, Purchases) start empty; SaveData.sanitize keeps unknown keys.
return {
	Version = 2,
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
}
