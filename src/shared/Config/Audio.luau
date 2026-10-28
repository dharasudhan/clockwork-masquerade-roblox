-- Music + sound effects (pure data, asset ids as numbers; the client builds Sounds).
-- ONLY ids already verified in Ghost Mansion's Config/Audio (free Roblox-licensed library:
-- APMOfficial music / Roblox UI sounds; IsPublicDomain checked, PreloadAsync Success +
-- TimeLength > 0 in a real server). Re-verified for this place by tests/audio_check.server.luau.
-- Nothing uploaded, nothing bought.
local function cue(id, name, volume, opts)
	local c = { id = id, name = name, volume = volume, creator = "APMOfficial" }
	for k, v in opts or {} do
		c[k] = v
	end
	return c
end

return {
	Music = {
		-- light, sneaky phonograph-style bed for the terrace lobby and the Day scavenge
		Lobby = cue(1837467266, "Sneaky Ghost", 0.3, { looped = true }),
		Day = cue(1837467266, "Sneaky Ghost", 0.25, { looped = true }),
		-- tense chase bed for the Night
		Night = cue(1835183577, "Stalking the Prey Main", 0.4, { looped = true }),
	},
	Sfx = {
		Click = cue(15675032796, "Roblox_UI_Small_Click", 0.5, { creator = "Roblox" }),
		NightStart = cue(1845411462, "Hollow Gong", 0.55, { maxSeconds = 6 }),
		Dawn = cue(1840004224, "Twinkle (a 30)", 0.5, { maxSeconds = 7 }),
		Tamper = cue(1846269128, "Gong", 0.5, { maxSeconds = 4 }),
		Repair = cue(1837718092, "Thermals (sting)", 0.55),
		Chest = cue(15675046931, "Roblox_UI_Sweep", 0.6, { creator = "Roblox" }),
		Tag = cue(9042217497, "Octagon (sting b)", 0.6, { maxSeconds = 3 }),
		Wisp = cue(15674975792, "Roblox_UI_Whoosh_03", 0.6, { creator = "Roblox" }),
		Win = cue(1836473398, "Victory Fanfare Sting", 0.7, { maxSeconds = 8 }),
		Lose = cue(1840410813, "For Whom The Bell Tolls (B)", 0.6, { maxSeconds = 6 }),
		Tokens = cue(127645268874265, "CoinTransfer_01", 0.6, { creator = "Roblox" }),
	},
	MusicFadeSeconds = 1.2,
}
